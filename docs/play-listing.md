# Kharcha — Play Store Listing (v0.1.0)

> Public layer: privacy-first framing only. Copy is ready to paste into Play
> Console. Permission declarations must match the merged manifest (below).

## Title

**Kharcha — UPI Expense Tracker**

## Short description (80 chars)

Your UPI payments auto-appear as expenses. Private, on-device, no manual entry.

## Full description

Kharcha is a private, offline-first expense tracker built for Indian UPI
users. Every UPI payment you make (GPay, PhonePe, Paytm) automatically shows
up as an expense — no manual entry needed.

**Why Kharcha**
- Indians spend through UPI dozens of times a month. Nobody remembers where
  the money went. Kharcha remembers — automatically.
- Supports both notification-based and SMS-based capture. Both are on-device and private.

**Features**
- 📲 **Auto-capture**: UPI payment notifications become expenses instantly
- 🧠 **Smart categories**: local rule map sorts Food, Travel, Bills and more
- 🎯 **Budgets**: monthly limits per category with progress alerts
- 📊 **Reports**: spend by category, monthly trend, top merchants
- 🔍 **Search & filter**: find any expense in seconds
- 💾 **Export**: CSV or JSON anytime
- 🔒 **Private by design**: on-device first, encrypted in transit + at rest,
  optional biometric app lock, never sold, never ad-targeted, no AI

**Privacy**
Your data stays yours. See our privacy policy in-app and on our site.
Never sold. Never shared. No ads in finance screens. Ever.

## App category

Finance → Money Management

## Content rating

Everyone (general audience; contains no objectionable content)

## Declared permissions (must match merged manifest)

| Permission | Justification |
|---|---|
| `BIND_NOTIFICATION_LISTENER_SERVICE` | Auto-capture UPI payment notifications (core feature; on-device) |
| `POST_NOTIFICATIONS` | Daily 9PM + Sunday weekly spend summaries (from flutter_local_notifications) |
| `USE_BIOMETRIC` / `USE_FINGERPRINT` | Optional app lock (from local_auth) |
| `INTERNET` | Supabase sync (debug/profile variants; release also needs it for sync) |

> Note: `INTERNET` appears in debug/profile manifests via Flutter; confirm the
> release merged manifest includes it before final submission (sync needs it).

## Data safety form (Play)

- **Does your app collect data?** Yes — user spend data (amount, merchant,
  category, date) with explicit user action / consent.
- **Data types:** Financial info (user-entered + notification-captured).
- **Shared with third parties?** No.
- **Encryption:** Data encrypted in transit (HTTPS) and at rest.
- **Deletion:** Users can delete expenses in-app; account deletion on request.
- **Ad targeting:** No ads. No data used for ad targeting.

## Screenshots plan (needs device capture)

1. Home dashboard (today/month/budget-left + category bars)
2. Transactions list with search/filters active
3. Budget tab (progress bars)
4. Reports (pie + trend line)
5. Profile (account, export, app lock)
6. Enable-capture disclosure screen

## Icon

Needs a launcher icon — ₹ mark, ink green `#0A6B4D` on light. Use
`flutter_launcher_icons` when adding.
