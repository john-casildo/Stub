import http from 'k6/http';
import { check } from 'k6';
import { SharedArray } from 'k6/data';

const BASE_URL = __ENV.BASE_URL || 'http://localhost:3000';

const users = new SharedArray('users', function () {
  return JSON.parse(open('../seed/output/users.json'));
});

// Exploratory 15-minute variant of scenario.js's 7-minute assignment
// profile — same ramp shape, just a longer peak hold (9 minutes instead
// of 1) to gather more data on this local setup's sustained real
// throughput ceiling. Not the assignment deliverable; scenario.js stays
// the official 7-minute/~493,020-request profile.
const FULL_STAGES = [
  { target: 500, duration: '60s' },
  { target: 1200, duration: '60s' },
  { target: 2417, duration: '60s' },
  { target: 2417, duration: '60s' },
  { target: 2417, duration: '60s' },
  { target: 2417, duration: '60s' },
  { target: 2417, duration: '60s' },
  { target: 2417, duration: '60s' },
  { target: 2417, duration: '60s' },
  { target: 2417, duration: '60s' },
  { target: 2417, duration: '60s' }, // 9 minutes held at peak
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
