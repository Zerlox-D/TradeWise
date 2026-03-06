import 'package:flutter/material.dart';
import '../api_service.dart';
import 'student_dashboard.dart';
import 'mentor_dashboard.dart';
import 'trade_screen.dart';
import 'portfolio_screen.dart';

// --- TEMPORARY PLACEHOLDER FOR PHASE 3 ---
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFF0A0E21),
      body: Center(child: Text("Market Overview building in Phase 3...", style: TextStyle(color: Colors.white))),
    );
  }
}

class MainLayout extends StatefulWidget {
  const MainLayout({super.key});

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  int _selectedIndex = 2; // 0 = Home/Portfolio, 1 = Profile/Dashboard
  
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

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFF0A0E21),
        body: Center(child: CircularProgressIndicator(color: Colors.greenAccent)),
      );
    }

    // Determine which dashboard to show on the right tab
    Widget profileScreen = _userProfile?['role'] == 'MENTOR' 
        ? const MentorDashboard() 
        : const StudentDashboard();

    final List<Widget> screens = [
      const PortfolioScreen(), // The new page we will build in Phase 3
      profileScreen,      // Your existing analytics/mentor dashboard
      const HomeScreen(),   // Placeholder for the Market Overview page in Phase 3
    ];

    return Scaffold(
      backgroundColor: const Color(0xFF0A0E21),
      body: screens[_selectedIndex],
      
      // --- THE FLOATING TRADE BUTTON ---
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => TradeScreen(
                userGoals: _goals,
                userDisciplineScore: _userProfile?['discipline_score'] ?? 50,
              ),
            ),
          ).then((_) => _fetchCoreData()); // Refresh if they made a trade!
        },
        backgroundColor: Colors.greenAccent,
        shape: const CircleBorder(),
        elevation: 8,
        child: const Icon(Icons.swap_horiz, color: Colors.black, size: 32),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      
      // --- THE BOTTOM NAV BAR ---
      bottomNavigationBar: BottomAppBar(
        color: const Color(0xFF1D1E33),
        shape: const CircularNotchedRectangle(),
        notchMargin: 8.0,
        child: SizedBox(
          height: 60,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              // Left: Portfolio / Market
              IconButton(
                icon: Icon(Icons.pie_chart, color: _selectedIndex == 0 ? Colors.greenAccent : Colors.grey[600]),
                onPressed: () => setState(() => _selectedIndex = 0),
              ),
              const SizedBox(width: 48), // Empty space for the floating Trade button
              // Right: Profile / Analytics
              IconButton(
                icon: Icon(Icons.person, color: _selectedIndex == 1 ? Colors.greenAccent : Colors.grey[600]),
                onPressed: () => setState(() => _selectedIndex = 1),
              ),
            ],
          ),
        ),
      ),
    );
  }
}