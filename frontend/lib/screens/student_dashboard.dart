import 'package:flutter/material.dart';
import '../api_service.dart';
import 'login_screen.dart';
import 'search_mentors.dart';
import 'trade_screen.dart';
import '../widgets/dashboard_header_analytics.dart';

class StudentDashboard extends StatefulWidget {
  const StudentDashboard({super.key});

  @override
  State<StudentDashboard> createState() => _StudentDashboardState();
}

class _StudentDashboardState extends State<StudentDashboard> {
  Map<String, dynamic>? _userProfile;
  List<dynamic> _mentorLinks = [];
  List<dynamic> _goals       = [];
  List<dynamic> _holdings    = [];
  List<dynamic> _trades      = [];
  Map<String, double> _livePrices = {};
  bool _isLoading = true;

  // ── Brand palette ──────────────────────────────────────────────────────────
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
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    setState(() => _isLoading = true);
    try {
      final profile  = await ApiService.getUserProfile();
      final links    = await ApiService.getMentorLinks();
      final goals    = await ApiService.getGoals();
      final holdings = await ApiService.getHoldings();
      final trades   = await ApiService.getTrades();

      if (mounted) {
        setState(() {
          _userProfile = profile;
          _mentorLinks = links;
          _holdings    = holdings;
          _goals       = goals;
          _trades      = trades;
          _isLoading   = false;
        });
        _fetchLivePricesForHoldings();
      }
    } catch (e) {
      print("Dashboard Error: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchLivePricesForHoldings() async {
    for (var holding in _holdings) {
      final symbol   = holding['symbol'];
      final quantity = holding['total_quantity'] ?? 0;
      if (symbol != null && quantity > 0) {
        final price = await ApiService.getLivePrice(symbol);
        if (price != null && mounted) {
          setState(() => _livePrices[symbol] = price);
        }
      }
    }
  }

  void _showLogoutConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _card,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Logout',
            style:
                TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: const Text(
          'Are you sure you want to log out of your account?',
          style: TextStyle(color: Colors.grey),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child:
                const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _logout();
            },
            child: const Text('Logout',
                style: TextStyle(
                    color: _red, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _logout() async {
    await ApiService.logout();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const LoginScreen()),
      (route) => false,
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────────────
  Widget _sectionHeader(String title, {Widget? trailing}) {
    return Row(
      children: [
        Container(
          width: 3,
          height: 18,
          decoration: BoxDecoration(
              color: _green, borderRadius: BorderRadius.circular(2)),
        ),
        const SizedBox(width: 10),
        Text(title,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600)),
        const Spacer(),
        if (trailing != null) trailing,
      ],
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: _bg,
        body: Center(child: CircularProgressIndicator(color: _green)),
      );
    }

    if (_userProfile == null) {
      return const Scaffold(
        backgroundColor: _bg,
        body: Center(
            child: Text('Failed to load profile',
                style: TextStyle(color: Colors.white))),
      );
    }

    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadDashboardData,
          color: _green,
          backgroundColor: _card,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Brand bar ────────────────────────────────────────────
                const Row(
                  children: [
                    Icon(Icons.bolt_rounded, color: _green, size: 18),
                    SizedBox(width: 6),
                    Text(
                      'TRADEWISE',
                      style: TextStyle(
                        color: _green,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // ── Profile hero ──────────────────────────────────────────
                _buildProfileHero(),
                const SizedBox(height: 28),

                // ── Analytics ─────────────────────────────────────────────
                _sectionHeader('Analytics'),
                const SizedBox(height: 14),
                DashboardHeaderAnalytics.buildAnalyticsSection(
                  _userProfile,
                  _goals,
                  () => DashboardHeaderAnalytics.showGoalsBottomSheet(
                    context,
                    _goals,
                    () => DashboardHeaderAnalytics.showAddGoalDialog(
                        context, _loadDashboardData),
                    (goal) => DashboardHeaderAnalytics.showEditGoalDialog(
                        context, goal, _loadDashboardData),
                    (goal) => DashboardHeaderAnalytics.confirmDeleteGoal(
                        context, goal, _loadDashboardData),
                  ),
                ),
                const SizedBox(height: 28),

                // ── Mentorship ────────────────────────────────────────────
                _buildStudentSection(),
                const SizedBox(height: 32),

                // ── Logout — bottom of screen ─────────────────────────────
                GestureDetector(
                  onTap: _showLogoutConfirmation,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: _red.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: _red.withOpacity(0.25)),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.logout_rounded, color: _red, size: 16),
                        SizedBox(width: 8),
                        Text(
                          'Logout',
                          style: TextStyle(
                            color: _red,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Profile hero ───────────────────────────────────────────────────────────
  Widget _buildProfileHero() {
    final balance     = _userProfile!['wallet_balance'] ?? '0.00';
    final riskProfile = _userProfile!['risk_profile'] ?? 'Moderate';
    final username    = _userProfile!['username'] ?? '';

    Color riskCol;
    switch (riskProfile) {
      case 'Low':
      case 'Conservative':
        riskCol = _green;
        break;
      case 'Moderate':
        riskCol = _amber;
        break;
      case 'High':
      case 'Aggressive':
        riskCol = _red;
        break;
      default:
        riskCol = _blue;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Welcome back,',
            style: TextStyle(fontSize: 14, color: Colors.grey[500])),
        const SizedBox(height: 6),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Text(username,
                  style: const TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      letterSpacing: -0.5)),
            ),
            const SizedBox(width: 12),
            // Risk profile badge
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: riskCol.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: riskCol.withOpacity(0.35)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                        color: riskCol, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 6),
                  Text(riskProfile,
                      style: TextStyle(
                          color: riskCol,
                          fontSize: 12,
                          fontWeight: FontWeight.w700)),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),

        // Wallet card
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF0D2137), Color(0xFF0A1628)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Total Balance',
                  style:
                      TextStyle(color: Colors.grey[500], fontSize: 13)),
              const SizedBox(height: 6),
              Text('₹$balance',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 34,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5)),
            ],
          ),
        ),
      ],
    );
  }

  // ── Student section (mentorship status / find mentor) ─────────────────────
  Widget _buildStudentSection() {
    final activeOrPending = _mentorLinks
        .where((link) =>
            link['status'] == 'PENDING' || link['status'] == 'ACCEPTED')
        .toList();

    // ── No mentor yet ──────────────────────────────────────────────────────
    if (activeOrPending.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader('Mentorship'),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: _card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _border),
            ),
            child: Column(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: _blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(Icons.person_search_rounded,
                      color: _blue, size: 28),
                ),
                const SizedBox(height: 16),
                const Text(
                  "You don't have a mentor yet.",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Connect with a mentor to unlock guided investing.',
                  style:
                      TextStyle(color: Colors.grey[500], fontSize: 13),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const FindMentorScreen(),
                        ),
                      ).then((_) => _loadDashboardData());
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: _green.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border:
                            Border.all(color: _green.withOpacity(0.3)),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.search_rounded,
                              color: _green, size: 18),
                          SizedBox(width: 8),
                          Text(
                            'FIND A MENTOR',
                            style: TextStyle(
                              color: _green,
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    // ── Has mentor link ────────────────────────────────────────────────────
    final link      = activeOrPending[0];
    final isAccepted = link['status'] == 'ACCEPTED';
    final statusCol  = isAccepted ? _green : _amber;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader(
          'Mentorship',
          trailing: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: statusCol.withOpacity(0.12),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: statusCol.withOpacity(0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                      color: statusCol, shape: BoxShape.circle),
                ),
                const SizedBox(width: 6),
                Text(
                  isAccepted ? 'Active' : 'Pending',
                  style: TextStyle(
                      color: statusCol,
                      fontSize: 12,
                      fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: _card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: statusCol.withOpacity(0.3)),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: statusCol.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  isAccepted
                      ? Icons.handshake_rounded
                      : Icons.hourglass_top_rounded,
                  color: statusCol,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      link['mentor_name'] ?? 'Mentor',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isAccepted
                          ? 'Connected & Active'
                          : 'Request Pending — awaiting mentor approval',
                      style: TextStyle(
                        color: statusCol,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}