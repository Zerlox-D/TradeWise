import 'package:flutter/material.dart';
import '../api_service.dart';

class MentorQuizDraftScreen extends StatefulWidget {
  final int studentId;
  final String studentName;
  final int requestId;

  const MentorQuizDraftScreen({
    super.key,
    required this.studentId,
    required this.studentName,
    required this.requestId,
  });

  @override
  State<MentorQuizDraftScreen> createState() => _MentorQuizDraftScreenState();
}

class _MentorQuizDraftScreenState extends State<MentorQuizDraftScreen>
    with TickerProviderStateMixin {
  bool _isLoading    = true;
  bool _isPublishing = false;
  int? _quizId;
  List<dynamic> _questions = [];

  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnim;

  // ── Palette ────────────────────────────────────────────────────────────────
  static const _bg     = Color(0xFF0A0E21);
  static const _card   = Color(0xFF151A30);
  static const _border = Color(0xFF1E2440);
  static const _green  = Color(0xFF00E676);
  static const _amber  = Color(0xFFFFB74D);
  static const _red    = Color(0xFFFF5252);
  static const _blue   = Color(0xFF42A5F5);

  // Option letter colours — A/B/C/D each get their own tint
  static const _optionColors = [_blue, _green, _amber, _red];
  static const _optionLetters = ['A', 'B', 'C', 'D'];

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _generateAIDraft();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _generateAIDraft() async {
    final response = await ApiService.draftMentorQuiz(widget.studentId);
    if (mounted) {
      if (response != null && response['quiz_id'] != null) {
        setState(() {
          _quizId    = response['quiz_id'];
          _questions = response['questions'];
          _isLoading = false;
        });
        _pulseController.stop();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(children: [
              Icon(Icons.error_outline_rounded, color: _red, size: 18),
              SizedBox(width: 10),
              Text('Failed to generate AI draft. Please try again.',
                  style: TextStyle(color: Colors.white)),
            ]),
            backgroundColor: _card,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: const BorderSide(color: _border),
            ),
          ),
        );
        Navigator.pop(context);
      }
    }
  }

  Future<void> _publishQuiz() async {
    setState(() => _isPublishing = true);
    final success = await ApiService.publishMentorQuiz(_quizId!, _questions);
    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(children: [
            Icon(Icons.check_circle_outline_rounded, color: _green, size: 18),
            SizedBox(width: 10),
            Text('Quiz published successfully!',
                style: TextStyle(color: Colors.white)),
          ]),
          backgroundColor: _card,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: const BorderSide(color: _border),
          ),
        ),
      );
      Navigator.pop(context);
    } else {
      setState(() => _isPublishing = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(children: [
              Icon(Icons.error_outline_rounded, color: _red, size: 18),
              SizedBox(width: 10),
              Text('Failed to publish quiz.',
                  style: TextStyle(color: Colors.white)),
            ]),
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
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(),
            Expanded(
              child: _isLoading ? _buildLoadingState() : _buildQuizList(),
            ),
            if (!_isLoading) _buildPublishBar(),
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
                  child: const Icon(Icons.arrow_back_ios_new_rounded,
                      color: Colors.white, size: 16),
                ),
              ),
              const Spacer(),
              const Icon(Icons.bolt_rounded, color: _green, size: 18),
              const SizedBox(width: 6),
              const Text('TRADEWISE',
                  style: TextStyle(
                      color: _green,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.5)),
            ],
          ),
          const SizedBox(height: 20),
          // Quiz header
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Quiz icon badge
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
                    const Text('AI Quiz Draft',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.3)),
                    const SizedBox(height: 2),
                    Text(
                      'For ${widget.studentName}',
                      style: TextStyle(
                          color: Colors.grey[500], fontSize: 13),
                    ),
                  ],
                ),
              ),
              if (!_isLoading)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: _amber.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border:
                        Border.all(color: _amber.withOpacity(0.3)),
                  ),
                  child: Text(
                    '${_questions.length} Qs',
                    style: const TextStyle(
                        color: _amber,
                        fontSize: 12,
                        fontWeight: FontWeight.w700),
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

  // ── Loading state ──────────────────────────────────────────────────────────
  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Pulsing AI brain icon
          AnimatedBuilder(
            animation: _pulseAnim,
            builder: (context, child) {
              return Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: _blue.withOpacity(0.08 * _pulseAnim.value),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: _blue.withOpacity(0.4 * _pulseAnim.value),
                    width: 1.5,
                  ),
                ),
                child: Icon(Icons.auto_awesome_rounded,
                    color: _blue.withOpacity(0.6 + 0.4 * _pulseAnim.value),
                    size: 36),
              );
            },
          ),
          const SizedBox(height: 28),
          const Text('Gemini AI is on it…',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),
          Text(
            'Analysing ${widget.studentName}\'s recent\ntrades to build a personalised quiz.',
            textAlign: TextAlign.center,
            style:
                TextStyle(color: Colors.grey[500], fontSize: 13, height: 1.6),
          ),
          const SizedBox(height: 32),
          // Animated dots
          AnimatedBuilder(
            animation: _pulseController,
            builder: (context, _) {
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(3, (i) {
                  final offset = (i / 3);
                  final v = ((_pulseController.value - offset) % 1.0)
                      .clamp(0.0, 1.0);
                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: _blue.withOpacity(0.3 + 0.7 * v),
                      shape: BoxShape.circle,
                    ),
                  );
                }),
              );
            },
          ),
        ],
      ),
    );
  }

  // ── Quiz list ──────────────────────────────────────────────────────────────
  Widget _buildQuizList() {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
      itemCount: _questions.length,
      itemBuilder: (context, index) {
        return _buildQuestionCard(index);
      },
    );
  }

  // ── Question card ──────────────────────────────────────────────────────────
  Widget _buildQuestionCard(int index) {
    final q = _questions[index];

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Card header band ─────────────────────────────────────────────
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: BoxDecoration(
              color: _bg,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(18)),
              border: const Border(
                  bottom: BorderSide(color: _border)),
            ),
            child: Row(
              children: [
                // Question number bubble
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
                          fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                const Text('Question',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600)),
                const Spacer(),
                // Correct answer selector inline in header
                Row(
                  children: [
                    Text('Answer:',
                        style: TextStyle(
                            color: Colors.grey[500], fontSize: 12)),
                    const SizedBox(width: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: _green.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border:
                            Border.all(color: _green.withOpacity(0.3)),
                      ),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 2),
                      child: DropdownButton<String>(
                        value: q['correct_answer'],
                        dropdownColor: _card,
                        underline: const SizedBox.shrink(),
                        isDense: true,
                        style: const TextStyle(
                            color: _green,
                            fontWeight: FontWeight.w700,
                            fontSize: 13),
                        items: ['A', 'B', 'C', 'D']
                            .map((v) => DropdownMenuItem(
                                value: v, child: Text(v)))
                            .toList(),
                        onChanged: (val) =>
                            setState(() => q['correct_answer'] = val),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // ── Body ─────────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Question text
                _editableField(
                  value: q['question_text'],
                  onChanged: (v) => q['question_text'] = v,
                  maxLines: 3,
                  placeholder: 'Enter question…',
                ),

                const SizedBox(height: 16),

                // Options — each with a coloured letter pill
                ...List.generate(4, (i) {
                  final key = 'option_${_optionLetters[i].toLowerCase()}';
                  final col = _optionColors[i];
                  final letter = _optionLetters[i];
                  final isCorrect = q['correct_answer'] == letter;

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Letter pill
                        Container(
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                            color: isCorrect
                                ? col.withOpacity(0.2)
                                : col.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isCorrect
                                  ? col.withOpacity(0.6)
                                  : col.withOpacity(0.25),
                            ),
                          ),
                          child: Center(
                            child: Text(
                              letter,
                              style: TextStyle(
                                color: isCorrect
                                    ? col
                                    : col.withOpacity(0.6),
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _editableField(
                            value: q[key] ?? '',
                            onChanged: (v) => q[key] = v,
                            placeholder: 'Option $letter…',
                            compact: true,
                          ),
                        ),
                      ],
                    ),
                  );
                }),

                const SizedBox(height: 6),

                // Divider
                Container(
                  height: 1,
                  color: _border,
                  margin: const EdgeInsets.symmetric(vertical: 14),
                ),

                // Explanation
                Row(
                  children: [
                    const Icon(Icons.lightbulb_outline_rounded,
                        color: _amber, size: 15),
                    const SizedBox(width: 6),
                    Text('Explanation',
                        style: TextStyle(
                            color: Colors.grey[400],
                            fontSize: 12,
                            fontWeight: FontWeight.w500)),
                  ],
                ),
                const SizedBox(height: 8),
                _editableField(
                  value: q['explanation'] ?? '',
                  onChanged: (v) => q['explanation'] = v,
                  maxLines: 3,
                  placeholder: 'Shown to student if they answer incorrectly…',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Publish bar ────────────────────────────────────────────────────────────
  Widget _buildPublishBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 14, 24, 24),
      decoration: const BoxDecoration(
        color: _bg,
        border: Border(top: BorderSide(color: _border)),
      ),
      child: GestureDetector(
        onTap: _isPublishing ? null : _publishQuiz,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          height: 54,
          decoration: BoxDecoration(
            color: _isPublishing ? _border : Color.fromARGB(255, 4, 196, 103),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Center(
            child: _isPublishing
                ? const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            color: _bg, strokeWidth: 2.5),
                      ),
                      SizedBox(width: 12),
                      Text('Publishing…',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w600)),
                    ],
                  )
                : const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.send_rounded, color: _bg, size: 18),
                      SizedBox(width: 10),
                      Text('PUBLISH QUIZ',
                          style: TextStyle(
                            color: _bg,
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.2,
                          )),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  // ── Editable field ─────────────────────────────────────────────────────────
  Widget _editableField({
    required String value,
    required Function(String) onChanged,
    int maxLines = 1,
    String placeholder = '',
    bool compact = false,
  }) {
    return TextFormField(
      initialValue: value,
      onChanged: onChanged,
      maxLines: maxLines,
      style: TextStyle(
          color: Colors.white,
          fontSize: compact ? 13 : 14,
          height: 1.4),
      decoration: InputDecoration(
        hintText: placeholder,
        hintStyle:
            TextStyle(color: Colors.grey[700], fontSize: compact ? 13 : 14),
        filled: true,
        fillColor: _bg,
        contentPadding: EdgeInsets.symmetric(
          horizontal: 14,
          vertical: compact ? 10 : 12,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _amber, width: 1.5),
        ),
      ),
    );
  }
}