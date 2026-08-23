import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../core/bill_splitter.dart';
import '../core/theme.dart';
import '../data/transaction_repository.dart';

final _currency = NumberFormat.currency(locale: 'en_IN', symbol: '₹');

/// Splits a bill across N people and inserts one transaction per person.
class BillSplitterScreen extends ConsumerStatefulWidget {
  const BillSplitterScreen({super.key});

  @override
  ConsumerState<BillSplitterScreen> createState() => _BillSplitterScreenState();
}

class _BillSplitterScreenState extends ConsumerState<BillSplitterScreen> {
  final _total = TextEditingController();
  int _people = 2;
  String _merchant = '';

  @override
  void dispose() {
    _total.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final totalPaisa = ((double.tryParse(_total.text.trim()) ?? 0) * 100).round();
    final shares = totalPaisa > 0 ? splitBillPaisa(totalPaisa, _people) : const <int>[];
    final canSave = totalPaisa > 0 && _merchant.trim().isNotEmpty;

    return Scaffold(
      appBar: AppBar(title: const Text('Split a bill')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _total,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Total bill', prefixText: '₹ '),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 16),
          TextField(
            decoration: const InputDecoration(labelText: 'Merchant', hintText: 'e.g. Dinner at 3 Brothers'),
            onChanged: (v) => setState(() => _merchant = v),
          ),
          const SizedBox(height: 16),
          Text('Split between $_people people'),
          Slider(
            value: _people.toDouble(),
            min: 1,
            max: 20,
            divisions: 19,
            label: '$_people',
            onChanged: (v) => setState(() => _people = v.round()),
          ),
          const SizedBox(height: 8),
          if (shares.isNotEmpty) ...[
            for (var i = 0; i < shares.length; i++)
              ListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                title: Text('Person ${i + 1}'),
                trailing: Text(_currency.format(shares[i] / 100), style: moneyStyle.copyWith(fontSize: 13)),
              ),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: canSave
                  ? () async {
                      final repo = ref.read(transactionRepositoryProvider);
                      for (var i = 0; i < shares.length; i++) {
                        // A sub-paisa share splits to 0 (₹0.01 / 3) — never
                        // insert a zero-amount expense (insertManual rejects).
                        if (shares[i] <= 0) continue;
                        await repo.insertManual(
                          amount: shares[i] / 100,
                          merchant: _merchant.trim(),
                          paymentMethod: 'upi',
                          txnDate: DateTime.now(),
                          note: 'Split ${i + 1}/${shares.length}',
                        );
                      }
                      if (!context.mounted) return;
                      Navigator.of(context).pop();
                    }
                  : null,
              child: Text('Save $_people expenses'),
            ),
          ],
        ],
      ),
    );
  }
}
