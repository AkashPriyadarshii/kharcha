import 'database.dart';

/// A transaction as stored on Supabase (snake_case columns).
///
/// Pure mapping + conflict rules. No Supabase client here — unit-testable
/// without network.
class RemoteTransaction {
  const RemoteTransaction({
    required this.amount,
    required this.merchant,
    required this.txnDate,
    required this.paymentMethod,
    required this.source,
    required this.updatedAt,
    this.isIncome = false,
    this.needsReview = false,
    this.isDeleted = false,
    this.accountMask,
    this.emoji,
    this.id,
    this.note,
    this.upiRef,
  });

  /// Remote row id; null on a freshly built push payload.
  final int? id;
  final double amount;
  final String merchant;
  final DateTime txnDate;
  final String? note;
  final String paymentMethod;
  final String? upiRef;
  final String source;
  final DateTime updatedAt;
  final bool isIncome;
  final bool needsReview;
  final bool isDeleted;
  final String? accountMask;
  final String? emoji;

  /// Local row → Supabase upsert payload. [userId] is the signed-in user;
  /// RLS requires `user_id = auth.uid()`. Local `id` is deliberately omitted
  /// (remote identity is the identity column) and `category_id` is never sent:
  /// categories are derived locally from merchant rules, so the remote copy is
  /// the same for every user and needs no per-user id mapping.
  ///
  /// `updated_at` carries the local row's own timestamp — it is the LWW clock.
  Map<String, dynamic> toRemoteJson(String userId) {
    return {
      'user_id': userId,
      'amount': amount,
      'merchant': merchant,
      'txn_date': txnDate.toUtc().toIso8601String(),
      'note': note,
      'payment_method': paymentMethod,
      'upi_ref': upiRef,
      'source': source,
      'is_income': isIncome,
      'needs_review': needsReview,
      'is_deleted': isDeleted,
      'account_mask': accountMask,
      'emoji': emoji,
      'updated_at': updatedAt.toUtc().toIso8601String(),
    };
  }

  static RemoteTransaction fromRemoteJson(Map<String, dynamic> json) {
    return RemoteTransaction(
      id: json['id'] as int?,
      amount: (json['amount'] as num).toDouble(),
      merchant: json['merchant'] as String,
      txnDate: DateTime.parse(json['txn_date'] as String).toLocal(),
      note: json['note'] as String?,
      paymentMethod: json['payment_method'] as String,
      upiRef: json['upi_ref'] as String?,
      source: json['source'] as String,
      isIncome: json['is_income'] as bool? ?? false,
      needsReview: json['needs_review'] as bool? ?? false,
      isDeleted: json['is_deleted'] as bool? ?? false,
      accountMask: json['account_mask'] as String?,
      emoji: json['emoji'] as String?,
      updatedAt: DateTime.parse(json['updated_at'] as String).toLocal(),
    );
  }

}

/// Local row → remote payload. Wraps [RemoteTransaction.toRemoteJson].
Map<String, dynamic> localToRemoteJson(Transaction t, String userId) {
  return RemoteTransaction(
    amount: t.amount,
    merchant: t.merchant,
    txnDate: t.txnDate,
    note: t.note,
    paymentMethod: t.paymentMethod,
    upiRef: t.upiRef,
    source: t.source,
    isIncome: t.isIncome,
    needsReview: t.needsReview,
    isDeleted: t.isDeleted,
    accountMask: t.accountMask,
    emoji: t.emoji,
    updatedAt: t.updatedAt,
  ).toRemoteJson(userId);
}

/// Last-write-wins: local wins on tie (keeps the user's copy, avoids churn).
bool localWins(DateTime localUpdatedAt, DateTime remoteUpdatedAt) {
  return !localUpdatedAt.isBefore(remoteUpdatedAt);
}
