import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../api_service.dart';

class FindMentorScreen extends StatefulWidget {
  const FindMentorScreen({super.key});

  @override
  State<FindMentorScreen> createState() => _FindMentorScreenState();
}

class _FindMentorScreenState extends State<FindMentorScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _codeController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  Map<String, dynamic>? _foundMentor;
  bool _isSearching = false;
  bool _isSending = false;
  bool _hasSearched = false;
  bool _requestSent = false;
  AnimationController? _animController;
  Animation<double>? _slideAnim;

  static const _bg = Color(0xFF0A0E21);
  static const _card = Color(0xFF151A30);
  static const _border = Color(0xFF1E2440);
  static const _green = Color(0xFF00E676);
  static const _amber = Color(0xFFFFB74D);
  static const _red = Color(0xFFFF5252);
  static const _blue = Color(0xFF42A5F5);

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _slideAnim = CurvedAnimation(
      parent: _animController!,
      curve: Curves.easeOutCubic,
    );
  }

  @override
  void dispose() {
    _animController?.dispose();
    _codeController.dispose();
    super.dispose();
  }

  void _searchMentor() async {
    if (!_formKey.currentState!.validate()) return;
    HapticFeedback.lightImpact();

    setState(() {
      _isSearching = true;
      _foundMentor = null;
      _hasSearched = false;
      _requestSent = false;
    });

    final result = await ApiService.searchMentor(_codeController.text);
    bool isAlreadyRequested = false;

    if (result != null) {
      final myLinks = await ApiService.getMentorLinks();
      for (var link in myLinks) {
        if (link['mentor'] == result['id'] && link['status'] == 'PENDING') {
          isAlreadyRequested = true;
          break;
        }
      }
    }

    setState(() {
      _isSearching = false;
      _foundMentor = result;
      _hasSearched = true;
      _requestSent = isAlreadyRequested;
    });

    if (result != null) _animController!.forward(from: 0.0);
  }

  void _sendRequest() async {
    HapticFeedback.mediumImpact();
    setState(() => _isSending = true);

    final errorMessage = await ApiService.sendMentorRequest(
      _foundMentor!['id'],
    );

    setState(() => _isSending = false);
    if (!mounted) return;

    if (errorMessage == null) {
      setState(() => _requestSent = true);
      HapticFeedback.heavyImpact();
      _showSnackbar(
        'Request sent! Waiting for approval.',
        Icons.check_circle_outline_rounded,
        _green,
      );
    } else {
      _showSnackbar(errorMessage, Icons.error_outline_rounded, _red);
    }
  }

  void _showSnackbar(String msg, IconData icon, Color col) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: col, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(msg, style: const TextStyle(color: Colors.white)),
            ),
          ],
        ),
        backgroundColor: _card,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: const BorderSide(color: _border),
        ),
      ),
    );
  }

  Color _riskColor(String risk) {
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: _card,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: _border),
                      ),
                      child: const Icon(
                        Icons.arrow_back_ios_new_rounded,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                  ),
                  const Row(
                    children: [
                      Icon(Icons.bolt_rounded, color: _green, size: 18),
                      SizedBox(width: 6),
                      Text(
                        'TRADEWISE',
                        style: TextStyle(
                          color: _green,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 38), // Placeholder for centering
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 40),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 12),
                      const Text(
                        'Find Your Mentor',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          height: 1.15,
                          letterSpacing: -1,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Enter the unique ID your mentor shared with you.',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[500],
                          height: 1.5,
                        ),
                      ),

                      const SizedBox(height: 36),
                      Container(
                        decoration: BoxDecoration(
                          color: _card,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: _border),
                        ),
                        padding: const EdgeInsets.fromLTRB(20, 20, 20, 4),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'MENTOR CODE',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 1.2,
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: _codeController,
                              keyboardType: TextInputType.number,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 38,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 6,
                              ),
                              decoration: InputDecoration(
                                hintText: '------',
                                hintStyle: TextStyle(
                                  color: _border,
                                  fontSize: 38,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 6,
                                ),
                                border: InputBorder.none,
                                isDense: true,
                                contentPadding: const EdgeInsets.only(
                                  bottom: 12,
                                ),
                              ),
                              validator: (v) {
                                if (v == null || v.trim().isEmpty) {
                                  return 'Please enter a mentor code';
                                }
                                return null;
                              },
                            ),
                            // Bottom row: error space + search trigger
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                // Inline validation hint
                                const SizedBox(width: 4),
                                // Search button inside the card
                                GestureDetector(
                                  onTap: _isSearching ? null : _searchMentor,
                                  child: Container(
                                    margin: const EdgeInsets.only(bottom: 16),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 20,
                                      vertical: 12,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Color.fromARGB(255, 4, 196, 103),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: _isSearching
                                        ? const SizedBox(
                                            width: 18,
                                            height: 18,
                                            child: CircularProgressIndicator(
                                              color: _bg,
                                              strokeWidth: 2.5,
                                            ),
                                          )
                                        : const Row(
                                            children: [
                                              Icon(
                                                Icons.search_rounded,
                                                color: _bg,
                                                size: 18,
                                              ),
                                              SizedBox(width: 6),
                                              Text(
                                                'Search',
                                                style: TextStyle(
                                                  color: _bg,
                                                  fontWeight: FontWeight.w700,
                                                  fontSize: 14,
                                                ),
                                              ),
                                            ],
                                          ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 36),
                      if (_hasSearched && _foundMentor == null && !_isSearching)
                        _buildNotFound(),
                      if (_foundMentor != null && _slideAnim != null)
                        FadeTransition(
                          opacity: _slideAnim!,
                          child: SlideTransition(
                            position: Tween<Offset>(
                              begin: const Offset(0, 0.15),
                              end: Offset.zero,
                            ).animate(_slideAnim!),
                            child: _buildMentorCard(),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotFound() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _red.withValues(alpha: 0.25)),
      ),
      child: Column(
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: _red.withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                ),
              ),
              const Icon(Icons.search_off_rounded, color: _red, size: 32),
            ],
          ),
          const SizedBox(height: 18),
          const Text(
            'No match found',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Double-check the code with your mentor\nand try again.",
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.grey[500],
              fontSize: 13,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMentorCard() {
    final riskProfile = _foundMentor!['risk_profile'] as String? ?? '';
    final riskCol = _riskColor(riskProfile);
    final username = _foundMentor!['username'] as String? ?? '?';
    final initial = username.isNotEmpty ? username[0].toUpperCase() : '?';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 3,
              height: 16,
              decoration: BoxDecoration(
                color: _green,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'Mentor found',
              style: TextStyle(
                color: Colors.grey[400],
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Large initial avatar
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    _green.withValues(alpha: 0.25),
                    _green.withValues(alpha: 0.08),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: _green.withValues(alpha: 0.3)),
              ),
              child: Center(
                child: Text(
                  initial,
                  style: const TextStyle(
                    color: _green,
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
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
                    username,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    'Mentor',
                    style: TextStyle(color: Colors.grey[500], fontSize: 13),
                  ),
                ],
              ),
            ),
          ],
        ),

        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: _statTile(
                label: 'Mentor ID',
                value: '${_foundMentor!['mentor_code']}',
                icon: Icons.tag_rounded,
                color: _blue,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _statTile(
                label: 'Risk Profile',
                value: riskProfile.isNotEmpty ? riskProfile : '-',
                icon: Icons.shield_outlined,
                color: riskCol,
              ),
            ),
          ],
        ),

        const SizedBox(height: 20),
        GestureDetector(
          onTap: (_isSending || _requestSent) ? null : _sendRequest,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: double.infinity,
            height: 54,
            decoration: BoxDecoration(
              color: _requestSent
                  ? _green.withValues(alpha: 0.08)
                  : _isSending
                  ? _border
                  : Color.fromARGB(255, 4, 196, 103),
              borderRadius: BorderRadius.circular(16),
              border: _requestSent
                  ? Border.all(color: _green.withValues(alpha: 0.3))
                  : null,
            ),
            child: Center(
              child: _isSending
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: _bg,
                        strokeWidth: 2.5,
                      ),
                    )
                  : _requestSent
                  ? const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.check_circle_outline_rounded,
                          color: _green,
                          size: 17,
                        ),
                        SizedBox(width: 8),
                        Text(
                          'REQUEST SENT',
                          style: TextStyle(
                            color: _green,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ],
                    )
                  : const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.link_rounded, color: _bg, size: 18),
                        SizedBox(width: 8),
                        Text(
                          'CONNECT',
                          style: TextStyle(
                            color: _bg,
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.5,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _statTile({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
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
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 15),
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: Colors.grey[500],
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
