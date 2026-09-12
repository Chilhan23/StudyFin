import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../main.dart' show AppColors;
import '../models/study_session.dart';
import '../services/database_services.dart';
import 'study_timer_screen.dart';

class StudyScreen extends StatefulWidget {
  const StudyScreen({super.key});

  @override
  State<StudyScreen> createState() => _StudyScreenState();
}

class _StudyScreenState extends State<StudyScreen>
    with SingleTickerProviderStateMixin {
  List<StudySession> _sessions = [];
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
    final data = await DatabaseService.instance.getAllStudySessions();
    if (mounted) {
      setState(() { _sessions = data; _loading = false; });
      _ctrl.forward(from: 0);
    }
  }

  // ── Aggregations ──────────────────────────────────────────────
  List<StudySession> get _todaySessions {
    final today = DateTime.now();
    return _sessions.where((s) =>
      s.date.year == today.year &&
      s.date.month == today.month &&
      s.date.day == today.day
    ).toList();
  }

  List<double> get _weeklyHours {
    final now = DateTime.now();
    return List.generate(7, (i) {
      final day = DateTime(now.year, now.month, now.day - (6 - i));
      final mins = _sessions
          .where((s) => s.date.year == day.year &&
              s.date.month == day.month &&
              s.date.day == day.day)
          .fold(0, (sum, s) => sum + s.durationMinutes);
      return mins / 60.0;
    });
  }

  double get _weeklyTotalHours => _weeklyHours.fold(0, (a, b) => a + b);

  Map<String, int> get _subjectMinutes {
    final map = <String, int>{};
    for (final s in _sessions) {
      map[s.subject] = (map[s.subject] ?? 0) + s.durationMinutes;
    }
    return Map.fromEntries(
      map.entries.toList()..sort((a, b) => b.value.compareTo(a.value)),
    );
  }

  // ── Bottom Sheet ───────────────────────────────────────────────
  void _showAddSheet() {
    final subjectCtrl = TextEditingController();
    final topicCtrl   = TextEditingController();
    final durationCtrl = TextEditingController();
    bool isDone = true;

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
              const Text('Add Study Session', style: TextStyle(
                color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w600,
              )),
              const SizedBox(height: 20),
              _SheetField(controller: subjectCtrl, label: 'Subject', hint: 'e.g. Mathematics'),
              const SizedBox(height: 12),
              _SheetField(controller: topicCtrl, label: 'Topic', hint: 'e.g. Integration'),
              const SizedBox(height: 12),
              _SheetField(
                controller: durationCtrl,
                label: 'Duration (minutes)',
                hint: 'e.g. 60',
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Mark as completed', style: TextStyle(
                    color: AppColors.textSecondary, fontSize: 13,
                  )),
                  Switch(
                    value: isDone,
                    onChanged: (v) => setSheet(() => isDone = v),
                    activeThumbColor: AppColors.background,
                    activeTrackColor: AppColors.primary,
                    inactiveTrackColor: AppColors.surfaceAlt,
                    inactiveThumbColor: AppColors.textSecondary,
                  ),
                ],
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
                    final subject = subjectCtrl.text.trim();
                    final topic   = topicCtrl.text.trim();
                    final mins    = int.tryParse(durationCtrl.text.trim()) ?? 0;
                    if (subject.isEmpty || topic.isEmpty || mins <= 0) return;
                    await DatabaseService.instance.insertStudySession(StudySession(
                      subject: subject, topic: topic,
                      durationMinutes: mins,
                      date: DateTime.now(), isDone: isDone,
                    ));
                    if (ctx.mounted) Navigator.pop(ctx);
                    _load();
                  },
                  child: const Text('Save Session', style: TextStyle(
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

  void _showEditSheet(StudySession session) {
    final subjectCtrl = TextEditingController(text: session.subject);
    final topicCtrl   = TextEditingController(text: session.topic);
    final durationCtrl = TextEditingController(text: session.durationMinutes.toString());
    bool isDone = session.isDone;

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
              const Text('Edit Study Session', style: TextStyle(
                color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w600,
              )),
              const SizedBox(height: 20),
              _SheetField(controller: subjectCtrl, label: 'Subject', hint: 'e.g. Mathematics'),
              const SizedBox(height: 12),
              _SheetField(controller: topicCtrl, label: 'Topic', hint: 'e.g. Integration'),
              const SizedBox(height: 12),
              _SheetField(
                controller: durationCtrl,
                label: 'Duration (minutes)',
                hint: 'e.g. 60',
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Mark as completed', style: TextStyle(
                    color: AppColors.textSecondary, fontSize: 13,
                  )),
                  Switch(
                    value: isDone,
                    onChanged: (v) => setSheet(() => isDone = v),
                    activeThumbColor: AppColors.background,
                    activeTrackColor: AppColors.primary,
                    inactiveTrackColor: AppColors.surfaceAlt,
                    inactiveThumbColor: AppColors.textSecondary,
                  ),
                ],
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
                    final subject = subjectCtrl.text.trim();
                    final topic   = topicCtrl.text.trim();
                    final mins    = int.tryParse(durationCtrl.text.trim()) ?? 0;
                    if (subject.isEmpty || topic.isEmpty || mins <= 0) return;
                    await DatabaseService.instance.updateStudySession(session.copyWith(
                      subject: subject,
                      topic: topic,
                      durationMinutes: mins,
                      isDone: isDone,
                    ));
                    if (ctx.mounted) Navigator.pop(ctx);
                    _load();
                  },
                  child: const Text('Update Session', style: TextStyle(
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

  Future<bool> _showDeleteConfirmDialog(StudySession session) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.border),
        ),
        title: const Row(
          children: [
            Icon(Icons.delete_outline, color: AppColors.textPrimary, size: 20),
            SizedBox(width: 8),
            Text('Hapus Sesi Belajar?', style: TextStyle(
              color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w600,
            )),
          ],
        ),
        content: Text(
          'Hapus data ini (${session.subject} - ${session.topic})? Data yang dihapus tidak dapat dikembalikan.',
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal', style: TextStyle(color: AppColors.textSecondary)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.background,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Hapus Data'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  // ── Build ──────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final weekHours = _weeklyHours;
    final maxH = weekHours.isEmpty ? 1.0 : weekHours.reduce((a, b) => a > b ? a : b);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Study Tracker'),
        actions: [
          IconButton(
            icon: const Icon(Icons.timer_outlined, size: 22),
            tooltip: 'Study Timer',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const StudyTimerScreen()),
            ).then((_) => _load()),
          ),
          IconButton(
            icon: const Icon(Icons.add, size: 22),
            tooltip: 'Add Session',
            onPressed: _showAddSheet,
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
                      _WeeklyCard(
                        weekHours: weekHours,
                        maxH: maxH,
                        totalHours: _weeklyTotalHours,
                      ),
                      const SizedBox(height: 24),

                      if (_subjectMinutes.isNotEmpty) ...[
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Subjects', style: textTheme.titleLarge),
                            Text('${_subjectMinutes.length} total',
                                style: const TextStyle(
                                  color: AppColors.textSecondary, fontSize: 13,
                                )),
                          ],
                        ),
                        const SizedBox(height: 12),
                        ..._subjectMinutes.entries.take(5).map((e) {
                          final maxMins = _subjectMinutes.values.first;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: _SubjectItem(
                              subject: e.key,
                              progress: maxMins > 0 ? e.value / maxMins : 0,
                              hours: _fmtHours(e.value),
                              sessions: _sessions.where((s) => s.subject == e.key).length,
                            ),
                          );
                        }),
                        const SizedBox(height: 16),
                      ],

                      Text("Today's Sessions", style: textTheme.titleLarge),
                      const SizedBox(height: 12),

                      Builder(builder: (context) {
                        final today = _todaySessions;
                        if (today.isEmpty) {
                          return const _EmptyState(
                            icon: Icons.menu_book_outlined,
                            message: 'No study sessions today.\nTap + to add one.',
                          );
                        }
                        return Container(
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Column(
                            children: List.generate(today.length, (i) {
                              final s = today[i];
                              return Column(
                                children: [
                                  _SessionItem(
                                    session: s,
                                    onStartTimer: () => Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => StudyTimerScreen(initialSession: s),
                                      ),
                                    ).then((_) => _load()),
                                    onEdit: () => _showEditSheet(s),
                                    onConfirmDelete: () => _showDeleteConfirmDialog(s),
                                    onDelete: () async {
                                      await DatabaseService.instance
                                          .deleteStudySession(s.studyId!);
                                      _load();
                                    },
                                  ),
                                  if (i < today.length - 1)
                                    const Divider(height: 1, indent: 16, endIndent: 16),
                                ],
                              );
                            }),
                          ),
                        );
                      }),

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
String _fmtHours(int minutes) {
  final h = minutes ~/ 60;
  final m = minutes % 60;
  if (h == 0) return '${m}m';
  if (m == 0) return '${h}h';
  return '${h}h ${m}m';
}

