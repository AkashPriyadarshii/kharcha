<div align="center">
  <img src="screenshots/app_icon.png" width="96" height="96" alt="Kharcha" style="border-radius: 22%">
  <h1>Kharcha</h1>
  <p><strong>India's Zero-Friction UPI Expense Tracker for Android.</strong></p>

  <a href="https://github.com/AkashPriyadarshii/kharcha/releases/latest"><img src="https://img.shields.io/github/v/release/AkashPriyadarshii/kharcha?style=flat-square&color=0A6B4D" alt="Latest Release"></a>
  <a href="https://github.com/AkashPriyadarshii/kharcha/blob/main/LICENSE"><img src="https://img.shields.io/badge/license-All%20Rights%20Reserved-red?style=flat-square" alt="License"></a>
  <a href="https://AkashPriyadarshii.github.io/kharcha/"><img src="https://img.shields.io/badge/website-kharcha.github.io-0A6B4D?style=flat-square" alt="Website"></a>
</div>

---

**Kharcha** is a native Android expense tracker built for India's UPI ecosystem. Every payment from **GPay, PhonePe, Paytm, or CRED** is captured, categorized, and added to your ledger automatically — no manual entry.

Kotlin + Rust, fully offline, zero cloud, zero AI. Parsing and dedupe run in a deterministic Rust core (`kharcha-core`); the Compose app only stores what Rust decides. Your money data never leaves the device.

**by Akash Priyadarshi** · [github.com/AkashPriyadarshii](https://github.com/AkashPriyadarshii) · [akashpriyadarshi.vercel.app](https://akashpriyadarshi.vercel.app)

**🌐 Website:** [**kharcha.github.io**](https://AkashPriyadarshii.github.io/kharcha/)

## Why Kharcha

Manual logging is friction; cloud sync is a trust tax. Kharcha kills both:

- **Every UPI debit auto-appears** — SMS + push notifications, parsed in Rust.
- **No doubles.** Triple-signal dedupe: ref + 5-min window + content hash.
- **Zero AI.** Categorization is a local rule map. Deterministic, auditable.
- **Offline by design.** No internet permission in the product. No account, no Supabase, no Firebase.

## 📲 Download

| | |
|---|---|
| **Latest release** | **v0.1.0** |
| **APK** | [`kharcha-armv8a-release.apk`](https://github.com/AkashPriyadarshii/kharcha/releases/latest/download/kharcha-armv8a-release.apk) (~29 MB) |
| **Requirements** | Android 12+ (arm64) |

**Install:** build or grab the APK → open it → allow "Install unknown apps" → done.

## ✨ Features

- **Automated UPI & SMS Capture** — notifications + SMS banking alerts, multi-part join, real-time.
- **Smart Spam Filter** — OTPs, recharge promos, collect requests, failed/pending alerts rejected in Rust before parsing.
- **Auto Wallets** — bank/account masks in messages auto-create wallets; message balance updates them.
- **Monthly Budgets** — per-category caps with progress bars, over-limit turns red.
- **Rules Engine (zero AI)** — normalize + longest-pattern match, learned rules beat builtin. Teach a category from any transaction; it remembers the merchant.
- **220 merchant logos** — word-boundary match, longest key wins. Emoji fallback for the rest.
- **Rolling spend hero** — 300ms animated ticker on every new capture.
- **Home widget** — month spend + 1-tap log, refreshed on each insert.
- **Shareable month cards** — PNG export via system share sheet.
- **Manual entry** — quick-add for anything the phone can't see.
- **CSV export** — to Downloads, PII-hashable.
- **Biometric app lock** — fingerprint/face gate on launch.
- **Batch reparse** — SMS backlog drain in one call via `parse_captures`.

## 🛠 Tech Stack

| Concern | Choice |
|---|---|
| Core engine | Rust (`kharcha-core`), UniFFI bindings, 59/59 tests (24 unit + 35 parity) |
| App | Kotlin + Jetpack Compose, Android 12+ (minSdk 32) |
| Local DB | Room (SQLite) — the only store |
| Native | JNA, BiometricPrompt, NotificationListenerService |
| Network | none |

## 🏗 Layout

```
kharcha-core/   Rust: parser, dedupe, categorize, money, filter, split (crate + UniFFI)
android-app/    Kotlin Compose: screens, Room, capture funnel, build → APK
docs/           state, design, plan, handoff, changelog
```

## 📝 Notes

- **Device-tested** (Realme RMX5061, Android 16): live `SMS_RECEIVED` insert, auto-learn, dedupe, notify, widget refresh, share PNG verified on-device.
- Self-send SIM-to-SIM never broadcasts to third-party apps on ColorOS — live path needs a genuine bank sender.
- Auto-update: release tag + `kharcha-armv8a-release.apk` asset, version bump gates it.

## 📄 License & Legal

Source-available. All rights reserved. Public for viewing only — no use, reproduction, or derivative works permitted. See LICENSE for full terms.
- [Play-listing copy](docs/play-listing.md)
- [Privacy policy](docs/privacy-policy.md)
- [Security Policy](SECURITY.md)

<!--
SEO Metadata & Keywords:
UPI expense tracker, expense tracker India, UPI payment tracker, GPay tracker, PhonePe tracker, Paytm tracker, money tracker app, spend tracker India, budget app India, auto expense tracker, SMS expense tracker, payment notification tracker, Kharcha app, personal finance app India, expense manager, money manager India, monthly budget tracker, UPI spend tracker, offline expense tracker, finance app Android, Rust expense tracker, Kotlin expense tracker.
-->