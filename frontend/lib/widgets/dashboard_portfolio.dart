import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

class DashboardPortfolio {

  static String _formatDate(String? isoString) {
    if (isoString == null) return "Unknown Date";
    try {
      final date = DateTime.parse(isoString).toLocal();
      // Returns format like "12/10/2025 • 14:30"
      return "${date.day}/${date.month}/${date.year} • ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}";
    } catch (e) {
      return "Date error";
    }
  }

  static Widget buildPortfolioPlaceholder(
    List<dynamic> holdings,
    Map<String, double> livePrices,
    List<dynamic> trades,
  ) {
    // 1. Filter out empty holdings and calculate the total book value
    double totalPortfolioValue = 0;
    List<Map<String, dynamic>> validHoldings = [];

    for (var holding in holdings) {
      final quantity = holding['total_quantity'] ?? 0;
      if (quantity > 0) {
        // Only count stocks they actually own!
        final avgPrice =
            double.tryParse(holding['average_price'].toString()) ?? 0.0;
        totalPortfolioValue += (quantity * avgPrice);
        // Cast it safely to pass into our helper functions
        validHoldings.add(Map<String, dynamic>.from(holding));
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [

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
              child: Text(
                "No assets yet. Hit 'TRADE' to start investing!",
                style: TextStyle(color: Colors.grey),
              ),
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
                      centerSpaceRadius:
                          40, // Creates the "donut" hole in the middle
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
                    // Scrollable in case they own a LOT of different stocks!
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
              final avgPrice =
                  double.tryParse(holding['average_price'].toString()) ?? 0.0;
              final totalValue = quantity * avgPrice;

              final symbol = holding['symbol'] ?? 'Unknown';
              final bookValue = quantity * avgPrice;

              // --- NEW P&L MATH ---
              final livePrice = livePrices[symbol];
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
                      child: const Icon(
                        Icons.business,
                        color: Colors.blueAccent,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      flex: 2,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            symbol,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          // Show Live Price next to Avg Price
                          Text(
                            "$quantity Shares",
                            style: TextStyle(
                              color: Colors.grey[400],
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            "Avg: ₹${avgPrice.toStringAsFixed(2)}",
                            style: TextStyle(
                              color: Colors.grey[500],
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
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          else ...[
                            Text(
                              "₹${currentValue.toStringAsFixed(2)}",
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            // The beautiful Profit/Loss indicator!
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: pnlColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                "$pnlSign₹${pnlAmount.abs().toStringAsFixed(2)} ($pnlSign${pnlPercentage.abs().toStringAsFixed(2)}%)",
                                style: TextStyle(
                                  color: pnlColor,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
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
          const SizedBox(height: 32),

          const Text(
            "Trade History",
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),

          if (trades.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFF1D1E33),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey[800]!),
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
              // Show newest trades first by reversing the index
              itemCount: trades.length,
              itemBuilder: (context, index) {
                final trade = trades[index];
                final isBuy = trade['transaction_type'] == 'BUY';
                final status = trade['status'] ?? 'UNKNOWN';
                
                // Color code the status
                Color statusColor = Colors.grey;
                if (status == 'EXECUTED') statusColor = Colors.greenAccent;
                if (status == 'PENDING_MENTOR') statusColor = Colors.orangeAccent;
                if (status == 'REJECTED') statusColor = Colors.redAccent;

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1D1E33),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      // Add a subtle red border if it was rejected!
                      color: status == 'REJECTED' ? Colors.red.withOpacity(0.3) : Colors.white.withOpacity(0.05)
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // The main trade info row
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: isBuy 
                                  ? Colors.greenAccent.withOpacity(0.1) 
                                  : Colors.redAccent.withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              isBuy ? Icons.arrow_downward : Icons.arrow_upward,
                              color: isBuy ? Colors.greenAccent : Colors.redAccent,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "${trade['transaction_type']} ${trade['symbol']}",
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _formatDate(trade['created_at']), 
                                  style: TextStyle(color: Colors.grey[500], fontSize: 12),
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
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                status.replaceAll('_', ' '), 
                                style: TextStyle(
                                  color: statusColor,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      
                      // --- NEW: THE MENTOR COMMENT ---
                      if (trade['mentor_comment'] != null && 
                          trade['mentor_comment'].toString().isNotEmpty && 
                          trade['mentor_comment'] != "Reviewed by Mentor.") ...[
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8.0),
                          child: Divider(color: Colors.white12),
                        ),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.format_quote_rounded, color: Colors.grey[500], size: 16),
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
                      ]
                    ],
                  ),
                );
              },
            ),
        ],
      ],
    );
  }

  static List<PieChartSectionData> _buildPieChartSections(
    List<Map<String, dynamic>> validHoldings,
    double totalValue,
  ) {
    // A nice neon palette for our dark theme
    final colors = [
      Colors.blueAccent,
      Colors.greenAccent,
      Colors.orangeAccent,
      Colors.purpleAccent,
      Colors.redAccent,
      Colors.cyanAccent,
    ];

    return List.generate(validHoldings.length, (i) {
      final holding = validHoldings[i];
      final quantity = holding['total_quantity'] ?? 0;
      final avgPrice =
          double.tryParse(holding['average_price'].toString()) ?? 0.0;
      final value = quantity * avgPrice;

      // Calculate the percentage of the portfolio this stock takes up
      final percentage = (value / totalValue) * 100;

      return PieChartSectionData(
        color: colors[i % colors.length], // Cycle through the colors
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

  static List<Widget> _buildPieChartLegend(
    List<Map<String, dynamic>> validHoldings,
  ) {
    final colors = [
      Colors.blueAccent,
      Colors.greenAccent,
      Colors.orangeAccent,
      Colors.purpleAccent,
      Colors.redAccent,
      Colors.cyanAccent,
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
            // Truncate long names so they don't break the UI
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


}