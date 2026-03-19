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

  @override
  void initState() {
    super.initState();
    _fetchQuizzes();

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) setState(() {}); 
    });
  }

  @override
  void dispose() {
    _timer?.cancel(); // 3. Prevent memory leaks when leaving the screen
    super.dispose();
  }

  Future<void> _fetchQuizzes() async {
    final quizzes = await ApiService.getStudentQuizzes();
    if (mounted) {
      setState(() {
        _quizzes = quizzes ?? [];
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFF0A0E21),
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF00E676)),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0A0E21),
      appBar: AppBar(
        title: const Text(
          "My Assessments",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF1D1E33),
        elevation: 0,
      ),
      body: _quizzes.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.check_circle_outline,
                    color: Colors.green[700],
                    size: 80,
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    "You have no assessment history.",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(20),
              itemCount: _quizzes.length,
              itemBuilder: (context, index) {
                final quiz = _quizzes[index];
                final status = quiz['status'];

                Color statusColor = Colors.grey;
                IconData statusIcon = Icons.history;
                String statusText = status;

                if (status == 'PUBLISHED') {
                  statusColor = Colors.orangeAccent;
                  statusIcon = Icons.warning_amber_rounded;
                  statusText = 'Pending (Action Required)';
                } else if (status == 'FAILED') {
                  statusColor = Colors.redAccent;
                  statusIcon = Icons.lock_clock;
                  
                  // Read the exact timestamp Django sent over
                  if (quiz['cooldown_ends_at'] != null) {
                    final endTime = DateTime.parse(quiz['cooldown_ends_at']).toLocal();
                    final remaining = endTime.difference(DateTime.now());

                    if (remaining.isNegative) {
                      // If the clock hits zero, turn blue!
                      statusText = 'Cooldown Finished - Ready to Retake';
                      statusColor = Colors.blueAccent; 
                    } else {
                      // Format the remaining time as MM:SS
                      final minutes = remaining.inMinutes.remainder(60).toString().padLeft(2, '0');
                      final seconds = remaining.inSeconds.remainder(60).toString().padLeft(2, '0');
                      statusText = 'Failed (Cooldown: $minutes:$seconds)';
                    }
                  } else {
                    statusText = 'Failed (Cooldown Active)';
                  }
                } else if (status == 'PASSED') {
                  statusColor = Colors.greenAccent;
                  statusIcon = Icons.verified;
                  statusText = 'Passed (Awaiting Unlock)';
                } else if (status == 'ARCHIVED') {
                  statusColor = Colors.grey;
                  statusIcon = Icons.archive;
                  statusText = 'Completed';
                }

                return GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            StudentQuizScreen(quizId: quiz['id']),
                      ),
                    ).then((_) {
                      // Refresh list and clear red dot when returning from a quiz
                      _fetchQuizzes();
                    });
                  },
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1D1E33),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: statusColor.withOpacity(0.5),
                        width: 1.5,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: statusColor.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(statusIcon, color: statusColor),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Assigned by ${quiz['mentor_name']}",
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                statusText,
                                style: TextStyle(
                                  color: statusColor,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(Icons.chevron_right, color: Colors.grey[600]),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
