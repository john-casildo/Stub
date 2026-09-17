import http from 'k6/http';
import { check } from 'k6';
import { SharedArray } from 'k6/data';

const BASE_URL = __ENV.BASE_URL || 'http://localhost:3000';

const users = new SharedArray('users', function () {
  return JSON.parse(open('../seed/output/users.json'));
});

const FULL_STAGES = [
  { target: 500, duration: '60s' },
  { target: 1200, duration: '60s' },
  { target: 2417, duration: '60s' },
  { target: 2417, duration: '60s' }, // peak minute: ~145,020 requests
  { target: 1200, duration: '60s' },
  { target: 500, duration: '60s' },
  { target: 0, duration: '60s' },
];

export const options = {
  scenarios: {
    stub_traffic: __ENV.SMOKE === '1'
      ? {
          executor: 'constant-arrival-rate',
          rate: 5,
          timeUnit: '1s',
          duration: '15s',
          preAllocatedVUs: 10,
          maxVUs: 20,
        }
      : {
          executor: 'ramping-arrival-rate',
          startRate: 0,
          timeUnit: '1s',
          // Real-run diagnosis (2026-09-16): the original 300/1000 here
          // wasn't enough VU headroom for this API's real per-request
          // latency under load (avg ~3.1s), so k6 dropped ~3.5x more
          // iterations than it completed (383,273 dropped vs. 110,766
          // completed) even though every request that did go out
          // succeeded (0% http_req_failed). Raising it to 2000/8000
          // to chase that shortfall made things categorically worse, not
          // better: it exposed a real server-side bug (server/src/db.ts's
          // `pg.Pool` defaulting to `max: 10` DB connections, with no
          // error handler on the pool) as a thundering-herd collapse —
          // 93.28% of requests failed/timed out and the API container
          // crashed and was auto-restarted mid-run. That root cause is
          // now fixed server-side (pool `max` raised to 80, see
          // db.ts) — with real per-request latency back down near
          // baseline, a moderate VU ceiling should be plenty; this is
          // set higher than the original 1000 only as a safety margin,
          // not because that much concurrency is expected to be needed.
          preAllocatedVUs: 500,
          maxVUs: 2000,
          stages: FULL_STAGES,
        },
  },
};

function randomUser() {
  return users[Math.floor(Math.random() * users.length)];
}

function authHeaders(token) {
  return { headers: { Authorization: `Bearer ${token}` } };
}

export default function () {
  const user = randomUser();
  const roll = Math.random() * 100;

  if (roll < 45) {
    const offset = Math.floor(Math.random() * 500);
    const res = http.get(`${BASE_URL}/transactions?limit=50&offset=${offset}`, authHeaders(user.token));
    check(res, { 'transactions 200': (r) => r.status === 200 });
  } else if (roll < 70) {
    const res = http.get(`${BASE_URL}/budgets`, authHeaders(user.token));
    check(res, { 'budgets 200': (r) => r.status === 200 });
  } else if (roll < 85) {
    const res = http.get(`${BASE_URL}/categories`, authHeaders(user.token));
    check(res, { 'categories 200': (r) => r.status === 200 });
  } else if (roll < 95) {
    const categoryId = user.categoryIds[Math.floor(Math.random() * user.categoryIds.length)];
    const payload = JSON.stringify({
      categoryId,
      merchant: 'Load Test Merchant',
      amount: Math.round((Math.random() * 200 + 2) * 100) / 100,
      source: 'manual',
      occurredAt: new Date().toISOString(),
    });
    const res = http.post(`${BASE_URL}/transactions`, payload, {
      headers: { Authorization: `Bearer ${user.token}`, 'Content-Type': 'application/json' },
    });
    check(res, { 'transaction created': (r) => r.status === 201 });
  } else {
    const res = http.get(`${BASE_URL}/account`, authHeaders(user.token));
    check(res, { 'account 200': (r) => r.status === 200 });
  }
}
