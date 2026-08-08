import 'package:flutter/material.dart';

/// Income/expense mode switch — the Cashew signature. Expense red, income
/// green, matching the colored amounts across the app. Shared by the quick-add
/// dialog and the full add form so both stay in sync.
class IncomeExpenseToggle extends StatelessWidget {
  const IncomeExpenseToggle({
    super.key,
    required this.isIncome,
    required this.onChanged,
  });

  final bool isIncome;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<bool>(
      segments: const [
        ButtonSegment(
          value: false,
          label: Text('Expense'),
          icon: Icon(Icons.remove_circle_outline),
        ),
        ButtonSegment(
          value: true,
          label: Text('Income'),
          icon: Icon(Icons.add_circle_outline),
        ),
      ],
      selected: {isIncome},
      showSelectedIcon: false,
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.resolveWith((states) {
          if (!states.contains(WidgetState.selected)) return null;
          return isIncome ? incomeGreen : expenseRed;
        }),
        foregroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? Colors.white : null,
        ),
      ),
      onSelectionChanged: (s) => onChanged(s.first),
    );
  }
}

/// Income figures render green, expense red — one pair of constants everywhere.
const incomeGreen = Color(0xFF2E9E6B);
const expenseRed = Color(0xFFEF476F);
