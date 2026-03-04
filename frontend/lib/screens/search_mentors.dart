import 'package:flutter/material.dart';
import '../api_service.dart';
import '../widgets/profile_icon.dart';

class FindMentorScreen extends StatefulWidget {
  const FindMentorScreen({super.key});

  @override
  State<FindMentorScreen> createState() => _FindMentorScreenState();
}

class _FindMentorScreenState extends State<FindMentorScreen> with SingleTickerProviderStateMixin {
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
      _requestSent = isAlreadyRequested; // Will be true if they already sent a request!
    });
    
    if (result != null) {
      _animationController!.forward(from: 0.0);
    }
  }

  void _sendRequest() async {
    setState(() => _isSending = true);
    
    // 1. Now we expect an error message back (or null if successful)
    String? errorMessage = await ApiService.sendMentorRequest(_foundMentor!['id']);
    
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
              Expanded(child: Text(errorMessage)), // Displays Django's custom message
            ],
          ),
          backgroundColor: Colors.red[700],
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      style: IconButton.styleFrom(
                        backgroundColor: const Color(0xFF1D1E33),
                        padding: const EdgeInsets.all(12),
                      ),
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
                      gradient: LinearGradient(
                        colors: [Colors.blue[400]!, Colors.purple[400]!],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.blue.withOpacity(0.3),
                          blurRadius: 20,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.person_search,
                      size: 60,
                      color: Colors.white,
                    ),
                  ),
                ),
                
                const SizedBox(height: 40),
                
                // Title
                const Center(
                  child: Text(
                    "Find Your Mentor",
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                
                // Subtitle
                Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1D1E33),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.blue.withOpacity(0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.info_outline, color: Colors.blue[300], size: 20),
                        const SizedBox(width: 8),
                        Text(
                          "Ask your Mentor for their unique Code",
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
                      labelText: "Enter Mentor Code",
                      labelStyle: TextStyle(color: Colors.grey[400]),
                      hintText: "e.g., 12345",
                      hintStyle: TextStyle(color: Colors.grey[600]),
                      prefixIcon: Icon(Icons.tag, color: Colors.blue[300]),
                      suffixIcon: Container(
                        margin: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Colors.blue[400]!, Colors.purple[400]!],
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.search, color: Colors.white),
                          onPressed: _isSearching ? null : _searchMentor,
                        ),
                      ),
                      filled: true,
                      fillColor: const Color(0xFF1D1E33),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey[800]!, width: 1),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.blue[400]!, width: 2),
                      ),
                      errorBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Colors.red, width: 1),
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
                          color: Colors.blue,
                          strokeWidth: 3,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          "Searching...",
                          style: TextStyle(color: Colors.grey[400], fontSize: 16),
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
                        color: const Color(0xFF1D1E33),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.grey[800]!),
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
                          gradient: LinearGradient(
                            colors: [
                              const Color(0xFF1D1E33),
                              Colors.blue.withOpacity(0.1),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Colors.blue.withOpacity(0.3),
                            width: 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.blue.withOpacity(0.1),
                              blurRadius: 10,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            // Mentor Avatar
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [Colors.blue[400]!, Colors.purple[400]!],
                                ),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.person_pin,
                                size: 50,
                                color: Colors.white,
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
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [Colors.purple[400]!.withOpacity(0.3), Colors.blue[400]!.withOpacity(0.3)],
                                ),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: Colors.purple[300]!.withOpacity(0.5)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const SizedBox(width: 6),
                                  Text(
                                    "ID: ${_foundMentor!['mentor_code']}",
                                    style: TextStyle(
                                      color: Colors.purple[200],
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
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              decoration: BoxDecoration(
                                color: Colors.blue.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: Colors.blue[300]!),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.analytics, color: Colors.blue[300], size: 18),
                                  const SizedBox(width: 8),
                                  Text(
                                    "Risk Profile: ${_foundMentor!['risk_profile']}",
                                    style: TextStyle(
                                      color: Colors.blue[300],
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            
                            const SizedBox(height: 30),
                            
                            // Connect Button
                            SizedBox(
                              width: double.infinity,
                              height: 56,
                              child: ElevatedButton(
                                // Disable the button if it's sending OR if it's already sent
                                onPressed: (_isSending || _requestSent) ? null : _sendRequest,
                                style: ElevatedButton.styleFrom(
                                  // Change to green when sent
                                  backgroundColor: _requestSent ? Colors.grey[700] : Colors.blue[600],
                                  disabledBackgroundColor: Colors.grey[700],
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
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              SizedBox(width: 8),
                                              Text(
                                                "REQUEST SENT",
                                                style: TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.bold,
                                                  letterSpacing: 1.2,
                                                  color: Colors.white,
                                                ),
                                              ),
                                            ],
                                          )
                                        : const Row(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              Icon(Icons.link, color: Colors.white),
                                              SizedBox(width: 8),
                                              Text(
                                                "CONNECT",
                                                style: TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.bold,
                                                  letterSpacing: 1.2,
                                                  color: Colors.white,
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