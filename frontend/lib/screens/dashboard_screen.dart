
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../api_service.dart';
import 'login_screen.dart';
import 'search_mentors.dart';
import 'student_portfolio_screen.dart';
import 'trade_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
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
            _livePrices[symbol] = price; // Update the state with the new live price!
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
  void _handleTradeAction(int tradeId, String action) async {
    // You can optionally show a dialog here to capture a 'comment', but we'll default to empty for now
    bool success = await ApiService.respondToTrade(tradeId, action, comment: "Reviewed by Mentor.");
    
    if (success) {
      _loadDashboardData(); // Refresh UI to remove it from the pending list!
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Trade ${action}d successfully."), backgroundColor: Colors.green),
      );
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Failed to process trade. The student's balance may have changed."), backgroundColor: Colors.redAccent),
      );
    }
  }

  // --- THE GOALS VIEWER ---
  void _showGoalsBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0A0E21),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      isScrollControlled: true, // Allows it to take up more screen space
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("Your Goals", style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                  IconButton(
                    icon: const Icon(Icons.add_circle, color: Colors.blueAccent, size: 32),
                    onPressed: () {
                      Navigator.pop(context); // Close the sheet
                      _showAddGoalDialog(); // Open the add dialog
                    },
                  )
                ],
              ),
              const SizedBox(height: 20),
              
              if (_goals.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: Center(child: Text("No goals yet. Add one to get started!", style: TextStyle(color: Colors.grey))),
                )
              else
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _goals.length,
                  itemBuilder: (context, index) {
                    final goal = _goals[index];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1D1E33),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(goal['name'] ?? "Goal", style: const TextStyle(color: Colors.white, fontSize: 16)),
                          const SizedBox(height: 4),
                          Text("Due: ${_goals[index]['deadline_date'] ?? 'N/A'}", style: TextStyle(color: Colors.grey[400], fontSize: 12)),
                          Text(
                            "₹${goal['target_amount'] ?? '0'}", 
                            style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(width: 8),
                          PopupMenuButton<String>(
                            color: const Color(0xFF1D1E33),
                            icon: const Icon(Icons.more_vert, color: Colors.grey),
                            onSelected: (value) {
                              Navigator.pop(context); // Close the bottom sheet first
                              if (value == 'edit') {
                                _showEditGoalDialog(goal);
                              } else if (value == 'delete') {
                                _confirmDeleteGoal(goal);
                              }
                            },
                            itemBuilder: (context) => [
                              const PopupMenuItem(
                                value: 'edit',
                                child: Text("Edit", style: TextStyle(color: Colors.white)),
                              ),
                              const PopupMenuItem(
                                value: 'delete',
                                child: Text("Delete", style: TextStyle(color: Colors.redAccent)),
                              ),
                            ],
                          )
                        ],
                      ),
                    );
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  // --- THE ADD GOAL FORM ---
  void _showAddGoalDialog() {
    final titleController = TextEditingController();
    final amountController = TextEditingController();
    DateTime? selectedDate; // Store the chosen date
    bool isSaving = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: const Color(0xFF1D1E33),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Text("Add New Goal", style: TextStyle(color: Colors.white)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: titleController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: "Goal Title (e.g. Emergency Fund)",
                    labelStyle: TextStyle(color: Colors.grey[400]),
                    enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.grey)),
                    focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.blueAccent)),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: amountController,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: "Target Amount (₹)",
                    labelStyle: TextStyle(color: Colors.grey[400]),
                    enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.grey)),
                    focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.blueAccent)),
                  ),
                ),
                const SizedBox(height: 24),
                
                // --- NEW: Date Picker Button ---
                OutlinedButton.icon(
                  onPressed: () async {
                    final DateTime? picked = await showDatePicker(
                      context: context,
                      initialDate: DateTime.now().add(const Duration(days: 30)),
                      firstDate: DateTime.now(),
                      lastDate: DateTime(2050),
                      builder: (context, child) {
                        return Theme(
                          data: Theme.of(context).copyWith(
                            colorScheme: const ColorScheme.dark(
                              primary: Colors.blueAccent,
                              onPrimary: Colors.white,
                              surface: Color(0xFF1D1E33),
                              onSurface: Colors.white,
                            ),
                          ),
                          child: child!,
                        );
                      },
                    );
                    if (picked != null) {
                      setDialogState(() => selectedDate = picked);
                    }
                  },
                  icon: const Icon(Icons.calendar_today, color: Colors.blueAccent),
                  label: Text(
                    selectedDate == null 
                        ? "Select Deadline" 
                        : "${selectedDate!.year}-${selectedDate!.month.toString().padLeft(2, '0')}-${selectedDate!.day.toString().padLeft(2, '0')}",
                    style: const TextStyle(color: Colors.white),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: Colors.blue.withOpacity(0.5)),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: isSaving ? null : () => Navigator.pop(context),
                child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
              ),
              ElevatedButton(
                onPressed: isSaving ? null : () async {
                  if (titleController.text.isEmpty || amountController.text.isEmpty || selectedDate == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Please fill all fields and select a date."), backgroundColor: Colors.orange),
                    );
                    return;
                  }
                  
                  setDialogState(() => isSaving = true);
                  
                  // Format the date as YYYY-MM-DD for Django
                  String formattedDate = "${selectedDate!.year}-${selectedDate!.month.toString().padLeft(2, '0')}-${selectedDate!.day.toString().padLeft(2, '0')}";
                  
                  bool success = await ApiService.addGoal(
                    titleController.text, 
                    double.tryParse(amountController.text) ?? 0.0,
                    formattedDate // Pass the new date string!
                  );
                  
                  if (success) {
                    Navigator.pop(context); 
                    _loadDashboardData(); 
                  } else {
                    setDialogState(() => isSaving = false);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Failed to save goal."), backgroundColor: Colors.redAccent),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent),
                child: isSaving 
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text("Save", style: TextStyle(color: Colors.white)),
              ),
            ],
          );
        }
      ),
    );
  }

  // --- THE EDIT GOAL FORM ---
  void _showEditGoalDialog(Map goal) {
    final titleController = TextEditingController(text: goal['title'] ?? goal['name']);
    final amountController = TextEditingController(text: goal['target_amount'].toString());
    DateTime? selectedDate = DateTime.tryParse(goal['deadline_date'] ?? '');
    bool isSaving = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: const Color(0xFF1D1E33),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Text("Edit Goal", style: TextStyle(color: Colors.white)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: titleController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: "Goal Title",
                    labelStyle: TextStyle(color: Colors.grey[400]),
                    enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.grey)),
                    focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.blueAccent)),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: amountController,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: "Target Amount (\$)",
                    labelStyle: TextStyle(color: Colors.grey[400]),
                    enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.grey)),
                    focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.blueAccent)),
                  ),
                ),
                const SizedBox(height: 24),
                
                // Date Picker Button
                OutlinedButton.icon(
                  onPressed: () async {
                    final DateTime? picked = await showDatePicker(
                      context: context,
                      initialDate: selectedDate ?? DateTime.now(),
                      firstDate: DateTime.now(),
                      lastDate: DateTime(2050),
                      builder: (context, child) {
                        return Theme(
                          data: Theme.of(context).copyWith(
                            colorScheme: const ColorScheme.dark(
                              primary: Colors.blueAccent, surface: Color(0xFF1D1E33), onSurface: Colors.white),
                          ),
                          child: child!,
                        );
                      },
                    );
                    if (picked != null) {
                      setDialogState(() => selectedDate = picked);
                    }
                  },
                  icon: const Icon(Icons.calendar_today, color: Colors.blueAccent),
                  label: Text(
                    selectedDate == null 
                        ? "Select Deadline" 
                        : "${selectedDate!.year}-${selectedDate!.month.toString().padLeft(2, '0')}-${selectedDate!.day.toString().padLeft(2, '0')}",
                    style: const TextStyle(color: Colors.white),
                  ),
                  style: OutlinedButton.styleFrom(side: BorderSide(color: Colors.blue.withOpacity(0.5))),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: isSaving ? null : () => Navigator.pop(context),
                child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
              ),
              ElevatedButton(
                onPressed: isSaving ? null : () async {
                  if (titleController.text.isEmpty || amountController.text.isEmpty || selectedDate == null) return;
                  
                  setDialogState(() => isSaving = true);
                  String formattedDate = "${selectedDate!.year}-${selectedDate!.month.toString().padLeft(2, '0')}-${selectedDate!.day.toString().padLeft(2, '0')}";
                  
                  // Call update instead of add!
                  bool success = await ApiService.updateGoal(
                    goal['id'], 
                    titleController.text, 
                    double.tryParse(amountController.text) ?? 0.0,
                    formattedDate
                  );
                  
                  if (success) {
                    Navigator.pop(context); 
                    _loadDashboardData(); 
                  } else {
                    setDialogState(() => isSaving = false);
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Failed to update goal."), backgroundColor: Colors.redAccent));
                  }
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent),
                child: isSaving 
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text("Update", style: TextStyle(color: Colors.white)),
              ),
            ],
          );
        }
      ),
    );
  }

  // --- THE DELETE CONFIRMATION ---
  void _confirmDeleteGoal(Map goal) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1D1E33),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text("Delete Goal?", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Text("Are you sure you want to delete '${goal['title'] ?? goal['name']}'?", style: const TextStyle(color: Colors.grey)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context); // Close dialog immediately
              bool success = await ApiService.deleteGoal(goal['id']);
              if (success) {
                _loadDashboardData(); // Refresh UI
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Goal deleted."), backgroundColor: Colors.green));
              } else {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Failed to delete goal."), backgroundColor: Colors.redAccent));
              }
            },
            child: const Text("Delete", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // --- HELPER 1: Draws the Pie Slices ---
  List<PieChartSectionData> _buildPieChartSections(List<Map<String, dynamic>> validHoldings, double totalValue) {
    // A nice neon palette for our dark theme
    final colors = [Colors.blueAccent, Colors.greenAccent, Colors.orangeAccent, Colors.purpleAccent, Colors.redAccent, Colors.cyanAccent];
    
    return List.generate(validHoldings.length, (i) {
      final holding = validHoldings[i];
      final quantity = holding['total_quantity'] ?? 0;
      final avgPrice = double.tryParse(holding['average_price'].toString()) ?? 0.0;
      final value = quantity * avgPrice;
      
      // Calculate the percentage of the portfolio this stock takes up
      final percentage = (value / totalValue) * 100;

      return PieChartSectionData(
        color: colors[i % colors.length], // Cycle through the colors
        value: percentage,
        title: '${percentage.toStringAsFixed(1)}%',
        radius: 50,
        titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white, shadows: [Shadow(color: Colors.black, blurRadius: 2)]),
      );
    });
  }

  // --- HELPER 2: Draws the Color Legend ---
  List<Widget> _buildPieChartLegend(List<Map<String, dynamic>> validHoldings) {
    final colors = [Colors.blueAccent, Colors.greenAccent, Colors.orangeAccent, Colors.purpleAccent, Colors.redAccent, Colors.cyanAccent];
    
    return List.generate(validHoldings.length, (i) {
      final symbol = validHoldings[i]['symbol'] ?? 'Unknown';
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4.0),
        child: Row(
          children: [
            Container(
              width: 12, height: 12, 
              decoration: BoxDecoration(color: colors[i % colors.length], shape: BoxShape.circle)
            ),
            const SizedBox(width: 8),
            // Truncate long names so they don't break the UI
            Expanded(child: Text(symbol, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis)),
          ],
        ),
      );
    });
  }

  void _showLogoutConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1D1E33),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text("Logout", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: const Text("Are you sure you want to log out of your account?", style: TextStyle(color: Colors.grey)),
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
            child: const Text("Logout", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
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
      (route) => false, // This prevents them from hitting the Android 'Back' button to return to the dashboard
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
        body: Center(child: Text("Failed to load profile", style: TextStyle(color: Colors.white))),
      );
    }

    final isMentor = _userProfile!['role'] == 'MENTOR';

    return Scaffold(
      backgroundColor: const Color(0xFF0A0E21),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => TradeScreen(userGoals: _goals), // Pass the goals!
            ),
          ).then((_) => _loadDashboardData()); // Refresh dashboard balance/holdings when they come back!
        },
        backgroundColor: Colors.blueAccent,
        icon: const Icon(Icons.show_chart, color: Colors.white),
        label: const Text("TRADE", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      appBar: AppBar(
        title: const Text("Dashboard", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          TextButton(
            onPressed: _showLogoutConfirmation,
            child: const Text(
              "Logout", 
              style: TextStyle(color: Colors.redAccent, fontSize: 16, fontWeight: FontWeight.bold),
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
              _buildHeader(),
              const SizedBox(height: 30),
              
              const Text("Analytics", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
              const SizedBox(height: 16),
              _buildAnalyticsSection(),
              
              const SizedBox(height: 30),

              // Placeholder for the Portfolio (Trades & Holdings) we will build next
              _buildPortfolioPlaceholder(),
              const SizedBox(height: 30),

              if (isMentor) _buildMentorSection() else _buildStudentSection(),
            ],
          ),
        ),
      ),
    );
  }

  // --- 1. THE NEW HEADER ---
  Widget _buildHeader() {
    // Providing default fallback values just in case the backend hasn't populated them yet
    final balance = _userProfile!['wallet_balance'] ?? "0.00";
    final riskProfile = _userProfile!['risk_profile'] ?? "Moderate";

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Welcome back,",
                  style: TextStyle(fontSize: 16, color: Colors.grey[400]),
                ),
                const SizedBox(height: 4),
                Text(
                  _userProfile!['username'],
                  style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ],
            ),
            // Risk Profile Badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.blue[300]!),
              ),
              child: Text(
                riskProfile,
                style: TextStyle(color: Colors.blue[300], fontWeight: FontWeight.bold, fontSize: 12),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        
        // Wallet Balance Card
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.green[600]!, Colors.teal[600]!],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(color: Colors.green.withOpacity(0.2), blurRadius: 15, spreadRadius: 2),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Total Balance", style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 16)),
              const SizedBox(height: 8),
              Text(
                "₹$balance", // Add your local currency symbol here if needed!
                style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.bold, letterSpacing: 1.5),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // --- 2. THE NEW ANALYTICS SECTION ---
  Widget _buildAnalyticsSection() {
    final disciplineScore = (_userProfile!['discipline_score'] ?? 0);

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch, 
        children: [
          // --- Discipline Score Card ---
          Expanded(
            flex: 2,
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF1D1E33),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text("Discipline", style: TextStyle(color: Colors.grey, fontSize: 14)),
                  const SizedBox(height: 12),
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        height: 70,
                        width: 70,
                        child: CircularProgressIndicator(
                          value: disciplineScore / 100,
                          strokeWidth: 8,
                          backgroundColor: Colors.grey[800],
                          color: _getScoreColor(disciplineScore),
                          strokeCap: StrokeCap.round,
                        ),
                      ),
                      Text(
                        "$disciplineScore",
                        style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 16),
          
          // --- Goals Summary Card (UPDATED) ---
          // --- Goals Summary Card (WITH PROGRESS BAR) ---
          Expanded(
            flex: 3,
            child: InkWell(
              onTap: _showGoalsBottomSheet,
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF1D1E33),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.blue.withOpacity(0.2)),
                ),
                child: Builder(
                  builder: (context) {
                    // 1. Handle the Empty State (No Goals)
                    if (_goals.isEmpty) {
                      return const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text("Active Goal", style: TextStyle(color: Colors.grey, fontSize: 14)),
                          SizedBox(height: 8),
                          Text("0", style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
                          SizedBox(height: 4),
                          Text("Tap to set goals", style: TextStyle(color: Colors.blue, fontSize: 12)),
                        ],
                      );
                    }

                    // 2. Parse the Math for the Active Goal
                    final firstGoal = _goals.first;
                    final currentAmt = double.tryParse(firstGoal['current_amount']?.toString() ?? '0') ?? 0.0;
                    final targetAmt = double.tryParse(firstGoal['target_amount']?.toString() ?? '1') ?? 1.0;
                    
                    // Prevent division by zero and cap the bar at 1.0 (100%)
                    final safeTarget = targetAmt > 0 ? targetAmt : 1.0;
                    final progress = (currentAmt / safeTarget).clamp(0.0, 1.0);

                    // 3. Draw the Progress UI
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text("Active Goal", style: TextStyle(color: Colors.grey, fontSize: 12)),
                            // Show the percentage text
                            Text(
                              "${(progress * 100).toStringAsFixed(0)}%", 
                              style: TextStyle(
                                color: progress >= 1.0 ? Colors.greenAccent : Colors.blueAccent, 
                                fontSize: 12, 
                                fontWeight: FontWeight.bold
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          firstGoal['name'] ?? 'Goal',
                          style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 12),
                        
                        // --- THE PROGRESS BAR ---
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: progress,
                            backgroundColor: Colors.grey[800],
                            // Turn the bar green when they hit 100%!
                            valueColor: AlwaysStoppedAnimation<Color>(
                              progress >= 1.0 ? Colors.greenAccent : Colors.blueAccent
                            ),
                            minHeight: 8,
                          ),
                        ),
                        const SizedBox(height: 8),
                        
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text("₹${currentAmt.toStringAsFixed(0)}", style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                            Text("of ₹${targetAmt.toStringAsFixed(0)}", style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                          ],
                        ),
                      ],
                    );
                  }
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Helper function to color the discipline score dynamically
  Color _getScoreColor(double score) {
    if (score >= 80) return Colors.greenAccent;
    if (score >= 50) return Colors.orangeAccent;
    return Colors.redAccent;
  }

  // --- 3A. THE MENTOR SECTION ---
  Widget _buildMentorSection() {
    // Separate links into pending requests and active students
    final pendingRequests = _mentorLinks.where((link) => link['status'] == 'PENDING').toList();
    final activeStudents = _mentorLinks.where((link) => link['status'] == 'ACCEPTED').toList();

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
                  Text("Mentor ID", style: TextStyle(color: Colors.grey[400], fontSize: 14)),
                  const SizedBox(height: 4),
                  Text(
                    "${_userProfile!['id'] + 130200}", // Your custom math logic!
                    style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 2),
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
          Text("Pending Requests (${pendingRequests.length})", style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
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
                          Text(req['student_name'] ?? "Investor", style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                          Text("Wants to connect", style: TextStyle(color: Colors.grey[400], fontSize: 12)),
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
                      icon: const Icon(Icons.check_circle, color: Colors.greenAccent, size: 28),
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
            final pendingTrades = _trades.where((t) => t['status'] == 'PENDING_MENTOR').toList();
            
            if (pendingTrades.isEmpty) return const SizedBox.shrink();
            
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Action Required: Risky Trades (${pendingTrades.length})", style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
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
                        border: Border.all(color: Colors.redAccent.withOpacity(0.4), width: 1.5), // Red border for high risk!
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Icon(isBuy ? Icons.arrow_downward : Icons.arrow_upward, color: isBuy ? Colors.greenAccent : Colors.orangeAccent),
                                  const SizedBox(width: 8),
                                  Text(
                                    "${trade['transaction_type']} ${trade['symbol']}", 
                                    style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                              Text("₹${trade['total_amount']}", style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(8)),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text("Student's Justification:", style: TextStyle(color: Colors.grey[400], fontSize: 12)),
                                const SizedBox(height: 4),
                                Text(
                                  trade['justification'] ?? "No justification provided.", 
                                  style: const TextStyle(color: Colors.white, fontStyle: FontStyle.italic),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              OutlinedButton(
                                onPressed: () => _handleTradeAction(trade['id'], 'reject'),
                                style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.redAccent)),
                                child: const Text("Reject", style: TextStyle(color: Colors.redAccent)),
                              ),
                              const SizedBox(width: 12),
                              ElevatedButton(
                                onPressed: () => _handleTradeAction(trade['id'], 'approve'),
                                style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                                child: const Text("Approve Trade", style: TextStyle(color: Colors.white)),
                              ),
                            ],
                          )
                        ],
                      ),
                    );
                  },
                ),
                const SizedBox(height: 20),
              ],
            );
          }
        ),

        // 3. Active Students List
        Text("My Investors (${activeStudents.length})", style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
        const SizedBox(height: 16),
        
        if (activeStudents.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(30.0),
              child: Text("You don't have any connected investors yet.", style: TextStyle(color: Colors.grey[500])),
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
                  final int targetId = student['student_id'] ?? student['student'];
                  
                  Navigator.push(
                    context, 
                    MaterialPageRoute(
                      builder: (context) => StudentPortfolioScreen(
                        studentId: targetId,
                        studentName: student['student_name'] ?? "Investor",
                      )
                    )
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
                          style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
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

  // --- 3B. THE STUDENT SECTION ---
  Widget _buildStudentSection() {
    // Check if they have an active or pending mentor link
    final activeOrPending = _mentorLinks.where((link) => link['status'] == 'PENDING' || link['status'] == 'ACCEPTED').toList();
    
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
                  style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.push(context, MaterialPageRoute(builder: (context) => const FindMentorScreen()))
                          .then((_) => _loadDashboardData()); // Refresh when coming back
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue[600],
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: const Text("FIND A MENTOR", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                  ),
                ),
              ],
            ),
          ),
        ] else ...[
          // Show their current status if they have a link
          const Text("Mentorship Status", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF1D1E33),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: activeOrPending[0]['status'] == 'ACCEPTED' ? Colors.green.withOpacity(0.3) : Colors.orange.withOpacity(0.3),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: activeOrPending[0]['status'] == 'ACCEPTED' ? Colors.green.withOpacity(0.1) : Colors.orange.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    activeOrPending[0]['status'] == 'ACCEPTED' ? Icons.handshake : Icons.hourglass_top,
                    color: activeOrPending[0]['status'] == 'ACCEPTED' ? Colors.greenAccent : Colors.orangeAccent,
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
                        style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        activeOrPending[0]['status'] == 'ACCEPTED' ? "Connected & Active" : "Request Pending",
                        style: TextStyle(
                          color: activeOrPending[0]['status'] == 'ACCEPTED' ? Colors.green[300] : Colors.orange[300], 
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
        ]
      ],
    );
  }

  Widget _buildPortfolioPlaceholder() {
    // 1. Filter out empty holdings and calculate the total book value
    double totalPortfolioValue = 0;
    List<Map<String, dynamic>> validHoldings = [];

    for (var holding in _holdings) {
      final quantity = holding['total_quantity'] ?? 0;
      if (quantity > 0) { // Only count stocks they actually own!
        final avgPrice = double.tryParse(holding['average_price'].toString()) ?? 0.0;
        totalPortfolioValue += (quantity * avgPrice);
        // Cast it safely to pass into our helper functions
        validHoldings.add(Map<String, dynamic>.from(holding)); 
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "My Portfolio", 
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
        ),
        const SizedBox(height: 16),
        
        if (validHoldings.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF1D1E33),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey[800]!),
            ),
            child: const Center(
              child: Text("No assets yet. Hit 'TRADE' to start investing!", style: TextStyle(color: Colors.grey)),
            ),
          )
        else ...[
          // --- INJECT THE NEW PIE CHART HERE ---
          Container(
            height: 200,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1D1E33),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.blue.withOpacity(0.1)),
            ),
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: PieChart(
                    PieChartData(
                      sectionsSpace: 2,
                      centerSpaceRadius: 40, // Creates the "donut" hole in the middle
                      sections: _buildPieChartSections(validHoldings, totalPortfolioValue),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 1,
                  child: SingleChildScrollView( // Scrollable in case they own a LOT of different stocks!
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: _buildPieChartLegend(validHoldings),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // --- KEEP THE EXISTING DETAILED LIST BELOW IT ---
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: validHoldings.length,
            itemBuilder: (context, index) {
              final holding = validHoldings[index];
              final quantity = holding['total_quantity'];
              final avgPrice = double.tryParse(holding['average_price'].toString()) ?? 0.0;
              final totalValue = quantity * avgPrice;

              final symbol = holding['symbol'] ?? 'Unknown';
              final bookValue = quantity * avgPrice;
              
              // --- NEW P&L MATH ---
              final livePrice = _livePrices[symbol];
              final isPriceLoaded = livePrice != null;
              
              double currentValue = bookValue;
              double pnlAmount = 0.0;
              double pnlPercentage = 0.0;
              
              if (isPriceLoaded) {
                currentValue = quantity * livePrice!;
                pnlAmount = currentValue - bookValue;
                pnlPercentage = (pnlAmount / bookValue) * 100;
              }

              // Determine the color based on profit or loss
              final isProfit = pnlAmount >= 0;
              final pnlColor = isProfit ? Colors.greenAccent : Colors.redAccent;
              final pnlSign = isProfit ? "+" : "-";

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF1D1E33),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.blue.withOpacity(0.1)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.business, color: Colors.blueAccent),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      flex: 2,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(symbol, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          // Show Live Price next to Avg Price
                          Text(
                            "$quantity Shares", 
                            style: TextStyle(color: Colors.grey[400], fontSize: 14)
                          ),
                          const SizedBox(height: 2),
                          Text(
                            "Avg: ₹${avgPrice.toStringAsFixed(2)}", 
                            style: TextStyle(color: Colors.grey[500], fontSize: 12)
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          if (!isPriceLoaded)
                            const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                          else ...[
                            Text(
                              "₹${currentValue.toStringAsFixed(2)}", 
                              style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 4),
                            // The beautiful Profit/Loss indicator!
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: pnlColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                "$pnlSign₹${pnlAmount.abs().toStringAsFixed(2)} ($pnlSign${pnlPercentage.abs().toStringAsFixed(2)}%)", 
                                style: TextStyle(color: pnlColor, fontSize: 12, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ]
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ]
      ],
    );
  }

}