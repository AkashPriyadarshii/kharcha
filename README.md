# Kharcha

**India-first UPI expense tracker.** Every UPI payment auto-appears as an expense — no manual entry. Offline-first, rule-based automation (no AI), Supabase sync.

## 🤖 For AI agents — quick clone & run

```bash
# 1. Clone
git clone https://github.com/AkashPriyadarshii/kharcha.git
cd kharcha

# 2. Deps
flutter pub get

# 3. Verify (no test on Windows host — see troubleshooting.md)
flutter analyze

# 4. Run on Android (full features: UPI capture, notifications, battery exemption)
flutter run -d <device-id>     # Android 12+ device/emulator
#   OR
flutter build apk --release --split-per-abi   # arm64 APK (see CLAUDE.md)

# Notes:
# - Android-only target. UPI auto-capture needs NotificationListenerService.
# - Guest mode: "Continue as guest" on auth → local-only, no Supabase sync
```

## Product

- **Auto-capture** — reads UPI push notifications (GPay, PhonePe, Paytm) → parses amount/merchant/date → saves expense. Play-legal, no SMS permission.
- **Auto-categorization** — rule map: Swiggy→Food, Uber→Travel, Amazon→Shopping, Reliance→Grocery. Self-learns from user corrections.
- **Duplicate-safe** — `upi_ref` unique; notification + manual can never double-add.
- **9PM Hinglish daily summary** — "Aaj ₹540 kharcha hue." Weekly Sunday recap.
- **Offline-first** — Drift SQLite source of truth, works with zero network, syncs to Supabase when online.
- **Budget alerts** — 50/80/100% per-category.
- **App lock** — biometric/PIN.
- **Max tracking, never sold** — collects granular spend data (that's the product); data is never sold, never ad-targeted.

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

## Getting started

```bash
flutter pub get
flutter analyze
flutter test
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
