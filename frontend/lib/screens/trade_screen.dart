import 'package:flutter/material.dart';
import '../api_service.dart';
import 'package:fl_chart/fl_chart.dart';

class TradeScreen extends StatefulWidget {
  final List<dynamic> userGoals; // Passed from the Dashboard!

  const TradeScreen({super.key, required this.userGoals});

  @override
  State<TradeScreen> createState() => _TradeScreenState();
}

class _TradeScreenState extends State<TradeScreen> {
  // A curated list of popular NSE stocks/ETFs
  final List<String> _availableAssets = [
    'RELIANCE',
    'TCS',
    'HDFCBANK',
    'INFY',
    'ICICIBANK',
    'SBIN',
    'NIFTYBEES',
    'ADANIENT',
  ];

  String? _selectedSymbol;
  String _transactionType = 'BUY'; // Defaults to Buy
  int? _selectedGoalId;

  final _quantityController = TextEditingController();
  final _justificationController = TextEditingController();

  double? _livePrice;
  bool _isLoadingPrice = false;
  bool _isSubmitting = false;

  List<double> _chartPrices = [];
  List<String> _chartDates = [];
  double _minPrice = 0;
  double _maxPrice = 0;
  bool _isLoadingChart = false;

  @override
  void dispose() {
    _quantityController.dispose();
    _justificationController.dispose();
    super.dispose();
  }

  // Triggers whenever they pick a new stock from the dropdown
  void _fetchPrice(String symbol) async {
    setState(() {
      _selectedSymbol = symbol;
      _isLoadingPrice = true;
      _isLoadingChart = true;
      _livePrice = null;
      _chartPrices = [];
    });

    // Fetch the single live price for the preview
    final price = await ApiService.getLivePrice(symbol);

    // Fetch the 30-day Pandas data for the chart
    final history = await ApiService.getStockHistory(symbol);

    if (mounted) {
      setState(() {
        _livePrice = price;
        _isLoadingPrice = false;

        if (history != null) {
          // Convert dynamic lists from JSON into proper typed lists
          _chartPrices = List<double>.from(
            history['prices'].map((x) => x.toDouble()),
          );
          _chartDates = List<String>.from(history['dates']);
          _minPrice = history['min_price'].toDouble();
          _maxPrice = history['max_price'].toDouble();
        }
        _isLoadingChart = false;
      });
    }
  }

