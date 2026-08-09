# Kharcha — India's UPI Expense Tracker for Android

**by Akash Priyadarshi** · [github.com/AkashPriyadarshii](https://github.com/AkashPriyadarshii) · [akashpriyadarshi.vercel.app](https://akashpriyadarshi.vercel.app)

India-first UPI expense tracker for Android. Every UPI payment from GPay, PhonePe, or Paytm auto-appears as an expense — no manual entry. Offline-first, rule-based automation (no AI), Supabase sync. Built with Flutter/Dart, Drift/SQLite.

## 📲 Download

| | |
|---|---|
| **Latest release** | **v0.2.4** |
| **APK** | [`kharcha-armv8a-release.apk`](https://github.com/AkashPriyadarshii/kharcha/releases/latest/download/kharcha-armv8a-release.apk) (~25 MB) |
| **Requirements** | Android 12+ (arm64) |

**Install:** download the APK → open it → allow "Install unknown apps" if prompted → done. App auto-updates itself after that — every release is checked and offered in-app, no sideloading needed again.

## Product

- **Auto-capture** — reads UPI push notifications (GPay, PhonePe, Paytm) → parses amount/merchant/date → saves expense. Play-legal, no SMS permission.
- **Auto-categorization** — rule map: Swiggy→Food, Uber→Travel, Amazon→Shopping, Reliance→Grocery. Self-learns from user corrections.
- **Duplicate-safe** — `upi_ref` unique; notification + manual can never double-add.
- **9PM Hinglish daily summary** — "Aaj ₹540 kharcha hue." Weekly Sunday recap.
- **Offline-first** — Drift SQLite source of truth, works with zero network, syncs to Supabase when online.
- **Budget alerts** — 50/80/100% per-category.
- **App lock** — biometric/PIN.
- **Max tracking, never sold** — collects granular spend data (that's the product); data is never sold, never ad-targeted.

## What's new in v0.2.4

- **Home redesign** — a proper greeting with your name, Income vs Spent cards side by side, and a 6-month spend trend chart right on the dashboard.
- **Reports upgrade** — Income/Spent/Net at a glance; category pie now shows percentage labels.

## What's new in v0.2.3

- **Auto-update** — app checks for updates daily and installs them in one tap. No more manual APK hunting.
- **Home UX pass** — pencil button for one-tap access to categories, wallets, subscriptions & more; sign-out is confirm-gated now.
- **Name + app-lock fixes** — your name shows correctly after Google sign-in; the lock screen no longer traps you after a fingerprint.

## Tech stack

| Concern | Choice |
|---|---|
| Framework | Flutter, Android 12+ (minSdk 32) |
| UI | Material 3, Riverpod, go_router |
| Local DB | Drift (SQLite) |
| Backend | Supabase (Google Auth, Postgres, sync) |
| Charts | fl_chart |
| Notifications | flutter_local_notifications |
| App lock | local_auth |

## Getting started (developers)

```bash
flutter pub get
flutter analyze
flutter test test/update_checker_test.dart   # run test files individually — full suite crashes on Windows (sqlite3 bug)
flutter run          # on Android 12+ device/emulator
```

## Docs

- `CLAUDE.md` — team contract, standards, anti-slop rules
- `docs/prd.md` — product requirements
- `docs/design.md` — architecture, data model, design direction
- `docs/implementation-plan.md` — build order
- `docs/contributors.md` — who's who
- `docs/state.md` — current status
- `docs/handoff.md` — handoff notes
- `docs/changelog.md` — version history
- `docs/ponytail.md` — the ponytail method (coding philosophy, required reading)

## Team

- Akash (`AkashPriyadarshii`) — owner

## License

Source-available. All rights reserved. This code is public for viewing only — no use, reproduction, or derivative works permitted. See LICENSE for full terms.
