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
          // Real-run diagnosis (2026-09-16): under this local Docker API's
          // actual response latency at load (avg ~3.1s, p95 ~6.5s against
          // the 1.2M-row seeded dataset), sustaining the 2417 req/s peak
          // rate needs roughly rate * latency concurrent in-flight VUs —
          // on the order of several thousand, not the 1000 originally
          // configured here. With maxVUs: 1000, k6 ran out of VUs and had
          // to drop ~3.5x more iterations than it completed (383,273
          // dropped vs. 110,766 completed), producing a real total far
          // short of the ~493,020 target even though every request that
          // did go out succeeded (0% http_req_failed, 100% checks
          // passed) — a VU-pool-exhaustion problem, not a correctness or
          // server-error problem. Raised to give k6 enough headroom to
          // actually reach the target rate.
          preAllocatedVUs: 2000,
          maxVUs: 8000,
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
