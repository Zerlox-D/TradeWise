import 'package:flutter/material.dart';
import '../api_service.dart';
import '../widgets/profile_icon.dart';

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
  AnimationController? _animationController;
  Animation<double>? _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _slideAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController!, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _animationController?.dispose();
    _codeController.dispose();
    super.dispose();
  }

  void _searchMentor() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSearching = true;
      _foundMentor = null;
      _hasSearched = false;
      _requestSent = false;
    });

    // 1. Search for the mentor
    final result = await ApiService.searchMentor(_codeController.text);
    bool isAlreadyRequested = false;

    // 2. If we found a mentor, check if we already sent them a request
    if (result != null) {
      final myLinks = await ApiService.getMentorLinks();

      for (var link in myLinks) {
        // Check if the mentor ID matches AND the status is still pending
        if (link['mentor'] == result['id'] && link['status'] == 'PENDING') {
          isAlreadyRequested = true;
          break; // Stop searching the list once we find it
        }
      }
    }

    setState(() {
      _isSearching = false;
      _foundMentor = result;
      _hasSearched = true;
      _requestSent =
          isAlreadyRequested; // Will be true if they already sent a request!
    });

    if (result != null) {
      _animationController!.forward(from: 0.0);
    }
  }

  void _sendRequest() async {
    setState(() => _isSending = true);

    // 1. Now we expect an error message back (or null if successful)
    String? errorMessage = await ApiService.sendMentorRequest(
      _foundMentor!['id'],
    );

    setState(() => _isSending = false);

    if (!mounted) return;

    if (errorMessage == null) {
      // SUCCESS: It returned null, meaning no errors!
      setState(() {
        _requestSent = true;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 12),
              Text("Request Sent! Wait for approval."),
            ],
          ),
          backgroundColor: Colors.green[700],
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    } else {
      // ERROR: Show the exact message Django sent us
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error_outline, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(
                child: Text(errorMessage),
              ), // Displays Django's custom message
            ],
          ),
          backgroundColor: Colors.red[700],
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E21),

      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 40),

                // Back Button
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                    ProfileIconButton(),
                  ],
                ),

                const SizedBox(height: 30),

                // Header Icon
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF00E676), Color(0xFF00BFA5)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Color(0xFF00E676),
                          blurRadius: 20,
                          spreadRadius: 1,
                          offset: Offset(0, 0),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.person_search,
                      size: 60,
                      color: Color(0xFF0A0E21),
                    ),
                  ),
                ),

                const SizedBox(height: 40),

                // Title
                const Center(
                  child: Text(
                    'Find Your Mentor',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      letterSpacing: -0.5,
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Subtitle
                Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF151A30),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF1E2440)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: Colors.grey[500],
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Ask your Mentor for their unique Code',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[400],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 50),

                // Search Form
                Form(
                  key: _formKey,
                  child: TextFormField(
                    controller: _codeController,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: Colors.white, fontSize: 18),
                    textAlign: TextAlign.center,
                    decoration: InputDecoration(
                      labelText: 'Enter Mentor Code',
                      labelStyle: TextStyle(color: Colors.grey[500]),
                      hintText: 'e.g., 12345',
                      hintStyle: TextStyle(color: Colors.grey[700]),
                      prefixIcon: const Icon(
                        Icons.tag,
                        color: Color(0xFF00E676),
                      ),
                      suffixIcon: Container(
                        margin: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF00E676),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: IconButton(
                          icon: const Icon(
                            Icons.search,
                            color: Color(0xFF0A0E21),
                          ),
                          onPressed: _isSearching ? null : _searchMentor,
                        ),
                      ),
                      filled: true,
                      fillColor: const Color(0xFF151A30),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: Color(0xFF1E2440),
                          width: 1,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: Color(0xFF00E676),
                          width: 2,
                        ),
                      ),
                      errorBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: Color(0xFFFF5252),
                          width: 1,
                        ),
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter a mentor code';
                      }
                      return null;
                    },
                  ),
                ),

                const SizedBox(height: 50),

                // Result Area
                if (_isSearching)
                  Center(
                    child: Column(
                      children: [
                        const CircularProgressIndicator(
                          color: Color(0xFF00E676),
                          strokeWidth: 3,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          "Searching...",
                          style: TextStyle(
                            color: Colors.grey[400],
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),

                // No Mentor Found Message
                if (_hasSearched && _foundMentor == null && !_isSearching)
                  Center(
                    child: Container(
                      padding: const EdgeInsets.all(30),
                      decoration: BoxDecoration(
                        color: const Color(0xFF151A30),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFF1E2440)),
                      ),
                      child: Column(
                        children: [
                          Icon(
                            Icons.person_off_outlined,
                            size: 60,
                            color: Colors.grey[600],
                          ),
                          const SizedBox(height: 20),
                          Text(
                            "No Mentor Found",
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey[400],
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            "We couldn't find a mentor with that code.\nPlease check and try again.",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[500],
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                if (_foundMentor != null && _slideAnimation != null)
                  SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0, 0.3),
                      end: Offset.zero,
                    ).animate(_slideAnimation!),
                    child: FadeTransition(
                      opacity: _slideAnimation!,
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: const Color(0xFF151A30),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: const Color(0xFF00E676).withOpacity(0.2),
                            width: 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF00E676).withOpacity(0.05),
                              blurRadius: 12,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            // Mentor Avatar
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: const BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Color(0xFF00E676),
                                    Color(0xFF00BFA5),
                                  ],
                                ),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.person_pin,
                                size: 50,
                                color: Color(0xFF0A0E21),
                              ),
                            ),

                            const SizedBox(height: 15),

                            // Mentor Name
                            Text(
                              _foundMentor!['username'],
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),

                            const SizedBox(height: 8),

                            // Mentor Code Badge
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1E2440),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: const Color(0xFF2A3258),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.tag,
                                    color: Color(0xFF00E676),
                                    size: 14,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    "ID: ${_foundMentor!['mentor_code']}",
                                    style: const TextStyle(
                                      color: Color(0xFF00E676),
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 16),

                            // Risk Profile Badge
                            Builder(
                              builder: (context) {
                                final riskProfile =
                                    _foundMentor!['risk_profile'] as String? ??
                                    '';
                                final riskColor =
                                    riskProfile == 'Low' ||
                                        riskProfile == 'Conservative'
                                    ? const Color(0xFF00E676)
                                    : riskProfile == 'Moderate'
                                    ? const Color(0xFFFFB74D)
                                    : riskProfile == 'High' ||
                                          riskProfile == 'Aggressive'
                                    ? const Color(0xFFFF5252)
                                    : const Color(0xFF42A5F5);
                                return Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: riskColor.withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: riskColor.withOpacity(0.3),
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
                                        'Risk: $riskProfile',
                                        style: TextStyle(
                                          color: riskColor,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),

                            const SizedBox(height: 30),

                            // Connect Button
                            SizedBox(
                              width: double.infinity,
                              height: 56,
                              child: ElevatedButton(
                                // Disable the button if it's sending OR if it's already sent
                                onPressed: (_isSending || _requestSent)
                                    ? null
                                    : _sendRequest,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _requestSent
                                      ? const Color(0xFF1E2440)
                                      : const Color(0xFF00E676),
                                  disabledBackgroundColor: const Color(
                                    0xFF1E2440,
                                  ),
                                  foregroundColor: _requestSent
                                      ? const Color(0xFF00E676)
                                      : const Color(0xFF0A0E21),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  elevation: 0,
                                ),
                                child: _isSending
                                    ? const SizedBox(
                                        height: 24,
                                        width: 24,
                                        child: CircularProgressIndicator(
                                          color: Colors.white,
                                          strokeWidth: 2.5,
                                        ),
                                      )
                                    : _requestSent
                                    ? const Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            Icons.check_circle_outline,
                                            color: Color(0xFF00E676),
                                            size: 18,
                                          ),
                                          SizedBox(width: 8),
                                          Text(
                                            'REQUEST SENT',
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                              letterSpacing: 1.2,
                                              color: Color(0xFF00E676),
                                            ),
                                          ),
                                        ],
                                      )
                                    : const Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            Icons.link,
                                            color: Color(0xFF0A0E21),
                                          ),
                                          SizedBox(width: 8),
                                          Text(
                                            'CONNECT',
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                              letterSpacing: 1.2,
                                              color: Color(0xFF0A0E21),
                                            ),
                                          ),
                                        ],
                                      ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
