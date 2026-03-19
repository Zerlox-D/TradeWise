import 'package:flutter/material.dart';
import '../api_service.dart';

class MentorQuizHub extends StatefulWidget {
  const MentorQuizHub({super.key});

  @override
  State<MentorQuizHub> createState() => _MentorQuizHubState();
}

class _MentorQuizHubState extends State<MentorQuizHub> {
  bool _isLoading = true;
  List<dynamic> _activeQuizzes = [];

  @override
  void initState() {
    super.initState();
    _fetchQuizzes();
  }

  Future<void> _fetchQuizzes() async {
    final quizzes = await ApiService.getMentorQuizzes();
    if (mounted) {
      setState(() {
        _activeQuizzes = quizzes ?? [];
        _isLoading = false;
      });
    }
  }

  Future<void> _unlockStudent(int quizId, String studentName) async {
    final success = await ApiService.unlockStudentAccount(quizId);
    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("$studentName has been successfully unlocked!"), backgroundColor: Colors.green),
      );
      _fetchQuizzes(); // Refresh the list to remove the archived quiz
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Failed to unlock student."), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFF0A0E21),
        body: Center(child: CircularProgressIndicator(color: Colors.blueAccent)),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0A0E21),
      appBar: AppBar(
        title: const Text("Active Assessments", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF1D1E33),
        elevation: 0,
      ),
      body: _activeQuizzes.isEmpty
          ? Center(
              child: Text("No active quizzes.", style: TextStyle(color: Colors.grey[500], fontSize: 16)),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(20),
              itemCount: _activeQuizzes.length,
              itemBuilder: (context, index) {
                final quiz = _activeQuizzes[index];
                final status = quiz['status'];
                
                // Color coding based on status
                Color statusColor = Colors.grey;
                if (status == 'PUBLISHED') statusColor = Colors.orangeAccent;
                if (status == 'FAILED') statusColor = Colors.redAccent;
                if (status == 'PASSED') statusColor = Colors.greenAccent;

                return Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1D1E33),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: statusColor.withOpacity(0.5), width: 1.5),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            quiz['student_name'],
                            style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: statusColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              status,
                              style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                      
                      // Show the unlock button ONLY if they passed!
                      if (status == 'PASSED') ...[
                        const SizedBox(height: 20),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () => _unlockStudent(quiz['id'], quiz['student_name']),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            icon: const Icon(Icons.lock_open, color: Colors.white),
                            label: const Text("Unlock Student Account", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ]
                    ],
                  ),
                );
              },
            ),
    );
  }
}