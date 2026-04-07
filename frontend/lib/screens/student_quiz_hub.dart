import 'package:flutter/material.dart';
import '../api_service.dart';
import 'student_quiz_screen.dart';
import 'dart:async';

class StudentQuizHub extends StatefulWidget {
  const StudentQuizHub({super.key});

  @override
  State<StudentQuizHub> createState() => _StudentQuizHubState();
}

class _StudentQuizHubState extends State<StudentQuizHub> {
  bool _isLoading = true;
  List<dynamic> _quizzes = [];
  Timer? _timer;

  static const _bg     = Color(0xFF0A0E21);
  static const _card   = Color(0xFF151A30);
  static const _border = Color(0xFF1E2440);
  static const _green  = Color(0xFF00E676);
  static const _amber  = Color(0xFFFFB74D);
  static const _red    = Color(0xFFFF5252);
  static const _blue   = Color(0xFF42A5F5);

  @override
  void initState() {
    super.initState();
    _fetchQuizzes();
    _timer = Timer.periodic(
        const Duration(seconds: 1), (_) { if (mounted) setState(() {}); });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _fetchQuizzes() async {
    final quizzes = await ApiService.getStudentQuizzes();
    if (mounted) {
      setState(() {
        _quizzes   = quizzes ?? [];
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: _bg,
        body: Center(
            child:
                CircularProgressIndicator(color: _green, strokeWidth: 2.5)),
      );
    }

    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _fetchQuizzes,
          color: _green,
          backgroundColor: _card,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(child: _buildHeader()),
              _quizzes.isEmpty
                  ? SliverFillRemaining(
                      hasScrollBody: false,
                      child: _buildEmptyState(),
                    )
                  : SliverPadding(
                      padding:
                          const EdgeInsets.fromLTRB(24, 20, 24, 40),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) => _buildQuizCard(index),
                          childCount: _quizzes.length,
                        ),
                      ),
                    ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Header ─────────────────────────────────────────────────────────────────
  Widget _buildHeader() {
    final pending   = _quizzes.where((q) => q['status'] == 'PUBLISHED').length;
    final passed    = _quizzes.where((q) => q['status'] == 'PASSED' || q['status'] == 'ARCHIVED').length;
    final failed    = _quizzes.where((q) => q['status'] == 'FAILED').length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Brand bar
          const Row(
            children: [
              Icon(Icons.bolt_rounded, color: _green, size: 18),
              SizedBox(width: 6),
              Text('TRADEWISE',
                  style: TextStyle(
                      color: _green,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.5)),
            ],
          ),
          const SizedBox(height: 20),

          // Title row
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: _amber.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _amber.withOpacity(0.3)),
                ),
                child: const Icon(Icons.quiz_rounded,
                    color: _amber, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('My Assessments',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.3)),
                    const SizedBox(height: 2),
                    Text(
                      '${_quizzes.length} assessment${_quizzes.length != 1 ? 's' : ''} assigned',
                      style: TextStyle(
                          color: Colors.grey[500], fontSize: 12),
                    ),
                  ],
                ),
              ),
              // Urgent badge if there are pending quizzes
              if (pending > 0)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: _amber.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: _amber.withOpacity(0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                            color: _amber, shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 5),
                      Text('$pending pending',
                          style: const TextStyle(
                              color: _amber,
                              fontSize: 11,
                              fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
            ],
          ),

          // Stats strip — only show if there are quizzes
          if (_quizzes.isNotEmpty) ...[
            const SizedBox(height: 20),
            Row(
              children: [
                _statChip('$pending', 'Pending', _amber),
                const SizedBox(width: 8),
                _statChip('$passed', 'Passed', _green),
                const SizedBox(width: 8),
                _statChip('$failed', 'Failed', _red),
              ],
            ),
          ],

          const SizedBox(height: 20),
          Container(height: 1, color: _border),
        ],
      ),
    );
  }

  Widget _statChip(String value, String label, Color col) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: col.withOpacity(0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: col.withOpacity(0.2)),
        ),
        child: Column(
          children: [
            Text(value,
                style: TextStyle(
                    color: col,
                    fontSize: 16,
                    fontWeight: FontWeight.w800)),
            const SizedBox(height: 2),
            Text(label,
                style: TextStyle(
                    color: col.withOpacity(0.7),
                    fontSize: 10,
                    fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }

  // ── Empty state ────────────────────────────────────────────────────────────
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: _green.withOpacity(0.08),
              shape: BoxShape.circle,
              border:
                  Border.all(color: _green.withOpacity(0.2)),
            ),
            child: const Icon(Icons.check_circle_outline_rounded,
                color: _green, size: 34),
          ),
          const SizedBox(height: 20),
          const Text('All clear!',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Text(
            'Assessments from your mentor\nwill appear here.',
            textAlign: TextAlign.center,
            style:
                TextStyle(color: Colors.grey[500], fontSize: 13, height: 1.5),
          ),
        ],
      ),
    );
  }

  // ── Quiz card ──────────────────────────────────────────────────────────────
  Widget _buildQuizCard(int index) {
    final quiz   = _quizzes[index];
    final status = quiz['status'] as String? ?? '';

    Color accentColor;
    IconData statusIcon;
    String statusLabel;
    bool hasCooldown = false;
    String? cooldownLabel;

    switch (status) {
      case 'PUBLISHED':
        accentColor = _amber;
        statusIcon  = Icons.warning_amber_rounded;
        statusLabel = 'Action Required';
        break;
      case 'FAILED':
        if (quiz['cooldown_ends_at'] != null) {
          final endTime =
              DateTime.parse(quiz['cooldown_ends_at']).toLocal();
          final remaining = endTime.difference(DateTime.now());
          if (remaining.isNegative) {
            accentColor = _blue;
            statusIcon  = Icons.refresh_rounded;
            statusLabel = 'Ready to Retake';
          } else {
            hasCooldown = true;
            final mm = remaining.inMinutes
                .remainder(60)
                .toString()
                .padLeft(2, '0');
            final ss = remaining.inSeconds
                .remainder(60)
                .toString()
                .padLeft(2, '0');
            accentColor  = _red;
            statusIcon   = Icons.lock_clock_rounded;
            statusLabel  = 'Failed';
            cooldownLabel = '$mm:$ss';
          }
        } else {
          accentColor = _red;
          statusIcon  = Icons.lock_clock_rounded;
          statusLabel = 'Cooldown Active';
        }
        break;
      case 'PASSED':
        accentColor = _green;
        statusIcon  = Icons.verified_rounded;
        statusLabel = 'Passed · Awaiting Unlock';
        break;
      case 'ARCHIVED':
        accentColor = Colors.grey.shade600;
        statusIcon  = Icons.archive_rounded;
        statusLabel = 'Completed';
        break;
      default:
        accentColor = Colors.grey;
        statusIcon  = Icons.schedule_rounded;
        statusLabel = status;
    }

    final mentorName =
        quiz['mentor_name'] as String? ?? 'Your Mentor';

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) =>
                StudentQuizScreen(quizId: quiz['id']),
          ),
        ).then((_) => _fetchQuizzes());
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: _card,
          borderRadius: BorderRadius.circular(16),
          border:
              Border.all(color: accentColor.withOpacity(0.25)),
        ),
        child: Column(
          children: [
            // ── Main row ────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  // Icon container
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: accentColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(13),
                      border: Border.all(
                          color: accentColor.withOpacity(0.3)),
                    ),
                    child: Icon(statusIcon,
                        color: accentColor, size: 22),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('By $mentorName',
                            style: TextStyle(
                                color: Colors.grey[500],
                                fontSize: 11,
                                fontWeight: FontWeight.w500)),
                        const SizedBox(height: 5),
                        Text(statusLabel,
                            style: TextStyle(
                                color: accentColor,
                                fontSize: 14,
                                fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
                  // Cooldown timer badge OR chevron
                  if (hasCooldown && cooldownLabel != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: _red.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: _red.withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.timer_outlined,
                              color: _red, size: 12),
                          const SizedBox(width: 4),
                          Text(cooldownLabel!,
                              style: const TextStyle(
                                  color: _red,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.5)),
                        ],
                      ),
                    )
                  else
                    Icon(Icons.chevron_right_rounded,
                        color: Colors.grey[700], size: 20),
                ],
              ),
            ),

            // ── Accent bar for action-required ─────────────────────────
            if (status == 'PUBLISHED')
              Container(
                height: 3,
                decoration: BoxDecoration(
                  color: _amber,
                  borderRadius: const BorderRadius.vertical(
                      bottom: Radius.circular(16)),
                ),
              ),
          ],
        ),
      ),
    );
  }
}