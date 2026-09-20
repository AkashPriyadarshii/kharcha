# Brag Plan: Kharcha

## What is this app?
Kharcha is a 100% offline, privacy-first Android expense tracker with an embedded Rust parsing engine (`kharcha-core`) that automatically tracks Indian UPI expenses directly from device notifications with zero cloud, zero bank credentials, and zero ads.

## The angle
Show the mechanical cause-and-effect: an authentic bank UPI notification drops in, and in 0.18ms the on-device Rust engine parses it, rolls the balance ticker, resolves cryptic VPAs to real contact names, and tracks recurring autopay mandates without touching the internet.

## Hook (first 2-3 seconds)
An authentic Android notification banner drops down on a real phone mockup: *"HDFC Bank: Paid ₹240.00 to Starbucks via UPI"*. Instant recognition for every Indian mobile user who deals with a dozen cryptic UPI alerts a day.

## Key moments (the middle)
- **Sub-millisecond Local Reaction**: The notification absorbs into Kharcha's transaction list in 0.18ms; daily spend balance ticker rolls from `₹3,420` to `₹3,660` while a Rust telemetry badge flashes.
- **P2P Contact Name Resolver**: Raw UPI VPA `9876543210@paytm` morphs into a clean contact name: "Kiran Sharma".
- **Autopay Mandate Tracker**: Live recurring mandate card shows upcoming Netflix and SIP debits with `Due in 2 days` pill.

## Outro / punchline
Cut to high-contrast dark brutalist screen (`#12120E`): **"No Bank Login. No Cloud. Zero Tracking."** Logo, release badge, and GitHub download CTA.

## User flow worth showing
Notification drop ➔ Sub-millisecond engine parse & balance increment ➔ P2P contact resolution & autopay mandate detection.

## Tone
- Preset: `polished`
- Creative direction: High-craft Linear-style dev demo for mobile; mechanical cause-and-effect; zero generic slide cards.
- Interpretation: Fast, precise UI transitions, physical device context, subtle haptic audio cues, and bold typographic contrast.

## Format: vertical — 1080x1920 (9:16 mobile-native)
## Duration: 16.0s

## Visual identity (from the project)
- Background: `#FAF6EE` (Warm Paper) for demo, `#12120E` (Obsidian) for outro
- Accent: `#1B5E45` (Ink Green) & `#B7791F` (Warm Amber)
- Text: `#21201C` (Deep Ink)
- Display font: System sans-serif / Segoe UI / Inter
- Strongest visual element: Real Android phone frame with live transaction feed, floating Rust telemetry badge, and K+₹ app icon.

## Share copy (draft)
Most expense trackers ask for your net banking password or upload your private SMS to their servers. We built Kharcha: 100% offline Android expense tracking powered by an embedded Rust engine. v0.1.2 is live on GitHub.

## Audio direction
- Role: Warm rhythmic bed with precise haptic UI accents.
- Music: `assets/music/bgm.mp3`
- Music treatment: Starts at 0.0s, gentle 0.5s fade-in, volume at 0.65, ducks slightly during key SFX hits, fades out from 15.0s to 16.0s.
- SFX posture: Crisp, sparse, motion-matched UI audio.
- Audio-coupled moments:
  - 0.6s: Notification drop sound (`drop.ogg`)
  - 3.8s: Mechanical number ticker tick (`click.ogg`)
  - 8.0s: P2P contact resolution switch (`switch.ogg`)
  - 10.0s: Mandate card slide switch (`switch.ogg`)
  - 12.2s: Outro bass impact (`impact.ogg`)

## Storyboard

### Scene 1 — The Hook (0.0s – 3.2s)
Phone mockup centered on warm paper canvas. At 0.6s, a realistic Android notification banner drops from the top: "HDFC Bank · Paid ₹240.00 to Starbucks via UPI".
Sequential/interaction: Notification drops down, settles, and highlights the ₹240.00 amount.
Audio intent: Immediate relatable context.
Audio-coupled idea: Crisp notification drop sound at 0.6s.
Music: Warm background groove.
Transition mood: Smooth slide/absorb into Scene 2.

### Scene 2 — Mechanical Reaction (3.2s – 7.5s)
Notification banner slides into the top of the Kharcha transaction feed. Daily spend ticker increments from ₹3,420 to ₹3,660. Rust telemetry pill flashes: `⚡ kharcha-core (Rust) · 0.18ms · 100% Offline`.
Sequential/interaction: Ticker rolls up, new card lands in list, telemetry pill pulses.
Audio intent: High-tech speed and precision.
Audio-coupled idea: Tick SFX on numeric roll at 3.8s.
Transition mood: Smooth pan into Scene 3.

### Scene 3 — The Secret Weapons (7.5s – 12.0s)
Inside the app interface:
1. P2P Contact Resolver: Raw VPA `9876543210@paytm` morphs into "Kiran Sharma" with green checkmark.
2. Autopay Mandates: Mandate card slides in highlighting upcoming Netflix and SIP renewals with due dates.
Sequential/interaction: Contact morphs at 8.0s; Mandate card slides in at 10.0s.
Audio intent: Revealing powerful local features.
Audio-coupled idea: Switch click at 8.0s and 10.0s.
Transition mood: Hard cut / zoom into Scene 4.

### Scene 4 — Dark Outro (12.0s – 16.0s)
Canvas cuts to deep obsidian `#12120E`. Chiseled Kharcha emblem lands in center with amber/green glow.
Bold typography: "No Bank Login. No Cloud. Zero Tracking."
Subtext: "Download v0.1.2 on GitHub Releases".
Sequential/interaction: Logo lands with bounce, text reveals, CTA pill pulses.
Audio intent: Authoritative, decisive close.
Audio-coupled idea: Impact thud at 12.2s.

**Music mood for this video:** Confident, rhythmic, modern electronic groove.
**Audio summary:** Rhythmic background bed carrying 5 crisp, physical UI sound cues that punctuate the app's real-time actions.
