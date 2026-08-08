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

  /// Earliest txnDate, inclusive (null = unbounded).
  final DateTime? from;

  /// Latest txnDate, inclusive (null = unbounded).
  final DateTime? to;

  bool get isEmpty =>
      query.isEmpty &&
      categoryId == null &&
      merchant == null &&
      paymentMethod == null &&
      from == null &&
      to == null;

  /// Rows matching every active criterion, keeping input order.
  List<Transaction> apply(List<Transaction> all) {
    final q = query.trim().toLowerCase();
    final f = from;
    final t2 = to;
    return [
      for (final t in all)
        if ((q.isEmpty ||
                t.merchant.toLowerCase().contains(q) ||
                (t.note?.toLowerCase().contains(q) ?? false)) &&
            (categoryId == null || t.categoryId == categoryId) &&
            (merchant == null || t.merchant == merchant) &&
            (paymentMethod == null || t.paymentMethod == paymentMethod) &&
            (f == null || !t.txnDate.isBefore(f)) &&
            (t2 == null || !t.txnDate.isAfter(t2)))
          t,
    ];
  }
}
