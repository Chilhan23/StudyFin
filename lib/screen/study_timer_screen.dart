import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../main.dart' show AppColors;
import '../models/study_session.dart';
import '../services/database_services.dart';

enum TimerStatus { initial, running, paused, completed }

class StudyTimerScreen extends StatefulWidget {
  final StudySession? initialSession;
  const StudyTimerScreen({super.key, this.initialSession});

  @override
  State<StudyTimerScreen> createState() => _StudyTimerScreenState();
}

class _StudyTimerScreenState extends State<StudyTimerScreen>
    with WidgetsBindingObserver {
  Timer? _timer;
  int _totalSeconds = 25 * 60;
  int _remainingSeconds = 25 * 60;
  TimerStatus _status = TimerStatus.initial;
  bool _failedDueToAppLeave = false;
  bool _isFullscreen = false;

  late final TextEditingController _subjectCtrl;
  late final TextEditingController _topicCtrl;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    if (widget.initialSession != null) {
      _subjectCtrl = TextEditingController(text: widget.initialSession!.subject);
      _topicCtrl = TextEditingController(text: widget.initialSession!.topic);
      final sessionSecs = widget.initialSession!.durationMinutes * 60;
      if (sessionSecs > 0) {
        _totalSeconds = sessionSecs;
        _remainingSeconds = sessionSecs;
      }
    } else {
      _subjectCtrl = TextEditingController(text: 'Focus Session');
      _topicCtrl = TextEditingController(text: 'Self-Study');
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    if (_isFullscreen) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
    _subjectCtrl.dispose();
    _topicCtrl.dispose();
    super.dispose();
  }

  void _toggleFullscreen(bool enable) {
    setState(() => _isFullscreen = enable);
    if (enable) {
      // Sembunyikan status bar dan navigation bar (Mode Layar Penuh Murni)
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    } else {
      // Tampilkan kembali navigasi dan status bar sistem normal
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
  }

  // ── Deteksi Pindah Aplikasi (Disiplin Belajar) ───────────────────
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_status == TimerStatus.running) {
      if (state == AppLifecycleState.paused ||
          state == AppLifecycleState.inactive) {
        // Hentikan seketika dan batalkan sesi
        _timer?.cancel();
        setState(() {
          _status = TimerStatus.initial;
          _remainingSeconds = _totalSeconds;
          _failedDueToAppLeave = true;
        });
      }
    } else if (state == AppLifecycleState.resumed && _failedDueToAppLeave) {
      _failedDueToAppLeave = false;
      _showAppLeaveDialog();
    }
  }

  void _showAppLeaveDialog() {
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.border),
        ),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppColors.textPrimary, size: 22),
            SizedBox(width: 10),
            Text('Sesi Dibatalkan', style: TextStyle(
              color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w600,
            )),
          ],
        ),
        content: const Text(
          'Sesi belajar gagal karena kamu meninggalkan aplikasi.\nTetap fokus pada aplikasi hingga timer selesai!',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.5),
        ),
        actions: [
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.background,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Saya Mengerti', style: TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  // ── Timer Logic ────────────────────────────────────────────────
  void _startTimer() {
    if (_remainingSeconds <= 0) return;
    setState(() => _status = TimerStatus.running);

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingSeconds > 1) {
        setState(() => _remainingSeconds--);
      } else {
        _timer?.cancel();
        setState(() {
          _remainingSeconds = 0;
          _status = TimerStatus.completed;
        });
        _onTimerComplete();
      }
    });
  }

  void _pauseTimer() {
    _timer?.cancel();
    setState(() => _status = TimerStatus.paused);
  }

  void _cancelTimer() {
    _timer?.cancel();
    setState(() {
      _status = TimerStatus.initial;
      _remainingSeconds = _totalSeconds;
    });
  }

  Future<void> _onTimerComplete() async {
    final mins = (_totalSeconds / 60).round();
    final subject = _subjectCtrl.text.trim().isEmpty ? 'Focus Session' : _subjectCtrl.text.trim();
    final topic = _topicCtrl.text.trim().isEmpty ? 'Self-Study' : _topicCtrl.text.trim();

    // Simpan otomatis ke SQLite
    await DatabaseService.instance.insertStudySession(StudySession(
      subject: subject,
      topic: topic,
      durationMinutes: mins > 0 ? mins : 1,
      date: DateTime.now(),
      isDone: true,
    ));

    // Bunyikan alert alarm dan getaran selesai
    SystemSound.play(SystemSoundType.alert);
    HapticFeedback.heavyImpact();

    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.border),
        ),
        title: const Row(
          children: [
            Icon(Icons.check_circle_outline, color: AppColors.textPrimary, size: 22),
            SizedBox(width: 10),
            Text('Sesi Selesai!', style: TextStyle(
              color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w600,
            )),
          ],
        ),
        content: Text(
          'Hebat! Kamu berhasil fokus selama $mins menit tanpa gangguan.\nData sesi otomatis disimpan ke riwayat belajar.',
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.5),
        ),
        actions: [
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.background,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              setState(() {
                _status = TimerStatus.initial;
                _remainingSeconds = _totalSeconds;
              });
            },
            child: const Text('Selesai', style: TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  void _setPreset(int minutes) {
    if (_status == TimerStatus.running) return;
    _timer?.cancel();
    setState(() {
      _totalSeconds = minutes * 60;
      _remainingSeconds = _totalSeconds;
      _status = TimerStatus.initial;
    });
  }

  void _showCustomDurationDialog() {
    if (_status == TimerStatus.running) return;
    final customCtrl = TextEditingController(text: (_totalSeconds ~/ 60).toString());

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.border),
        ),
        title: const Text('Custom Durasi', style: TextStyle(
          color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w600,
        )),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Masukkan durasi belajar (menit):', style: TextStyle(
              color: AppColors.textSecondary, fontSize: 13,
            )),
            const SizedBox(height: 12),
            TextField(
              controller: customCtrl,
              keyboardType: TextInputType.number,
              autofocus: true,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: const TextStyle(color: AppColors.textPrimary, fontSize: 15),
              cursorColor: AppColors.primary,
              decoration: InputDecoration(
                suffixText: 'menit',
                suffixStyle: const TextStyle(color: AppColors.textSecondary),
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
                  borderSide: const BorderSide(color: AppColors.primary),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal', style: TextStyle(color: AppColors.textSecondary)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.background,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () {
              final mins = int.tryParse(customCtrl.text.trim()) ?? 0;
              if (mins > 0 && mins <= 360) {
                _setPreset(mins);
                Navigator.pop(ctx);
              }
            },
            child: const Text('Terapkan'),
          ),
        ],
      ),
    );
  }

  String get _timeDisplay {
    final m = _remainingSeconds ~/ 60;
    final s = _remainingSeconds % 60;
    final mStr = m.toString().padLeft(2, '0');
    final sStr = s.toString().padLeft(2, '0');
    return '$mStr:$sStr';
  }

  double get _progressFraction {
    if (_totalSeconds <= 0) return 0.0;
    return (_totalSeconds - _remainingSeconds) / _totalSeconds;
  }

  Future<bool> _onWillPop() async {
    if (_status == TimerStatus.running) {
      final shouldLeave = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: AppColors.border),
          ),
          title: const Text('Batalkan Sesi?', style: TextStyle(
            color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w600,
          )),
          content: const Text(
            'Timer masih berjalan. Keluar sekarang akan membatalkan sesi belajar ini.',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Tetap di Sini', style: TextStyle(color: AppColors.textSecondary)),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.background,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Keluar'),
            ),
          ],
        ),
      );
      if (shouldLeave == true) {
        _timer?.cancel();
        return true;
      }
      return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final isRunning = _status == TimerStatus.running;
    final isPaused = _status == TimerStatus.paused;

    return PopScope(
      canPop: !isRunning,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final allow = await _onWillPop();
        if (allow && context.mounted) {
          Navigator.pop(context);
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text('Focus Timer'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, size: 18),
            onPressed: () async {
              final allow = await _onWillPop();
              if (allow && context.mounted) {
                Navigator.pop(context);
              }
            },
          ),
          actions: [
            IconButton(
              icon: Icon(
                _isFullscreen ? Icons.fullscreen_exit : Icons.fullscreen,
                size: 24,
                color: _isFullscreen ? AppColors.primary : AppColors.textSecondary,
              ),
              tooltip: _isFullscreen ? 'Keluar Layar Penuh' : 'Mode Layar Penuh (Immersive)',
              onPressed: () => _toggleFullscreen(!_isFullscreen),
            ),
            const SizedBox(width: 4),
          ],
        ),
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight - 32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // ── Subject & Topic Card ──────────────────────────────
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Rencana Belajar', style: TextStyle(
                            color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w500,
                          )),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _subjectCtrl,
                                  enabled: !isRunning,
                                  style: const TextStyle(
                                    color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w600,
                                  ),
                                  decoration: const InputDecoration(
                                    isDense: true,
                                    hintText: 'Mata Kuliah / Pelajaran',
                                    hintStyle: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                                    border: InputBorder.none,
                                    contentPadding: EdgeInsets.zero,
                                  ),
                                ),
                              ),
                              const Text(' · ', style: TextStyle(color: AppColors.textSecondary)),
                              Expanded(
                                child: TextField(
                                  controller: _topicCtrl,
                                  enabled: !isRunning,
                                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                                  decoration: const InputDecoration(
                                    isDense: true,
                                    hintText: 'Topik Bahasan',
                                    hintStyle: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                                    border: InputBorder.none,
                                    contentPadding: EdgeInsets.zero,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // ── Preset Selection Chips ────────────────────────────
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _PresetChip(
                          label: '25m',
                          selected: _totalSeconds == 25 * 60,
                          enabled: !isRunning,
                          onTap: () => _setPreset(25),
                        ),
                        const SizedBox(width: 10),
                        _PresetChip(
                          label: '50m',
                          selected: _totalSeconds == 50 * 60,
                          enabled: !isRunning,
                          onTap: () => _setPreset(50),
                        ),
                        const SizedBox(width: 10),
                        _PresetChip(
                          label: _totalSeconds != 25 * 60 && _totalSeconds != 50 * 60
                              ? '${_totalSeconds ~/ 60}m'
                              : 'Custom',
                          selected: _totalSeconds != 25 * 60 && _totalSeconds != 50 * 60,
                          enabled: !isRunning,
                          onTap: _showCustomDurationDialog,
                        ),
                      ],
                    ),

                    const SizedBox(height: 32),

                    // ── Countdown Circular / Large Display ─────────────────
                    Center(
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          SizedBox(
                            width: 250,
                            height: 250,
                            child: CircularProgressIndicator(
                              value: _progressFraction,
                              strokeWidth: 4,
                              backgroundColor: AppColors.surfaceAlt,
                              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
                            ),
                          ),
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _timeDisplay,
                                style: const TextStyle(
                                  color: AppColors.textPrimary,
                                  fontSize: 56,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: -1.5,
                                  fontFeatures: [FontFeature.tabularFigures()],
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                isRunning
                                    ? 'FOKUS AKTIF'
                                    : isPaused
                                        ? 'DIJEDA'
                                        : 'SIAP MULAI',
                                style: const TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 11,
                                  letterSpacing: 1.5,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // ── Fullscreen Toggle Card ─────────────────────────────
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                Icon(
                                  _isFullscreen ? Icons.fullscreen : Icons.stay_current_portrait_outlined,
                                  size: 18,
                                  color: _isFullscreen ? AppColors.primary : AppColors.textSecondary,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _isFullscreen ? 'Mode Layar Penuh (Aktif)' : 'Mode Layar Normal',
                                        style: const TextStyle(
                                          color: AppColors.textPrimary,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        _isFullscreen
                                            ? 'Status bar & navigasi disembunyikan'
                                            : 'Status bar & tombol navigasi tetap ada',
                                        style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Switch(
                            value: _isFullscreen,
                            onChanged: (v) => _toggleFullscreen(v),
                            activeThumbColor: AppColors.background,
                            activeTrackColor: AppColors.primary,
                            inactiveTrackColor: AppColors.surfaceAlt,
                            inactiveThumbColor: AppColors.textSecondary,
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Disiplin notice
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceAlt,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.shield_outlined, size: 15, color: AppColors.textSecondary),
                          SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              'Jangan keluar aplikasi saat sesi berlangsung.',
                              style: TextStyle(color: AppColors.textSecondary, fontSize: 11),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // ── Action Buttons ────────────────────────────────────
                    Row(
                      children: [
                        if (isRunning || isPaused) ...[
                          Expanded(
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: AppColors.border),
                                foregroundColor: AppColors.textSecondary,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              ),
                              onPressed: _cancelTimer,
                              child: const Text('Batal', style: TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w600,
                              )),
                            ),
                          ),
                          const SizedBox(width: 12),
                        ],
                        Expanded(
                          flex: 2,
                          child: FilledButton(
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: AppColors.background,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            ),
                            onPressed: () {
                              if (isRunning) {
                                _pauseTimer();
                              } else {
                                _startTimer();
                              }
                            },
                            child: Text(
                              isRunning
                                  ? 'Jeda'
                                  : isPaused
                                      ? 'Lanjutkan'
                                      : 'Mulai Belajar',
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PresetChip extends StatelessWidget {
  final String label;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  const _PresetChip({
    required this.label,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.border,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? AppColors.background : AppColors.textSecondary,
            fontSize: 13,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}
