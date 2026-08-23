# Kharcha — Privacy Policy (Play Store / public)

> Public layer: privacy-first framing only. This is the user-facing contract.
> Do not add internal "track everything" language here. See CLAUDE.md §Data & privacy.

_Last updated: 2026-08-08_

## Overview

Kharcha is an India-first UPI expense tracker. Your spend data stays on your
device. We do not sell your data, share it with advertisers, or use it for ad
targeting.

## What Kharcha collects

- **Expenses you record** — amount, merchant, category, note, date, payment
  method. You see every one of these in the app and can export them anytime.
- **UPI payment notifications** — with your permission, Kharcha reads UPI
  payment notifications (GPay, PhonePe, Paytm, etc.) to auto-add the expense.
  It reads only the payment details (amount, merchant, transaction ref) and
  never the full notification content.

## Permissions

| Permission | Why |
|---|---|
| Notification & SMS access | Auto-capture UPI payments (opt-in, on-device, SMS supported) |
| Biometric / PIN | Optional app lock so only you can open Kharcha |
| Notifications | Daily 9PM + Sunday weekly spend summaries (opt-in) |

## Data storage

- Your expenses are stored **on-device** first (offline-first).
- If you sign in with Google, expenses sync to our backend so they're backed
  up across your devices. Sync is optional — the app works fully offline.
- Data is **encrypted in transit** (HTTPS) and **encrypted at rest**.
- App lock protects on-device access (biometric / PIN).

## What we do NOT do

- **Never sell** your data.
- **Never share** with advertisers.
- **Never** ad-target.
- **Opt-in** SMS reading for auto-capture.
- **No** bank login or credential storage.
- **No AI.** Categorization is a local rule map.

## Your control

- **Export anytime** — CSV or JSON from the Profile tab.
- **Delete** — you can delete any expense in the app.
- **Turn off capture** — disable notification access anytime.
- **Sign out** — stops sync; on-device data remains yours.

## Contact

For privacy questions: Akash — owner, via the GitHub repo
`AkashPriyadarshii/kharcha`.
