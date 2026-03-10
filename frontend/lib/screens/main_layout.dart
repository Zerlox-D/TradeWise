import 'package:flutter/material.dart';
import 'package:flutter_feather_icons/flutter_feather_icons.dart';
import '../api_service.dart';
import 'student_dashboard.dart';
import 'mentor_dashboard.dart';
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

  @override
  void initState() {
    super.initState();
    _fetchCoreData();
  }

  Future<void> _fetchCoreData() async {
    try {
      final profile = await ApiService.getUserProfile();
      final goals = await ApiService.getGoals();
      if (mounted) {
        setState(() {
          _userProfile = profile;
          _goals = goals;
          _isLoading = false;
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

    final List<Widget> screens = [
      const HomeScreen(),
      const PortfolioScreen(),
      dashboardScreen,
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
      color: const Color(0xFF111633),
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
                icon: Icons.dashboard_outlined,
                activeIcon: Icons.dashboard,
                label: 'Dashboard',
                index: 2,
              ),
            ),
            Expanded(
              child: _buildNavItem(
                icon: Icons.person_outline_rounded,
                activeIcon: Icons.person,
                label: 'Profile',
                index: 3,
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
  }) {
    final bool isActive = _selectedIndex == index;
    final Color color = isActive
        ? const Color(0xFF00E676)
        : const Color(0xFF4C5078);

    return GestureDetector(
      onTap: () => setState(() => _selectedIndex = index),
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(isActive ? activeIcon : icon, color: color, size: 22),
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
