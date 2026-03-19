import 'package:flutter/material.dart';
import 'package:flutter_feather_icons/flutter_feather_icons.dart';
import 'package:fl_chart/fl_chart.dart';
import '../api_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Map<String, dynamic>? _marketData;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchMarketData();
  }

  Future<void> _fetchMarketData() async {
    try {
      final data = await ApiService.getMarketOverview();
      if (mounted) {
        setState(() {
          _marketData = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      print("Error loading home screen data: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFF0A0E21),
        body: Center(
          child: CircularProgressIndicator(color: Colors.greenAccent),
        ),
      );
    }

    if (_marketData == null || _marketData!['assets'] == null) {
      return const Scaffold(
        backgroundColor: Color(0xFF0A0E21),
        body: Center(
          child: Text(
            "Failed to load market data.",
            style: TextStyle(color: Colors.white),
          ),
        ),
      );
    }

    final topGainer = _marketData!['top_gainer'];
    final topLoser = _marketData!['top_loser'];
    final List<dynamic> allAssets = _marketData!['assets'];

    List<dynamic> displayList = [];
    if (allAssets.length <= 10) {
      displayList = allAssets;
    } else {
      final top5 = allAssets.take(5).toList(); // Biggest 5 gainers
      final bottom5 = allAssets
          .skip(allAssets.length - 5)
          .toList(); // Biggest 5 losers
      displayList = [...top5, ...bottom5];
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0A0E21),
      // Use SafeArea since we don't have a standard AppBar on this screen
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- HEADER ---
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.bolt_rounded,
                                color: Color(0xFF00E676),
                                size: 18,
                              ),
                              const SizedBox(width: 6),
                              const Text(
                                "TRADEWISE",
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
                            "Market Movers",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 26,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "Track intraday gainers & losers",
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // --- TOP CARDS (THE SPARKLINES) ---
                  Row(
                    children: [
                      Expanded(
                        child: _buildSparklineCard(topGainer, isGainer: true),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildSparklineCard(topLoser, isGainer: false),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),

                  // --- MARKET OVERVIEW HEADER (FIXED) ---
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
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
                            "Market Overview",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF00E676).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          "${displayList.length} Assets",
                          style: const TextStyle(
                            color: Color(0xFF00E676),
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                ],
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _fetchMarketData,
                color: Colors.greenAccent,
                backgroundColor: const Color(0xFF1D1E33),
                child: ListView.builder(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 30),
                  itemCount: displayList.length,
                  itemBuilder: (context, index) {
                    final asset = displayList[index];
                    final isPositive = asset['is_positive'];
                    final pnlColor = isPositive
                        ? Colors.greenAccent
                        : Colors.redAccent;

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
                          color: const Color(0xFF1E2440),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          // Custom Icon background based on symbol letter
                          Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  _getSymbolColor(
                                    asset['symbol'],
                                  ).withOpacity(0.2),
                                  _getSymbolColor(
                                    asset['symbol'],
                                  ).withOpacity(0.05),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Center(
                              child: Text(
                                asset['symbol'].substring(0, 1),
                                style: TextStyle(
                                  color: _getSymbolColor(asset['symbol']),
                                  fontWeight: FontWeight.w700,
                                  fontSize: 17,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),

                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  asset['name'],
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  asset['symbol'],
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 11,
                                    fontWeight: FontWeight.w400,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                "₹${asset['current_price']}",
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: pnlColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      isPositive
                                          ? Icons.arrow_upward_rounded
                                          : Icons.arrow_downward_rounded,
                                      color: pnlColor,
                                      size: 12,
                                    ),
                                    const SizedBox(width: 2),
                                    Text(
                                      "${asset['pct_change']}%",
                                      style: TextStyle(
                                        color: pnlColor,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- THE MAGIC CHART WIDGET ---
  Widget _buildSparklineCard(
    Map<String, dynamic> assetData, {
    required bool isGainer,
  }) {
    final color = isGainer ? Colors.greenAccent : Colors.redAccent;
    final sparklineRaw = assetData['sparkline'] as List<dynamic>;

    // Convert raw JSON numbers into FlSpots
    List<FlSpot> spots = [];
    for (int i = 0; i < sparklineRaw.length; i++) {
      spots.add(FlSpot(i.toDouble(), (sparklineRaw[i] as num).toDouble()));
    }

    final double minPrice = (assetData['min_price'] as num).toDouble();
    final double maxPrice = (assetData['max_price'] as num).toDouble();

    return Container(
      height: 180,
      decoration: BoxDecoration(
        color: const Color(0xFF151A30),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withOpacity(0.15), width: 1),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.06),
            blurRadius: 12,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Stack(
        children: [
          // The Chart Background Layer
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Align(
              alignment: Alignment.bottomCenter,
              child: SizedBox(
                height: 100, // Restrict chart to the bottom half of the card
                child: LineChart(
                  LineChartData(
                    minX: 0,
                    maxX: (sparklineRaw.length - 1).toDouble(),
                    minY: minPrice,
                    maxY:
                        maxPrice +
                        (maxPrice - minPrice) *
                            0.2, // Add buffer so line doesn't hit the text
                    gridData: FlGridData(show: false),
                    borderData: FlBorderData(show: false),
                    titlesData: FlTitlesData(show: false), // Hide all axes!
                    lineTouchData: LineTouchData(
                      enabled: true,
                      touchTooltipData: LineTouchTooltipData(
                        getTooltipColor: (touchedSpot) =>
                            const Color(0xFF1A1F36),
                        getTooltipItems: (touchedSpots) {
                          return touchedSpots.map((spot) {
                            return LineTooltipItem(
                              "₹${spot.y.toStringAsFixed(2)}",
                              TextStyle(
                                color: color,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            );
                          }).toList();
                        },
                      ),
                    ),
                    lineBarsData: [
                      LineChartBarData(
                        spots: spots,
                        isCurved: true,
                        color: color,
                        barWidth: 2,
                        isStrokeCapRound: true,
                        dotData: FlDotData(show: false),
                        belowBarData: BarAreaData(
                          show: true,
                          gradient: LinearGradient(
                            colors: [
                              color.withOpacity(0.4),
                              color.withOpacity(0.0),
                            ],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // The Text Foreground Layer
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const SizedBox(height: 4),
                    Expanded(
                      child: Text(
                        assetData['symbol'],
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Icon(
                      isGainer
                          ? Icons.trending_up_rounded
                          : Icons.trending_down_rounded,
                      color: color,
                      size: 18,
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      "₹${assetData['current_price']}",
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isGainer
                              ? Icons.arrow_drop_up
                              : Icons.arrow_drop_down,
                          color: color,
                          size: 20,
                        ),
                        Text(
                          "${assetData['pct_change']}%",
                          style: TextStyle(
                            color: color,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _getSymbolColor(String symbol) {
    const colors = [
      Color(0xFF5C6BC0),
      Color(0xFF26A69A),
      Color(0xFFEF5350),
      Color(0xFFAB47BC),
      Color(0xFF42A5F5),
      Color(0xFFFFA726),
      Color(0xFF66BB6A),
      Color(0xFFEC407A),
    ];
    return colors[symbol.codeUnitAt(0) % colors.length];
  }
}
