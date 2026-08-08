import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../data/database.dart';
import '../data/sync_engine.dart';
import '../data/transaction_repository.dart';
import '../widgets/income_expense_toggle.dart';

/// Full manual expense entry. Launched from the transactions list.
class AddExpenseScreen extends ConsumerStatefulWidget {
  const AddExpenseScreen({super.key});

  @override
  ConsumerState<AddExpenseScreen> createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends ConsumerState<AddExpenseScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amount = TextEditingController();
  final _merchant = TextEditingController();
  final _note = TextEditingController();

  int? _categoryId;
  int? _walletId;
  String _paymentMethod = 'upi';
  DateTime _date = DateTime.now();
  bool _isIncome = false;
  bool _saving = false;

  @override
  void dispose() {
    _amount.dispose();
    _merchant.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);
    final container = ProviderScope.containerOf(context);
    try {
      await ref.read(transactionRepositoryProvider).insertManual(
            amount: double.parse(_amount.text),
            merchant: _merchant.text,
            categoryId: _categoryId,
            walletId: _walletId,
            note: _note.text,
            paymentMethod: _paymentMethod,
            txnDate: _date,
            isIncome: _isIncome,
          );
      unawaited(syncIfSignedIn(container));
      if (!mounted) return;
      context.pop();
    } catch (e) {
      setState(() => _saving = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Could not save: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final categories = ref.watch(categoriesProvider).value ?? const <Category>[];
    // Only the categories that match the current mode (expense or income).
    final cats = categories.where((c) => c.isIncome == _isIncome).toList();
    final wallets = ref.watch(walletsProvider).value ?? const <Wallet>[];

    return Scaffold(
      appBar: AppBar(
        title: Text(_isIncome ? 'Add income' : 'Add expense'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          tooltip: 'Cancel',
          onPressed: () => context.pop(),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            IncomeExpenseToggle(
              isIncome: _isIncome,
              onChanged: (v) => setState(() {
                _isIncome = v;
                _categoryId = null; // category list changes with the mode
              }),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _amount,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
              decoration: const InputDecoration(
                labelText: 'Amount',
                prefixText: '₹ ',
              ),
              validator: (value) {
                final amount = double.tryParse(value ?? '');
                if (amount == null || amount <= 0) return 'Enter an amount greater than zero.';
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _merchant,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Merchant',
                hintText: 'e.g. Swiggy, Rapido, Amazon',
              ),
              validator: (value) =>
                  (value ?? '').trim().isEmpty ? 'Enter the merchant name.' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _note,
              decoration: const InputDecoration(labelText: 'Note (optional)'),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<int>(
              decoration: const InputDecoration(labelText: 'Category'),
              hint: const Text('Uncategorized'),
              items: [
                for (final c in cats)
                  DropdownMenuItem(value: c.id, child: Text('${c.emoji}  ${c.name}')),
              ],
              onChanged: (value) => setState(() => _categoryId = value),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<int?>(
              decoration: const InputDecoration(labelText: 'Wallet'),
              hint: const Text('No wallet'),
              initialValue: _walletId,
              items: [
                for (final w in wallets)
                  DropdownMenuItem(value: w.id, child: Text(w.name)),
              ],
              onChanged: (value) => setState(() => _walletId = value),
            ),
            const SizedBox(height: 16),
            SegmentedButton<String>(
              segments: [
                for (final m in TransactionRepository.paymentMethods)
                  ButtonSegment(value: m, label: Text(m.toUpperCase())),
              ],
              selected: {_paymentMethod},
              onSelectionChanged: (s) => setState(() => _paymentMethod = s.first),
            ),
            const SizedBox(height: 16),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.calendar_today),
              title: Text('Date: ${DateFormat.yMMMd().format(_date)}'),
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _date,
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now().add(const Duration(days: 365)),
                );
                if (picked != null) setState(() => _date = picked);
              },
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(_isIncome ? 'Save income' : 'Save expense'),
            ),
          ],
        ),
      ),
    );
  }
}
