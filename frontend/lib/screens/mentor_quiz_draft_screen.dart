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

class _MentorQuizDraftScreenState extends State<MentorQuizDraftScreen> {
  bool _isLoading = true;
  bool _isPublishing = false;
  int? _quizId;
  List<dynamic> _questions = [];

  @override
  void initState() {
    super.initState();
    _generateAIDraft();
  }

  Future<void> _generateAIDraft() async {
    // NOTE: You will need to add this method to your ApiService!
    final response = await ApiService.draftMentorQuiz(widget.studentId);
    
    if (mounted) {
      if (response != null && response['quiz_id'] != null) {
        setState(() {
          _quizId = response['quiz_id'];
          _questions = response['questions'];
          _isLoading = false;
        });
      } else {
        // Handle failure (e.g., student has no trades, or AI failed)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Failed to generate AI draft. Please try again."), backgroundColor: Colors.red),
        );
        Navigator.pop(context);
      }
    }
  }

  Future<void> _publishQuiz() async {
    setState(() => _isPublishing = true);

    // NOTE: You will need to add this method to your ApiService!
    final success = await ApiService.publishMentorQuiz(_quizId!, _questions);

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Quiz Published Successfully!"), backgroundColor: Colors.green),
      );
      // Automatically pop back to the dashboard
      Navigator.pop(context);
    } else {
      setState(() => _isPublishing = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Failed to publish quiz."), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E21),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text("Draft Quiz for ${widget.studentName}", style: const TextStyle(fontSize: 18)),
        actions: [
          if (!_isLoading)
            TextButton.icon(
              onPressed: _isPublishing ? null : _publishQuiz,
              icon: _isPublishing 
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.send, color: Colors.greenAccent),
              label: Text(
                _isPublishing ? "Publishing..." : "Publish",
                style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold),
              ),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(color: Colors.blueAccent),
                  const SizedBox(height: 20),
                  Text("Gemini AI is analyzing recent trades...", style: TextStyle(color: Colors.grey[400])),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _questions.length,
              itemBuilder: (context, index) {
                final q = _questions[index];
                return Container(
                  margin: const EdgeInsets.only(bottom: 24),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1D1E33),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.blueAccent.withOpacity(0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Question ${index + 1}", style: const TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      
                      // 1. Question Text
                      _buildEditableField("Question", q['question_text'], (val) => q['question_text'] = val, maxLines: 3),
                      const SizedBox(height: 16),
                      
                      // 2. Options
                      _buildEditableField("Option A", q['option_a'], (val) => q['option_a'] = val),
                      const SizedBox(height: 8),
                      _buildEditableField("Option B", q['option_b'], (val) => q['option_b'] = val),
                      const SizedBox(height: 8),
                      _buildEditableField("Option C", q['option_c'], (val) => q['option_c'] = val),
                      const SizedBox(height: 8),
                      _buildEditableField("Option D", q['option_d'], (val) => q['option_d'] = val),
                      const SizedBox(height: 16),

                      // 3. Correct Answer Dropdown
                      Row(
                        children: [
                          const Text("Correct Answer: ", style: TextStyle(color: Colors.grey)),
                          const SizedBox(width: 12),
                          DropdownButton<String>(
                            value: q['correct_answer'],
                            dropdownColor: const Color(0xFF0A0E21),
                            style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold),
                            items: ['A', 'B', 'C', 'D'].map((String val) {
                              return DropdownMenuItem<String>(value: val, child: Text(val));
                            }).toList(),
                            onChanged: (newVal) {
                              setState(() => q['correct_answer'] = newVal);
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // 4. Explanation
                      _buildEditableField("Explanation (Shown if they fail)", q['explanation'], (val) => q['explanation'] = val, maxLines: 4),
                    ],
                  ),
                );
              },
            ),
    );
  }

  // Helper widget to keep the code clean!
  Widget _buildEditableField(String label, String initialValue, Function(String) onChanged, {int maxLines = 1}) {
    return TextFormField(
      initialValue: initialValue,
      onChanged: onChanged,
      maxLines: maxLines,
      style: const TextStyle(color: Colors.white, fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.grey[500]),
        filled: true,
        fillColor: const Color(0xFF0A0E21),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );
  }
}