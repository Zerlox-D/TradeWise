import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../api_service.dart';

class PortfolioScreen extends StatefulWidget {
  const PortfolioScreen({super.key});

  @override
  State<PortfolioScreen> createState() => _PortfolioScreenState();
}

class _PortfolioScreenState extends State<PortfolioScreen> {
  List<dynamic> _holdings = [];
  List<dynamic> _trades = [];
  final Map<String, double> _livePrices = {};
  bool _isLoading = true;

  String _formatDate(String? isoString) {
    if (isoString == null) return "Unknown Date";
    try {
      final date = DateTime.parse(isoString).toLocal();
      return "${date.day}/${date.month}/${date.year} • ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}";
    } catch (e) {
      return "Date error";
    }
  }

  static Color _getSymbolColor(String symbol) {
    final colors = [
      const Color(0xFF42A5F5),
      const Color(0xFF00E676),
      const Color(0xFFFFB74D),
      const Color(0xFFAB47BC),
      const Color(0xFFFF5252),
      const Color(0xFF26C6DA),
    ];
    int hash = 0;
    for (final char in symbol.codeUnits) {
      hash = (hash * 31 + char) & 0xFFFFFF;
    }
    return colors[hash % colors.length];
  }

  List<PieChartSectionData> _buildPieChartSections(
    List<Map<String, dynamic>> validHoldings,
    double totalValue,
  ) {
    final colors = [
      const Color(0xFF42A5F5),
      const Color(0xFF00E676),
      const Color(0xFFFFB74D),
      const Color(0xFFAB47BC),
      const Color(0xFFFF5252),
      const Color(0xFF26C6DA),
    ];

    return List.generate(validHoldings.length, (i) {
      final holding = validHoldings[i];
      final quantity = holding['total_quantity'] ?? 0;
      final avgPrice =
          double.tryParse(holding['average_price'].toString()) ?? 0.0;
      final value = quantity * avgPrice;
      final percentage = totalValue > 0 ? (value / totalValue) * 100 : 0.0;

      return PieChartSectionData(
        color: colors[i % colors.length],
        value: percentage,
        title: '${percentage.toStringAsFixed(1)}%',
        radius: 50,
        titleStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.white,
          shadows: [Shadow(color: Colors.black, blurRadius: 2)],
        ),
      );
    });
  }

  List<Widget> _buildPieChartLegend(List<Map<String, dynamic>> validHoldings) {
    final colors = [
      const Color(0xFF42A5F5),
      const Color(0xFF00E676),
      const Color(0xFFFFB74D),
      const Color(0xFFAB47BC),
      const Color(0xFFFF5252),
      const Color(0xFF26C6DA),
    ];

    return List.generate(validHoldings.length, (i) {
      final symbol = validHoldings[i]['symbol'] ?? 'Unknown';
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4.0),
        child: Row(
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: colors[i % colors.length],
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                symbol,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      );
    });
  }

  Widget _buildPortfolioContent() {
    double totalPortfolioValue = 0;
    final List<Map<String, dynamic>> validHoldings = [];

    for (var holding in _holdings) {
      final quantity = holding['total_quantity'] ?? 0;
      if (quantity > 0) {
        final avgPrice =
            double.tryParse(holding['average_price'].toString()) ?? 0.0;
        totalPortfolioValue += (quantity * avgPrice);
        validHoldings.add(Map<String, dynamic>.from(holding));
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // --- HOLDINGS SECTION HEADER ---
        Row(
          children: [
            Container(
              width: 3,
              height: 18,
              decoration: BoxDecoration(
                color: const Color(0xFF00E676),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 10),
            const Text(
              'Current Holdings',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF00E676).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '${validHoldings.length} Assets',
                style: const TextStyle(
                  color: Color(0xFF00E676),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        if (validHoldings.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: const Color(0xFF151A30),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFF1E2440)),
            ),
            child: const Center(
              child: Text(
                "No assets yet.",
                style: TextStyle(color: Colors.grey),
              ),
            ),
          )
        else ...[
          // Pie chart card
          Container(
            height: 200,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF0D2137), Color(0xFF0A1628)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF1E2440)),
            ),
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: PieChart(
                    PieChartData(
                      sectionsSpace: 2,
                      centerSpaceRadius: 40,
                      sections: _buildPieChartSections(
                        validHoldings,
                        totalPortfolioValue,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 1,
                  child: SingleChildScrollView(
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
          const SizedBox(height: 16),

          // Holdings list
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: validHoldings.length,
            itemBuilder: (context, index) {
              final holding = validHoldings[index];
              final quantity = holding['total_quantity'];
              final avgPrice =
                  double.tryParse(holding['average_price'].toString()) ?? 0.0;

              final symbol = holding['symbol'] ?? 'Unknown';
              final bookValue = quantity * avgPrice;
              final symbolColor = _getSymbolColor(symbol);

              final livePrice = _livePrices[symbol];
              final isPriceLoaded = livePrice != null;

              double currentValue = bookValue;
              double pnlAmount = 0.0;
              double pnlPercentage = 0.0;

              if (isPriceLoaded) {
                currentValue = quantity * livePrice;
                pnlAmount = currentValue - bookValue;
                pnlPercentage = bookValue > 0
                    ? (pnlAmount / bookValue) * 100
                    : 0.0;
              }

              final isProfit = pnlAmount >= 0;
              final pnlColor = isProfit
                  ? const Color(0xFF00E676)
                  : const Color(0xFFFF5252);
              final pnlSign = isProfit ? "+" : "-";

              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF151A30),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFF1E2440)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            symbolColor.withValues(alpha: 0.2),
                            symbolColor.withValues(alpha: 0.05),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: Text(
                          symbol.isNotEmpty ? symbol.substring(0, 1) : '?',
                          style: TextStyle(
                            color: symbolColor,
                            fontWeight: FontWeight.w700,
                            fontSize: 17,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      flex: 2,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            symbol,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            "$quantity Shares",
                            style: TextStyle(
                              color: Colors.grey[400],
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            "Avg: ₹${avgPrice.toStringAsFixed(2)}",
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 12,
                            ),
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
                            const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Color(0xFF00E676),
                              ),
                            )
                          else ...[
                            Text(
                              "₹${currentValue.toStringAsFixed(2)}",
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: pnlColor.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                "$pnlSign₹${pnlAmount.abs().toStringAsFixed(2)} ($pnlSign${pnlPercentage.abs().toStringAsFixed(2)}%)",
                                style: TextStyle(
                                  color: pnlColor,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],

        const SizedBox(height: 28),

        // --- TRADE HISTORY SECTION HEADER ---
        Row(
          children: [
            Container(
              width: 3,
              height: 18,
              decoration: BoxDecoration(
                color: const Color(0xFF00E676),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 10),
            const Text(
              'Trade History',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        if (_trades.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: const Color(0xFF151A30),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFF1E2440)),
            ),
            child: const Center(
              child: Text(
                "No trades executed yet.",
                style: TextStyle(color: Colors.grey),
              ),
            ),
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _trades.length,
            itemBuilder: (context, index) {
              final trade = _trades[index];
              final isBuy = trade['transaction_type'] == 'BUY';
              final status = trade['status'] ?? 'UNKNOWN';
              final symbol = (trade['symbol'] ?? 'X') as String;
              final symbolColor = _getSymbolColor(symbol);

              Color statusColor = Colors.grey;
              if (status == 'EXECUTED') {
                statusColor = const Color(0xFF00E676);
              } else if (status == 'PENDING_MENTOR' ||
                  status == 'PENDING_EXECUTION') {
                statusColor = const Color(0xFFFFB74D);
              } else if (status == 'REJECTED' || status == 'FAILED') {
                statusColor = const Color(0xFFFF5252);
              }

              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF151A30),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: status == 'REJECTED'
                        ? const Color(0xFFFF5252).withValues(alpha: 0.3)
                        : const Color(0xFF1E2440),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                symbolColor.withValues(alpha: 0.2),
                                symbolColor.withValues(alpha: 0.05),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Center(
                            child: Text(
                              symbol.isNotEmpty ? symbol.substring(0, 1) : '?',
                              style: TextStyle(
                                color: symbolColor,
                                fontWeight: FontWeight.w700,
                                fontSize: 17,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    isBuy
                                        ? Icons.arrow_downward
                                        : Icons.arrow_upward,
                                    color: isBuy
                                        ? const Color(0xFF00E676)
                                        : const Color(0xFFFFB74D),
                                    size: 14,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    "${trade['transaction_type']} $symbol",
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 3),
                              Text(
                                _formatDate(trade['created_at']),
                                style: TextStyle(
                                  color: Colors.grey[500],
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              "₹${trade['total_amount']}",
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: statusColor.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                status.replaceAll('_', ' '),
                                style: TextStyle(
                                  color: statusColor,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    if (trade['mentor_comment'] != null &&
                        trade['mentor_comment'].toString().isNotEmpty &&
                        trade['mentor_comment'] != "Reviewed by Mentor.") ...[
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8.0),
                        child: Divider(color: Color(0xFF1E2440)),
                      ),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.format_quote_rounded,
                            color: Colors.grey[500],
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              "Mentor: ${trade['mentor_comment']}",
                              style: TextStyle(
                                color: Colors.grey[400],
                                fontSize: 13,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              );
            },
          ),
      ],
    );
  }

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
      debugPrint("Portfolio Fetch Error: $e");
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
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF00E676)),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0A0E21),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // TRADEWISE header row with back button
                  Row(
                    children: [
                      const Icon(
                        Icons.bolt_rounded,
                        color: Color(0xFF00E676),
                        size: 18,
                      ),
                      const SizedBox(width: 6),
                      const Text(
                        'TRADEWISE',
                        style: TextStyle(
                          color: Color(0xFF00E676),
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'My Portfolio',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Holdings & trade overview',
                    style: TextStyle(color: Colors.grey[600], fontSize: 13),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _loadPortfolioData,
                color: const Color(0xFF00E676),
                backgroundColor: const Color(0xFF151A30),
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
                  child: _buildPortfolioContent(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
