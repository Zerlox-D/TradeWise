import 'package:flutter/material.dart';
import '../api_service.dart';
import '../widgets/dashboard_portfolio.dart';

class PortfolioScreen extends StatefulWidget {
  const PortfolioScreen({super.key});

  @override
  State<PortfolioScreen> createState() => _PortfolioScreenState();
}

class _PortfolioScreenState extends State<PortfolioScreen> {
  List<dynamic> _holdings = [];
  List<dynamic> _trades = [];
  Map<String, double> _livePrices = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPortfolioData();
  }

  Future<void> _loadPortfolioData() async {
    setState(() => _isLoading = true);
    try {
      final holdings = await ApiService.getHoldings();
      final trades = await ApiService.getTrades();

      if (mounted) {
        setState(() {
          _holdings = holdings;
          _trades = trades;
          _isLoading = false;
        });
      }
      
      // Fetch live prices after the basic data is loaded
      _fetchLivePricesForHoldings();
    } catch (e) {
      print("Portfolio Fetch Error: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchLivePricesForHoldings() async {
    for (var holding in _holdings) {
      final symbol = holding['symbol'];
      final quantity = holding['total_quantity'] ?? 0;

      if (symbol != null && quantity > 0) {
        final price = await ApiService.getLivePrice(symbol);
        if (price != null && mounted) {
          setState(() {
            _livePrices[symbol] = price;
          });
        }
      }
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
        title: const Text(
          "My Portfolio",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: RefreshIndicator(
        onRefresh: _loadPortfolioData,
        color: Colors.blueAccent,
        backgroundColor: const Color(0xFF1D1E33),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(24.0),
          child: DashboardPortfolio.buildPortfolioPlaceholder(
            _holdings,
            _livePrices,
            _trades,
          ),
        ),
      ),
    );
  }
}