  void _executeTrade() async {
    // 1. Basic Form Validation
    if (_selectedSymbol == null || _selectedGoalId == null) {
      _showError("Please select an asset and a linked goal.");
      return;
    }

    int qty = int.tryParse(_quantityController.text) ?? 0;
    if (qty <= 0) {
      _showError("Enter a valid quantity.");
      return;
    }

    if (_justificationController.text.trim().length < 10) {
      _showError("Please provide a proper justification (min 10 chars).");
      return;
    }

    // 2. Submit to Backend
    setState(() => _isSubmitting = true);

    final result = await ApiService.submitTrade(
      symbol: _selectedSymbol!,
      type: _transactionType,
      quantity: qty,
      goalId: _selectedGoalId!,
      justification: _justificationController.text,
    );

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (result['success']) {
      // Trade Successful! Your backend handles the risk routing automatically.
      final status = result['data']['status']; // 'EXECUTED' or 'PENDING_MENTOR'

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          backgroundColor: const Color(0xFF1D1E33),
          title: Icon(
            status == 'EXECUTED' ? Icons.check_circle : Icons.hourglass_top,
            color: status == 'EXECUTED' ? Colors.green : Colors.orange,
            size: 50,
          ),
          content: Text(
            status == 'EXECUTED'
                ? "Trade Executed Successfully!"
                : "High Risk Trade. Sent to your Mentor for approval.",
            style: const TextStyle(color: Colors.white, fontSize: 18),
            textAlign: TextAlign.center,
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context); // Close dialog
                Navigator.pop(
                  context,
                  true,
                ); // Go back to dashboard & tell it to refresh
              },
              child: const Text("Done"),
            ),
          ],
        ),
      );
    } else {
      _showError(result['message']);
    }
  }

  void _showError(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1D1E33),
        title: const Icon(
          Icons.error_outline,
          color: Colors.redAccent,
          size: 50,
        ),
        content: Text(
          message,
          style: const TextStyle(color: Colors.white, fontSize: 16),
          textAlign: TextAlign.center,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("OK"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Calculate total cost preview dynamically
    int qty = int.tryParse(_quantityController.text) ?? 0;
    double estimatedTotal = (_livePrice ?? 0) * qty;

    return Scaffold(
      backgroundColor: const Color(0xFF0A0E21),
      appBar: AppBar(
        title: const Text(
          "New Trade",
          style: TextStyle(
            color: Color.fromARGB(255, 214, 211, 211),
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- 1. BUY / SELL TOGGLE ---
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFF1D1E33),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _transactionType = 'BUY'),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        decoration: BoxDecoration(
                          color: _transactionType == 'BUY'
                              ? Colors.green[600]
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Center(
                          child: Text(
                            "BUY",
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _transactionType = 'SELL'),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        decoration: BoxDecoration(
                          color: _transactionType == 'SELL'
                              ? Colors.red[600]
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Center(
                          child: Text(
                            "SELL",
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),

            // --- 2. ASSET SELECTION & LIVE PRICE ---
            const Text(
              "Asset",
              style: TextStyle(color: Colors.grey, fontSize: 14),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              dropdownColor: const Color(0xFF1D1E33),
              value: _selectedSymbol,
              style: const TextStyle(color: Colors.white, fontSize: 18),
              decoration: InputDecoration(
                filled: true,
                fillColor: const Color(0xFF1D1E33),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
              items: _availableAssets.map((symbol) {
                return DropdownMenuItem(value: symbol, child: Text(symbol));
              }).toList(),
              onChanged: (val) => _fetchPrice(val!),
              hint: const Text(
                "Select Stock/ETF",
                style: TextStyle(color: Colors.grey),
              ),
            ),

            // Live Price Indicator
            if (_isLoadingPrice)
              const Padding(
                padding: EdgeInsets.only(top: 12),
                child: Row(
                  children: [
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    SizedBox(width: 8),
                    Text(
                      "Fetching live price...",
                      style: TextStyle(color: Colors.blueAccent),
                    ),
                  ],
                ),
              )
            else if (_livePrice != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  "Live Price: ₹$_livePrice",
                  style: const TextStyle(
                    color: Colors.greenAccent,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            const SizedBox(height: 24),

            _buildChart(), // Show the price history chart
            // --- 3. QUANTITY ---
            const Text(
              "Quantity",
              style: TextStyle(color: Colors.grey, fontSize: 14),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _quantityController,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Colors.white, fontSize: 18),
              onChanged: (val) =>
                  setState(() {}), // Trigger rebuild to update estimated total
              decoration: InputDecoration(
                filled: true,
                fillColor: const Color(0xFF1D1E33),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                hintText: "0",
                hintStyle: TextStyle(color: Colors.grey[600]),
              ),
            ),
            const SizedBox(height: 24),

            // --- 4. GOAL LINKING ---
            const Text(
              "Link to Goal",
              style: TextStyle(color: Colors.grey, fontSize: 14),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<int>(
              dropdownColor: const Color(0xFF1D1E33),
              value: _selectedGoalId,
              style: const TextStyle(color: Colors.white, fontSize: 16),
              decoration: InputDecoration(
                filled: true,
                fillColor: const Color(0xFF1D1E33),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
              items: widget.userGoals.map((goal) {
                return DropdownMenuItem<int>(
                  value: goal['id'],
                  child: Text(goal['title'] ?? goal['name'] ?? "Goal"),
                );
              }).toList(),
              onChanged: (val) => setState(() => _selectedGoalId = val),
              hint: const Text(
                "Select a Goal",
                style: TextStyle(color: Colors.grey),
              ),
            ),
            const SizedBox(height: 24),

            // --- 5. THE BEHAVIORAL FRICTION (Justification) ---
            const Text(
              "Trade Justification (Why are you making this trade?)",
              style: TextStyle(color: Colors.grey, fontSize: 14),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _justificationController,
              maxLines: 3,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                filled: true,
                fillColor: const Color(0xFF1D1E33),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                hintText: "Explain your rationale to your mentor...",
                hintStyle: TextStyle(color: Colors.grey[600]),
              ),
            ),
            const SizedBox(height: 40),

            // --- 6. ESTIMATED TOTAL & SUBMIT ---
            if (_livePrice != null) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "Estimated Total:",
                    style: TextStyle(color: Colors.grey, fontSize: 16),
                  ),
                  Text(
                    "₹${estimatedTotal.toStringAsFixed(2)}",
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
            ],

            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _executeTrade,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _transactionType == 'BUY'
                      ? Colors.green[600]
                      : Colors.red[600],
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isSubmitting
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Text(
                        "SUBMIT ${_transactionType} ORDER",
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChart() {
    if (_isLoadingChart) {
      return const SizedBox(
        height: 250,
        child: Center(
          child: CircularProgressIndicator(color: Colors.blueAccent),
        ),
      );
    }

    if (_chartPrices.isEmpty) {
      return const SizedBox(
        height: 250,
        child: Center(
          child: Text(
            "Select an asset to view its 30-day trend.",
            style: TextStyle(color: Colors.grey),
          ),
        ),
      );
    }

    // Convert our prices list into X,Y coordinates for fl_chart
    List<FlSpot> spots = [];
    for (int i = 0; i < _chartPrices.length; i++) {
      spots.add(FlSpot(i.toDouble(), _chartPrices[i]));
    }

    return Container(
      height: 250,
      padding: const EdgeInsets.only(right: 16, left: 4, top: 24, bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1D1E33),
        borderRadius: BorderRadius.circular(16),
      ),
      child: LineChart(
        LineChartData(
          minX: 0,
          maxX: (_chartPrices.length - 1).toDouble(),
          minY: _minPrice * 0.98, // Add a 2% buffer at the bottom
          maxY: _maxPrice * 1.02, // Add a 2% buffer at the top
          // Disable the background grid lines for a cleaner look
          gridData: FlGridData(show: false),

          // Configure the borders
          borderData: FlBorderData(show: false),

          // Set up the X and Y axis labels
          titlesData: FlTitlesData(
            rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ), // Hide left axis to save space
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 22,
                getTitlesWidget: (value, meta) {
                  int index = value.toInt();
                  // Only show 3 date labels to prevent crowding
                  if (index == 0 ||
                      index == (_chartPrices.length / 2).floor() ||
                      index == _chartPrices.length - 1) {
                    return Text(
                      _chartDates[index],
                      style: const TextStyle(color: Colors.grey, fontSize: 10),
                    );
                  }
                  return const Text('');
                },
              ),
            ),
          ),

          // Draw the actual line
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true, // Smooths out the sharp edges
              color: Colors.blueAccent,
              barWidth: 3,
              isStrokeCapRound: true,
              dotData: FlDotData(show: false), // Hide the dots on each point
              belowBarData: BarAreaData(
                show: true,
                // Add a fading gradient below the line
                gradient: LinearGradient(
                  colors: [
                    Colors.blueAccent.withOpacity(0.3),
                    Colors.transparent,
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ],

          // Make it interactive when the user drags their finger over it
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              // --- THE FIX: Use getTooltipColor instead of tooltipBgColor ---
              getTooltipColor: (touchedSpot) => Colors.blueGrey[900]!,
              getTooltipItems: (touchedSpots) {
                return touchedSpots.map((spot) {
                  return LineTooltipItem(
                    "₹${spot.y.toStringAsFixed(2)}\n${_chartDates[spot.x.toInt()]}",
                    const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  );
                }).toList();
              },
            ),
          ),
        ),
      ),
    );
  }
}
