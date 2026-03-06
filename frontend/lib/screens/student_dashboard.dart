import 'package:flutter/material.dart';
import '../api_service.dart';
import 'login_screen.dart';
import 'search_mentors.dart';
import 'trade_screen.dart';
import '../widgets/dashboard_header_analytics.dart';
import '../widgets/dashboard_portfolio.dart';

class StudentDashboard extends StatefulWidget {
  const StudentDashboard({super.key});

  @override
  State<StudentDashboard> createState() => _StudentDashboardState();
}

class _StudentDashboardState extends State<StudentDashboard> {
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

              _buildStudentSection(),
            ],
          ),
        ),
      ),
    );
  }

  // --- 3B. THE STUDENT SECTION ---
  Widget _buildStudentSection() {
    // Check if they have an active or pending mentor link
    final activeOrPending = _mentorLinks
        .where(
          (link) => link['status'] == 'PENDING' || link['status'] == 'ACCEPTED',
        )
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (activeOrPending.isEmpty) ...[
          // Show "Find Mentor" shortcut if they have no active/pending requests
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF1D1E33),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey[800]!),
            ),
            child: Column(
              children: [
                Icon(Icons.person_search, size: 50, color: Colors.grey[600]),
                const SizedBox(height: 16),
                const Text(
                  "You don't have a mentor yet.",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const FindMentorScreen(),
                        ),
                      ).then(
                        (_) => _loadDashboardData(),
                      ); // Refresh when coming back
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue[600],
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: const Text(
                      "FIND A MENTOR",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ] else ...[
          // Show their current status if they have a link
          const Text(
            "Mentorship Status",
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF1D1E33),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: activeOrPending[0]['status'] == 'ACCEPTED'
                    ? Colors.green.withOpacity(0.3)
                    : Colors.orange.withOpacity(0.3),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: activeOrPending[0]['status'] == 'ACCEPTED'
                        ? Colors.green.withOpacity(0.1)
                        : Colors.orange.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    activeOrPending[0]['status'] == 'ACCEPTED'
                        ? Icons.handshake
                        : Icons.hourglass_top,
                    color: activeOrPending[0]['status'] == 'ACCEPTED'
                        ? Colors.greenAccent
                        : Colors.orangeAccent,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        activeOrPending[0]['mentor_name'] ?? "Mentor",
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        activeOrPending[0]['status'] == 'ACCEPTED'
                            ? "Connected & Active"
                            : "Request Pending",
                        style: TextStyle(
                          color: activeOrPending[0]['status'] == 'ACCEPTED'
                              ? Colors.green[300]
                              : Colors.orange[300],
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
