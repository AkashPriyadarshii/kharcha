# Kharcha — India's UPI Expense Tracker for Android

**by Akash Priyadarshi** · [github.com/AkashPriyadarshii](https://github.com/AkashPriyadarshii) · [akashpriyadarshi.vercel.app](https://akashpriyadarshi.vercel.app)

India-first UPI expense tracker for Android. Every UPI payment from GPay, PhonePe, or Paytm auto-appears as an expense — no manual entry. Offline-first, rule-based automation (no AI), Supabase sync. Built with Flutter/Dart, Drift/SQLite.

## 📲 Download

| | |
|---|---|
| **Latest release** | **v0.2.5** |
| **APK** | [`kharcha-armv8a-release.apk`](https://github.com/AkashPriyadarshii/kharcha/releases/latest/download/kharcha-armv8a-release.apk) (~25 MB) |
| **Requirements** | Android 12+ (arm64) |

**Install:** download the APK → open it → allow "Install unknown apps" if prompted → done. The app then auto-updates itself — every release is checked and offered in-app, no sideloading again.

## Screenshots

| | | |
|---|---|---|
| ![Home](screenshots/HOME.png) | ![Transactions](screenshots/TRANSACTIONS.png) | ![Budget](screenshots/BUDGET.png) |
| ![Reports](screenshots/REPORTS.png) | ![Categories](screenshots/CATEGORIES.png) | ![Profile](screenshots/PROFILE.png) |

## Product

- **Auto-capture** — reads UPI push notifications (GPay, PhonePe, Paytm) → parses amount/merchant/date → saves expense. Play-legal, no SMS permission.
- **Auto-categorization** — rule map: Swiggy→Food, Uber→Travel, Amazon→Shopping, Reliance→Grocery. Self-learns from user corrections.
- **Duplicate-safe** — `upi_ref` unique; notification + manual can never double-add.
- **9PM Hinglish daily summary** — "Aaj ₹540 kharcha hue." Weekly Sunday recap.
- **Offline-first** — Drift SQLite source of truth, works with zero network, syncs to Supabase when online.
- **Budget alerts** — 50/80/100% per-category.
- **App lock** — biometric/PIN.
- **Max tracking, never sold** — collects granular spend data (that's the product); data is never sold, never ad-targeted.

## What's new in v0.2.5

- **Notification fixes** — daily/weekly summaries now fire at the right time on every device (timezone fallback), and the weekly recap is no longer silently lost when it lands on a Sunday evening.
- **Name fix** — your Google name now shows correctly after sign-in (was missing for many accounts).
- **Home redesign** — greeting with your name, Income vs Spent cards, and a 6-month spend trend right on the dashboard.
- **Reports upgrade** — Income/Spent/Net at a glance; category pie shows percentage labels.

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

## Team

- Akash (`AkashPriyadarshii`) — owner

## License

Source-available. All rights reserved. This code is public for viewing only — no use, reproduction, or derivative works permitted. See LICENSE for full terms.
