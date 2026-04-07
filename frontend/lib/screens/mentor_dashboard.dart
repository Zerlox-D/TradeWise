import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../api_service.dart';
import 'login_screen.dart';
import 'mentor_quiz_draft_screen.dart';
import 'student_portfolio_screen.dart';
import '../widgets/dashboard_header_analytics.dart';

class MentorDashboard extends StatefulWidget {
  const MentorDashboard({super.key});

  @override
  State<MentorDashboard> createState() => _MentorDashboardState();
}

class _MentorDashboardState extends State<MentorDashboard> {
  Map<String, dynamic>? _userProfile;
  List<dynamic> _mentorLinks    = [];
  List<dynamic> _goals          = [];
  List<dynamic> _holdings       = [];
  List<dynamic> _trades         = [];
  List<dynamic> _unlockRequests = [];
  List<dynamic> _activeQuizzes  = [];
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
      final profile        = await ApiService.getUserProfile();
      final links          = await ApiService.getMentorLinks();
      final goals          = await ApiService.getGoals();
      final holdings       = await ApiService.getHoldings();
      final trades         = await ApiService.getTrades();
      final unlockRequests = await ApiService.getTradeUnlockRequests();
      final activeQuizzes  = await ApiService.getMentorQuizzes() ?? [];

      if (mounted) {
        setState(() {
          _userProfile    = profile;
          _mentorLinks    = links;
          _holdings       = holdings;
          _goals          = goals;
          _trades         = trades;
          _unlockRequests = unlockRequests;
          _activeQuizzes  = activeQuizzes;
          _isLoading      = false;
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

  void _handleUnlockRequestAction(int requestId, String action) async {
    final bool success = await ApiService.respondToTradeUnlockRequest(
      requestId,
      action,
      comment: action == 'approve'
          ? 'Unlock approved by mentor.'
          : 'Mentor kept the lock active.',
    );
    if (success) {
      _loadDashboardData();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(action == 'approve'
              ? 'Trading unlocked for student.'
              : 'Student remains locked.'),
          backgroundColor: action == 'approve' ? _green : _amber,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to process unlock request.'),
          backgroundColor: _red,
        ),
      );
    }
  }

  void _handleRequest(int linkId, String action) async {
    bool success = await ApiService.respondToRequest(linkId, action);
    if (success) {
      _loadDashboardData();
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Failed to $action request. Please try again."),
          backgroundColor: _red,
        ),
      );
    }
  }

  Future<void> _handleTradeAction(
      int tradeId, String action, String comment) async {
    bool success = await ApiService.respondToTrade(
      tradeId,
      action,
      comment: comment.isEmpty ? "Reviewed by Mentor." : comment,
    );
    if (success) {
      _loadDashboardData();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Trade ${action}ed successfully."),
          backgroundColor: _green,
        ),
      );
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              "Failed to process trade. The student's balance may have changed."),
          backgroundColor: _red,
        ),
      );
    }
  }

  void _showCommentDialog(int tradeId, String action) {
    final commentController = TextEditingController();
    bool isSubmitting = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) => StatefulBuilder(
        builder: (BuildContext context, StateSetter setS) => AlertDialog(
          backgroundColor: _card,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            action == 'approve' ? "Approve Trade" : "Reject Trade",
            style: TextStyle(
              color: action == 'approve' ? _green : _red,
              fontWeight: FontWeight.bold,
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
                controller: commentController,
                maxLines: 3,
                enabled: !isSubmitting,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: _bg,
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
              onPressed: isSubmitting
                  ? null
                  : () => Navigator.pop(dialogContext),
              child: Text("Cancel",
                  style: TextStyle(
                      color: isSubmitting ? Colors.grey[600] : Colors.grey)),
            ),
            ElevatedButton(
              onPressed: isSubmitting
                  ? null
                  : () async {
                      final comment = commentController.text.trim();
                      if (action == 'reject' && comment.isEmpty) {
                        ScaffoldMessenger.of(dialogContext).showSnackBar(
                          const SnackBar(
                              content: Text(
                                  "Please provide a reason for rejection.")),
                        );
                        return;
                      }
                      setS(() => isSubmitting = true);
                      await _handleTradeAction(tradeId, action, comment);
                      if (mounted) Navigator.pop(dialogContext);
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: isSubmitting
                    ? Colors.grey
                    : (action == 'approve'
                        ? const Color(0xFF00C853)
                        : const Color(0xFFD32F2F)),
              ),
              child: isSubmitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white)),
                    )
                  : const Text("Submit",
                      style: TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  void _showLogoutConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _card,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text("Logout",
            style:
                TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: const Text(
          "Are you sure you want to log out of your account?",
          style: TextStyle(color: Colors.grey),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child:
                const Text("Cancel", style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _logout();
            },
            child: const Text("Logout",
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

  Widget _countBadge(int count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text('$count',
          style: TextStyle(
              color: color, fontSize: 12, fontWeight: FontWeight.w700)),
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
            child: Text("Failed to load profile",
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

                // ── Mentor ID card with working copy ─────────────────────
                _buildMentorIdCard(),
                const SizedBox(height: 28),

                // ── Analytics header ─────────────────────────────────────
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

                // ── Mentor actions + investors ────────────────────────────
                _buildMentorSection(),
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
    final balance     = _userProfile!['wallet_balance'] ?? "0.00";
    final riskProfile = _userProfile!['risk_profile'] ?? "Moderate";
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
            // Risk profile badge — back in its original position
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
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
                    decoration:
                        BoxDecoration(color: riskCol, shape: BoxShape.circle),
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

        // Wallet + Risk + Discipline hero card
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
                  style: TextStyle(color: Colors.grey[500], fontSize: 13)),
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

  // ── Mentor ID card ─────────────────────────────────────────────────────────
  Widget _buildMentorIdCard() {
    final mentorId    = _userProfile!['id'] + 130200;
    final mentorIdStr = mentorId.toString();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: _green.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.badge_rounded, color: _green, size: 22),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Mentor ID',
                    style:
                        TextStyle(color: Colors.grey[500], fontSize: 11)),
                const SizedBox(height: 3),
                Text(mentorIdStr,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2)),
              ],
            ),
          ),
          // ── Functional copy button ────────────────────────────────────
          GestureDetector(
            onTap: () {
              Clipboard.setData(ClipboardData(text: mentorIdStr));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Row(
                    children: [
                      Icon(Icons.check_circle_outline,
                          color: _green, size: 18),
                      SizedBox(width: 10),
                      Text('Mentor ID copied!',
                          style: TextStyle(color: Colors.white)),
                    ],
                  ),
                  backgroundColor: _card,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                      side: const BorderSide(color: _border)),
                  duration: const Duration(seconds: 2),
                ),
              );
            },
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              decoration: BoxDecoration(
                color: _green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _green.withOpacity(0.3)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.copy_rounded, color: _green, size: 20),
                  // SizedBox(width: 6),
                  // Text('Copy',
                  //     style: TextStyle(
                  //         color: _green,
                  //         fontSize: 13,
                  //         fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Mentor section ─────────────────────────────────────────────────────────
  Widget _buildMentorSection() {
    final pendingRequests = _mentorLinks
        .where((link) => link['status'] == 'PENDING')
        .toList();
    final activeStudents = _mentorLinks
        .where((link) => link['status'] == 'ACCEPTED')
        .toList();
    final pendingUnlockRequests =
        _unlockRequests.where((req) => req['status'] == 'PENDING').toList();
    final pendingTrades =
        _trades.where((t) => t['status'] == 'PENDING_MENTOR').toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Pending connection requests ──────────────────────────────────
        if (pendingRequests.isNotEmpty) ...[
          _sectionHeader('Pending Requests',
              trailing: _countBadge(pendingRequests.length, _amber)),
          const SizedBox(height: 14),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: pendingRequests.length,
            itemBuilder: (context, index) {
              final req = pendingRequests[index];
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: _card,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _amber.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: _amber.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.person_add_rounded,
                          color: _amber, size: 20),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(req['student_name'] ?? "Investor",
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600)),
                          const SizedBox(height: 2),
                          Text('Wants to connect',
                              style: TextStyle(
                                  color: Colors.grey[500], fontSize: 12)),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: _red),
                      onPressed: () =>
                          _handleRequest(req['id'], 'reject'),
                    ),
                    IconButton(
                      icon: const Icon(Icons.check_circle_rounded,
                          color: _green, size: 26),
                      onPressed: () =>
                          _handleRequest(req['id'], 'accept'),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 24),
        ],

        // ── Trade unlock requests ────────────────────────────────────────
        if (pendingUnlockRequests.isNotEmpty) ...[
          _sectionHeader('Trade Unlock Requests',
              trailing:
                  _countBadge(pendingUnlockRequests.length, _amber)),
          const SizedBox(height: 14),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: pendingUnlockRequests.length,
            itemBuilder: (context, index) {
              final req = pendingUnlockRequests[index];
              final bool hasActiveQuiz = _activeQuizzes.any(
                  (q) => q['student_name'] == req['student_name'] && q['status'] == 'PUBLISHED');

              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _card,
                  borderRadius: BorderRadius.circular(14),
                  border:
                      Border.all(color: _amber.withOpacity(0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: _amber.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.lock_open_rounded,
                              color: _amber, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                              req['student_name'] ?? 'Investor',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 15)),
                        ),
                        if (hasActiveQuiz)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: _blue.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                  color: _blue.withOpacity(0.3)),
                            ),
                            child: const Text('Quiz Active',
                                style: TextStyle(
                                    color: _blue,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600)),
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _bg,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        req['requested_reason'] ??
                            'Trading is locked. Student requests to unlock.',
                        style: TextStyle(
                            color: Colors.grey[300], fontSize: 13),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: hasActiveQuiz
                          ? MainAxisAlignment.center
                          : MainAxisAlignment.end,
                      children: [
                        if (!hasActiveQuiz) ...[
                          OutlinedButton(
                            onPressed: () =>
                                _handleUnlockRequestAction(
                                    req['id'], 'reject'),
                            style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: _amber)),
                            child: const Text("Keep Locked",
                                style: TextStyle(color: _amber)),
                          ),
                          const SizedBox(width: 10),
                        ],
                        ElevatedButton(
                          onPressed: hasActiveQuiz
                              ? null
                              : () {
                                  final int studentId =
                                      req['student_id'] ??
                                          req['user_id'] ??
                                          req['student'];
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          MentorQuizDraftScreen(
                                        studentId: studentId,
                                        studentName:
                                            req['student_name'] ?? 'Student',
                                        requestId: req['id'],
                                      ),
                                    ),
                                  ).then((_) => _loadDashboardData());
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: hasActiveQuiz
                                ? const Color(0xFF1E2440)
                                : _blue,
                          ),
                          child: Text(
                            hasActiveQuiz ? "Quiz Active" : "Draft Quiz",
                            style: TextStyle(
                                color: hasActiveQuiz
                                    ? Colors.grey[500]
                                    : Colors.white),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 24),
        ],

        // ── Risky trades ─────────────────────────────────────────────────
        if (pendingTrades.isNotEmpty) ...[
          _sectionHeader('Risky Trades · Action Required',
              trailing: _countBadge(pendingTrades.length, _red)),
          const SizedBox(height: 14),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: pendingTrades.length,
            itemBuilder: (context, index) {
              final trade = pendingTrades[index];
              final isBuy = trade['transaction_type'] == 'BUY';

              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _card,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color: _red.withOpacity(0.4), width: 1.5),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment:
                          MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(
                              isBuy
                                  ? Icons.arrow_downward
                                  : Icons.arrow_upward,
                              color: isBuy ? _green : _amber,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              "${trade['transaction_type']} ${trade['symbol']}",
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                        Text("₹${trade['total_amount']}",
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.w600)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.person_outline,
                            color: Colors.grey[500], size: 14),
                        const SizedBox(width: 6),
                        Text(
                          "Requested by: ${trade['username'] ?? trade['user_name'] ?? 'Student'}",
                          style: TextStyle(
                              color: Colors.grey[400], fontSize: 12),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                          color: _bg,
                          borderRadius: BorderRadius.circular(10)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("Student's Justification:",
                              style: TextStyle(
                                  color: Colors.grey[500],
                                  fontSize: 11)),
                          const SizedBox(height: 4),
                          Text(
                            trade['justification'] ??
                                "No justification provided.",
                            style: const TextStyle(
                                color: Colors.white,
                                fontStyle: FontStyle.italic,
                                fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        OutlinedButton(
                          onPressed: () =>
                              _showCommentDialog(trade['id'], 'reject'),
                          style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: _red)),
                          child: const Text("Reject",
                              style: TextStyle(color: _red)),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton(
                          onPressed: () =>
                              _showCommentDialog(trade['id'], 'approve'),
                          style: ElevatedButton.styleFrom(
                              backgroundColor:
                                  const Color(0xFF00C853)),
                          child: const Text("Approve",
                              style: TextStyle(color: Colors.white)),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 24),
        ],

        // ── Active investors ─────────────────────────────────────────────
        _sectionHeader('My Investors',
            trailing: _countBadge(activeStudents.length, _blue)),
        const SizedBox(height: 14),

        if (activeStudents.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: _card,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _border),
            ),
            child: Center(
              child: Text(
                "You don't have any connected investors yet.",
                style: TextStyle(color: Colors.grey[500]),
                textAlign: TextAlign.center,
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
              return GestureDetector(
                onTap: () {
                  final int targetId =
                      student['student_id'] ?? student['student'];
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => StudentPortfolioScreen(
                        studentId: targetId,
                        studentName:
                            student['student_name'] ?? "Investor",
                      ),
                    ),
                  );
                },
                child: Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: _card,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: _border),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: _blue.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.person_rounded,
                            color: _blue, size: 20),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          student['student_name'] ?? "Investor",
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w600),
                        ),
                      ),
                      Icon(Icons.chevron_right,
                          color: Colors.grey[600]),
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