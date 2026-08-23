import '../data/database.dart';

/// Client-side filter for the transactions list. Immutable.
///
/// Applied in memory over the watched list — personal expense volume is
/// small, so this avoids new DB queries and stream churn. Pure: unit-testable
/// without a widget tree or database.
class TransactionFilter {
  const TransactionFilter({
    this.query = '',
    this.categoryId,
    this.merchant,
    this.paymentMethod,
    this.isIncome,
    this.from,
    this.to,
  });

  /// Free-text, case-insensitive over merchant + note.
  final String query;

  /// Exact category id (null = all).
  final int? categoryId;

  /// Exact merchant name (null = all).
  final String? merchant;

  /// Exact payment method: cash | upi | card | wallet (null = all).
  final String? paymentMethod;

  /// Income/expense filter (null = both).
  final bool? isIncome;

  /// Earliest txnDate, inclusive (null = unbounded).
  final DateTime? from;

  /// Latest txnDate, inclusive (null = unbounded).
  final DateTime? to;

  bool get isEmpty =>
      query.isEmpty &&
      categoryId == null &&
      merchant == null &&
      paymentMethod == null &&
      isIncome == null &&
      from == null &&
      to == null;

  /// Rows matching every active criterion, keeping input order.
  List<Transaction> apply(List<Transaction> all) {
    final q = query.trim().toLowerCase();
    final tokens = q.split(RegExp(r'\s+')).where((s) => s.isNotEmpty).toList();
    final f = from;
    final t2 = to;
    return [
      for (final t in all)
        if ((tokens.isEmpty ||
                tokens.every((tok) =>
                    t.merchant.toLowerCase().contains(tok) ||
                    (t.note?.toLowerCase().contains(tok) ?? false) ||
                    (t.upiRef?.toLowerCase().contains(tok) ?? false) ||
                    t.amount.toString().contains(tok))) &&
            (categoryId == null || t.categoryId == categoryId) &&
            (merchant == null || t.merchant == merchant) &&
            (paymentMethod == null || t.paymentMethod == paymentMethod) &&
            (isIncome == null || t.isIncome == isIncome) &&
            (f == null || !t.txnDate.isBefore(f)) &&
            (t2 == null || !t.txnDate.isAfter(t2)))
          t,
    ];
  }
}
