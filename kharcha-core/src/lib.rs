//! Kharcha core — India-first UPI expense tracker logic.
//! Pure Rust, no Flutter, no network. Consumed via UniFFI by the Kotlin
//! Compose app.

pub mod categorizer;
pub mod money;
pub mod upi_parser;

uniffi::setup_scaffolding!();

#[uniffi::export]
pub fn parse_amount(text: String) -> Option<f64> {
    money::parse_amount(&text)
}

#[uniffi::export]
pub fn normalize_merchant(raw: String) -> String {
    categorizer::normalize_merchant(&raw)
}

#[uniffi::export]
pub fn is_non_transaction(text: String) -> bool {
    upi_parser::is_non_transaction(&text)
}

#[uniffi::export]
pub fn parse_payment(text: String) -> Option<upi_parser::ParsedPayment> {
    upi_parser::parse_payment(&text)
}

use categorizer::Classifier;

#[uniffi::export]
impl Classifier {
    #[uniffi::constructor]
    pub fn new_from_vec(rules: Vec<categorizer::Rule>) -> Self {
        Self::new(&rules)
    }

    pub fn categorize_id(&self, merchant: String) -> Option<i64> {
        self.category_of(&merchant)
    }
}