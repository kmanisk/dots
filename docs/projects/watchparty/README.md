# WatchParty (Afterglow)

**Self-hostable, low-overhead synchronized video playback room for friends, family, and watch parties.**

- **Project Path:** [`/home/onyx/Projects/watchparty`](file:///home/onyx/Projects/watchparty)
- **Architecture:** Fullstack TypeScript / Node.js with Vite + React 19 frontend and Express + Socket.IO backend.
- **Theme & Aesthetic:** Rosé Pine Moon palette, self-hosted Inter typography, CRT retro test card, ticket join flow, and live statusline.
- **Port Mapping:** Port 5173 (Vite dev proxy) / Port 3001 (Express & Socket.IO server).

---

## 1. Overview & Core Features

WatchParty ("Afterglow") enables real-time synchronized video playback across remote participants with millisecond-grade sync algorithms and zero database overhead:

- **Universal Video Sync:** Supports YouTube videos (via IFrame API) and direct MP4/WebM video streams (HTML5 video).
- **Sub-Second Drift Correction:** Socket.IO timestamp telemetry detects playback drift between host and participants; automatically soft-seeks when drift exceeds 1.5 seconds.
- **Zero Registration / Zero DB:** Rooms and session states exist entirely in-memory with automatic cleanup on room vacancy.
- **Integrated Live Chat:** Real-time ephemeral text messaging alongside synchronized media playback.
- **CRT Test Card & Ticket Flow:** Polished waiting room experience with retro TV test pattern and ticket invite code handling.

---

## 2. Quick Start & Development

```bash
cd /home/onyx/Projects/watchparty

# Install dependencies
npm ci

# Start development servers (Vite frontend on 5173 + Express backend on 3001)
npm run dev

# Run automated tests
npm run test
```

---

## 3. Architecture & Repository Documentation

- [Project Specification (`SPEC.md`)](./SPEC.md)
- [Design Brief & Interface Architecture (`DESIGN.md`)](./DESIGN.md)
- [Deployment & Production Hosting Guide (`DEPLOY.md`)](./DEPLOY.md)
- [Upstream Repository README](./source-README.md)
