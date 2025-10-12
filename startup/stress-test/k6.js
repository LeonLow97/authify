import http from 'k6/http';
import { check, sleep } from 'k6';

const BASE_URL = 'http://localhost:8080'; // 👈 REPLACE with your actual base URL
const payload = JSON.stringify({
  email: 'lowjiewei@email.com',
  password: 'Password123!',
});

const params = {
  headers: {
    'Content-Type': 'application/json',
  },
};

export const options = {
  // Scenario: 1000 VUs ramping up instantly over 1s
  scenarios: {
    login_stress: {
      executor: 'constant-vus',
      vus: 200,
      duration: '5s',
      gracefulStop: '0s', // Stop immediately after 1s
    },
  },

  // Optional: thresholds for pass/fail criteria
  //   thresholds: {
  //     http_req_duration: ['p(95) < 500'], // 95% of requests should finish under 500ms
  //     http_req_failed: ['rate < 0.01'], // Error rate < 1%
  //   },
};

export default function () {
  const res = http.post(`${BASE_URL}/api/v1/login`, payload, params);

  // Check if response is OK (status 200-299)
  check(res, {
    'status is 200': (r) => r.status === 200,
    'transaction time < 1s': (r) => r.timings.duration < 1000,
  });

  // Optional: add small delay to avoid overwhelming client-side (not needed for pure stress)
  // sleep(0.1);
}
