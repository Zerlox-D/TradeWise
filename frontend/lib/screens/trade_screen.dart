import 'package:flutter/material.dart';
import '../api_service.dart';
import 'package:fl_chart/fl_chart.dart';

class TradeScreen extends StatefulWidget {
  final List<dynamic> userGoals;
  final int userDisciplineScore;

  const TradeScreen({
    super.key,
    required this.userGoals,
    required this.userDisciplineScore,
  });

  @override
  State<TradeScreen> createState() => _TradeScreenState();
}

class _TradeScreenState extends State<TradeScreen> {
  // A curated list of popular NSE stocks/ETFs
  List<dynamic> _availableAssets = [];
  bool _isLoadingAssets = true;

  @override
  void initState() {
    super.initState();
    _loadAssets();
  }

  Future<void> _loadAssets() async {
    final assets = await ApiService.getAssets();
    if (mounted) {
      setState(() {
        _availableAssets = assets;
        _isLoadingAssets = false;
      });
    }
  }

  String? _selectedSymbol;
  String _transactionType = 'BUY';
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

  double getFeePercentage() {
    if (widget.userDisciplineScore >= 75) return 0.0;
    if (widget.userDisciplineScore >= 40) return 0.01;
    return 0.03;
  }

  @override
  void dispose() {
    _quantityController.dispose();
    _justificationController.dispose();
    super.dispose();
  }

