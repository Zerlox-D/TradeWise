import 'package:flutter/material.dart';
import 'package:flutter_feather_icons/flutter_feather_icons.dart';
import '../api_service.dart';
import 'mentor_quiz_hub.dart';
import 'student_dashboard.dart';
import 'mentor_dashboard.dart';
import 'student_quiz_hub.dart';
import 'student_quiz_screen.dart';
import 'trade_screen.dart';
import 'portfolio_screen.dart';
import 'home_screen.dart';

class MainLayout extends StatefulWidget {
  const MainLayout({super.key});

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  int _selectedIndex = 0;

  Map<String, dynamic>? _userProfile;
  List<dynamic> _goals = [];
  bool _isLoading = true;
  bool _hasPendingQuiz = false;
  bool _hasMentorNotifications = false;
  bool _hasPassedQuizzes = false;

  @override
  void initState() {
    super.initState();
    _fetchCoreData();
  }

  Future<void> _fetchCoreData() async {
    try {
      final profile = await ApiService.getUserProfile();
      final goals = await ApiService.getGoals();
      bool hasQuiz = false;
      bool hasMentorAlerts = false;
      bool passedQuizzesAlert = false;
      
      if (profile['role'] == 'MENTOR') {
          // Read the new flag we just added to Django!
          hasMentorAlerts = profile['has_pending_mentor_actions'] ?? false;
          passedQuizzesAlert = profile['has_passed_quizzes'] ?? false;

          print("DEBUG: Django sent has_passed_quizzes = ${profile['has_passed_quizzes']}");

        } else {
          // Student logic
          final quizData = await ApiService.getStudentPendingQuiz();
          if (quizData != null && quizData['quiz_id'] != null) {
            hasQuiz = true;
          }
        }

      if (mounted) {
        setState(() {
          _userProfile = profile;
          _goals = goals;
          _isLoading = false;
          _hasPendingQuiz = hasQuiz;
          _hasMentorNotifications = hasMentorAlerts;
          _hasPassedQuizzes = passedQuizzesAlert;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _onTrade() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TradeScreen(
          userGoals: _goals,
          userDisciplineScore: _userProfile?['discipline_score'] ?? 50,
        ),
      ),
    ).then((_) => _fetchCoreData());
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFF0A0E21),
        body: Center(
          child: CircularProgressIndicator(
            color: Color(0xFF00E676),
            strokeWidth: 2.5,
          ),
        ),
      );
    }

    Widget dashboardScreen = _userProfile?['role'] == 'MENTOR'
        ? const MentorDashboard()
        : const StudentDashboard();

    // NEW logic: The Quiz/Assessment Tab
    Widget assessmentScreen = _userProfile?['role'] == 'MENTOR'
        ? MentorQuizHub() 
        : StudentQuizHub();

    final List<Widget> screens = [
      const HomeScreen(),
      const PortfolioScreen(),
      assessmentScreen,
      dashboardScreen,
    ];

    return Scaffold(
      backgroundColor: const Color(0xFF0A0E21),
      body: screens[_selectedIndex],
      floatingActionButton: _buildTradeFAB(),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: _buildBottomBar(),
    );
  }

  Widget _buildTradeFAB() {
    return Container(
      height: 60,
      width: 60,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          colors: [Color(0xFF00E676), Color(0xFF00C853)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF00E676).withOpacity(0.35),
            blurRadius: 18,
            spreadRadius: 1,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: FloatingActionButton(
        onPressed: _onTrade,
        backgroundColor: Colors.transparent,
        elevation: 0,
        shape: const CircleBorder(),
        child: const Icon(
          FeatherIcons.activity,
          color: Color(0xFF0A0E21),
          size: 32,
        ),
      ),
    );
  }

  Widget _buildBottomBar() {
    return BottomAppBar(
      color: const Color.fromARGB(255, 14, 27, 46),
      shape: const CircularNotchedRectangle(),
      notchMargin: 10,
      elevation: 20,
      child: SizedBox(
        height: 70,
        child: Row(
          children: [
            Expanded(
              child: _buildNavItem(
                icon: Icons.candlestick_chart_outlined,
                activeIcon: Icons.candlestick_chart,
                label: 'Market',
                index: 0,
              ),
            ),
            Expanded(
              child: _buildNavItem(
                icon: Icons.account_balance_wallet_outlined,
                activeIcon: Icons.account_balance_wallet,
                label: 'Portfolio',
                index: 1,
              ),
            ),
            const SizedBox(width: 72),
            Expanded(
              child: _buildNavItem(
                icon: Icons.assignment_outlined, // Changed Icon!
                activeIcon: Icons.assignment, // Changed Icon!
                label: 'Assessments', // Changed Label!
                index: 2,
                showBadge: _userProfile?['role'] != 'MENTOR' && _hasPendingQuiz || 
                           (_userProfile?['role'] == 'MENTOR' && _hasPassedQuizzes),
              ),
            ),
            Expanded(
              child: _buildNavItem(
                icon: Icons.person_outline_rounded,
                activeIcon: Icons.person,
                label: 'Profile',
                index: 3,
                showBadge: _userProfile?['role'] == 'MENTOR' && _hasMentorNotifications,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required IconData icon,
    required IconData activeIcon,
    required String label,
    required int index,
    bool showBadge = false,
  }) {
    final bool isActive = _selectedIndex == index;
    final Color color = isActive
        ? const Color(0xFF00E676)
        : const Color(0xFF4C5078);

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedIndex = index;
          
          // YOUR FIX: Clear the dots the moment they open the tab!
          
          // 1. If a Student opens the Assessment tab (Index 2), clear the dot
          if (index == 2 && _userProfile?['role'] != 'MENTOR') {
            _hasPendingQuiz = false;
          }

          if (index == 2 && _userProfile?['role'] == 'MENTOR') {
            _hasPassedQuizzes = false;
          }
          
          // 2. If a Mentor opens the Profile/Dashboard tab (Index 3), clear the dot
          if (index == 3 && _userProfile?['role'] == 'MENTOR') {
            _hasMentorNotifications = false;
          }
        });
      },
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Use a Stack to put the red dot over the icon!
          Stack(
            clipBehavior: Clip.none,
            children: [
              Icon(isActive ? activeIcon : icon, color: color, size: 22),
              if (showBadge)
                Positioned(
                  top: -2,
                  right: -2,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Colors.redAccent,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}
