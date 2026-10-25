# Sentinel: API Health, Latency & Uptime Telemetry Platform

**Production-grade API health, latency, and uptime telemetry platform designed for high-throughput observability.**

- **Project Path:** [`/home/onyx/Projects/sentinel`](file:///home/onyx/Projects/sentinel)
- **Architecture:** Fastify backend (TypeScript/Node.js) + React 18 / Tailwind frontend + PostgreSQL 16 + Redis telemetry cache.
- **Repository:** [`https://github.com/kmanisk/sentinel`](https://github.com/kmanisk/sentinel)
- **Deployment:** Fully containerized multi-stage Docker builds with Nginx reverse proxy routing and WebSocket streaming.

---

## 1. Overview & Core Features

Sentinel provides enterprise-grade infrastructure monitoring with low resource overhead:
- **Asynchronous Probing:** High-frequency HTTP, TCP, and ICMP network probes with custom payload assertions and timeout controls.
- **Real-Time Telemetry:** Live WebSocket telemetry pushes latency distributions and status changes directly to the dashboard.
- **Rolling SLA Calculations:** Computes rolling uptime percentages, percentile latencies (p50, p95, p99), and MTTR.
- **Anti-Flap Tracking:** Intelligent incident management preventing alerting storms during intermittent flapping states.
- **Multi-Channel Alerting:** Webhook integrations for Discord, Slack, PagerDuty, and email.

---

## 2. Docker & Local Deployment

```bash
cd /home/onyx/Projects/sentinel

# Start full stack (Nginx, API server, client, PostgreSQL, Redis)
docker compose up -d

# Check service logs
docker compose logs -f
```

---

## 3. Architecture & Repository Documentation

- [Upstream Repository README](./source-README.md)
