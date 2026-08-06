# Kharcha — Design Doc (v0.1.0)

**Date:** 2026-08-06
**Status:** Approved by user
**Repo (planned):** `AkashPriyadarshii/kharcha` (private, collaborators: priyaranjan122002)

## Vision

India-first UPI expense tracker. Every UPI payment auto-appears as an expense — no manual entry needed. Offline-first, privacy-first, rule-based automation (no AI/LLM). Designed for Indian spending habits, Hinglish-friendly, Android 12+.

## Principles

- **Offline-first** — Drift SQLite is the source of truth on device. Works with zero network.
- **Rule-based automation, zero AI** — categorization, normalization, dedupe all local dictionaries + user-learned rules.
- **No ads in finance screens.** No AI slop. No bank API dependency.
- **Never depend on a risky permission** — notification capture is the primary path; SMS is a later opt-in toggle (P2).

## Scope

### v0.1.0 (build now)

1. **Google sign-in** via Supabase Auth (free tier, no Clerk).
2. **Manual expense entry** — amount, merchant, category, note, payment method (cash/UPI/card/wallet), date. Quick-add <2s.
3. **UPI notification auto-capture** — `NotificationListenerService` reads UPI push notifications → parse amount/merchant/date → auto-save expense.
4. **Auto-categorization rule map** — ~100 pre-seeded merchant→category rules (Swiggy→Food, Uber→Travel, Amazon→Shopping, Reliance→Grocery, Netflix→Bills…).
5. **Self-learning rules** — user corrects a category once → saved as rule → auto-applied next time.
6. **Merchant name normalization** — fuzzy match (`zomato / ZOMATO / Zomato-UB` → one merchant). Rule-based.
7. **Duplicate detection** — `upi_ref` unique; notification + manual + (later) SMS can never double-add.
8. **9PM Hinglish daily summary push** — "Aaj ₹540 kharcha hue." Tap-through to add notes / where. Also nudges: "3 transactions bina category ke. Add karo?" → tag screen.
9. **Weekly Sunday recap** — "Is week ₹3,200 kharcha. Top 3: Food, Travel, Shopping."
10. **Home dashboard** — today ₹, this month ₹, budget left, category bars.
11. **Transactions tab** — list, search, filters (category/date/merchant/payment method).
12. **Reports tab** — category pie, monthly trend, merchant ranking.
13. **Budget tab** — per-category limits, progress, 50/80/100% alerts.
14. **Profile tab** — Google account, payment methods, export CSV/JSON, backup status, settings.
15. **Offline-first + Supabase sync** from day one.
16. **App lock** — biometric/PIN (local_auth).

### P2 (after v0.1.0 stable)

- SMS import (opt-in, `READ_SMS`, Play declaration)
- Recurring expenses / subscription detection
- Savings goals
- Split with friends
- PDF/Excel export
- Widgets, voice entry
- Bill-due prediction, spending heatmap

### P3 (later)

- Family shared budget, "where did my salary go", financial health score (rule-based), tax tags, multi-language, receipt OCR, cashback tracking

### Deliberately excluded

- AI/LLM insights, ads in finance screens, bank API integration, SMS as a dependency.

## Architecture

```
Flutter app (Android 12+, minSdk 32)
│
├── UI layer (Material 3, Riverpod, go_router)
├── Domain (expenses, categories, budgets, merchant rules)
├── Data layer
│   ├── Drift SQLite   ← source of truth (offline-first)
│   └── Supabase       ← Google auth + Postgres + background sync
├── Capture
│   ├── NotificationListenerService  (Kotlin) → parse → dedupe → insert
│   └── Manual entry (fallback)
└── Local notifications (flutter_local_notifications)
    ├── 9PM daily summary (Hinglish)
    └── Sunday weekly recap
```

### Data flow: capture

```
UPI push notification → NotificationListenerService
  → parse (₹, merchant, upi_ref, date)
  → dedupe by upi_ref
  → auto-category via rule map / learned rule
  → insert local (instant)
  → queue for Supabase sync
```

### Sync

- Local writes are immediate. Dirty rows tracked; background upsert to Supabase when online. Pull on login. Conflicts resolved by `updated_at` last-write-wins (single-user app — adequate).

## Data model

Supabase Postgres, mirrored locally in Drift.

```sql
users:        id (uuid, = auth.uid), email, name, avatar_url, currency, created_at

transactions: id, user_id, amount (numeric), merchant_id, category_id,
              txn_date, note, payment_method, upi_ref (unique, nullable),
              source (notification | manual | sms), created_at, updated_at

categories:   id, user_id, name, emoji, color, is_custom, sort_order

merchants:    id, user_id, name (normalized), category_id (default), icon

rules:        id, user_id, pattern, category_id, type (builtin|learned), priority

budgets:      id, user_id, category_id, amount, period (monthly),
              alert_pct_50, alert_pct_80, alert_pct_100
```

- `upi_ref` unique per user → dedupe enforced at DB level.
- RLS: every table scoped by `user_id = auth.uid()`.

## Stack

| Concern | Choice |
|---|---|
| Framework | Flutter (Android 12+, minSdk 32), Material 3 |
| State | Riverpod |
| Navigation | go_router |
| Local DB | Drift (SQLite) |
| Backend | Supabase (Google Auth, Postgres, sync) |
| Charts | fl_chart |
| Local notifications | flutter_local_notifications |
| App lock | local_auth |
| Capture | NotificationListenerService (Kotlin) |
| Export | CSV/JSON (dart:convert / csv package) |

## Cost

₹0 at launch: Supabase free tier (50k MAU, 500MB DB) + Google OAuth. Monetization later (premium ₹99–199/mo) — never before usage justifies it.

## Security / Privacy

- App lock (biometric/PIN) on financial data.
- No bank login, no credential storage.
- Permission model: notification-access only in MVP (disclosure on first use). SMS is P2, opt-in only.
- Privacy policy before any Play submission.

## Build order

1. App shell + Google sign-in + Drift local schema
2. Manual entry + builtin category/merchant rule map
3. Notification listener + parser + dedupe
4. Supabase sync
5. 9PM/Weekly Hinglish notifications
6. Home + Transactions + Reports + Budget tabs
7. App lock, export, privacy policy, Play listing

## Success metrics

- Transactions logged per user per week
- % of transactions auto-captured (notification) without manual correction
- Budget completion rate
- 30-day retention
- Crash-free sessions