// ── Sub-widgets ───────────────────────────────────────────────────

class _WeeklyCard extends StatelessWidget {
  final List<double> weekHours;
  final double maxH;
  final double totalHours;

  const _WeeklyCard({required this.weekHours, required this.maxH, required this.totalHours});

  @override
  Widget build(BuildContext context) {
    const dayLabels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    final now = DateTime.now();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('This Week', style: TextStyle(
                    color: AppColors.textSecondary, fontSize: 12,
                  )),
                  SizedBox(height: 2),
                  Text('Study Hours', style: TextStyle(
                    color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w600,
                  )),
                ],
              ),
              Text(
                '${totalHours.toStringAsFixed(1)}h',
                style: const TextStyle(
                  color: AppColors.primary, fontSize: 18, fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(7, (i) {
              final h = weekHours[i];
              final fraction = maxH > 0 ? h / maxH : 0.0;
              final isToday = i == 6;
              // map index to correct day label
              final labelIdx = ((now.weekday - 1) - (6 - i) + 7) % 7;
              return _DayBar(
                label: dayLabels[labelIdx],
                value: fraction,
                isToday: isToday,
              );
            }),
          ),
        ],
      ),
    );
  }
}

class _DayBar extends StatelessWidget {
  final String label;
  final double value;
  final bool isToday;

