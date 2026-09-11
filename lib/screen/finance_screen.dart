import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../main.dart' show AppColors;
import '../models/transaction_item.dart';
import '../services/database_services.dart';

class FinanceScreen extends StatefulWidget {
  const FinanceScreen({super.key});

  @override
  State<FinanceScreen> createState() => _FinanceScreenState();
}

class _FinanceScreenState extends State<FinanceScreen>
    with SingleTickerProviderStateMixin {
  List<TransactionItem> _transactions = [];
  bool _loading = true;

  late final AnimationController _ctrl;
  late final Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    _fadeAnim = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _load();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final data = await DatabaseService.instance.getAllTransactions();
    if (mounted) {
      setState(() { _transactions = data; _loading = false; });
      _ctrl.forward(from: 0);
    }
  }

  // ── Aggregations ──────────────────────────────────────────────
  double get _totalIncome =>
      _transactions.where((t) => t.isIncome).fold(0.0, (s, t) => s + t.amount);

  double get _totalExpenses =>
      _transactions.where((t) => !t.isIncome).fold(0.0, (s, t) => s + t.amount);

  double get _balance => _totalIncome - _totalExpenses;

  double get _budgetFraction =>
      _totalIncome > 0 ? (_totalIncome - _totalExpenses) / _totalIncome : 0.0;

  Map<String, double> get _categoryTotals {
    final map = <String, double>{};
    for (final t in _transactions.where((t) => !t.isIncome)) {
      map[t.category] = (map[t.category] ?? 0) + t.amount;
    }
    return Map.fromEntries(
      map.entries.toList()..sort((a, b) => b.value.compareTo(a.value)),
    );
  }

  // ── Bottom Sheet ───────────────────────────────────────────────
  void _showAddSheet() {
    final titleCtrl    = TextEditingController();
    final amountCtrl   = TextEditingController();
    final categoryCtrl = TextEditingController();
    bool isIncome = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: EdgeInsets.only(
            left: 20, right: 20, top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Container(
                width: 40, height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              )),
              const Text('Add Transaction', style: TextStyle(
                color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w600,
              )),
              const SizedBox(height: 20),

              // Type toggle — monochrome
              Container(
                decoration: BoxDecoration(
                  color: AppColors.surfaceAlt,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    Expanded(child: _TypeButton(
                      label: 'Expense',
                      selected: !isIncome,
                      onTap: () => setSheet(() => isIncome = false),
                    )),
                    Expanded(child: _TypeButton(
                      label: 'Income',
                      selected: isIncome,
                      onTap: () => setSheet(() => isIncome = true),
                    )),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              _SheetField(controller: titleCtrl, label: 'Title', hint: 'e.g. Lunch'),
              const SizedBox(height: 12),
              _SheetField(
                controller: amountCtrl,
                label: 'Amount (Rp)',
                hint: 'e.g. 25000',
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              ),
              const SizedBox(height: 12),
              _SheetField(
                controller: categoryCtrl,
                label: 'Category',
                hint: 'e.g. Food, Transport, Education',
              ),
              const SizedBox(height: 20),

              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.background,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () async {
                    final title    = titleCtrl.text.trim();
                    final amount   = double.tryParse(amountCtrl.text.trim()) ?? 0;
                    final category = categoryCtrl.text.trim();
                    if (title.isEmpty || amount <= 0 || category.isEmpty) return;
                    await DatabaseService.instance.insertTransaction(TransactionItem(
                      title: title, amount: amount,
                      category: category,
                      date: DateTime.now(), isIncome: isIncome,
                    ));
                    if (ctx.mounted) Navigator.pop(ctx);
                    _load();
                  },
                  child: const Text('Save Transaction', style: TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w600,
                  )),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final cats  = _categoryTotals;
    final maxCat = cats.isEmpty ? 1.0 : cats.values.first;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Finance Tracker'),
        actions: [
          IconButton(icon: const Icon(Icons.add, size: 22), onPressed: _showAddSheet),
          const SizedBox(width: 4),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(
              color: AppColors.accent, strokeWidth: 2))
          : FadeTransition(
              opacity: _fadeAnim,
              child: RefreshIndicator(
                color: AppColors.primary,
                backgroundColor: AppColors.surface,
                onRefresh: _load,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 8),

                      _BalanceCard(
                        balance: _balance,
                        fraction: _budgetFraction.clamp(0.0, 1.0),
                        remainingPct: (_budgetFraction * 100).clamp(0, 100).round(),
                      ),
                      const SizedBox(height: 16),

                      Row(
                        children: [
                          Expanded(child: _FlowCard(
                            label: 'Income',
                            amount: _fmtRupiah(_totalIncome),
                            icon: Icons.arrow_downward,
                            isIncome: true,
                          )),
                          const SizedBox(width: 12),
                          Expanded(child: _FlowCard(
                            label: 'Expenses',
                            amount: _fmtRupiah(_totalExpenses),
                            icon: Icons.arrow_upward,
                            isIncome: false,
                          )),
                        ],
                      ),
                      const SizedBox(height: 24),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Transactions', style: textTheme.titleLarge),
                          Text('${_transactions.length} total', style: const TextStyle(
                            color: AppColors.textSecondary, fontSize: 13,
                          )),
                        ],
                      ),
                      const SizedBox(height: 12),

                      if (_transactions.isEmpty)
                        _EmptyState(
                          icon: Icons.account_balance_wallet_outlined,
                          message: 'No transactions yet.\nTap + to add one.',
                        )
                      else
                        Container(
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Column(
                            children: List.generate(_transactions.length, (i) {
                              final t = _transactions[i];
                              return Column(
                                children: [
                                  _TransactionTile(transaction: t, onDelete: () async {
                                    await DatabaseService.instance.deleteTransaction(t.id!);
                                    _load();
                                  }),
                                  if (i < _transactions.length - 1)
                                    const Divider(height: 1, indent: 16, endIndent: 16),
                                ],
                              );
                            }),
                          ),
                        ),

                      if (cats.isNotEmpty) ...[
                        const SizedBox(height: 24),
                        Text('By Category', style: textTheme.titleLarge),
                        const SizedBox(height: 12),
                        ...cats.entries.take(5).map((e) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _CategoryBar(
                            label: e.key,
                            amount: _fmtRupiah(e.value),
                            fraction: maxCat > 0 ? e.value / maxCat : 0,
                          ),
                        )),
                      ],

                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────────
