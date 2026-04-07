import 'package:flutter/material.dart';
import '../api_service.dart';

class DashboardHeaderAnalytics {
  // ── Brand colours ──────────────────────────────────────────────────────────
  static const _bg     = Color(0xFF0A0E21);
  static const _card   = Color(0xFF151A30);
  static const _border = Color(0xFF1E2440);
  static const _green  = Color(0xFF00E676);
  static const _amber  = Color(0xFFFFB74D);
  static const _red    = Color(0xFFFF5252);
  static const _blue   = Color(0xFF42A5F5);

  // ── Risk colour helper ─────────────────────────────────────────────────────
  static Color _riskColor(String risk) {
    switch (risk) {
      case 'Low':
      case 'Conservative':
        return _green;
      case 'Moderate':
        return _amber;
      case 'High':
      case 'Aggressive':
        return _red;
      default:
        return _blue;
    }
  }

  static Color _getScoreColor(int score) {
    if (score >= 75) return _green;
    if (score >= 40) return _amber;
    return _red;
  }

  // ── Header ─────────────────────────────────────────────────────────────────
  static Widget buildHeader(Map<String, dynamic>? userProfile) {
    final balance      = userProfile!['wallet_balance'] ?? "0.00";
    final riskProfile  = userProfile['risk_profile'] ?? "Moderate";
    final riskCol      = _riskColor(riskProfile);
    final username     = userProfile['username'] ?? '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Brand bar ──────────────────────────────────────────────────────
        Row(
          children: [
            const Icon(Icons.bolt_rounded, color: _green, size: 18),
            const SizedBox(width: 6),
            const Text(
              'TRADEWISE',
              style: TextStyle(
                color: _green,
                fontSize: 13,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.5,
              ),
            ),
            const Spacer(),
          ],
        ),
        const SizedBox(height: 20),

        // ── Greeting ───────────────────────────────────────────────────────
        Text(
          'Welcome back,',
          style: TextStyle(fontSize: 14, color: Colors.grey[500]),
        ),
        const SizedBox(height: 2),
        Text(
          username,
          style: const TextStyle(
            fontSize: 30,
            fontWeight: FontWeight.w700,
            color: Colors.white,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 20),

        // ── Wallet + Risk + Discipline hero card ───────────────────────────
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF0D2137), Color(0xFF0A1628)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Label row
              Row(
                children: [
                  Text(
                    'Total Balance',
                    style: TextStyle(
                      color: Colors.grey[500],
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                '₹$balance',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 34,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 20),
              // Divider
              Container(height: 1, color: _border),
              const SizedBox(height: 16),
              // Risk Profile + Discipline Score — prominent side-by-side
              Row(
                children: [
                  // Risk Profile block
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Risk Profile',
                          style: TextStyle(color: Colors.grey[500], fontSize: 11),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: riskCol.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: riskCol.withOpacity(0.35)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 7,
                                height: 7,
                                decoration: BoxDecoration(
                                  color: riskCol,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 7),
                              Text(
                                riskProfile,
                                style: TextStyle(
                                  color: riskCol,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Vertical divider
                  Container(
                    width: 1,
                    height: 52,
                    color: _border,
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                  ),
                  // Discipline Score block
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        'Discipline Score',
                        style: TextStyle(color: Colors.grey[500], fontSize: 11),
                      ),
                      const SizedBox(height: 6),
                      _DisciplineRing(
                        score: userProfile['discipline_score'] ?? 0,
                        radius: 28,
                        strokeWidth: 5,
                        fontSize: 15,
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Analytics section (discipline + goals) ─────────────────────────────────
  static Widget buildAnalyticsSection(
    Map<String, dynamic>? userProfile,
    List<dynamic> goals,
    VoidCallback onShowGoals,
  ) {
    final disciplineScore = (userProfile!['discipline_score'] ?? 0) as int;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Discipline score — full-width prominent card ─────────────────
        Builder(builder: (context) {
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            decoration: BoxDecoration(
              color: _card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _border),
            ),
            child: Row(
              children: [
                // Big ring
                _DisciplineRing(
                  score: disciplineScore,
                  radius: 40,
                  strokeWidth: 7,
                  fontSize: 22,
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text(
                            'Discipline Score',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const Spacer(),
                          GestureDetector(
                            onTap: () => _showInfoSheet(context),
                            child: Container(
                              width: 26,
                              height: 26,
                              decoration: BoxDecoration(
                                color: _blue.withOpacity(0.1),
                                shape: BoxShape.circle,
                                border: Border.all(
                                    color: _blue.withOpacity(0.3)),
                              ),
                              child: const Icon(Icons.info_outline_rounded,
                                  color: _blue, size: 15),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _disciplineLabel(disciplineScore),
                        style: TextStyle(
                          color: _getScoreColor(disciplineScore),
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 10),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: disciplineScore / 100,
                          backgroundColor: const Color(0xFF1E2440),
                          valueColor: AlwaysStoppedAnimation<Color>(
                            _getScoreColor(disciplineScore),
                          ),
                          minHeight: 6,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }),
        const SizedBox(height: 16),

        // ── Goals — full-width, tappable ─────────────────────────────────
        InkWell(
          onTap: onShowGoals,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: _card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _border),
            ),
            child: Builder(
              builder: (context) {
                // Empty state
                if (goals.isEmpty) {
                  return Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: _green.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.flag_rounded,
                            color: _green, size: 22),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Active Goals',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              'Tap to set your first goal',
                              style: TextStyle(
                                  color: Colors.grey[500], fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.chevron_right, color: Colors.grey[600]),
                    ],
                  );
                }

                // Goal with progress
                final firstGoal  = goals.first;
                final currentAmt = double.tryParse(
                        firstGoal['current_amount']?.toString() ?? '0') ??
                    0.0;
                final targetAmt = double.tryParse(
                        firstGoal['target_amount']?.toString() ?? '1') ??
                    1.0;
                final safeTarget = targetAmt > 0 ? targetAmt : 1.0;
                final progress = (currentAmt / safeTarget).clamp(0.0, 1.0);
                final progressColor =
                    progress >= 1.0 ? _green : _blue;
                final extraCount = goals.length - 1;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: progressColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(Icons.flag_rounded,
                              color: progressColor, size: 22),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    'Active Goals',
                                    style: TextStyle(
                                        color: Colors.grey[500], fontSize: 11),
                                  ),
                                  const Spacer(),
                                  Text(
                                    '${(progress * 100).toStringAsFixed(0)}%',
                                    style: TextStyle(
                                      color: progressColor,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 3),
                              Text(
                                firstGoal['name'] ?? 'Goal',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(Icons.chevron_right, color: Colors.grey[600]),
                      ],
                    ),
                    const SizedBox(height: 14),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: progress,
                        backgroundColor: _border,
                        valueColor:
                            AlwaysStoppedAnimation<Color>(progressColor),
                        minHeight: 8,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '₹${currentAmt.toStringAsFixed(0)}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          'of ₹${targetAmt.toStringAsFixed(0)}',
                          style: TextStyle(
                              color: Colors.grey[500], fontSize: 12),
                        ),
                      ],
                    ),
                    if (extraCount > 0) ...[
                      const SizedBox(height: 10),
                      Container(
                        height: 1,
                        color: _border,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        '+$extraCount more goal${extraCount > 1 ? 's' : ''} · tap to view all',
                        style: TextStyle(
                          color: Colors.grey[500],
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  static void _showInfoSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0A0E21),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      isScrollControlled: true,
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: _border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Sheet title
              Row(
                children: [
                  Container(
                    width: 3,
                    height: 18,
                    decoration: BoxDecoration(
                      color: _blue,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'How are these calculated?',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Discipline Score section
              _infoBlock(
                icon: Icons.track_changes_rounded,
                color: _green,
                title: 'Discipline Score',
                body:
                    'Your Discipline Score (0-100) is the core metric of your '
                    'trading psychology. It actively tracks your market behavior, '
                    'penalizing impulsive decisions and rewarding consistent, well-planned investing.\n\n'
                    'This score ensures accountability across the entire platform. '
                    'Note that Mentors are also held to this standard: a Mentor whose Discipline Score '
                    'drops below 50 is temporarily restricted from accepting new student connection requests.',
              ),
              const SizedBox(height: 16),

              // Risk Profile section
              _infoBlock(
                icon: Icons.shield_outlined,
                color: _amber,
                title: 'Risk Profile',
                body:
                    'Your Risk Profile is directly determined by your Discipline Score. '
                    'Every stock is actively analyzed for volatility and classified as Low, Moderate, or High risk.\n\n'
                    '• 75–100 (Excellent): Conservative Tier.\n'
                    '• 40–74 (Moderate): Moderate Tier.\n'
                    '• Below 40 (Warning): Aggressive Tier.\n\n'
                    'Attempting to purchase an asset that exceeds your current tier triggers our system guardrails. '
                    'The trade will be intercepted and marked as "Pending," requiring you to submit '
                    'a written justification to your Mentor for manual approval.',
              ),
            ],
          ),
        );
      },
    );
  }

  static Widget _infoBlock({
    required IconData icon,
    required Color color,
    required String title,
    required String body,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 18),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            body,
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 13,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }

  static String _disciplineLabel(int score) {
    if (score >= 75) return 'Excellent · Keep it up!';
    if (score >= 40) return 'Moderate · Room to improve';
    return 'Needs attention';
  }

  // ── Goals bottom sheet ─────────────────────────────────────────────────────
  static void showGoalsBottomSheet(
    BuildContext context,
    List<dynamic> goals,
    VoidCallback onAddGoal,
    Function(Map) onEditGoal,
    Function(Map) onDeleteGoal,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: _bg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      isScrollControlled: true,
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: _border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 3,
                        height: 18,
                        decoration: BoxDecoration(
                          color: _green,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        'Your Goals',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  GestureDetector(
                    onTap: () {
                      Navigator.pop(context);
                      onAddGoal();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 7),
                      decoration: BoxDecoration(
                        color: _green.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: _green.withOpacity(0.3)),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.add, color: _green, size: 16),
                          SizedBox(width: 4),
                          Text(
                            'Add Goal',
                            style: TextStyle(
                                color: _green,
                                fontSize: 13,
                                fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              if (goals.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: Center(
                    child: Text(
                      'No goals yet. Add one to get started!',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                )
              else
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: goals.length,
                  itemBuilder: (context, index) {
                    final goal = goals[index];
                    final currentAmt = double.tryParse(
                            goal['current_amount']?.toString() ?? '0') ??
                        0.0;
                    final targetAmt = double.tryParse(
                            goal['target_amount']?.toString() ?? '1') ??
                        1.0;
                    final progress =
                        (currentAmt / (targetAmt > 0 ? targetAmt : 1))
                            .clamp(0.0, 1.0);
                    final progressColor =
                        progress >= 1.0 ? _green : _blue;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: _card,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: _border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  goal['name'] ?? 'Goal',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              PopupMenuButton<String>(
                                color: _card,
                                icon: Icon(Icons.more_vert,
                                    color: Colors.grey[500], size: 18),
                                onSelected: (value) {
                                  Navigator.pop(context);
                                  if (value == 'edit') {
                                    onEditGoal(goal);
                                  } else if (value == 'delete') {
                                    onDeleteGoal(goal);
                                  }
                                },
                                itemBuilder: (context) => [
                                  const PopupMenuItem(
                                    value: 'edit',
                                    child: Text('Edit',
                                        style:
                                            TextStyle(color: Colors.white)),
                                  ),
                                  const PopupMenuItem(
                                    value: 'delete',
                                    child: Text('Delete',
                                        style: TextStyle(color: _red)),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Due: ${goal['deadline_date'] ?? 'N/A'}',
                                style: TextStyle(
                                    color: Colors.grey[500], fontSize: 11),
                              ),
                              Text(
                                '₹${targetAmt.toStringAsFixed(0)}',
                                style: const TextStyle(
                                  color: _green,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: progress,
                              backgroundColor: _border,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                  progressColor),
                              minHeight: 6,
                            ),
                          ),
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

  // ── Add goal dialog ────────────────────────────────────────────────────────
  static void showAddGoalDialog(BuildContext context, VoidCallback onRefresh) {
    final titleController  = TextEditingController();
    final amountController = TextEditingController();
    DateTime? selectedDate;
    bool isSaving = false;

    showModalBottomSheet(
      context: context,
      backgroundColor: _bg,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setS) {
          return Padding(
            padding: EdgeInsets.fromLTRB(
                24, 24, 24, MediaQuery.of(context).viewInsets.bottom + 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Handle
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                        color: _border,
                        borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                const SizedBox(height: 24),

                // Title row
                Row(
                  children: [
                    Container(
                      width: 3,
                      height: 18,
                      decoration: BoxDecoration(
                          color: _green,
                          borderRadius: BorderRadius.circular(2)),
                    ),
                    const SizedBox(width: 10),
                    const Text(
                      'Add New Goal',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Goal title field
                _sheetField(titleController, 'Goal Title',
                    hint: 'e.g. Emergency Fund'),
                const SizedBox(height: 16),

                // Amount field
                _sheetField(amountController, 'Target Amount',
                    hint: '₹ 0', numeric: true),
                const SizedBox(height: 16),

                // Date picker
                _sheetDatePicker(
                  context,
                  selectedDate,
                  (picked) => setS(() => selectedDate = picked),
                  initialOffset: const Duration(days: 30),
                ),
                const SizedBox(height: 28),

                // Save button
                GestureDetector(
                  onTap: isSaving
                      ? null
                      : () async {
                          if (titleController.text.isEmpty ||
                              amountController.text.isEmpty ||
                              selectedDate == null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                    'Please fill all fields and select a date.'),
                                backgroundColor: _amber,
                              ),
                            );
                            return;
                          }
                          setS(() => isSaving = true);
                          bool success = await ApiService.addGoal(
                            titleController.text,
                            double.tryParse(amountController.text) ?? 0.0,
                            _fmt(selectedDate!),
                          );
                          if (success) {
                            Navigator.pop(context);
                            onRefresh();
                          } else {
                            setS(() => isSaving = false);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Failed to save goal.'),
                                backgroundColor: _red,
                              ),
                            );
                          }
                        },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    decoration: BoxDecoration(
                      color: isSaving ? _border : _green.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                          color: isSaving
                              ? Colors.transparent
                              : _green.withOpacity(0.4)),
                    ),
                    child: Center(
                      child: isSaving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  color: _green, strokeWidth: 2),
                            )
                          : const Text(
                              'Save Goal',
                              style: TextStyle(
                                  color: _green,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700),
                            ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // ── Edit goal dialog ───────────────────────────────────────────────────────
  static void showEditGoalDialog(
    BuildContext context,
    Map goal,
    VoidCallback onRefresh,
  ) {
    final titleController =
        TextEditingController(text: goal['title'] ?? goal['name']);
    final amountController =
        TextEditingController(text: goal['target_amount'].toString());
    DateTime? selectedDate =
        DateTime.tryParse(goal['deadline_date'] ?? '');
    bool isSaving = false;

    showModalBottomSheet(
      context: context,
      backgroundColor: _bg,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setS) {
          return Padding(
            padding: EdgeInsets.fromLTRB(
                24, 24, 24, MediaQuery.of(context).viewInsets.bottom + 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                        color: _border,
                        borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Container(
                      width: 3,
                      height: 18,
                      decoration: BoxDecoration(
                          color: _blue,
                          borderRadius: BorderRadius.circular(2)),
                    ),
                    const SizedBox(width: 10),
                    const Text(
                      'Edit Goal',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                _sheetField(titleController, 'Goal Title'),
                const SizedBox(height: 16),
                _sheetField(amountController, 'Target Amount',
                    hint: '₹ 0', numeric: true),
                const SizedBox(height: 16),
                _sheetDatePicker(
                  context,
                  selectedDate,
                  (picked) => setS(() => selectedDate = picked),
                ),
                const SizedBox(height: 28),
                GestureDetector(
                  onTap: isSaving
                      ? null
                      : () async {
                          if (titleController.text.isEmpty ||
                              amountController.text.isEmpty ||
                              selectedDate == null) return;
                          setS(() => isSaving = true);
                          bool success = await ApiService.updateGoal(
                            goal['id'],
                            titleController.text,
                            double.tryParse(amountController.text) ?? 0.0,
                            _fmt(selectedDate!),
                          );
                          if (success) {
                            Navigator.pop(context);
                            onRefresh();
                          } else {
                            setS(() => isSaving = false);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Failed to update goal.'),
                                backgroundColor: _red,
                              ),
                            );
                          }
                        },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    decoration: BoxDecoration(
                      color: isSaving ? _border : _blue.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                          color: isSaving
                              ? Colors.transparent
                              : _blue.withOpacity(0.4)),
                    ),
                    child: Center(
                      child: isSaving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  color: _blue, strokeWidth: 2),
                            )
                          : const Text(
                              'Update Goal',
                              style: TextStyle(
                                  color: _blue,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700),
                            ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // ── Delete goal dialog ─────────────────────────────────────────────────────
  static void confirmDeleteGoal(
    BuildContext context,
    Map goal,
    VoidCallback onRefresh,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: _bg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                      color: _border,
                      borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Container(
                    width: 3,
                    height: 18,
                    decoration: BoxDecoration(
                        color: _red,
                        borderRadius: BorderRadius.circular(2)),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'Delete Goal?',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _card,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _border),
                ),
                child: Text(
                  "Are you sure you want to delete '${goal['title'] ?? goal['name']}'? This cannot be undone.",
                  style: TextStyle(color: Colors.grey[400], fontSize: 14, height: 1.5),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          color: _card,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: _border),
                        ),
                        child: const Center(
                          child: Text('Cancel',
                              style: TextStyle(
                                  color: Colors.grey,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600)),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: GestureDetector(
                      onTap: () async {
                        Navigator.pop(context);
                        bool success =
                            await ApiService.deleteGoal(goal['id']);
                        if (success) {
                          onRefresh();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Goal deleted.'),
                              backgroundColor: _green,
                            ),
                          );
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Failed to delete goal.'),
                              backgroundColor: _red,
                            ),
                          );
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          color: _red.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(14),
                          border:
                              Border.all(color: _red.withOpacity(0.3)),
                        ),
                        child: const Center(
                          child: Text('Delete',
                              style: TextStyle(
                                  color: _red,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700)),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  // ── Private helpers ────────────────────────────────────────────────────────
  static String _fmt(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static Widget _sheetField(
    TextEditingController controller,
    String label, {
    String? hint,
    bool numeric = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(
                color: Colors.grey[500],
                fontSize: 12,
                fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: numeric ? TextInputType.number : TextInputType.text,
          style: const TextStyle(color: Colors.white, fontSize: 15),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: Colors.grey[700]),
            filled: true,
            fillColor: _card,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: _border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: _border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: _blue),
            ),
          ),
        ),
      ],
    );
  }

  static Widget _sheetDatePicker(
    BuildContext context,
    DateTime? selectedDate,
    void Function(DateTime) onPicked, {
    Duration initialOffset = Duration.zero,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Deadline',
            style: TextStyle(
                color: Colors.grey[500],
                fontSize: 12,
                fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: () async {
            final DateTime? picked = await showDatePicker(
              context: context,
              initialDate: selectedDate ??
                  DateTime.now().add(
                    initialOffset == Duration.zero
                        ? const Duration(days: 1)
                        : initialOffset,
                  ),
              firstDate: DateTime.now(),
              lastDate: DateTime(2050),
              builder: (context, child) => Theme(
                data: Theme.of(context).copyWith(
                  colorScheme: const ColorScheme.dark(
                    primary: _blue,
                    onPrimary: Colors.white,
                    surface: _card,
                    onSurface: Colors.white,
                  ),
                ),
                child: child!,
              ),
            );
            if (picked != null) onPicked(picked);
          },
          child: Container(
            width: double.infinity,
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: _card,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: selectedDate != null
                      ? _blue.withOpacity(0.5)
                      : _border),
            ),
            child: Row(
              children: [
                Icon(Icons.calendar_today_rounded,
                    color: selectedDate != null ? _blue : Colors.grey[600],
                    size: 16),
                const SizedBox(width: 10),
                Text(
                  selectedDate == null
                      ? 'Select a deadline'
                      : _fmt(selectedDate),
                  style: TextStyle(
                    color: selectedDate != null
                        ? Colors.white
                        : Colors.grey[600],
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ── Discipline ring widget ─────────────────────────────────────────────────
class _DisciplineRing extends StatelessWidget {
  final int score;
  final double radius;
  final double strokeWidth;
  final double fontSize;

  const _DisciplineRing({
    required this.score,
    required this.radius,
    required this.strokeWidth,
    required this.fontSize,
  });

  static Color _color(int s) {
    if (s >= 75) return const Color(0xFF00E676);
    if (s >= 40) return const Color(0xFFFFB74D);
    return const Color(0xFFFF5252);
  }

  @override
  Widget build(BuildContext context) {
    final col = _color(score);
    return Stack(
      alignment: Alignment.center,
      children: [
        SizedBox(
          height: radius * 2,
          width: radius * 2,
          child: CircularProgressIndicator(
            value: score / 100,
            strokeWidth: strokeWidth,
            backgroundColor: const Color(0xFF1E2440),
            color: col,
            strokeCap: StrokeCap.round,
          ),
        ),
        Text(
          '$score',
          style: TextStyle(
            color: Colors.white,
            fontSize: fontSize,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}