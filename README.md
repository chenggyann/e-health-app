# CareFlow E-Health

CareFlow is a model-driven patient e-health Flutter app generated from the MDE artifacts in [docs/mde](./docs/mde). It uses the class, state, sequence, and ER models as the source for a patient portal experience.

## Features

- Family profile switching and care goals
- Appointment booking, check-in, and video-visit actions
- Medication tracking and refill requests
- Test result review and follow-up status
- Remote vital recording with alert generation
- Secure message triage with urgent escalation
- Care plan tasks, billing, care access, and record sharing surfaces
- Supabase persistence with shared_preferences fallback

## App Stack

- Flutter 3.41 / Dart 3.11
- Supabase Flutter client
- shared_preferences offline fallback
- Material 3 responsive UI
- Vercel static hosting of the Flutter web release bundle

## Local Development

Install Flutter, then run:

```bash
cd flutter_app
flutter pub get
flutter run -d chrome
```

Build for web:

```bash
cd flutter_app
flutter build web --release
```

This workspace was verified with a local Flutter SDK at `.tooling/flutter`, but that SDK is intentionally not committed.

## Supabase Setup

Run [supabase/schema.sql](./supabase/schema.sql) in the Supabase SQL editor for project `ktbpsliejglodmonmzhs` before expecting persistent storage. Until the schema exists, the app automatically uses local browser storage so the deployed demo remains usable.

The included policies allow anonymous demo access. For a real healthcare deployment, replace them with authenticated row-level security policies and do not expose clinical records publicly.

## MDE Traceability

| Model artifact | App implementation |
| --- | --- |
| Class diagram | Flutter data model maps and Supabase tables |
| State diagrams | Appointment state transitions and alert/message workflows |
| Sequence diagrams | Booking, medication refill, vitals-to-alerts, secure messaging |
| ER diagram | `supabase/schema.sql` |
| Invariants | Valid appointment actions, vital alert thresholds, urgent message triage |

## Deployment

Vercel serves the committed Flutter web release bundle from `flutter_app/build/web`.

When changing Flutter code:

```bash
cd flutter_app
flutter build web --release
```

Then commit both the Flutter source and updated `flutter_app/build/web` output.
