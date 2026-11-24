import http from 'k6/http';
import { check, sleep } from 'k6';
import { UserDataProvider } from '../helpers/UserDataProvider.js';

const userData = new UserDataProvider('usuarios', import.meta.resolve('./data/users.csv'));

export const options = {
  stages: [
    { duration: '2m', target: 60 },
    { duration: '10m', target: 60 },
    { duration: '1m', target: 0 },
  ],
  thresholds: {
    http_req_duration: ['p(95)<1500', 'max<1500'],
    http_req_failed: ['rate<0.03'],
    http_reqs: ['rate>=20'],
    checks: ['rate>0.97'],
  },
};

const URL = 'https://fakestoreapi.com/auth/login';
const params = { headers: { 'Content-Type': 'application/json' } };

export default function () {
  const user = userData.getByVU();

  const payload = JSON.stringify({
    username: user.user,
    password: user.passwd,
  });

  const res = http.post(URL, payload, params);

  check(res, {
    'status es 201': (r) => r.status === 201,
    'respuesta contiene un token JWT': (r) => {
      try {
        const token = r.json('token');
        return typeof token === 'string' && token.split('.').length === 3;
      } catch (e) {
        return false;
      }
    },
    'tiempo de respuesta < 1.5s': (r) => r.timings.duration < 1500,
  });

  sleep(2);
}
