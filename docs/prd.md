# Kharcha — Product Requirements Doc (PRD)

**Status:** Approved (v0.1.0)

## 1. Summary

A privacy-first (public), offline-first UPI expense tracker for Indian users. The core promise: **every UPI payment shows up as an expense automatically** — no manual entry. Built on rule-based automation (no AI). Public framing is privacy-first; internally the product collects granular spend data (the entire point of an expense tracker). Data is never sold, never ad-targeted.

## 2. Problem

Indians spend through UPI (GPay, PhonePe, Paytm) dozens of times a month. No one remembers where the money went. Existing trackers (Walnut/Axio, Money Manager, Monefy) require manual entry — friction kills them.

## 3. Solution

Read UPI **push notifications** and **SMS messages** (opt-in) → parse amount + merchant + date → auto-categorize by rule → save. Offline-first, syncs to Supabase when online. Manual entry always available as fallback.

## 4. Target users

Primary: students, working professionals, freelancers, families. India, Android 12+.

## 5. Personas

- **Rohit (24, working professional)** — 30 UPI payments/month, wants to know monthly breakdown, forgets to log anything. Value: zero-effort tracking + monthly report.
- **Priya (21, student)** — lives on Swiggy/Zomato, budget-conscious. Value: category budgets + alerts so she doesn't overshoot Food.
- **Ramesh (45, small business owner)** — cash + UPI, wants total monthly outflow. Value: manual entry + cash tracking + merchant ranking.

## 6. User stories (v0.1.0)

1. As a user, I sign in with Google and see my dashboard in seconds.
2. When I pay ₹250 to Zomato via UPI, it appears in my transactions automatically — correct category (Food), correct merchant.
3. If I fix a wrong category once, it's remembered for next time.
4. At 9PM, I get a Hinglish push: "Aaj ₹540 kharcha hue." I can tap to add a note.
5. I can see this month's spend, budget left, and category bars on Home.
6. I can search/filter my transactions by category, merchant, date, or payment method.
7. I can set a Food budget of ₹6,000; at 50/80/100% I get an alert.
8. I can see category pie, monthly trend, and merchant ranking in Reports.
9. I can export my data as CSV/JSON.
10. I can lock the app with biometrics/PIN.

## 7. Feature list (v0.1.0)

1. Google sign-in (Supabase Auth)
2. Manual expense entry — amount, merchant, category, note, payment method (cash/UPI/card/wallet), date. Quick-add <2s.
3. UPI notification auto-capture (NotificationListenerService)
4. Auto-categorization rule map (~100 merchant rules pre-seeded)
5. Self-learning rules (user correction → new rule)
6. Merchant name normalization (fuzzy match → one merchant)
7. Duplicate detection (upi_ref unique)
8. 9PM Hinglish daily summary push + tap-through notes
9. Sunday Hinglish weekly recap
10. Home dashboard (today ₹, this month ₹, budget left, category bars)
11. Transactions tab (list, search, filters)
12. Reports tab (category pie, monthly trend, merchant ranking)
13. Budget tab (per-category, 50/80/100% alerts)
14. Profile tab (account, export CSV/JSON, backup status, settings)
15. Offline-first + Supabase sync from day one
16. App lock (biometric/PIN)

## 8. Out of scope (v0.1.0)

- SMS import (P2, opt-in, Play declaration)
- Recurring/subscription detection (P2)
- Savings goals (P2)
- Split with friends (P2)
- PDF/Excel export (P2)
- Widgets, voice entry (P2)
- Family budget, financial health score, tax tags, multi-language, OCR, cashback (P3)
- AI/LLM insights (banned)
- Ads in finance screens (banned)
- Bank API integration (banned)
- iOS (later)

## 9. Non-functional requirements

- **Performance:** transactions list scrolls 60fps; cold start < 2s on mid-range Android.
- **Offline:** app fully usable with no network; syncs when back online.
- **Privacy:** public framing = privacy-first, private, on-device, never sold. Internally the product tracks full granular data (every payment, merchant, category, date) — that's the product. Data never sold, never ad-targeted. No bank login, no credential storage. App lock via biometric/PIN. Privacy policy before Play submission.
- **Non-generic UI:** Material 3 base, deliberately opinionated. No default template cards, no stock hero, no safe-gray flat layout. See `docs/design.md` design direction.
- **Permission model:** notification-access and SMS (with disclosure). SMS is permitted for auto-capture.
- **Android:** minSdk 32 (Android 12+).

## 10. Metrics (post-launch)

- Transactions logged per user per week
- % auto-captured without manual correction
- Budget completion rate
- 30-day retention
- Crash-free sessions
- DAU

## 11. Monetization (later, not now)

Free core. Premium (₹99–199/mo): advanced analytics, unlimited exports, multi-device sync. Only after usage justifies it. No ads ever.

## 12. Risks

| Risk | Mitigation |
|---|---|
| Google rejects notification-based parsing (unlikely, no restricted perm) | Manual entry is full-featured fallback; app usable without capture |
| UPI notification format changes per app | Rule-based parser, test against GPay/PhonePe/Paytm; merchant normalization absorbs variance |
| Supabase free tier limits at scale | Only reached after real usage; paid tier is cheap |
| Friend pushes slop (dead code, AI, mock features) | CLAUDE.md anti-slop rules + mandatory code review on every PR |