String _fmtRupiah(double amount) {
  if (amount < 0) return '-${_fmtRupiah(amount.abs())}';
  if (amount >= 1000000) return 'Rp ${(amount / 1000000).toStringAsFixed(1)}M';
  if (amount >= 1000) return 'Rp ${(amount / 1000).toStringAsFixed(0)}K';
  return 'Rp ${amount.toStringAsFixed(0)}';
}

String _monthAbbr(int month) {
  const m = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
  return m[month - 1];
}

// ── Sub-widgets ───────────────────────────────────────────────────

class _BalanceCard extends StatelessWidget {
  final double balance;
  final double fraction;
  final int remainingPct;

  const _BalanceCard({required this.balance, required this.fraction, required this.remainingPct});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Current Balance', style: TextStyle(
            color: AppColors.textSecondary, fontSize: 13,
          )),
          const SizedBox(height: 8),
          Text(
            balance >= 0 ? _fmtRupiah(balance) : '-${_fmtRupiah(balance.abs())}',
            style: TextStyle(
              color: balance >= 0 ? AppColors.textPrimary : AppColors.accent,
              fontSize: 28, fontWeight: FontWeight.w700, letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: fraction,
              minHeight: 4,
              backgroundColor: AppColors.surfaceAlt,
              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Income vs Expenses', style: TextStyle(
                color: AppColors.textSecondary, fontSize: 12,
              )),
              Text('$remainingPct% remaining', style: const TextStyle(
                color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.w500,
              )),
            ],
          ),
        ],
      ),
    );
  }
}