  const _DayBar({required this.label, required this.value, this.isToday = false});

  @override
  Widget build(BuildContext context) {
    const barHeight = 56.0;
    return Column(
      children: [
        SizedBox(
          height: barHeight, width: 24,
          child: Align(
            alignment: Alignment.bottomCenter,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeOutCubic,
              width: 8,
              height: value == 0 ? 3 : (barHeight * value).clamp(3.0, barHeight),
              decoration: BoxDecoration(
                color: isToday
                    ? AppColors.border
                    : value > 0.6
                        ? AppColors.primary
                        : AppColors.accent.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(label, style: TextStyle(
          color: isToday ? AppColors.primary : AppColors.textSecondary,
          fontSize: 11,
          fontWeight: isToday ? FontWeight.w600 : FontWeight.w400,
        )),
      ],
    );
  }
}

class _SubjectItem extends StatelessWidget {
  final String subject;
  final double progress;
  final String hours;
  final int sessions;

  const _SubjectItem({required this.subject, required this.progress,
    required this.hours, required this.sessions});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(child: Text(subject, style: const TextStyle(
                color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w500,
              ), overflow: TextOverflow.ellipsis)),
              const SizedBox(width: 8),
              Text(hours, style: const TextStyle(
                color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w600,
              )),
              const SizedBox(width: 8),
              Text('$sessions sessions', style: const TextStyle(
                color: AppColors.textSecondary, fontSize: 12,
              )),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 4,
              backgroundColor: AppColors.surfaceAlt,
              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
            ),
          ),
        ],
      ),
    );
  }
}

class _SessionItem extends StatelessWidget {
  final StudySession session;
  final VoidCallback onStartTimer;
  final VoidCallback onEdit;
  final Future<bool> Function() onConfirmDelete;
  final VoidCallback onDelete;

  const _SessionItem({
    required this.session,
    required this.onStartTimer,
    required this.onEdit,
    required this.onConfirmDelete,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: Key('session_${session.studyId}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: AppColors.surfaceAlt,
        child: const Icon(Icons.delete_outline, color: AppColors.textSecondary, size: 20),
      ),
      confirmDismiss: (direction) async => await onConfirmDelete(),
      onDismissed: (_) => onDelete(),
      child: InkWell(
        onTap: onEdit,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 8, height: 8,
                margin: const EdgeInsets.only(right: 14),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: session.isDone ? AppColors.primary : AppColors.border,
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(session.subject, style: const TextStyle(
                      color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w500,
                    )),
                    const SizedBox(height: 2),
                    Text(session.topic, style: const TextStyle(
                      color: AppColors.textSecondary, fontSize: 12,
                    )),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(_fmtHours(session.durationMinutes), style: const TextStyle(
                    color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w500,
                  )),
                  const SizedBox(height: 2),
                  Text(
                    session.isDone ? 'Completed' : 'Upcoming',
                    style: TextStyle(
                      color: session.isDone ? AppColors.primary : AppColors.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 6),
              IconButton(
                icon: const Icon(Icons.play_circle_outline, size: 22, color: AppColors.primary),
                tooltip: 'Mulai Timer',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                onPressed: onStartTimer,
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, size: 18, color: AppColors.textSecondary),
                color: AppColors.surface,
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                  side: const BorderSide(color: AppColors.border),
                ),
                onSelected: (val) async {
                  if (val == 'start') {
                    onStartTimer();
                  } else if (val == 'edit') {
                    onEdit();
                  } else if (val == 'delete') {
                    final confirmed = await onConfirmDelete();
                    if (confirmed) {
                      onDelete();
                    }
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'start',
                    height: 38,
                    child: Row(
                      children: [
                        Icon(Icons.play_arrow_outlined, size: 18, color: AppColors.primary),
                        SizedBox(width: 10),
                        Text('Mulai Timer', style: TextStyle(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'edit',
                    height: 38,
                    child: Row(
                      children: [
                        Icon(Icons.edit_outlined, size: 16, color: AppColors.textPrimary),
                        SizedBox(width: 10),
                        Text('Edit', style: TextStyle(color: AppColors.textPrimary, fontSize: 13)),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'delete',
                    height: 38,
                    child: Row(
                      children: [
                        Icon(Icons.delete_outline, size: 16, color: AppColors.textSecondary),
                        SizedBox(width: 10),
                        Text('Hapus', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
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