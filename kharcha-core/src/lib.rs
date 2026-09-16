//! Kharcha core — India-first UPI expense tracker logic.
//! Pure Rust, no Flutter, no network. Consumed later via UniFFI by the
//! Kotlin Compose app.

pub mod categorizer;
pub mod money;
pub mod upi_parser;