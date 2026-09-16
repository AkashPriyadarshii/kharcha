//! kharcha-core — deterministic core of the Kharcha UPI expense tracker.
//!
//! Rule-based, no AI. Pure functions: SMS/notification text in, structured
//! payment out. Ports of `lib/core/*` (Dart) + `GenericUpiParser.kt` +
//! the `insertCaptured` dedupe rules.

pub mod categorize;
pub mod dedupe;
pub mod engine;
pub mod ffi;
pub mod filter;
pub mod money;
pub mod non_transaction;
pub mod parser;
pub mod split;

pub use categorize::{categorize, normalize_merchant, Rule};
pub use dedupe::{decide_capture, CaptureDecision, ExistingRow, DRIFT_SECS, WINDOW_MS};
pub use engine::{parse, parse_batch, ParsedTransaction};
pub use filter::{TransactionFilter, TxRow};
pub use money::parse_amount_paise;
pub use non_transaction::is_non_transaction;
pub use parser::{encode_inbox_line, parse_upi_notification, ParsedPayment};
pub use split::split_bill_paisa;

uniffi::setup_scaffolding!();
