// k6 load for the notes API.  MODE=read|write|mixed  JVM=<name>  VUS=100  DUR=10m  N=<seeded rows>
import http from 'k6/http';
import { check } from 'k6';

const BASE = __ENV.TARGET, MODE = __ENV.MODE, N = +(__ENV.N || 200000);
const TAGS = ['java', 'spring', 'postgres', 'k6', 'grafana', 'docker', 'linux', 'jvm'];
const H = { headers: { 'Content-Type': 'application/json' } };

export const options = {
  scenarios: { [MODE]: { executor: 'constant-vus', vus: +(__ENV.VUS || 100), duration: __ENV.DUR || '10m' } },
  tags: { jvm: __ENV.JVM, mode: MODE },
  discardResponseBodies: true,
  summaryTrendStats: ['avg', 'p(50)', 'p(95)', 'p(99)', 'max'],
  // no `url` tag: every /notes/{id} would become its own Prometheus series
  systemTags: ['status', 'method', 'name', 'scenario', 'expected_response', 'check'],
};

const id = () => 1 + Math.floor(Math.random() * N);
const tag = () => TAGS[Math.floor(Math.random() * TAGS.length)];
const note = () => JSON.stringify({ title: `Note ${id()} about ${tag()}`, body: 'Written by k6 during the JVM test. '.repeat(4), tag: tag() });

function read() {
  if (Math.random() < 0.7) check(http.get(`${BASE}/notes/${id()}`, { tags: { name: 'GET /notes/{id}' } }), { ok: (r) => r.status === 200 });
  else check(http.get(`${BASE}/notes?tag=${tag()}`, { tags: { name: 'GET /notes?tag' } }), { ok: (r) => r.status === 200 });
}
function write() {
  if (Math.random() < 0.5) check(http.post(`${BASE}/notes`, note(), { ...H, tags: { name: 'POST /notes' } }), { ok: (r) => r.status === 201 });
  else check(http.put(`${BASE}/notes/${id()}`, note(), { ...H, tags: { name: 'PUT /notes/{id}' } }), { ok: (r) => r.status === 200 });
}
export default function () {
  if (MODE === 'read') read();
  else if (MODE === 'write') write();
  else Math.random() < 0.8 ? read() : write();
}
