import 'package:flutter/material.dart';
import '../api_service.dart';
import 'login_screen.dart';
import 'student_portfolio_screen.dart';
import '../widgets/dashboard_header_analytics.dart';

class MentorDashboard extends StatefulWidget {
  const MentorDashboard({super.key});

  @override
  State<MentorDashboard> createState() => _MentorDashboardState();
}

class _MentorDashboardState extends State<MentorDashboard> {
  Map<String, dynamic>? _userProfile;
  List<dynamic> _mentorLinks = [];
  List<dynamic> _goals = [];
  List<dynamic> _holdings = [];
  List<dynamic> _trades = [];
  Map<String, double> _livePrices = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    setState(() => _isLoading = true);
    try {
      // Fetch profile, links, and goals in parallel
      final profile = await ApiService.getUserProfile();
      final links = await ApiService.getMentorLinks();
      final goals = await ApiService.getGoals();
      final holdings = await ApiService.getHoldings();
      final trades = await ApiService.getTrades();

      if (mounted) {
        setState(() {
          _userProfile = profile;
          _mentorLinks = links;
          _holdings = holdings;
          _goals = goals;
          _trades = trades;
          _isLoading = false;
        });

        _fetchLivePricesForHoldings();
      }
    } catch (e) {
      print("Dashboard Error: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // Fetches live prices in the background so the UI doesn't freeze!
  Future<void> _fetchLivePricesForHoldings() async {
    for (var holding in _holdings) {
      final symbol = holding['symbol'];
      final quantity = holding['total_quantity'] ?? 0;

      // Only fetch prices for stocks they actually currently own
      if (symbol != null && quantity > 0) {
        final price = await ApiService.getLivePrice(symbol);
        if (price != null && mounted) {
          setState(() {
            _livePrices[symbol] =
                price; // Update the state with the new live price!
          });
        }
      }
    }
  }

  // Action for mentors to accept/reject
  void _handleRequest(int linkId, String action) async {
    // Calls the ApiService function we added earlier
    bool success = await ApiService.respondToRequest(linkId, action);

    if (success) {
      _loadDashboardData(); // Refresh the dashboard to move them from Pending to Active!
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Failed to $action request. Please try again."),
          backgroundColor: Colors.red[700],
        ),
      );
    }
  }

