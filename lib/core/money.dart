/// Money parsing for user input. Amounts are stored as double (Drift Real),
/// so every boundary parse rounds to 2 decimal places to kill float drift
/// (0.1 + 0.2 ≠ 0.3). Returns null for garbage/negative input.
///
/// ponytail: true integer-paise storage (int columns + divide by 100) would
/// be exact, but touches every table + screen. Boundary rounding covers all
/// real drift sources for a tenth of the diff — revisit if accounting-grade
/// precision is ever required.
double? parseAmount(String? text) {
  final v = double.tryParse(text?.trim() ?? '');
  if (v == null || v < 0) return null;
  return (v * 100).round() / 100;
}
