# Kharcha — Implementation Plan (v0.1.0)

Build order. Each step = one PR, merges to `main` after review + passing analyze/test.

## Phase 1 — Foundation

**Step 1.1: Scaffold Flutter app + git setup**
`flutter create` with org, minSdk 32. Base pubspec: riverpod, go_router, drift, flutter_local_notifications, local_auth, supabase_flutter, fl_chart, intl, csv. Set up analysis_options with strict linting. Branch: `feat/scaffold`.
✅ Verify: builds, runs on emulator, `flutter analyze` clean.

**Step 1.2: Google sign-in (Supabase Auth)**
Wire Supabase project, Google OAuth, auth flow → Home or Auth screen. Session persistence (supabase_flutter). RLS helper on `auth.uid()`.
✅ Verify: sign in, sign out, session survives restart.

**Step 1.3: Drift local schema**
Tables: transactions, categories, merchants, rules, budgets. Migration scaffold. Seed default categories + ~100 builtin merchant rules.
✅ Verify: unit test — schema creates, seed inserts, upi_ref unique enforced.

## Phase 2 — Core capture

**Step 2.1: Manual entry + quick-add**
Full form (amount, merchant, category, note, payment method, date) + minimal quick-add. Writes to Drift. Category picker uses seed data.
✅ Verify: entry appears in list; quick-add < 2s.

**Step 2.2: Rule-based categorization + normalization**
`Categorizer` service: merchant string → normalize → rule match → category. Learned rules override builtin. `MerchantNormalizer`: case/suffix stripping, fuzzy match.
✅ Verify: unit test — Zomato variants → Food; unknown → null (prompt to pick).

**Step 2.3: NotificationListenerService (Kotlin)**
Listen UPI app notifications, extract amount/merchant/upi_ref/date, hand to Flutter via platform channel. Dedupe by upi_ref before insert. Permission disclosure screen on first enable.
✅ Verify: adb-pushed fake UPI notification → expense auto-added once; duplicate push → not re-added.

## Phase 3 — Sync + notifications

**Step 3.1: Supabase sync**
Dirty-row queue, background upsert to Postgres, pull on login. Last-write-wins by updated_at. Handle offline → queued → flush.
✅ Verify: add expense offline → sync when online → appears in Supabase; RLS blocks other user's rows.

**Step 3.2: 9PM daily + Sunday weekly Hinglish notifications**
flutter_local_notifications scheduled. Daily: today's total, uncategorized count (tap → tag screen). Weekly: total, top 3 categories.
✅ Verify: schedule fires at 9PM; taps route correctly.

## Phase 4 — Screens

**Step 4.1: Home dashboard** — today ₹, this month ₹, budget left, category bars.
**Step 4.2: Transactions tab** — list, search, filters (category/date/merchant/payment method).
**Step 4.3: Reports tab** — category pie, monthly trend, merchant ranking (fl_chart).
**Step 4.4: Budget tab** — per-category budgets, progress, 50/80/100% alerts.
**Step 4.5: Profile tab** — account, payment methods, export CSV/JSON, backup status, settings, app lock.
✅ Verify each: manual smoke on Android emulator.

## Phase 5 — Ship prep

**Step 5.1: Export CSV/JSON** — working, tested.
**Step 5.2: App lock** — local_auth biometric + PIN fallback.
**Step 5.3: Privacy policy + Play listing assets.**
**Step 5.4: Final regression** — analyze, test, smoke, release build.
**Step 5.5: Release v0.1.0** — tagged, signed APK.

## Definition of done per step

- Code matches CLAUDE.md standards
- `flutter analyze` passes
- `flutter test` passes
- Manual smoke test on Android device/emulator
- PR reviewed + approved
- `docs/state.md` updated

## Dependencies

Phase 1 → 2 → 3 → 4 → 5. Steps within a phase can parallelize between devs where files don't overlap (e.g. 4.3 Reports and 4.4 Budget).
