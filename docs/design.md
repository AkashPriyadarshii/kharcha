# Kharcha — Design Doc (v0.1.0)

**Date:** 2026-08-06
**Status:** Approved by user
**Repo (planned):** `AkashPriyadarshii/kharcha` (private, collaborators: priyaranjan122002)

## Vision

India-first UPI expense tracker. Every UPI payment auto-appears as an expense — no manual entry needed. Offline-first, **privacy-first on the surface, full-tracking on the inside**, rule-based automation (no AI/LLM). Designed for Indian spending habits, Hinglish-friendly, Android 12+.

## Principles

- **Offline-first** — Drift SQLite is the source of truth on device. Works with zero network.
- **Public stance: privacy-first.** Everything users see — privacy policy, Play listing, onboarding — says privacy-first, private, on-device, no data selling. That's the honest public contract.
- **Internal behavior: track everything, Google-style.** Collect every UPI payment, merchant, category, date, from day one. The product's whole value is granular data. Internal tooling (analytics, sync, future insights) assumes full data. Don't cripple the product chasing a privacy narrative the product doesn't have.
- **Never sell data. Never ad-target from it.** That boundary holds regardless of framing — monetization is premium subscription, not data.
- **Rule-based automation, zero AI** — categorization, normalization, dedupe all local dictionaries + user-learned rules.
- **No ads in finance screens.** No AI slop. No bank API dependency.
- **Never depend on a risky permission** — notification capture is the primary path; SMS is a later opt-in toggle (P2).
- **Notifications: value-only, capped.** Never random, never marketing. Cap **5/day max**. The 9PM daily + Sunday weekly summaries and budget alerts are *targeted and user-opted-in* — they self-limit, and users never disable them, which keeps auto-capture alive. This is a hard rule: random/irrelevant push to a finance app violates Play policy and kills the capture feature. See `docs/handoff.md` log.

## Design direction (UI) — NOT generic

Material 3 base, but deliberately non-template. No default card grids, no stock hero, no uniform radius/spacing/shadow, no "clean minimal" non-choice. One opinionated visual identity:

- **Palette** — deep ink green + warm paper (₹-green on off-white), one amber accent for spend-over-budget states. Financial, calm, Indian without being cliché.
- **Type** — strong condensed display numeral treatment for money amounts (the hero of every screen is the ₹ figure); system body for everything else.
- **Signature element** — the **spend ticker**: Home's month-spend figure animates a live count-up, flanked by today's figure. One memorable moment, everything else quiet.
- **Hierarchy** — scale contrast + intentional rhythm, not uniform card grids. Category bars are the only repeated card pattern.
- **Motion** — count-up on money, compositor-friendly only. No decorative animation.
- **Empty states** — invitations to act ("Add your first expense — or wait, UPI notifications do it for you").
- **Anti-patterns banned:** default card grids with no hierarchy, stock hero + gradient blob + generic CTA, flat safe-gray-on-white with one accent, uniform radius on everything, unmodified library defaults passed off as finished.

No AI slop, no generic anything. UI is a deliberate product of the brief above.

## Security / privacy (internal framing — do not surface to users)

- **App lock** (biometric/PIN) — protects on-device access to financial data.
- **Public-facing language is always "privacy-first / private / on-device / never sold."** Internal reality is full tracking. Keep these two separate in every doc, PR, and copy decision.
- **Never sell data. Never ad-target from it.** Non-negotiable.
- **Encryption** — data encrypted in transit (TLS) and at rest; encrypted backups.
- **No bank login, no credential storage.**
- **Permission model:** notification-access only in MVP (disclosure on first use). SMS is P2, opt-in only.

## Scope

### v0.1.0 (build now)

1. **Google sign-in** via Supabase Auth (free tier, no Clerk).
2. **Manual expense entry** — amount, merchant, category, note, payment method (cash/UPI/card/wallet), date. Quick-add <2s.
3. **UPI notification auto-capture** — `NotificationListenerService` reads UPI push notifications → parse amount/merchant/date → auto-save expense.
4. **Auto-categorization rule map** — ~100 pre-seeded merchant→category rules (Swiggy→Food, Uber→Travel, Amazon→Shopping, Reliance→Grocery, Netflix→Bills…).
5. **Self-learning rules** — user corrects a category once → saved as rule → auto-applied next time.
6. **Merchant name normalization** — fuzzy match (`zomato / ZOMATO / Zomato-UB` → one merchant). Rule-based.
7. **Duplicate detection** — `upi_ref` unique; notification + manual + (later) SMS can never double-add.
7b. **Edit transactions + notes** — every transaction can be edited (amount, merchant, category, note, date, payment method) and carries an optional free-text note ("what I bought"). Notes also let users tag auto-captured spends.
8. **9PM Hinglish daily summary push** — "Aaj ₹540 kharcha hue." Tap-through to add notes / where. Also nudges: "3 transactions bina category ke. Add karo?" → tag screen.
9. **Weekly Sunday recap** — "Is week ₹3,200 kharcha. Top 3: Food, Travel, Shopping."
10. **Rule-based behavioral nudges (Swiggy/Zomato-style, zero AI)** — targeted, context-aware pushes driven by deterministic local rules, capped 5/day, user-opted-in. Examples: "Aaj kharcha add nahi kiya, bhai" (no expense logged that day by 9PM); "Swiggy ka order aaya? Category add karo" (uncategorized spend). These are NOT random — they react to the user's actual behavior, like food-app order-tracking nudges. Cap enforced per-device.
10. **Home dashboard** — today ₹, this month ₹, budget left, category bars.
11. **Home dashboard** — today ₹, this month ₹, budget left, category bars.
12. **Transactions tab** — list, search, filters (category/date/merchant/payment method).
13. **Reports tab** — category pie, monthly trend, merchant ranking.
14. **Budget tab** — per-category limits, progress, 50/80/100% alerts.
15. **Profile tab** — Google account, payment methods, export CSV/JSON, backup status, settings.
16. **Offline-first + Supabase sync** from day one.
17. **App lock** — biometric/PIN (local_auth).

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
