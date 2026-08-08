/// Splits [total] across [count] people so the parts sum EXACTLY to [total].
///
/// Distributes a whole-paise grid across people: base + remainder spread one
/// extra paisa to the first `rem` people. No floating-point drift.
List<int> splitBillPaisa(int totalPaisa, int count) {
  if (count <= 0) return const [];
  if (count == 1) return [totalPaisa];
  final base = totalPaisa ~/ count;
  final rem = totalPaisa % count;
  return [for (var i = 0; i < count; i++) base + (i < rem ? 1 : 0)];
}
