import http from 'k6/http';
import { check } from 'k6';

const BASE_URL = 'http://localhost:8080';
const payload = JSON.stringify({
  email: 'lowjiewei@email.com',
  password: 'Password123!',
});

const params = {
  headers: { 'Content-Type': 'application/json' },
};

export const options = {
  scenarios: {
    login_stress: {
      executor: 'constant-arrival-rate',
      rate: 1000, // 1000 iterations (requests) per second
      timeUnit: '1s', // defines the rate as per second
      duration: '5s', // total test duration
      preAllocatedVUs: 50, // number of VUs to pre-allocate
      maxVUs: 100, // maximum VUs if k6 needs more
    },
  },
};

export default function () {
  const res = http.post(`${BASE_URL}/api/v1/login`, payload, params);

  check(res, {
    'status is 200': (r) => r.status === 200,
    'transaction time < 1s': (r) => r.timings.duration === 1000,
  });
}
