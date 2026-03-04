import 'package:flutter/material.dart';
import '../api_service.dart';

class StudentPortfolioScreen extends StatefulWidget {
  final int studentId;
  final String studentName;

  const StudentPortfolioScreen({super.key, required this.studentId, required this.studentName});

  @override
  State<StudentPortfolioScreen> createState() => _StudentPortfolioScreenState();
}

class _StudentPortfolioScreenState extends State<StudentPortfolioScreen> {
  Map<String, dynamic>? _portfolioData;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() async {
    final data = await ApiService.getStudentPortfolio(widget.studentId);
    if (mounted) {
      setState(() {
        _portfolioData = data;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(backgroundColor: const Color(0xFF0A0E21), appBar: AppBar(backgroundColor: Colors.transparent), body: const Center(child: CircularProgressIndicator(color: Colors.blueAccent)));
    }

    if (_portfolioData == null) {
      return Scaffold(backgroundColor: const Color(0xFF0A0E21), appBar: AppBar(backgroundColor: Colors.transparent), body: const Center(child: Text("Failed to load portfolio.", style: TextStyle(color: Colors.white))));
    }

    final holdings = _portfolioData!['holdings'] as List<dynamic>;

    return Scaffold(
      backgroundColor: const Color(0xFF0A0E21),
      appBar: AppBar(
        title: Text("${widget.studentName}'s Portfolio", style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- 1. STUDENT STATS CARD ---
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [Colors.blueGrey[800]!, Colors.blueGrey[900]!]),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.blueGrey[700]!),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("Wallet Balance", style: TextStyle(color: Colors.grey, fontSize: 14)),
                      const SizedBox(height: 4),
                      Text("₹${_portfolioData!['wallet_balance']}", style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Icon(Icons.shield, color: Colors.blue[300], size: 16),
                          const SizedBox(width: 4),
                          Text(_portfolioData!['risk_profile'], style: TextStyle(color: Colors.blue[300], fontWeight: FontWeight.bold)),
                        ],
                      )
                    ],
                  ),
                  Column(
                    children: [
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          SizedBox(
                            height: 60, width: 60,
                            child: CircularProgressIndicator(
                              value: (_portfolioData!['discipline_score'] ?? 0) / 100,
                              strokeWidth: 6,
                              backgroundColor: Colors.grey[800],
                              color: (_portfolioData!['discipline_score'] ?? 0) >= 80 ? Colors.greenAccent : Colors.orangeAccent,
                            ),
                          ),
                          Text("${_portfolioData!['discipline_score']}", style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Text("Discipline", style: TextStyle(color: Colors.grey, fontSize: 12)),
                    ],
                  )
                ],
              ),
            ),
            const SizedBox(height: 30),

            // --- 2. HOLDINGS LIST ---
            const Text("Current Holdings", style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            
            if (holdings.isEmpty)
              const Center(child: Padding(padding: EdgeInsets.all(30), child: Text("This student hasn't bought any assets yet.", style: TextStyle(color: Colors.grey))))
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: holdings.length,
                itemBuilder: (context, index) {
                  final holding = holdings[index];
                  final qty = holding['total_quantity'];
                  final avgPrice = double.tryParse(holding['average_price'].toString()) ?? 0.0;
                  final bookValue = qty * avgPrice;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: const Color(0xFF1D1E33), borderRadius: BorderRadius.circular(16)),
                    child: Row(
                      children: [
                        const Icon(Icons.business, color: Colors.blueAccent),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(holding['symbol'], style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                              Text("$qty Shares @ ₹${avgPrice.toStringAsFixed(2)}", style: const TextStyle(color: Colors.grey, fontSize: 14)),
                            ],
                          ),
                        ),
                        Text("₹${bookValue.toStringAsFixed(2)}", style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}