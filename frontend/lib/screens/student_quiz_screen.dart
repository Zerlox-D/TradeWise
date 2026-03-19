import 'package:flutter/material.dart';
import '../api_service.dart';

class StudentQuizScreen extends StatefulWidget {
  final int quizId;
  const StudentQuizScreen({super.key, required this.quizId});

  @override
  State<StudentQuizScreen> createState() => _StudentQuizScreenState();
}

class _StudentQuizScreenState extends State<StudentQuizScreen> {
  bool _isLoading = true;
  bool _isSubmitting = false;
  
  int? _quizId;
  List<dynamic> _questions = [];
  
  // Stores the student's selected answers { "question_id": "A" }
  final Map<String, String> _selectedAnswers = {};
  
  // Post-submission state
  bool _hasSubmitted = false;
  bool _hasPassed = false;
  bool _isCooldownActive = false;
  String _resultMessage = "";
  List<dynamic> _gradedResults = [];

  @override
  void initState() {
    super.initState();
    _fetchQuiz();
  }

  Future<void> _fetchQuiz() async {
    final data = await ApiService.getStudentQuizDetail(widget.quizId);
    
    if (mounted && data != null) {
      setState(() {
        _quizId = data['quiz_id'];
        _questions = data['questions'];
        
        final status = data['status'];
        
        // 1. Define it by pulling the timestamp straight from Django!
        final cooldownEndsAt = data['cooldown_ends_at']; 
        
        // 2. Check the timer safely
        if (status == 'FAILED' && cooldownEndsAt != null) {
          final endTime = DateTime.parse(cooldownEndsAt).toLocal();
          // FIX: Use !isNegative instead of the non-existent isPositive!
          _isCooldownActive = !endTime.difference(DateTime.now()).isNegative; 
        } else {
          _isCooldownActive = false;
        }

        // 3. Lock UI if they passed, archived, OR are in an active cooldown!
        if (status == 'PASSED' || status == 'ARCHIVED' || _isCooldownActive) {
          _hasSubmitted = true;
          _hasPassed = status == 'PASSED' || status == 'ARCHIVED';
          
          _resultMessage = _hasPassed 
              ? "Assessment Completed & Passed." 
              : "Cooldown Active. Review your mistakes below.";
          
          // 4. Rebuild the exact state using Django's snapshot
          final lastAnswers = data['last_submitted_answers'] ?? {};

          _gradedResults = _questions.map((q) {
            final studentPicked = lastAnswers[q['id'].toString()];
            return {
              "question_id": q['id'],
              "student_answer": studentPicked ?? "Unanswered", // What they actually clicked
              "correct_answer": q['correct_answer'],
              "is_correct": studentPicked == q['correct_answer'], 
              "explanation": q['explanation'] ?? "No explanation Available"
            };
          }).toList();
          
          // 5. Pre-fill the circles on the UI
          for (var q in _questions) {
            if (lastAnswers[q['id'].toString()] != null) {
              _selectedAnswers[q['id'].toString()] = lastAnswers[q['id'].toString()];
            }
          }
          
        } else {
          // 6. Cooldown expired! Reset everything so they can retake the test.
          _hasSubmitted = false;
          _selectedAnswers.clear(); 
          _gradedResults.clear();
        }
        
        _isLoading = false;
      });
    }
  }