class _FlowCard extends StatelessWidget {
  final String label;
  final String amount;
  final IconData icon;
  final bool isIncome;

  const _FlowCard({required this.label, required this.amount,
    required this.icon, required this.isIncome});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: AppColors.surfaceAlt,
              borderRadius: BorderRadius.circular(10),
              // income gets a subtle white border, expense stays plain
              border: isIncome
                  ? Border.all(color: AppColors.primary.withValues(alpha: 0.3))
                  : null,
            ),
            child: Icon(icon, size: 16,
              color: isIncome ? AppColors.incomeColor : AppColors.expenseColor,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(
                  color: AppColors.textSecondary, fontSize: 11,
                )),
                const SizedBox(height: 2),
                Text(amount, style: const TextStyle(
                  color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w600,
                ), overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TransactionTile extends StatelessWidget {
  final TransactionItem transaction;
  final VoidCallback onDelete;

  const _TransactionTile({required this.transaction, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final t = transaction;
    final dateStr = '${t.date.day} ${_monthAbbr(t.date.month)}';

    return Dismissible(
      key: Key('txn_${t.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Icon(Icons.delete_outline, color: AppColors.textSecondary, size: 20),
      ),
      onDismissed: (_) => onDelete(),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: AppColors.surfaceAlt,
                borderRadius: BorderRadius.circular(10),
                // income: subtle outer border to distinguish without color
                border: t.isIncome
                    ? Border.all(color: AppColors.primary.withValues(alpha: 0.25))
                    : Border.all(color: AppColors.border),
              ),
              child: Icon(
                t.isIncome ? Icons.arrow_downward : Icons.arrow_upward,
                size: 16,
                color: t.isIncome ? AppColors.incomeColor : AppColors.expenseColor,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(t.title, style: const TextStyle(
                    color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w500,
                  )),
                  const SizedBox(height: 2),
                  Text(t.category, style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: 12,
                  )),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${t.isIncome ? '+' : '-'}${_fmtRupiah(t.amount)}',
                  style: TextStyle(
                    // income = crisp white, expense = muted ash
                    color: t.isIncome ? AppColors.incomeColor : AppColors.expenseColor,
                    fontSize: 13, fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(dateStr, style: const TextStyle(
                  color: AppColors.textSecondary, fontSize: 11,
                )),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryBar extends StatelessWidget {
  final String label;
  final String amount;
  final double fraction;

  const _CategoryBar({required this.label, required this.amount, required this.fraction});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(
              color: AppColors.textPrimary, fontSize: 13,
            )),
            Text(amount, style: const TextStyle(
              color: AppColors.textSecondary, fontSize: 13,
            )),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: fraction,
            minHeight: 5,
            backgroundColor: AppColors.surfaceAlt,
            valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
          ),
        ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;
  const _EmptyState({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 40),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Icon(icon, size: 32, color: AppColors.textSecondary),
          const SizedBox(height: 12),
          Text(message, style: const TextStyle(
            color: AppColors.textSecondary, fontSize: 13, height: 1.5,
          ), textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

class _TypeButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _TypeButton({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(label, textAlign: TextAlign.center, style: TextStyle(
          color: selected ? AppColors.background : AppColors.textSecondary,
          fontSize: 13, fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
        )),
      ),
    );
  }
}

class _SheetField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final TextInputType keyboardType;
  final List<TextInputFormatter>? inputFormatters;

  const _SheetField({
    required this.controller, required this.label, required this.hint,
    this.keyboardType = TextInputType.text, this.inputFormatters,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(
          color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w500,
        )),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
          cursorColor: AppColors.primary,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
            filled: true,
            fillColor: AppColors.surfaceAlt,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }
}