  // Action for mentors to approve/reject high-risk trades
  void _handleTradeAction(int tradeId, String action, String comment) async {
    // You can optionally show a dialog here to capture a 'comment', but we'll default to empty for now
    bool success = await ApiService.respondToTrade(
      tradeId,
      action,
      comment: comment.isEmpty ? "Reviewed by Mentor." : comment,
    );

    if (success) {
      _loadDashboardData(); // Refresh UI to remove it from the pending list!
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Trade ${action}ed successfully."),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Failed to process trade. The student's balance may have changed.",
          ),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  // --- ADD THIS NEW DIALOG FUNCTION ---
  void _showCommentDialog(int tradeId, String action) {
    final _commentController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1D1E33),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          action == 'approve' ? "Approve Trade" : "Reject Trade",
          style: TextStyle(
            color: action == 'approve' ? Colors.greenAccent : Colors.redAccent,
            fontWeight: FontWeight.bold
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              action == 'approve' 
                ? "Add an optional note for the student:" 
                : "Please provide a reason for rejecting this trade:",
              style: const TextStyle(color: Colors.white, fontSize: 14),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _commentController,
              maxLines: 3,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                filled: true,
                fillColor: const Color(0xFF0A0E21),
                hintText: "Type your feedback here...",
                hintStyle: TextStyle(color: Colors.grey[600]),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              final comment = _commentController.text.trim();
              if (action == 'reject' && comment.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Please provide a reason for rejection.")),
                );
                return; // Stop them from submitting an empty rejection
              }
              Navigator.pop(context);
              _handleTradeAction(tradeId, action, comment); // Pass the comment to the API!
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: action == 'approve' ? Colors.green[600] : Colors.red[600],
            ),
            child: const Text("Submit", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showLogoutConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1D1E33),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          "Logout",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: const Text(
          "Are you sure you want to log out of your account?",
          style: TextStyle(color: Colors.grey),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context), // Close dialog
            child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              _logout(); // Actually log them out
            },
            child: const Text(
              "Logout",
              style: TextStyle(
                color: Colors.redAccent,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _logout() async {
    // 1. Clear the token from your ApiService/Storage
    await ApiService.logout();

    if (!mounted) return;

    // 2. Navigate back to Login and completely clear the app's route history
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const LoginScreen()),
      (route) =>
          false, // This prevents them from hitting the Android 'Back' button to return to the dashboard
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFF0A0E21),
        body: Center(child: CircularProgressIndicator(color: Colors.blue)),
      );
    }

    if (_userProfile == null) {
      return const Scaffold(
        backgroundColor: Color(0xFF0A0E21),
        body: Center(
          child: Text(
            "Failed to load profile",
            style: TextStyle(color: Colors.white),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0A0E21),
      
      appBar: AppBar(
        title: const Text(
          "Dashboard",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          TextButton(
            onPressed: _showLogoutConfirmation,
            child: const Text(
              "Logout",
              style: TextStyle(
                color: Colors.redAccent,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 10),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadDashboardData,
        color: Colors.blue,
        backgroundColor: const Color(0xFF1D1E33),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DashboardHeaderAnalytics.buildHeader(_userProfile),
              const SizedBox(height: 30),

              const Text(
                "Analytics",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 16),
              DashboardHeaderAnalytics.buildAnalyticsSection(
                _userProfile,
                _goals,
                () => DashboardHeaderAnalytics.showGoalsBottomSheet(
                  context,
                  _goals,
                  () => DashboardHeaderAnalytics.showAddGoalDialog(
                    context,
                    _loadDashboardData,
                  ),
                  (goal) => DashboardHeaderAnalytics.showEditGoalDialog(
                    context,
                    goal,
                    _loadDashboardData,
                  ),
                  (goal) => DashboardHeaderAnalytics.confirmDeleteGoal(
                    context,
                    goal,
                    _loadDashboardData,
                  ),
                ),
              ),

              const SizedBox(height: 30),

              _buildMentorSection(),
            ],
          ),
        ),
      ),
    );
  }

  // --- 3A. THE MENTOR SECTION ---
  Widget _buildMentorSection() {
    // Separate links into pending requests and active students
    final pendingRequests = _mentorLinks
        .where((link) => link['status'] == 'PENDING')
        .toList();
    final activeStudents = _mentorLinks
        .where((link) => link['status'] == 'ACCEPTED')
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. The Invite Code Card
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF1D1E33),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.blue.withOpacity(0.3)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Mentor ID",
                    style: TextStyle(color: Colors.grey[400], fontSize: 14),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "${_userProfile!['id'] + 130200}", // Your custom math logic!
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.copy, color: Colors.blue[400]),
              ),
            ],
          ),
        ),
        const SizedBox(height: 30),

        // 2. Pending Requests List
        if (pendingRequests.isNotEmpty) ...[
          Text(
            "Pending Requests (${pendingRequests.length})",
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: pendingRequests.length,
            itemBuilder: (context, index) {
              final req = pendingRequests[index];
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF1D1E33),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.orange.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: Colors.orange.withOpacity(0.2),
                      child: const Icon(Icons.person_add, color: Colors.orange),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            req['student_name'] ?? "Investor",
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            "Wants to connect",
                            style: TextStyle(
                              color: Colors.grey[400],
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Reject Button
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.redAccent),
                      onPressed: () => _handleRequest(req['id'], 'reject'),
                    ),
                    // Accept Button
                    IconButton(
                      icon: const Icon(
                        Icons.check_circle,
                        color: Colors.greenAccent,
                        size: 28,
                      ),
                      onPressed: () => _handleRequest(req['id'], 'accept'),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 20),
        ],

        Builder(
          builder: (context) {
            final pendingTrades = _trades
                .where((t) => t['status'] == 'PENDING_MENTOR')
                .toList();

            if (pendingTrades.isEmpty) return const SizedBox.shrink();

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Action Required: Risky Trades (${pendingTrades.length})",
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 16),
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: pendingTrades.length,
                  itemBuilder: (context, index) {
                    final trade = pendingTrades[index];
                    final isBuy = trade['transaction_type'] == 'BUY';

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1D1E33),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.redAccent.withOpacity(0.4),
                          width: 1.5,
                        ), // Red border for high risk!
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    isBuy
                                        ? Icons.arrow_downward
                                        : Icons.arrow_upward,
                                    color: isBuy
                                        ? Colors.greenAccent
                                        : Colors.orangeAccent,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    "${trade['transaction_type']} ${trade['symbol']}",
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              Text(
                                "₹${trade['total_amount']}",
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.black26,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "Student's Justification:",
                                  style: TextStyle(
                                    color: Colors.grey[400],
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  trade['justification'] ??
                                      "No justification provided.",
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              OutlinedButton(
                                onPressed: () =>
                                    _showCommentDialog(trade['id'], 'reject'),
                                style: OutlinedButton.styleFrom(
                                  side: const BorderSide(
                                    color: Colors.redAccent,
                                  ),
                                ),
                                child: const Text(
                                  "Reject",
                                  style: TextStyle(color: Colors.redAccent),
                                ),
                              ),
                              const SizedBox(width: 12),
                              ElevatedButton(
                                onPressed: () =>
                                    _showCommentDialog(trade['id'], 'approve'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green,
                                ),
                                child: const Text(
                                  "Approve Trade",
                                  style: TextStyle(color: Colors.white),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
                const SizedBox(height: 20),
              ],
            );
          },
        ),

        // 3. Active Students List
        Text(
          "My Investors (${activeStudents.length})",
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 16),

        if (activeStudents.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(30.0),
              child: Text(
                "You don't have any connected investors yet.",
                style: TextStyle(color: Colors.grey[500]),
              ),
            ),
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: activeStudents.length,
            itemBuilder: (context, index) {
              final student = activeStudents[index];

              // --- WRAPPED IN GESTURE DETECTOR ---
              return GestureDetector(
                onTap: () {
                  // Safely extract the ID depending on how your Django serializer names it
                  final int targetId =
                      student['student_id'] ?? student['student'];

                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => StudentPortfolioScreen(
                        studentId: targetId,
                        studentName: student['student_name'] ?? "Investor",
                      ),
                    ),
                  );
                },
                child: Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1D1E33),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: Colors.blue.withOpacity(0.2),
                        child: const Icon(Icons.person, color: Colors.blue),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          student['student_name'] ?? "Investor",
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Icon(Icons.chevron_right, color: Colors.grey[600]),
                    ],
                  ),
                ),
              );
            },
          ),
      ],
    );
  }
}