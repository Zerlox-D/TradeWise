import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../api_service.dart';

class StudentQuizScreen extends StatefulWidget {
  final int quizId;
  const StudentQuizScreen({super.key, required this.quizId});

  @override
  State<StudentQuizScreen> createState() => _StudentQuizScreenState();
}

class _StudentQuizScreenState extends State<StudentQuizScreen>
    with TickerProviderStateMixin {
  bool _isLoading = true;
  bool _isSubmitting = false;

  int? _quizId;
  List<dynamic> _questions = [];
  final Map<String, String> _selectedAnswers = {};

  bool _hasSubmitted = false;
  bool _hasPassed = false;
  bool _isCooldownActive = false;
  String _resultMessage = '';
  List<dynamic> _gradedResults = [];

  late final AnimationController _resultAnimController;
  late final Animation<double> _resultAnim;
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
    _resultAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _resultAnim = CurvedAnimation(
      parent: _resultAnimController,
      curve: Curves.easeOutCubic,
    );
    _fetchQuiz();
  }

  @override
  void dispose() {
    _resultAnimController.dispose();
    super.dispose();
  }

  Future<void> _fetchQuiz() async {
    final data = await ApiService.getStudentQuizDetail(widget.quizId);

    if (mounted && data != null) {
      setState(() {
        _quizId = data['quiz_id'];
        _questions = data['questions'];

        final status = data['status'];
        final cooldownEndsAt = data['cooldown_ends_at'];

        if (status == 'FAILED' && cooldownEndsAt != null) {
          final endTime = DateTime.parse(cooldownEndsAt).toLocal();
          _isCooldownActive = !endTime.difference(DateTime.now()).isNegative;
        } else {
          _isCooldownActive = false;
        }

        if (status == 'PASSED' || status == 'ARCHIVED' || _isCooldownActive) {
          _hasSubmitted = true;
          _hasPassed = status == 'PASSED' || status == 'ARCHIVED';
          _resultMessage = _hasPassed
              ? 'Assessment completed & passed.'
              : 'Cooldown active. Review your mistakes below.';

          final lastAnswers = data['last_submitted_answers'] ?? {};
          _gradedResults = _questions.map((q) {
            final studentPicked = lastAnswers[q['id'].toString()];
            return {
              'question_id': q['id'],
              'student_answer': studentPicked ?? 'Unanswered',
              'correct_answer': q['correct_answer'],
              'is_correct': studentPicked == q['correct_answer'],
              'explanation': q['explanation'] ?? 'No explanation available',
            };
          }).toList();

          for (var q in _questions) {
            final a = lastAnswers[q['id'].toString()];
            if (a != null) _selectedAnswers[q['id'].toString()] = a;
          }
        } else {
          _hasSubmitted = false;
          _selectedAnswers.clear();
          _gradedResults.clear();
        }

        _isLoading = false;
      });

      if (_hasSubmitted) _resultAnimController.forward();
    }
  }

  Future<void> _submitQuiz() async {
    if (_selectedAnswers.length < _questions.length) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: _amber, size: 18),
              SizedBox(width: 10),
              Text(
                'Please answer all questions before submitting.',
                style: TextStyle(color: Colors.white),
              ),
            ],
          ),
          backgroundColor: _card,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: const BorderSide(color: _border),
          ),
        ),
      );
      return;
    }

    HapticFeedback.mediumImpact();
    setState(() => _isSubmitting = true);

    final response = await ApiService.submitStudentQuiz(
      _quizId!,
      _selectedAnswers,
    );

    if (mounted) {
      setState(() => _isSubmitting = false);
      if (response != null) {
        setState(() {
          _hasSubmitted = true;
          _hasPassed = response['status'] == 'PASSED';
          _resultMessage = response['message'] ?? '';
          _gradedResults = response['results'] ?? [];
        });
        HapticFeedback.heavyImpact();
        _resultAnimController.forward(from: 0.0);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.error_outline_rounded, color: _red, size: 18),
                SizedBox(width: 10),
                Text(
                  'Failed to submit. Please try again.',
                  style: TextStyle(color: Colors.white),
                ),
              ],
            ),
            backgroundColor: _card,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: const BorderSide(color: _border),
            ),
          ),
        );
      }
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
    if (_questions.isEmpty) {
      return Scaffold(
        backgroundColor: _bg,
        body: SafeArea(
          child: Column(
            children: [
              _buildTopBar(title: 'Assessment', showCount: false),
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: _green.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: _green.withValues(alpha: 0.3),
                          ),
                        ),
                        child: const Icon(
                          Icons.check_rounded,
                          color: _green,
                          size: 40,
                        ),
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'All clear!',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'You have no pending assessments.',
                        style: TextStyle(color: Colors.grey[500], fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(title: 'Trading Assessment'),

            if (_hasSubmitted)
              FadeTransition(
                opacity: _resultAnim,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, -0.3),
                    end: Offset.zero,
                  ).animate(_resultAnim),
                  child: _buildResultBanner(),
                ),
              ),

            // Progress indicator while taking the quiz
            if (!_hasSubmitted) _buildProgressBar(),

            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
                itemCount: _questions.length,
                itemBuilder: (context, index) => _buildQuestionCard(index),
              ),
            ),

            // Submit bar
            if (!_hasSubmitted && !_isCooldownActive) _buildSubmitBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar({required String title, bool showCount = true}) {
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
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: _amber.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _amber.withValues(alpha: 0.3)),
                ),
                child: const Icon(Icons.quiz_rounded, color: _amber, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Get all questions right to pass. You can retake if you fail.',
                      style: TextStyle(color: Colors.grey[500], fontSize: 12),
                    ),
                  ],
                ),
              ),
              if (showCount && _questions.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: _amber.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: _amber.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    '${_questions.length} Qs',
                    style: const TextStyle(
                      color: _amber,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
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

  Widget _buildProgressBar() {
    final answered = _selectedAnswers.length;
    final total = _questions.length;
    final progress = total > 0 ? answered / total : 0.0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '$answered of $total answered',
                style: TextStyle(color: Colors.grey[500], fontSize: 12),
              ),
              Text(
                '${(progress * 100).toInt()}%',
                style: const TextStyle(
                  color: _amber,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: _border,
              valueColor: const AlwaysStoppedAnimation<Color>(_amber),
              minHeight: 5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultBanner() {
    final col = _hasPassed ? _green : _red;
    final icon = _hasPassed
        ? Icons.check_circle_outline_rounded
        : Icons.highlight_off_rounded;
    final label = _hasPassed ? 'PASSED' : 'FAILED';

    return Container(
      margin: const EdgeInsets.fromLTRB(24, 16, 24, 0),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: col.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: col.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: col.withValues(alpha: 0.15),
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
                  label,
                  style: TextStyle(
                    color: col,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1,
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

  Widget _buildQuestionCard(int index) {
    final q = _questions[index];
    final qId = q['id'].toString();

    Map<String, dynamic>? gradingData;
    if (_hasSubmitted) {
      final matches = _gradedResults.where(
        (r) => r['question_id'].toString() == qId,
      );
      gradingData = matches.isNotEmpty
          ? matches.first as Map<String, dynamic>
          : null;
    }

    final isWrong = gradingData != null && !(gradingData['is_correct'] as bool);

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isWrong ? _red.withValues(alpha: 0.4) : _border,
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
                    color: _amber.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: _amber.withValues(alpha: 0.3)),
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
                if (_hasSubmitted && gradingData != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: gradingData['is_correct']
                          ? _green.withValues(alpha: 0.12)
                          : _red.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: gradingData['is_correct']
                            ? _green.withValues(alpha: 0.3)
                            : _red.withValues(alpha: 0.3),
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

                // Options
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
                if (_hasSubmitted && gradingData != null) ...[
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
                            Icon(
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

    if (_hasSubmitted && gradingData != null) {
      if (isCorrect) {
        borderCol = _green.withValues(alpha: 0.5);
        bgCol = _green.withValues(alpha: 0.08);
        letterCol = _green;
      } else if (isWrongPick) {
        borderCol = _red.withValues(alpha: 0.5);
        bgCol = _red.withValues(alpha: 0.08);
        letterCol = _red;
      } else {
        borderCol = _border;
        bgCol = Colors.transparent;
        letterCol = Colors.grey.shade600;
      }
    } else {
      borderCol = isSelected ? accentColor.withValues(alpha: 0.6) : _border;
      bgCol = isSelected
          ? accentColor.withValues(alpha: 0.08)
          : Colors.transparent;
      letterCol = isSelected ? accentColor : Colors.grey.shade600;
    }

    return GestureDetector(
      onTap: () {
        if (!_hasSubmitted) {
          HapticFeedback.selectionClick();
          setState(() => _selectedAnswers[questionId] = letter);
        }
      },
      child: Container(
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
            if (_hasSubmitted && gradingData != null) ...[
              if (isCorrect)
                const Icon(Icons.check_circle_rounded, color: _green, size: 18),
              if (isWrongPick)
                const Icon(Icons.cancel_rounded, color: _red, size: 18),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSubmitBar() {
    final allAnswered = _selectedAnswers.length == _questions.length;

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 14, 24, 24),
      decoration: const BoxDecoration(
        color: _bg,
        border: Border(top: BorderSide(color: _border)),
      ),
      child: GestureDetector(
        onTap: _isSubmitting ? null : _submitQuiz,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          height: 54,
          decoration: BoxDecoration(
            color: _isSubmitting
                ? _border
                : allAnswered
                ? _green
                : _green.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Center(
            child: _isSubmitting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: _bg,
                      strokeWidth: 2.5,
                    ),
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.send_rounded,
                        color: allAnswered ? _bg : _bg.withValues(alpha: 0.5),
                        size: 18,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'SUBMIT ANSWERS',
                        style: TextStyle(
                          color: allAnswered ? _bg : _bg.withValues(alpha: 0.5),
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