  void _fetchPrice(String symbol) async {
    setState(() {
      _selectedSymbol = symbol;
      _isLoadingPrice = true;
      _isLoadingChart = true;
      _livePrice = null;
      _chartPrices = [];
    });

    final price = await ApiService.getLivePrice(symbol);
    final history = await ApiService.getStockHistory(symbol);

    if (mounted) {
      setState(() {
        _livePrice = price;
        _isLoadingPrice = false;
        if (history != null) {
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
      final status = result['data']['status'];
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          backgroundColor: const Color(0xFF151A30),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Icon(
            status == 'EXECUTED'
                ? Icons.check_circle_rounded
                : Icons.hourglass_top_rounded,
            color: status == 'EXECUTED'
                ? const Color(0xFF00E676)
                : Colors.orange,
            size: 52,
          ),
          content: Text(
            status == 'EXECUTED'
                ? "Trade Executed\nSuccessfully!"
                : "High Risk Trade.\nSent to your Mentor\nfor approval.",
            style: const TextStyle(color: Colors.white, fontSize: 17),
            textAlign: TextAlign.center,
          ),
          actions: [
            Center(
              child: TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  Future.delayed(const Duration(milliseconds: 100), () {
                    if (mounted) Navigator.pop(context, true);
                  });
                },
                child: const Text(
                  "Done",
                  style: TextStyle(
                    color: Color(0xFF00E676),
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
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
        backgroundColor: const Color(0xFF151A30),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Icon(
          Icons.error_outline_rounded,
          color: Colors.redAccent,
          size: 52,
        ),
        content: Text(
          message,
          style: const TextStyle(color: Colors.white, fontSize: 16),
          textAlign: TextAlign.center,
        ),
        actions: [
          Center(
            child: TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                "OK",
                style: TextStyle(
                  color: Color(0xFF00E676),
                  fontWeight: FontWeight.w600,
                ),
              ),
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

  bool get _isChartPositive =>
      _chartPrices.length >= 2 && _chartPrices.last >= _chartPrices.first;

  Color get _chartColor => _chartPrices.isEmpty
      ? const Color(0xFF00E676)
      : (_isChartPositive ? const Color(0xFF00E676) : Colors.redAccent);

  @override
  Widget build(BuildContext context) {
    final int qty = int.tryParse(_quantityController.text) ?? 0;
    final double estimatedTotal = (_livePrice ?? 0) * qty;
    final bool isBuy = _transactionType == 'BUY';
    final Color actionColor = isBuy
        ? const Color(0xFF00E676)
        : Colors.redAccent;

    return Scaffold(
      backgroundColor: const Color(0xFF0A0E21),
      appBar: null,
      body: SafeArea(
        child: Column(
          children: [
            // ── HEADER ──────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: const EdgeInsets.all(9),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1A1F36),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: const Color(0xFF252A45),
                          width: 1,
                        ),
                      ),
                      child: const Icon(
                        Icons.arrow_back_ios_new_rounded,
                        color: Colors.white70,
                        size: 16,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: const [
                          Icon(
                            Icons.bolt_rounded,
                            color: Color(0xFF00E676),
                            size: 13,
                          ),
                          SizedBox(width: 4),
                          Text(
                            "TRADEWISE",
                            style: TextStyle(
                              color: Color(0xFF00E676),
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.5,
                            ),
                          ),
                        ],
                      ),
                      const Text(
                        "New Trade",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.3,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // ── SCROLLABLE BODY ──────────────────────────────────────
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── BUY / SELL TOGGLE ──────────────────────────
                    Container(
                      height: 50,
                      padding: const EdgeInsets.all(4),
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
                          _buildToggleTab('BUY', const Color(0xFF00E676)),
                          _buildToggleTab('SELL', Colors.redAccent),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // ── ASSET PICKER ───────────────────────────────
                    _buildSectionHeader("Select Asset"),
                    const SizedBox(height: 12),

                    if (_isLoadingAssets)
                      const SizedBox(
                        height: 82,
                        child: Center(
                          child: CircularProgressIndicator(
                            color: Color(0xFF00E676),
                            strokeWidth: 2,
                          ),
                        ),
                      )
                    else
                      SizedBox(
                        height: 82,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: _availableAssets.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(width: 10),
                          itemBuilder: (context, index) {
                            final asset = _availableAssets[index];
                            final symbol = asset['symbol'].toString();
                            final isSelected = _selectedSymbol == symbol;
                            final symColor = _getSymbolColor(symbol);

                            return GestureDetector(
                              onTap: () => _fetchPrice(symbol),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 180),
                                width: 78,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 10,
                                  horizontal: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? symColor.withOpacity(0.12)
                                      : const Color(0xFF151A30),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: isSelected
                                        ? symColor
                                        : const Color(0xFF1E2440),
                                    width: isSelected ? 1.5 : 1,
                                  ),
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Container(
                                      width: 32,
                                      height: 32,
                                      decoration: BoxDecoration(
                                        color: symColor.withOpacity(0.15),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Center(
                                        child: Text(
                                          symbol.substring(0, 1),
                                          style: TextStyle(
                                            color: symColor,
                                            fontWeight: FontWeight.w700,
                                            fontSize: 15,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      symbol.length > 7
                                          ? symbol.substring(0, 7)
                                          : symbol,
                                      style: TextStyle(
                                        color: isSelected
                                            ? Colors.white
                                            : Colors.grey[500],
                                        fontSize: 10,
                                        fontWeight: isSelected
                                            ? FontWeight.w600
                                            : FontWeight.w400,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    const SizedBox(height: 16),

                    // ── SELECTED ASSET PRICE ROW ───────────────────
                    if (_selectedSymbol != null) ...[
                      Container(
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
                            Container(
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(
                                color: _getSymbolColor(
                                  _selectedSymbol!,
                                ).withOpacity(0.15),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Center(
                                child: Text(
                                  _selectedSymbol!.substring(0, 1),
                                  style: TextStyle(
                                    color: _getSymbolColor(_selectedSymbol!),
                                    fontWeight: FontWeight.w700,
                                    fontSize: 18,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _selectedSymbol!,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  Text(
                                    "NSE",
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (_isLoadingPrice)
                              const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  color: Color(0xFF00E676),
                                  strokeWidth: 2,
                                ),
                              )
                            else if (_livePrice != null)
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    "₹${_livePrice!.toStringAsFixed(2)}",
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 17,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  if (_chartPrices.length >= 2) ...[
                                    const SizedBox(height: 3),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: _chartColor.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            _isChartPositive
                                                ? Icons.arrow_upward_rounded
                                                : Icons.arrow_downward_rounded,
                                            color: _chartColor,
                                            size: 11,
                                          ),
                                          const SizedBox(width: 2),
                                          Text(
                                            "${((_chartPrices.last - _chartPrices.first) / _chartPrices.first * 100).toStringAsFixed(2)}%",
                                            style: TextStyle(
                                              color: _chartColor,
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // ── CHART ──────────────────────────────────────
                    _buildChart(),
                    const SizedBox(height: 24),

                    // ── QUANTITY ───────────────────────────────────
                    _buildSectionHeader("Quantity"),
                    const SizedBox(height: 12),
                    Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF151A30),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: const Color(0xFF1E2440),
                          width: 1,
                        ),
                      ),
                      child: TextField(
                        controller: _quantityController,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                        ),
                        onChanged: (val) => setState(() {}),
                        decoration: InputDecoration(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                          border: InputBorder.none,
                          hintText: "Enter number of shares",
                          hintStyle: TextStyle(
                            color: Colors.grey[700],
                            fontSize: 14,
                          ),
                          prefixIcon: const Icon(
                            Icons.tag_rounded,
                            color: Color(0xFF4C5078),
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // ── LINK TO GOAL ───────────────────────────────
                    _buildSectionHeader("Link to Goal"),
                    const SizedBox(height: 12),
                    Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF151A30),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: const Color(0xFF1E2440),
                          width: 1,
                        ),
                      ),
                      child: DropdownButtonFormField<int>(
                        dropdownColor: const Color(0xFF151A30),
                        value: _selectedGoalId,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                        ),
                        iconEnabledColor: const Color(0xFF4C5078),
                        decoration: const InputDecoration(
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                          border: InputBorder.none,
                          prefixIcon: Icon(
                            Icons.flag_outlined,
                            color: Color(0xFF4C5078),
                            size: 20,
                          ),
                        ),
                        items: widget.userGoals.map((goal) {
                          return DropdownMenuItem<int>(
                            value: goal['id'],
                            child: Text(
                              goal['title'] ?? goal['name'] ?? "Goal",
                            ),
                          );
                        }).toList(),
                        onChanged: (val) =>
                            setState(() => _selectedGoalId = val),
                        hint: Text(
                          "Select a Goal",
                          style: TextStyle(
                            color: Colors.grey[700],
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // ── JUSTIFICATION ──────────────────────────────
                    _buildSectionHeader("Trade Justification"),
                    const SizedBox(height: 12),
                    Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF151A30),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: const Color(0xFF1E2440),
                          width: 1,
                        ),
                      ),
                      child: TextField(
                        controller: _justificationController,
                        maxLines: 3,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                        ),
                        decoration: InputDecoration(
                          contentPadding: const EdgeInsets.all(16),
                          border: InputBorder.none,
                          hintText: "Explain your rationale to your mentor...",
                          hintStyle: TextStyle(
                            color: Colors.grey[700],
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // ── ORDER SUMMARY ──────────────────────────────
                    if (_livePrice != null && qty > 0) ...[
                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: const Color(0xFF151A30),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: getFeePercentage() == 0.03
                                ? Colors.redAccent.withOpacity(0.35)
                                : const Color(0xFF1E2440),
                            width: 1,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildSectionHeader("Order Summary"),
                            const SizedBox(height: 16),
                            _buildSummaryRow(
                              "Shares Value (${qty}x)",
                              "₹${estimatedTotal.toStringAsFixed(2)}",
                              Colors.grey[500]!,
                              Colors.white,
                            ),
                            const SizedBox(height: 10),
                            _buildSummaryRow(
                              "Brokerage Fee ${(getFeePercentage() * 100).toInt()}%",
                              "₹${(estimatedTotal * getFeePercentage()).toStringAsFixed(2)}",
                              getFeePercentage() == 0.03
                                  ? Colors.redAccent
                                  : Colors.grey[500]!,
                              getFeePercentage() == 0.03
                                  ? Colors.redAccent
                                  : Colors.white,
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              child: Divider(
                                color: const Color(0xFF1E2440),
                                thickness: 1,
                              ),
                            ),
                            _buildSummaryRow(
                              isBuy ? "Total Cost" : "Total Payout",
                              isBuy
                                  ? "₹${(estimatedTotal * (1 + getFeePercentage())).toStringAsFixed(2)}"
                                  : "₹${(estimatedTotal * (1 - getFeePercentage())).toStringAsFixed(2)}",
                              Colors.white,
                              actionColor,
                              valueSize: 17,
                            ),
                            if (getFeePercentage() == 0.03) ...[
                              const SizedBox(height: 12),
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Colors.redAccent.withOpacity(0.08),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: Colors.redAccent.withOpacity(0.2),
                                    width: 1,
                                  ),
                                ),
                                child: const Row(
                                  children: [
                                    Icon(
                                      Icons.warning_amber_rounded,
                                      color: Colors.redAccent,
                                      size: 18,
                                    ),
                                    SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        "3% Impulse Penalty applied due to low Discipline Score. Hold assets to improve your score!",
                                        style: TextStyle(
                                          color: Colors.redAccent,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],

                    // ── SUBMIT BUTTON ──────────────────────────────
                    Container(
                      width: double.infinity,
                      height: 56,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        gradient: LinearGradient(
                          colors: isBuy
                              ? [
                                  const Color(0xFF00E676),
                                  const Color(0xFF00C853),
                                ]
                              : [Colors.redAccent, const Color(0xFFB71C1C)],
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: actionColor.withOpacity(0.28),
                            blurRadius: 16,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: ElevatedButton(
                        onPressed: _isSubmitting ? null : _executeTrade,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: _isSubmitting
                            ? const CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              )
                            : Text(
                                "SUBMIT $_transactionType ORDER",
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF0A0E21),
                                  letterSpacing: 0.6,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 36),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── HELPERS ────────────────────────────────────────────────────────

  Widget _buildToggleTab(String label, Color activeColor) {
    final bool isActive = _transactionType == label;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _transactionType = label),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: isActive
                ? activeColor.withOpacity(0.15)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isActive
                  ? activeColor.withOpacity(0.5)
                  : Colors.transparent,
              width: 1,
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: isActive ? activeColor : const Color(0xFF4C5078),
                fontWeight: FontWeight.w700,
                fontSize: 14,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Row(
      children: [
        Container(
          width: 3,
          height: 16,
          decoration: BoxDecoration(
            color: const Color(0xFF00E676),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryRow(
    String label,
    String value,
    Color labelColor,
    Color valueColor, {
    double valueSize = 14,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(color: labelColor, fontSize: 13)),
        Text(
          value,
          style: TextStyle(
            color: valueColor,
            fontSize: valueSize,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildChart() {
    if (_isLoadingChart) {
      return Container(
        height: 200,
        decoration: BoxDecoration(
          color: const Color(0xFF151A30),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF1E2440), width: 1),
        ),
        child: const Center(
          child: CircularProgressIndicator(
            color: Color(0xFF00E676),
            strokeWidth: 2,
          ),
        ),
      );
    }

    if (_chartPrices.isEmpty) {
      return Container(
        height: 160,
        decoration: BoxDecoration(
          color: const Color(0xFF151A30),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF1E2440), width: 1),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.candlestick_chart_outlined,
                color: Colors.grey[700],
                size: 32,
              ),
              const SizedBox(height: 8),
              Text(
                "Select an asset to view its 30-day trend",
                style: TextStyle(color: Colors.grey[600], fontSize: 13),
              ),
            ],
          ),
        ),
      );
    }

    final List<FlSpot> spots = [
      for (int i = 0; i < _chartPrices.length; i++)
        FlSpot(i.toDouble(), _chartPrices[i]),
    ];
    final color = _chartColor;

    return Container(
      height: 200,
      padding: const EdgeInsets.fromLTRB(4, 20, 16, 12),
      decoration: BoxDecoration(
        color: const Color(0xFF151A30),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.2), width: 1),
      ),
      child: LineChart(
        LineChartData(
          minX: 0,
          maxX: (_chartPrices.length - 1).toDouble(),
          minY: _minPrice * 0.98,
          maxY: _maxPrice * 1.02,
          gridData: FlGridData(show: false),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 22,
                getTitlesWidget: (value, meta) {
                  final int index = value.toInt();
                  if (index == 0 ||
                      index == (_chartPrices.length / 2).floor() ||
                      index == _chartPrices.length - 1) {
                    return Text(
                      _chartDates[index],
                      style: const TextStyle(
                        color: Color(0xFF4C5078),
                        fontSize: 10,
                      ),
                    );
                  }
                  return const Text('');
                },
              ),
            ),
          ),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              color: color,
              barWidth: 2.5,
              isStrokeCapRound: true,
              dotData: FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  colors: [color.withOpacity(0.25), Colors.transparent],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ],
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipColor: (touchedSpot) => const Color(0xFF1A1F36),
              getTooltipItems: (touchedSpots) {
                return touchedSpots.map((spot) {
                  return LineTooltipItem(
                    "₹${spot.y.toStringAsFixed(2)}\n${_chartDates[spot.x.toInt()]}",
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
        ),
      ),
    );
  }
}