  Future<void> _submitQuiz() async {
    // Ensure they answered everything
    if (_selectedAnswers.length < _questions.length) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please answer all questions before submitting."), backgroundColor: Colors.orangeAccent),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    final response = await ApiService.submitStudentQuiz(_quizId!, _selectedAnswers);

    if (mounted) {
      setState(() => _isSubmitting = false);

      if (response != null) {
        setState(() {
          _hasSubmitted = true;
          _hasPassed = response['status'] == 'PASSED';
          _resultMessage = response['message'] ?? "";
          _gradedResults = response['results'] ?? [];
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Failed to submit quiz. Please try again."), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFF0A0E21),
        body: Center(child: CircularProgressIndicator(color: Color(0xFF00E676))),
      );
    }

    // STATE 1: No Quiz Available
    if (_questions.isEmpty) {
      return Scaffold(
        backgroundColor: const Color(0xFF0A0E21),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.check_circle_outline, color: Colors.green[700], size: 80),
              const SizedBox(height: 20),
              const Text(
                "You have no pending assessments.",
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                "Your trading account is in good standing.",
                style: TextStyle(color: Colors.grey[500]),
              ),
            ],
          ),
        ),
      );
    }

    // STATE 2 & 3: Taking the Quiz or Reviewing Results
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E21),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1D1E33),
        elevation: 0,
        title: const Text("Trading Assessment", style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: Column(
        children: [
          // If submitted, show the top banner with Pass/Fail status
          if (_hasSubmitted)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              color: _hasPassed ? Colors.green[800] : Colors.red[800],
              child: Column(
                children: [
                  Text(
                    _hasPassed ? "Assessment Passed!" : "Assessment Failed",
                    style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _resultMessage,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                ],
              ),
            ),

          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(20),
              itemCount: _questions.length,
              itemBuilder: (context, index) {
                final q = _questions[index];
                final String qId = q['id'].toString();
                
                // If submitted, find the grading data for this specific question
                Map<String, dynamic>? gradingData;
                if (_hasSubmitted) {
                  // 1. Find all matches (returns an Iterable)
                  final matches = _gradedResults.where(
                    (res) => res['question_id'].toString() == qId
                  );
                  
                  // 2. Safely grab the first one if it exists, otherwise leave it null!
                  gradingData = matches.isNotEmpty 
                      ? matches.first as Map<String, dynamic> 
                      : null;
                }

                return Container(
                  margin: const EdgeInsets.only(bottom: 24),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1D1E33),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: _hasSubmitted && gradingData != null && !gradingData['is_correct']
                          ? Colors.redAccent.withOpacity(0.5)
                          : Colors.blueAccent.withOpacity(0.1),
                      width: 2,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Question ${index + 1}",
                        style: TextStyle(color: Colors.blue[400], fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        q['question_text'],
                        style: const TextStyle(color: Colors.white, fontSize: 16, height: 1.4),
                      ),
                      const SizedBox(height: 20),
                      
                      _buildOption(qId, "A", q['option_a'], gradingData),
                      _buildOption(qId, "B", q['option_b'], gradingData),
                      _buildOption(qId, "C", q['option_c'], gradingData),
                      _buildOption(qId, "D", q['option_d'], gradingData),

                      // Show explanation if the quiz has been graded
                      if (_hasSubmitted && gradingData != null) ...[
                        const SizedBox(height: 20),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.black26,
                            borderRadius: BorderRadius.circular(12),
                            border: Border(left: BorderSide(color: gradingData['is_correct'] ? Colors.green : Colors.red, width: 4)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                gradingData['is_correct'] ? "Correct" : "Incorrect (Correct Answer: ${gradingData['correct_answer']})",
                                style: TextStyle(
                                  color: gradingData['is_correct'] ? Colors.green : Colors.red,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                gradingData['explanation'],
                                style: TextStyle(color: Colors.grey[300], fontSize: 13, height: 1.4),
                              ),
                            ],
                          ),
                        ),
                      ]
                    ],
                  ),
                );
              },
            ),
          ),

          // Submit Button (Hides once they submit)
          if (!_hasSubmitted && !_isCooldownActive && _questions.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(24),
              width: double.infinity,
              color: const Color(0xFF0A0E21),
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submitQuiz,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: const Color(0xFF00E676),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _isSubmitting
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text("Submit Answers", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildOption(String questionId, String optionLetter, String optionText, Map<String, dynamic>? gradingData) {
    bool isSelected = _selectedAnswers[questionId] == optionLetter;
    
    // Determine colors based on grading state
    Color borderColor = isSelected ? Colors.blueAccent : Colors.grey[800]!;
    Color bgColor = isSelected ? Colors.blueAccent.withOpacity(0.1) : Colors.transparent;
    
    if (_hasSubmitted && gradingData != null) {
      if (gradingData['correct_answer'] == optionLetter) {
        borderColor = Colors.green;
        bgColor = Colors.green.withOpacity(0.1);
      } else if (isSelected && !gradingData['is_correct']) {
        borderColor = Colors.red;
        bgColor = Colors.red.withOpacity(0.1);
      } else {
        borderColor = Colors.grey[800]!;
        bgColor = Colors.transparent;
      }
    }

    return GestureDetector(
      onTap: () {
        if (!_hasSubmitted) {
          setState(() => _selectedAnswers[questionId] = optionLetter);
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor, width: 1.5),
        ),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: isSelected && !_hasSubmitted ? Colors.blueAccent : Colors.transparent,
                shape: BoxShape.circle,
                border: Border.all(color: borderColor),
              ),
              child: Center(
                child: Text(
                  optionLetter,
                  style: TextStyle(
                    color: isSelected && !_hasSubmitted ? Colors.white : Colors.grey[400],
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                optionText,
                style: const TextStyle(color: Colors.white, fontSize: 14),
              ),
            ),
            if (_hasSubmitted && gradingData != null && gradingData['correct_answer'] == optionLetter)
              const Icon(Icons.check_circle, color: Colors.green),
            if (_hasSubmitted && gradingData != null && isSelected && !gradingData['is_correct'])
              const Icon(Icons.cancel, color: Colors.red),
          ],
        ),
      ),
    );
  }
}