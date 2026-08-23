---
target: lib/screens/tabs/home_tab.dart
total_score: 21
max_score: 40
na_heuristics: 
p0_count: 1
p1_count: 2
timestamp: 2026-08-23T05-03-15Z
slug: lib-screens-tabs-home-tab-dart
---
Method: dual-agent (A: 0970d1c2-e7c0-48b8-bcc1-55bcc8f7a7c6 · B: a0814456-2a4b-42f8-a60e-caf6437920fa)

### Design Health Score

| # | Heuristic | Score | Key Issue |
|---|---|:---:|---|
| 1 | Visibility of System Status | 2 | No sync indicator or notification listener health badge on Home; OS service status invisible. |
| 2 | Match System / Real World | 3 | Indian currency formatting (`en_IN`) is solid, but transactions lack UPI payment context (VPA/UPI ref/P2M). |
| 3 | User Control and Freedom | 2 | Recent transaction items on Home are inert (`_RecentTile` has no `onTap`); cannot edit or inspect from Home. |
| 4 | Consistency and Standards | 2 | Duplicated metrics across Hero and Stat cards (Income/Today); competing Add buttons (AppBar vs FAB). |
| 5 | Error Prevention | 2 | Persistent Sign Out icon on main AppBar risks accidental taps during one-handed mobile use. |
| 6 | Recognition Rather Than Recall | 2 | Trend line chart has no Y-axis/tooltips; category bars normalized to top category rather than budget or % total. |
| 7 | Flexibility and Efficiency | 2 | No pull-to-refresh for capture inbox drain/sync; no swipe actions on recent transactions. |
| 8 | Aesthetic and Minimalist Design | 2 | Top half is overcrowded with 3 cards repeating the same metrics; muddy brown over-budget palette. |
| 9 | Error Recovery | 2 | Stream error state renders raw exception string `Could not load dashboard.\n$e` without retry button. |
| 10 | Help and Documentation | 2 | Empty states render plain unstyled text without actionable trigger buttons or capture setup guidance. |
| **Total** | | **21/40** | **Deficient (Significant Structural & Cognitive Flaws)** |

### Design Specificity Verdict

**LLM Assessment**:
Kharcha achieves good atmospheric grounding with its warm paper (`#FBF7EF`) and deep ink-green (`#0A3D2E`) palette, along with proper `en_IN` currency formatting. However, the UX hierarchy currently lapses into a traditional accounting desktop ledger. The app lacks distinct UPI native affordances: no visual cue of the auto-capture notification listener status, no P2P vs P2M merchant context, and no instant verification loop when an expense is logged.

**Deterministic Scan**:
- **CLI Detector**: Web-focused scanner returned clean exit code 0 (`[]` findings) because Flutter Dart widgets render to a native graphics canvas.
- **Structural Code Analysis**:
  - `_RecentTile` uses `dense: true` without an `onTap` handler, creating an accessibility issue (<48dp touch target) and an interaction dead-end.
  - Raw exception string `$e` leaked directly in `home_tab.dart` stream error builder without retry button.
  - Hardcoded color literals (`#0A3D2E`, `#2A1606`, `#FFFFC266`) bypass theme tokens.
  - Sub-minimum font size (`fontSize: 10`) in stat card subtitles.
  - Missing `Semantics` wrappers on progress indicators and count-up animations.

**Visual Overlays**:
Native Flutter application target (Android/macOS); HTML DOM injection overlay not applicable.

### Overall Impression
Kharcha's visual identity has a warm, confident foundation with its ink-green and paper theme, but the Home screen suffers from metric redundancy in the hero area, dead-end interaction patterns on recent transactions, and invisible system status for its core auto-capture engine.

### What's Working
1. **Distinct Brand Identity**: Deep ink-green and warm paper background avoids sterile fintech grays and neon crypto gradients.
2. **Hero Spend Animation**: Count-up animation creates an immediate monetary anchor for the monthly budget.
3. **Reactive Data Architecture**: Single stream provider recalculates totals reactively across local database updates.

### Priority Issues

- **[P0] Inert Recent Transactions on Home Dashboard**
  - **Why it matters**: Users check Home to verify if their UPI spend logged. Inability to tap, categorize, or view notes breaks the core loop.
  - **Fix**: Add `onTap` navigation to transaction editor/details, show relative timestamps ("5m ago"), and add a "View all" link to the Transactions tab.
  - **Suggested command**: `/impeccable polish lib/screens/tabs/home_tab.dart`

- **[P1] Information Architecture Clutter & Metric Duplication**
  - **Why it matters**: "Income this month" and "Today's spend" are rendered twice within the top 300px, pushing actionable transactions below the fold.
  - **Fix**: Remove `_IncomeExpenseRow`; consolidate the Hero card into Month Spend + Budget Balance with a compact secondary pill row.
  - **Suggested command**: `/impeccable layout lib/screens/tabs/home_tab.dart`

- **[P1] Destructive Sign-Out Icon & Competing Add Affordances in Primary AppBar**
  - **Why it matters**: Persistent logout icon risks accidental tap; two competing "Add" buttons create cognitive confusion.
  - **Fix**: Move `Sign out` to Profile Tab; replace AppBar actions with capture status indicator and brand header.
  - **Suggested command**: `/impeccable layout lib/screens/home_shell.dart`

- **[P2] Dimensionless Sparkline Chart & Unanchored Category Progress**
  - **Why it matters**: Trend curve has no Y-axis values or tooltips; category bars lack % of total or budget context.
  - **Fix**: Add touch tooltips to sparkline and display spend percentage of total on category progress bars.
  - **Suggested command**: `/impeccable clarify lib/screens/tabs/home_tab.dart`

- **[P3] Monospace Numeral Treatment & Murky Alert Palette**
  - **Why it matters**: Monospace display font looks uncrafted; over-budget brown (`#2A1606`) fails clarity.
  - **Fix**: Use proportional sans font with tabular figures (`FontFeature.tabularFigures()`); update alert state to ink-amber (`#331E05`) with crisp gold accents.
  - **Suggested command**: `/impeccable colorize lib/screens/tabs/home_tab.dart`

### Persona Red Flags
- **Alex (Power User)**: Frustrated by dead UI surfaces (cannot tap transactions or category bars) and lack of tooltips/numbers on the trend chart.
- **Casey (Distracted Mobile User)**: Faces action paralysis from competing "Add" buttons and risks accidental logout via the top-right AppBar icon.
- **Akash (Daily UPI Payer)**: Zero visibility into whether the notification listener service is active, and transactions lack merchant badges/relative timestamps.

### Minor Observations
- Missing `RefreshIndicator` for manual capture inbox drain and Supabase sync.
- Raw exception string leaked on error state without retry action.
- Decorative 28px tertiary strip inside Hero card adds visual noise.

### Questions to Consider
1. What if the Home Tab behaved like a live UPI passbook—showing an instant pulse card for the last detected transaction with one-tap category confirmation?
2. Should the 6-month historical sparkline move to Reports Tab to give daily recent transactions primary focus?
3. Could auto-capture status be elevated to a discreet top badge ("Capture Active • Synced 2m ago")?
