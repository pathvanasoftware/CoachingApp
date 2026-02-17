# CoachingApp

## Local backend (stable path)

Use repo-local backend path (avoid deleted agent temp paths):

```bash
cd /Users/jianpinghuang/projects/CoachingApp
./scripts/start_backend.sh
```

Expected API base URL:

- `http://localhost:8000/api/v1`

### Coaching styles (backend)

`POST /api/v1/chat/` now supports optional `coaching_style`:
- `directive`
- `facilitative`
- `supportive`
- `strategic`

If omitted, style is auto-routed from user text + emotion signal.


A modern coaching application.

## Overview

This project provides a platform for coaching and mentorship.

## Getting Started

### Prerequisites

- Node.js 18+
- npm or yarn

### Installation

```bash
npm install
```

### Development

```bash
npm run dev
```

## Features

- Feature 1
- Feature 2
- Feature 3

## Tech Stack

- Frontend: TBD
- Backend: TBD
- Database: TBD

## Contributing

Contributions are welcome! Please read our contributing guidelines.

## License

MIT
