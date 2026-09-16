//! Smoke CLI: parse one SMS/notification through the unified engine.
//! `cargo run --bin demo -- "₹450 paid to Swiggy using UPI UPI Ref 123456789012" [sender]`

use kharcha_core::engine;

fn main() {
    let args: Vec<String> = std::env::args().collect();
    let body = args.get(1).map(String::as_str).unwrap_or("₹450 paid to Swiggy using UPI UPI Ref 123456789012");
    let sender = args.get(2).map(String::as_str).unwrap_or("HDFCBK");
    match engine::parse(body, sender, 0) {
        Some(t) => println!("{t:?}"),
        None => println!("not-a-payment"),
    }
}
