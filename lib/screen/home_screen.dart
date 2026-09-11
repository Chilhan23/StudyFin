import 'package:flutter/material.dart';
import '../main.dart' show AppColors;
import '../models/study_session.dart';
import '../models/transaction_item.dart';
import '../services/database_services.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  List<StudySession> _sessions = [];
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
    final results = await Future.wait([
      DatabaseService.instance.getAllStudySessions(),
      DatabaseService.instance.getAllTransactions(),
    ]);
    if (mounted) {
      setState(() {
        _sessions = results[0] as List<StudySession>;
        _transactions = results[1] as List<TransactionItem>;
        _loading = false;
      });
      _ctrl.forward(from: 0);
    }
  }

  // ── Aggregations ──────────────────────────────────────────────
  int get _weeklyStudyMinutes {
    final now = DateTime.now();
    return _sessions.where((s) {
      final diff = now.difference(s.date).inDays;
      return diff >= 0 && diff < 7;
    }).fold(0, (sum, s) => sum + s.durationMinutes);
  }

  String get _studyHoursLabel {
    final mins = _weeklyStudyMinutes;
    final h = mins ~/ 60;
    final m = mins % 60;
    if (h == 0) return '${m}m';
    if (m == 0) return '${h}h';
    return '${h}h ${m}m';
  }

  double get _balance {
    final income = _transactions.where((t) => t.isIncome).fold(0.0, (s, t) => s + t.amount);
    final expense = _transactions.where((t) => !t.isIncome).fold(0.0, (s, t) => s + t.amount);
    return income - expense;
  }

  List<_ActivityEntry> get _recentActivity {
    final list = <_ActivityEntry>[];
    for (final s in _sessions) {
      list.add(_ActivityEntry(
        icon: Icons.menu_book_outlined,
        title: s.subject,
        subtitle: 'Study · ${_fmtMins(s.durationMinutes)}',
        date: s.date,
        iconColor: AppColors.accent,
      ));
    }
    for (final t in _transactions) {
      list.add(_ActivityEntry(
        icon: t.isIncome ? Icons.add_circle_outline : Icons.remove_circle_outline,
        title: t.title,
        subtitle: '${t.isIncome ? 'Income' : 'Expense'} · ${_fmtRupiah(t.amount)}',
        date: t.date,
        iconColor: t.isIncome ? AppColors.incomeColor : AppColors.expenseColor,
      ));
    }
    list.sort((a, b) => b.date.compareTo(a.date));
    return list.take(5).toList();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final activity = _recentActivity;
    final weekSessions = _sessions.where((s) {
      final diff = DateTime.now().difference(s.date).inDays;
      return diff >= 0 && diff < 7;
    }).length;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('StudyFin'),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined, size: 22),
            onPressed: () {},
          ),
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
                      Text('Overview', style: textTheme.bodyMedium),
                      const SizedBox(height: 2),
                      Text('StudyFin', style: textTheme.headlineLarge),
                      const SizedBox(height: 24),

                      Row(
                        children: [
                          Expanded(child: _SummaryCard(
                            label: 'Study This Week',
                            value: _studyHoursLabel,
                            icon: Icons.menu_book_outlined,
                            sub: '$weekSessions sessions',
                          )),
                          const SizedBox(width: 12),
                          Expanded(child: _SummaryCard(
                            label: 'Balance',
                            value: _fmtRupiah(_balance),
                            icon: Icons.account_balance_wallet_outlined,
                            sub: '${_transactions.length} transactions',
                          )),
                        ],
                      ),
                      const SizedBox(height: 24),

                      Text('Recent Activity', style: textTheme.titleLarge),
                      const SizedBox(height: 12),

                      if (activity.isEmpty)
                        _EmptyState(
                          icon: Icons.history,
                          message: 'No activity yet.\nAdd a study session or transaction.',
                        )
                      else
                        Container(
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Column(
                            children: List.generate(activity.length, (i) {
                              final a = activity[i];
                              return Column(
                                children: [
                                  _ActivityRow(entry: a),
                                  if (i < activity.length - 1)
                                    const Divider(height: 1, indent: 16, endIndent: 16),
                                ],
                              );
                            }),
                          ),
                        ),

                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}

// ── Shared helpers ────────────────────────────────────────────────
String _fmtRupiah(double amount) {
  if (amount < 0) return '-${_fmtRupiah(amount.abs())}';
  if (amount >= 1000000) return 'Rp ${(amount / 1000000).toStringAsFixed(1)}M';
  if (amount >= 1000) return 'Rp ${(amount / 1000).toStringAsFixed(0)}K';
  return 'Rp ${amount.toStringAsFixed(0)}';
}

String _fmtMins(int mins) {
  final h = mins ~/ 60;
  final m = mins % 60;
  if (h == 0) return '${m}m';
  if (m == 0) return '${h}h';
  return '${h}h ${m}m';
}

String _timeAgo(DateTime date) {
  final diff = DateTime.now().difference(date);
  if (diff.inDays == 0) return 'Today';
  if (diff.inDays == 1) return 'Yesterday';
  if (diff.inDays < 7) return '${diff.inDays}d ago';
  return '${date.day}/${date.month}';
}

// ── Data class ────────────────────────────────────────────────────
class _ActivityEntry {
  final IconData icon;
  final String title;
  final String subtitle;
  final DateTime date;
  final Color iconColor;

  const _ActivityEntry({
    required this.icon, required this.title, required this.subtitle,
    required this.date, required this.iconColor,
  });
}

// ── Sub-widgets ───────────────────────────────────────────────────

class _SummaryCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final String sub;

  const _SummaryCard({required this.label, required this.value,
    required this.icon, required this.sub});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(child: Text(label, style: const TextStyle(
                color: AppColors.textSecondary, fontSize: 11,
              ), overflow: TextOverflow.ellipsis)),
              Icon(icon, size: 15, color: AppColors.textSecondary),
            ],
          ),
          const SizedBox(height: 10),
          Text(value, style: const TextStyle(
            color: AppColors.textPrimary, fontSize: 20,
            fontWeight: FontWeight.w700, letterSpacing: -0.3,
          )),
          const SizedBox(height: 4),
          Text(sub, style: const TextStyle(
            color: AppColors.textSecondary, fontSize: 11)),
        ],
      ),
    );
  }
}

class _ActivityRow extends StatelessWidget {
  final _ActivityEntry entry;
  const _ActivityRow({required this.entry});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: AppColors.surfaceAlt,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(entry.icon, size: 17, color: entry.iconColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(entry.title, style: const TextStyle(
                  color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w500,
                )),
                const SizedBox(height: 2),
                Text(entry.subtitle, style: const TextStyle(
                  color: AppColors.textSecondary, fontSize: 12,
                )),
              ],
            ),
          ),
          Text(_timeAgo(entry.date), style: const TextStyle(
            color: AppColors.textSecondary, fontSize: 12,
          )),
        ],
      ),
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