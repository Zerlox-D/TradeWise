import 'package:flutter/material.dart';
import '../api_service.dart';
import 'mentor_quiz_result_screen.dart';

class MentorQuizHub extends StatefulWidget {
  const MentorQuizHub({super.key});

  @override
  State<MentorQuizHub> createState() => _MentorQuizHubState();
}

class _MentorQuizHubState extends State<MentorQuizHub> {
  bool _isLoading = true;
  List<dynamic> _quizHistory = [];

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
  }

  Future<void> _fetchQuizzes() async {
    final quizzes = await ApiService.getMentorQuizzes();
    if (mounted) {
      setState(() {
        _quizHistory = quizzes ?? [];
        _isLoading   = false;
      });
    }
  }

  Future<void> _unlockStudent(int quizId, String studentName) async {
    final success = await ApiService.unlockStudentAccount(quizId);
    if (!mounted) return;
    if (success) {
      _showSnackbar(
        '$studentName has been successfully unlocked!',
        Icons.lock_open_rounded,
        _green,
      );
      _fetchQuizzes();
    } else {
      _showSnackbar(
        'Failed to unlock student.',
        Icons.error_outline_rounded,
        _red,
      );
    }
  }

  void _showSnackbar(String msg, IconData icon, Color col) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        Icon(icon, color: col, size: 18),
        const SizedBox(width: 10),
        Expanded(
            child: Text(msg, style: const TextStyle(color: Colors.white))),
      ]),
      backgroundColor: _card,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: _border),
      ),
    ));
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
              _quizHistory.isEmpty
                  ? SliverFillRemaining(
                      hasScrollBody: false,
                      child: _buildEmptyState(),
                    )
                  : SliverPadding(
                      padding:
                          const EdgeInsets.fromLTRB(24, 20, 24, 40),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) =>
                              _buildQuizCard(index),
                          childCount: _quizHistory.length,
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
    final passed  = _quizHistory.where((q) => q['status'] == 'PASSED' || q['status'] == 'ARCHIVED').length;
    final failed  = _quizHistory.where((q) => q['status'] == 'FAILED').length;
    final pending = _quizHistory.where((q) => q['status'] == 'PUBLISHED').length;

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
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Assessment History',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.3)),
                    SizedBox(height: 2),
                    Text('Review your students\' quiz attempts',
                        style: TextStyle(color: Color(0xFF6B7280), fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),

          // Stats strip — only show if there are quizzes
          if (_quizHistory.isNotEmpty) ...[
            const SizedBox(height: 20),
            Row(
              children: [
                _statChip('${_quizHistory.length}', 'Total', _blue),
                const SizedBox(width: 8),
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
              color: _amber.withOpacity(0.08),
              shape: BoxShape.circle,
              border:
                  Border.all(color: _amber.withOpacity(0.2)),
            ),
            child: const Icon(Icons.quiz_outlined,
                color: _amber, size: 34),
          ),
          const SizedBox(height: 20),
          const Text('No assessments yet',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Text(
            'Assessments you assign to students\nwill appear here.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey[500], fontSize: 13, height: 1.5),
          ),
        ],
      ),
    );
  }

  // ── Quiz card ──────────────────────────────────────────────────────────────
  Widget _buildQuizCard(int index) {
    final quiz   = _quizHistory[index];
    final status = quiz['status'] as String? ?? '';

    Color accentColor;
    IconData statusIcon;
    String statusLabel;

    switch (status) {
      case 'PUBLISHED':
        accentColor = _amber;
        statusIcon  = Icons.pending_outlined;
        statusLabel = 'In Review';
        break;
      case 'FAILED':
        accentColor = _red;
        statusIcon  = Icons.highlight_off_rounded;
        statusLabel = 'Failed';
        break;
      case 'PASSED':
        accentColor = _green;
        statusIcon  = Icons.check_circle_outline_rounded;
        statusLabel = 'Passed';
        break;
      case 'ARCHIVED':
        accentColor = _blue;
        statusIcon  = Icons.verified_rounded;
        statusLabel = 'Unlocked';
        break;
      default:
        accentColor = Colors.grey;
        statusIcon  = Icons.schedule_rounded;
        statusLabel = status;
    }

    final studentName = quiz['student_name'] as String? ?? 'Student';
    final initial     = studentName.isNotEmpty
        ? studentName[0].toUpperCase()
        : '?';

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accentColor.withOpacity(0.25)),
      ),
      child: Column(
        children: [
          // ── Card body ──────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Student initial avatar
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: accentColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(13),
                    border: Border.all(
                        color: accentColor.withOpacity(0.3)),
                  ),
                  child: Center(
                    child: Text(initial,
                        style: TextStyle(
                            color: accentColor,
                            fontSize: 20,
                            fontWeight: FontWeight.w800)),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(studentName,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w700)),
                      const SizedBox(height: 5),
                      // Status pill
                      Row(
                        children: [
                          Icon(statusIcon,
                              color: accentColor, size: 13),
                          const SizedBox(width: 5),
                          Text(statusLabel,
                              style: TextStyle(
                                  color: accentColor,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── Action buttons ─────────────────────────────────────────────
          Container(
            decoration: BoxDecoration(
              color: _bg,
              borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(16)),
              border: const Border(top: BorderSide(color: _border)),
            ),
            padding: const EdgeInsets.all(12),
            child: status == 'PASSED'
                ? Row(
                    children: [
                      Expanded(
                        child: _actionButton(
                          icon: Icons.visibility_rounded,
                          label: 'View Results',
                          color: _blue,
                          onTap: () => _openResult(quiz['id']),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _actionButton(
                          icon: Icons.lock_open_rounded,
                          label: 'Unlock Student',
                          color: _green,
                          onTap: () => _unlockStudent(
                              quiz['id'], studentName),
                        ),
                      ),
                    ],
                  )
                : _actionButton(
                    icon: Icons.visibility_rounded,
                    label: 'View Assessment',
                    color: _blue,
                    onTap: () => _openResult(quiz['id']),
                  ),
          ),
        ],
      ),
    );
  }

  void _openResult(int quizId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MentorQuizResultScreen(quizId: quizId),
      ),
    );
  }

  Widget _actionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 15),
            const SizedBox(width: 6),
            Text(label,
                style: TextStyle(
                    color: color,
                    fontSize: 12,
                    fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }
}