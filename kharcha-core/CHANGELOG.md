# Changelog

## v0.1.1 (2026-09-20)

- `ATM_WITHDRAWAL_RE` — ATM cash withdrawal detection (all major banks).
- `DIRECT_PAYEE_RE` — capitalized payee extraction without prepositions (AMAZON, SWIGGY, ZOMATO).
- Indian mobile VPA normalization: `+91`/`91` prefix → canonical 10-digit number.
- `RECIPIENT_MERCHANT_RE` updated to handle leading `+` and 11+ digit numbers with `@`.
- Pan-Indian bank coverage: SBI, HDFC, ICICI, Axis, Kotak, PNB, BOB, Canara, Union Bank, IDFC FIRST, IndusInd, Federal, Yes Bank.
- UPI app formats: PhonePe, GPay, Paytm, CRED, BHIM, Navi, Tata Neu.
- Credit card templates: OneCard, Scapia, HDFC CC, ICICI CC, SBI Card.
- New formats: UPI Lite, Rupay Credit on UPI, NACH/SI mandate, ATM withdrawal, POS/NFC contactless.
- Non-transaction filter: loan pre-approval, EMI conversion offers, bill generation reminders, pre-approved credit limit alerts all rejected.
- 60/60 tests passing (24 unit + 36 parity).

## v0.1 (2026-09-17)

- Initial Rust port of kharcha's deterministic core: money, split, categorize,
  filter, UPI parser, spam rejection, capture dedupe.
- i64 paise money, `fancy-regex` engine, parity harness vs Dart corpus.
