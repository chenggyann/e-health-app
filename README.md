# CareFlow E-Health

CareFlow is a model-driven e-health demo application generated from the MDE artifacts in [docs/mde](./docs/mde). The app demonstrates how class, state, sequence, and ER models can be transformed into a working care coordination system.

## Features

- Patient roster and care goals
- Appointment booking with state-machine transitions
- Encounter workflow with sign-off states
- Prescription creation
- Lab orders and critical-result alerts
- Remote vital recording with alert generation
- Secure message triage with urgent escalation
- Audit event capture
- Supabase persistence with browser-storage fallback

## Local Development

```bash
npm install
npm run dev
```

The app uses these public Supabase values by default:

- URL: `https://ktbpsliejglodmonmzhs.supabase.co`
- Anon key: configured in `src/lib/supabase.js`

You can override them with:

```bash
VITE_SUPABASE_URL=...
VITE_SUPABASE_ANON_KEY=...
```

## Supabase Setup

Run [supabase/schema.sql](./supabase/schema.sql) in the Supabase SQL editor for the project before expecting persistent storage. Until the schema exists, the app automatically uses browser storage so the deployed demo remains usable.

The included policies allow anonymous demo access. For a real healthcare deployment, replace them with authenticated row-level security policies and do not expose clinical records publicly.

## MDE Traceability

| Model artifact | App implementation |
| --- | --- |
| Class diagram | React state shape, Supabase tables, form boundaries |
| State diagrams | Appointment, encounter, alert, message workflow buttons |
| Sequence diagrams | Booking, consultation, prescribing, vitals, messaging flows |
| ER diagram | `supabase/schema.sql` |
| Invariants | Time-window checks, vital alert rules, status transitions |

## Deployment

The project is configured for Vercel as a Vite static app. Build output is written to `dist`.

```bash
npm run build
```
