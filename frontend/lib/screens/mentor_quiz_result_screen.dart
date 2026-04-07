import 'package:flutter/material.dart';
import '../api_service.dart';

class MentorQuizResultScreen extends StatefulWidget {
  final int quizId;
  const MentorQuizResultScreen({super.key, required this.quizId});

  @override
  State<MentorQuizResultScreen> createState() => _MentorQuizResultScreenState();
}

class _MentorQuizResultScreenState extends State<MentorQuizResultScreen>
    with SingleTickerProviderStateMixin {
  bool _isLoading = true;
  String _studentName = '';
  String _status = '';
  String _resultMessage = '';
  List<dynamic> _questions = [];
  List<dynamic> _gradedResults = [];
  final Map<String, String> _selectedAnswers = {};

  late final AnimationController _bannerAnimController;
  late final Animation<double> _bannerAnim;

  // ── Palette ────────────────────────────────────────────────────────────────
  static const _bg = Color(0xFF0A0E21);
  static const _card = Color(0xFF151A30);
  static const _border = Color(0xFF1E2440);
  static const _green = Color(0xFF00E676);
  static const _amber = Color(0xFFFFB74D);
  static const _red = Color(0xFFFF5252);
  static const _blue = Color(0xFF42A5F5);

  static const _optionColors = [_blue, _green, _amber, _red];
  static const _optionLetters = ['A', 'B', 'C', 'D'];

  @override
  void initState() {
    super.initState();
    _bannerAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _bannerAnim = CurvedAnimation(
      parent: _bannerAnimController,
      curve: Curves.easeOutCubic,
    );
    _fetchQuiz();
  }

  @override
  void dispose() {
    _bannerAnimController.dispose();
    super.dispose();
  }

  Future<void> _fetchQuiz() async {
    final data = await ApiService.getMentorQuizDetail(widget.quizId);

    if (mounted) {
      if (data == null) {
        setState(() {
          _isLoading = false;
          _resultMessage = 'Unable to load quiz results.';
        });
        return;
      }

      final status = (data['status'] ?? '').toString();
      final questions = (data['questions'] ?? []) as List<dynamic>;
      final lastAnswers =
          (data['last_submitted_answers'] ?? {}) as Map<String, dynamic>;

      // Only create grading data if student has actually attempted the quiz
      final hasAttempt = lastAnswers.isNotEmpty;
      final graded = hasAttempt
          ? questions.map((q) {
              final studentPicked = lastAnswers[q['id'].toString()];
              return {
                'question_id': q['id'],
                'student_answer': studentPicked ?? 'Unanswered',
                'correct_answer': q['correct_answer'],
                'is_correct': studentPicked == q['correct_answer'],
                'explanation': q['explanation'] ?? 'No explanation available',
              };
            }).toList()
          : []; // Empty list if no attempt

      for (var q in questions) {
        final a = lastAnswers[q['id'].toString()];
        if (a != null) _selectedAnswers[q['id'].toString()] = a.toString();
      }

      String message;
      if (lastAnswers.isEmpty) {
        message = 'No attempt has been submitted for this assessment yet.';
      } else if (status == 'PASSED' || status == 'ARCHIVED') {
        message =
            'Latest attempt passed. Review answers and explanations below.';
      } else if (status == 'FAILED') {
        message = 'Latest attempt failed. Review incorrect answers below.';
      } else {
        message = 'Assessment is active. Showing latest submitted attempt.';
      }

      setState(() {
        _studentName = (data['student_name'] ?? '').toString();
        _status = status;
        _questions = questions;
        _gradedResults = graded;
        _resultMessage = message;
        _isLoading = false;
      });

      _bannerAnimController.forward();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: _bg,
        body: Center(
          child: CircularProgressIndicator(color: _green, strokeWidth: 2.5),
        ),
      );
    }

    final hasPassed = _status == 'PASSED' || _status == 'ARCHIVED';
    final hasFailed = _status == 'FAILED';

    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(),

            // Animated result banner
            FadeTransition(
              opacity: _bannerAnim,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, -0.3),
                  end: Offset.zero,
                ).animate(_bannerAnim),
                child: _buildResultBanner(hasPassed, hasFailed),
              ),
            ),

            Expanded(
              child: _questions.isEmpty
                  ? _buildEmptyState()
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
                      itemCount: _questions.length,
                      itemBuilder: (context, index) =>
                          _buildQuestionCard(index),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Top bar ────────────────────────────────────────────────────────────────
  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: _card,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: _border),
                  ),
                  child: const Icon(
                    Icons.arrow_back_ios_new_rounded,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
              ),            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: _amber.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _amber.withOpacity(0.3)),
                ),
                child: const Icon(Icons.quiz_rounded, color: _amber, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Assessment Results',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _studentName.isNotEmpty
                          ? 'For $_studentName'
                          : 'Quiz review',
                      style: TextStyle(color: Colors.grey[500], fontSize: 13),
                    ),
                  ],
                ),
              ),
              if (_status.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: _statusColor(_status).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: _statusColor(_status).withOpacity(0.3),
                    ),
                  ),
                  child: Text(
                    _status,
                    style: TextStyle(
                      color: _statusColor(_status),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 20),
          Container(height: 1, color: _border),
        ],
      ),
    );
  }

  // ── Result banner ──────────────────────────────────────────────────────────
  Widget _buildResultBanner(bool hasPassed, bool hasFailed) {
    final col = hasPassed
        ? _green
        : hasFailed
        ? _red
        : _blue;
    final icon = hasPassed
        ? Icons.check_circle_outline_rounded
        : hasFailed
        ? Icons.highlight_off_rounded
        : Icons.pending_outlined;

    return Container(
      margin: const EdgeInsets.fromLTRB(24, 16, 24, 0),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: col.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: col.withOpacity(0.35)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: col.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: col, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  hasPassed
                      ? 'Passed'
                      : hasFailed
                      ? 'Failed'
                      : 'In Review',
                  style: TextStyle(
                    color: col,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  _resultMessage,
                  style: TextStyle(
                    color: Colors.grey[400],
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
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
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: _blue.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.inbox_rounded, color: _blue, size: 32),
          ),
          const SizedBox(height: 20),
          const Text(
            'No questions found',
            style: TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'This quiz has no questions yet.',
            style: TextStyle(color: Colors.grey[500], fontSize: 13),
          ),
        ],
      ),
    );
  }

  // ── Question card ──────────────────────────────────────────────────────────
  Widget _buildQuestionCard(int index) {
    final q = _questions[index];
    final qId = q['id'].toString();

    final matches = _gradedResults.where(
      (r) => r['question_id'].toString() == qId,
    );
    final Map<String, dynamic>? gradingData = matches.isNotEmpty
        ? matches.first as Map<String, dynamic>
        : null;

    final isWrong = gradingData != null && !(gradingData['is_correct'] as bool);

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isWrong ? _red.withOpacity(0.4) : _border,
          width: isWrong ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Card header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: BoxDecoration(
              color: _bg,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(18),
              ),
              border: const Border(bottom: BorderSide(color: _border)),
            ),
            child: Row(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: _amber.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: _amber.withOpacity(0.3)),
                  ),
                  child: Center(
                    child: Text(
                      '${index + 1}',
                      style: const TextStyle(
                        color: _amber,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                const Text(
                  'Question',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                if (gradingData != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: gradingData['is_correct']
                          ? _green.withOpacity(0.12)
                          : _red.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: gradingData['is_correct']
                            ? _green.withOpacity(0.3)
                            : _red.withOpacity(0.3),
                      ),
                    ),
                    child: Text(
                      gradingData['is_correct'] ? 'Correct' : 'Incorrect',
                      style: TextStyle(
                        color: gradingData['is_correct'] ? _green : _red,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Body
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  q['question_text'] ?? '',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 18),

                ...List.generate(4, (i) {
                  final letter = _optionLetters[i];
                  final key = 'option_${letter.toLowerCase()}';
                  return _buildOption(
                    qId,
                    letter,
                    q[key] ?? '',
                    gradingData,
                    _optionColors[i],
                  );
                }),

                // Explanation
                if (gradingData != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: _bg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border(
                        left: BorderSide(
                          color: gradingData['is_correct'] ? _green : _red,
                          width: 3,
                        ),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.lightbulb_outline_rounded,
                              color: _amber,
                              size: 14,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              gradingData['is_correct']
                                  ? 'Correct!'
                                  : 'Correct answer: ${gradingData['correct_answer']}',
                              style: TextStyle(
                                color: gradingData['is_correct']
                                    ? _green
                                    : _red,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          gradingData['explanation'] ?? '',
                          style: TextStyle(
                            color: Colors.grey[400],
                            fontSize: 13,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Option row ─────────────────────────────────────────────────────────────
  Widget _buildOption(
    String questionId,
    String letter,
    String text,
    Map<String, dynamic>? gradingData,
    Color accentColor,
  ) {
    final isSelected = _selectedAnswers[questionId] == letter;
    final isCorrect = gradingData?['correct_answer'] == letter;
    final isWrongPick =
        isSelected && gradingData != null && gradingData['is_correct'] == false;

    Color borderCol;
    Color bgCol;
    Color letterCol;

    if (gradingData != null) {
      if (isCorrect) {
        borderCol = _green.withOpacity(0.5);
        bgCol = _green.withOpacity(0.08);
        letterCol = _green;
      } else if (isWrongPick) {
        borderCol = _red.withOpacity(0.5);
        bgCol = _red.withOpacity(0.08);
        letterCol = _red;
      } else {
        borderCol = _border;
        bgCol = Colors.transparent;
        letterCol = Colors.grey.shade600;
      }
    } else {
      borderCol = isSelected ? accentColor.withOpacity(0.5) : _border;
      bgCol = isSelected ? accentColor.withOpacity(0.08) : Colors.transparent;
      letterCol = isSelected ? accentColor : Colors.grey.shade600;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: BoxDecoration(
        color: bgCol,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderCol, width: 1.5),
      ),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: bgCol,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: borderCol),
            ),
            child: Center(
              child: Text(
                letter,
                style: TextStyle(
                  color: letterCol,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(color: Colors.white, fontSize: 14),
            ),
          ),
          if (gradingData != null) ...[
            if (isCorrect)
              const Icon(Icons.check_circle_rounded, color: _green, size: 18),
            if (isWrongPick)
              const Icon(Icons.cancel_rounded, color: _red, size: 18),
          ],
        ],
      ),
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────────────
  Color _statusColor(String status) {
    switch (status) {
      case 'PASSED':
      case 'ARCHIVED':
        return _green;
      case 'FAILED':
        return _red;
      default:
        return _blue;
    }
  }
}
