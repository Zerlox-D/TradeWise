import 'package:flutter/material.dart';
import '../api_service.dart';

class StudentPortfolioScreen extends StatefulWidget {
  final int studentId;
  final String studentName;

  const StudentPortfolioScreen({
    super.key,
    required this.studentId,
    required this.studentName,
  });

  @override
  State<StudentPortfolioScreen> createState() => _StudentPortfolioScreenState();
}

class _StudentPortfolioScreenState extends State<StudentPortfolioScreen> {
  Map<String, dynamic>? _portfolioData;
  List<dynamic> _trades = [];
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
        // Filter trades to only this student's trades and take last 5
        _trades = data?['recent_trades'] ?? [];
        _isLoading = false;
      });
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

  static String _formatDate(String? isoString) {
    if (isoString == null) return "Unknown Date";
    try {
      final date = DateTime.parse(isoString).toLocal();
      return "${date.day}/${date.month}/${date.year} • ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}";
    } catch (e) {
      return "Date error";
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

    if (_portfolioData == null) {
      return const Scaffold(
        backgroundColor: Color(0xFF0A0E21),
        body: Center(
          child: Text(
            'Failed to load portfolio.',
            style: TextStyle(color: Colors.white),
          ),
        ),
      );
    }

    final holdings = _portfolioData!['holdings'] as List<dynamic>;
    final riskProfile = _portfolioData!['risk_profile'] as String? ?? '';
    final riskColor = riskProfile == 'Low' || riskProfile == 'Conservative'
        ? const Color(0xFF00E676)
        : riskProfile == 'Moderate'
        ? const Color(0xFFFFB74D)
        : riskProfile == 'High' || riskProfile == 'Aggressive'
        ? const Color(0xFFFF5252)
        : const Color(0xFF42A5F5);

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
                  Row(
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.of(context).pop(),
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: const Color(0xFF151A30),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFF1E2440)),
                          ),
                          child: const Icon(
                            Icons.arrow_back_ios_new_rounded,
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
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
                  Text(
                    "${widget.studentName}'s Portfolio",
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Holdings & wallet overview',
                    style: TextStyle(color: Colors.grey[600], fontSize: 13),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // --- 1. STUDENT STATS CARD ---
                    Container(
                      padding: const EdgeInsets.all(20),
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
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Wallet Balance',
                                style: TextStyle(
                                  color: Colors.grey[500],
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '₹${_portfolioData!["wallet_balance"]}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: riskColor.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: riskColor.withValues(alpha: 0.3),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: 6,
                                      height: 6,
                                      decoration: BoxDecoration(
                                        color: riskColor,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      riskProfile,
                                      style: TextStyle(
                                        color: riskColor,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          Column(
                            children: [
                              Stack(
                                alignment: Alignment.center,
                                children: [
                                  SizedBox(
                                    height: 64,
                                    width: 64,
                                    child: CircularProgressIndicator(
                                      value:
                                          (_portfolioData!['discipline_score'] ??
                                              0) /
                                          100,
                                      strokeWidth: 6,
                                      backgroundColor: const Color(0xFF1E2440),
                                      color:
                                          (_portfolioData!['discipline_score'] ??
                                                  0) >=
                                              75
                                          ? const Color(0xFF00E676)
                                          : (_portfolioData!['discipline_score'] ??
                                                    0) >=
                                                40
                                          ? const Color(0xFFFFB74D)
                                          : const Color(0xFFFF5252),
                                    ),
                                  ),
                                  Text(
                                    '${_portfolioData!["discipline_score"]}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Discipline',
                                style: TextStyle(
                                  color: Colors.grey[500],
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 28),

                    // --- 2. HOLDINGS SECTION HEADER ---
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
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(
                              0xFF00E676,
                            ).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '${holdings.length} Assets',
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

                    if (holdings.isEmpty)
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
                            "This student hasn't bought any assets yet.",
                            style: TextStyle(color: Colors.grey),
                          ),
                        ),
                      )
                    else
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: holdings.length,
                        itemBuilder: (context, index) {
                          final holding = holdings[index];
                          final symbol = (holding['symbol'] ?? 'X') as String;
                          final qty = holding['total_quantity'];
                          final avgPrice =
                              double.tryParse(
                                holding['average_price'].toString(),
                              ) ??
                              0.0;
                          final bookValue = qty * avgPrice;
                          final symbolColor = _getSymbolColor(symbol);

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
                              ),
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
                                      symbol.isNotEmpty
                                          ? symbol.substring(0, 1)
                                          : '?',
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
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
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
                                        '$qty Shares @ ₹${avgPrice.toStringAsFixed(2)}',
                                        style: TextStyle(
                                          color: Colors.grey[600],
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Text(
                                  '₹${bookValue.toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    const SizedBox(height: 28),

                    // --- TRADE HISTORY SECTION ---
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
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(
                              0xFF00E676,
                            ).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'Last 5 Trades',
                            style: TextStyle(
                              color: Color(0xFF00E676),
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
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
                            "This student hasn't made any trades yet.",
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
                          final symbol = (trade['symbol'] ?? 'X') as String;
                          final qty = trade['quantity'];
                          final pricePerShare =
                              double.tryParse(
                                trade['price_at_request'].toString(),
                              ) ??
                              0.0;
                          final totalAmount =
                              double.tryParse(
                                trade['total_amount'].toString(),
                              ) ??
                              0.0;
                          final status = trade['status'] as String;
                          final symbolColor = _getSymbolColor(symbol);

                          Color statusColor = Colors.grey;
                          if (status == 'EXECUTED') {
                            statusColor = const Color(0xFF00E676);
                          } else if (status == 'PENDING_MENTOR' ||
                              status == 'PENDING_EXECUTION') {
                            statusColor = const Color(0xFFFFB74D);
                          } else if (status == 'REJECTED' ||
                              status == 'FAILED') {
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
                                color: const Color(0xFF1E2440),
                              ),
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
                                      symbol.isNotEmpty
                                          ? symbol.substring(0, 1)
                                          : '?',
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
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
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
                                            symbol,
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
                                      const SizedBox(height: 2),
                                      Text(
                                        '$qty × ₹${pricePerShare.toStringAsFixed(2)}',
                                        style: TextStyle(
                                          color: Colors.grey[600],
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      '₹${totalAmount.toStringAsFixed(2)}',
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
                                        color: statusColor.withValues(
                                          alpha: 0.15,
                                        ),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        status,
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
                          );
                        },
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
