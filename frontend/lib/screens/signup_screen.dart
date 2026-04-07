import 'package:flutter/material.dart';
import '../api_service.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _usernameController        = TextEditingController();
  final TextEditingController _emailController           = TextEditingController();
  final TextEditingController _passwordController        = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _isLoading            = false;
  bool _obscurePassword      = true;
  bool _obscureConfirmPassword = true;
  String _selectedRole       = 'INVESTOR';
  DateTime? _selectedDate;
  AnimationController? _animationController;
  Animation<double>? _fadeAnimation;

  // ── Brand palette ──────────────────────────────────────────────────────────
  static const _bg     = Color(0xFF0A0E21);
  static const _card   = Color(0xFF151A30);
  static const _border = Color(0xFF1E2440);
  static const _green  = Color(0xFF00E676);
  static const _amber  = Color(0xFFFFB74D);
  static const _red    = Color(0xFFFF5252);

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController!, curve: Curves.easeOut),
    );
    _animationController!.forward();
  }

  @override
  void dispose() {
    _animationController?.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime(2000),
      firstDate: DateTime(1950),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: _green,
              onPrimary: _bg,
              surface: _card,
              onSurface: Colors.white,
            ),
            dialogBackgroundColor: _bg,
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedDate) {
      setState(() => _selectedDate = picked);
    }
  }

  int _calculateAge(DateTime birthDate) {
    final now = DateTime.now();
    int age = now.year - birthDate.year;
    if (now.month < birthDate.month ||
        (now.month == birthDate.month && now.day < birthDate.day)) {
      age--;
    }
    return age;
  }

  void _handleSignup() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedDate == null) {
      _showSnackbar(
        'Please select your date of birth.',
        Icons.error_outline_rounded,
        _amber,
      );
      return;
    }

    int age = _calculateAge(_selectedDate!);
    if (_selectedRole == 'MENTOR' && age < 21) {
      _showSnackbar(
        'Mentors must be at least 21 years old.',
        Icons.error_outline_rounded,
        _red,
      );
      return;
    }

    final dobString =
        '${_selectedDate!.year}-${_selectedDate!.month.toString().padLeft(2, '0')}-${_selectedDate!.day.toString().padLeft(2, '0')}';

    setState(() => _isLoading = true);

    bool success = await ApiService.register(
      _usernameController.text.trim(),
      _emailController.text.trim(),
      _passwordController.text,
      dobString,
      _selectedRole,
    );

    setState(() => _isLoading = false);
    if (!mounted) return;

    if (success) {
      _showSnackbar(
        'Account created! Please log in.',
        Icons.check_circle_outline_rounded,
        _green,
      );
      Navigator.pop(context);
    } else {
      _showSnackbar(
        'Signup failed. Try a different username.',
        Icons.error_outline_rounded,
        _red,
      );
    }
  }

  void _showSnackbar(String message, IconData icon, Color iconColor) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: iconColor, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(message,
                  style: const TextStyle(color: Colors.white)),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnimation ?? const AlwaysStoppedAnimation(1.0),
          child: _buildContent(),
        ),
      ),
    );
  }

  Widget _buildContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 56),

            // ── Brand mark ────────────────────────────────────────────────
            Center(
              child: Column(
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: const Color.fromARGB(255, 4, 20, 13),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color.fromARGB(255, 4, 196, 103).withOpacity(0.3)),
                    ),
                    child: const Icon(
                      Icons.bolt_rounded,
                      size: 40,
                      color: _green,
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'TRADEWISE',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: 3,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Smart Trading, Smarter Decisions',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[500],
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 48),

            // ── Page heading ──────────────────────────────────────────────
            Row(
              children: [
                Container(
                  width: 3,
                  height: 22,
                  decoration: BoxDecoration(
                    color: _green,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 10),
                const Text(
                  'Create Account',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    letterSpacing: -0.5,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.only(left: 13),
              child: Text(
                'Sign up to start trading',
                style: TextStyle(fontSize: 14, color: Colors.grey[500]),
              ),
            ),

            const SizedBox(height: 32),

            // ── Username ──────────────────────────────────────────────────
            _fieldLabel('Username'),
            const SizedBox(height: 8),
            _buildField(
              controller: _usernameController,
              hint: 'Enter your username',
              icon: Icons.person_outline_rounded,
              validator: (v) {
                if (v == null || v.trim().isEmpty)
                  return 'Please enter a username';
                if (v.trim().length < 3)
                  return 'Username must be at least 3 characters';
                return null;
              },
            ),

            const SizedBox(height: 20),

            // ── Date of Birth ─────────────────────────────────────────────
            _fieldLabel('Date of Birth'),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () => _selectDate(context),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 16),
                decoration: BoxDecoration(
                  color: _card,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _selectedDate != null
                        ? _green.withOpacity(0.5)
                        : _border,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.calendar_month_outlined,
                      color: _selectedDate != null
                          ? _green
                          : Colors.grey[600],
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _selectedDate == null
                            ? 'Select your date of birth'
                            : '${_selectedDate!.day.toString().padLeft(2, '0')}/${_selectedDate!.month.toString().padLeft(2, '0')}/${_selectedDate!.year}',
                        style: TextStyle(
                          color: _selectedDate == null
                              ? Colors.grey[700]
                              : Colors.white,
                          fontSize: 15,
                        ),
                      ),
                    ),
                    Icon(Icons.chevron_right_rounded,
                        color: Colors.grey[600], size: 20),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // ── Email ─────────────────────────────────────────────────────
            _fieldLabel('Email'),
            const SizedBox(height: 8),
            _buildField(
              controller: _emailController,
              hint: 'Enter your email address',
              icon: Icons.mail_outline_rounded,
              keyboardType: TextInputType.emailAddress,
              validator: (v) {
                if (v == null || v.trim().isEmpty)
                  return 'Please enter your email';
                if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$')
                    .hasMatch(v))
                  return 'Please enter a valid email';
                return null;
              },
            ),

            const SizedBox(height: 20),

            // ── Password ──────────────────────────────────────────────────
            _fieldLabel('Password'),
            const SizedBox(height: 8),
            _buildField(
              controller: _passwordController,
              hint: 'Create a password',
              icon: Icons.lock_outline_rounded,
              obscure: _obscurePassword,
              toggleObscure: () =>
                  setState(() => _obscurePassword = !_obscurePassword),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Please enter a password';
                if (v.length < 6)
                  return 'Password must be at least 6 characters';
                return null;
              },
            ),

            const SizedBox(height: 20),

            // ── Confirm Password ──────────────────────────────────────────
            _fieldLabel('Confirm Password'),
            const SizedBox(height: 8),
            _buildField(
              controller: _confirmPasswordController,
              hint: 'Re-enter your password',
              icon: Icons.lock_outline_rounded,
              obscure: _obscureConfirmPassword,
              toggleObscure: () => setState(
                  () => _obscureConfirmPassword = !_obscureConfirmPassword),
              validator: (v) {
                if (v == null || v.isEmpty)
                  return 'Please confirm your password';
                if (v != _passwordController.text)
                  return 'Passwords do not match';
                return null;
              },
            ),

            const SizedBox(height: 20),

            // ── Role selector ─────────────────────────────────────────────
            _fieldLabel('I am a/an'),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: _card,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _border),
              ),
              child: DropdownButtonFormField<String>(
                value: _selectedRole,
                dropdownColor: _card,
                style: const TextStyle(color: Colors.white, fontSize: 15),
                iconEnabledColor: Colors.grey[600],
                decoration: InputDecoration(
                  hintText: 'Select your role',
                  hintStyle:
                      TextStyle(color: Colors.grey[700], fontSize: 14),
                  prefixIcon: Icon(Icons.badge_outlined,
                      color: Colors.grey[600], size: 20),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 16),
                  border: InputBorder.none,
                ),
                items: const [
                  DropdownMenuItem(value: 'INVESTOR', child: Text('Investor')),
                  DropdownMenuItem(value: 'MENTOR', child: Text('Mentor')),
                ],
                onChanged: (value) => setState(() => _selectedRole = value!),
              ),
            ),

            const SizedBox(height: 36),

            // ── Sign up button ────────────────────────────────────────────
            GestureDetector(
              onTap: _isLoading ? null : _handleSignup,
              child: Container(
                width: double.infinity,
                height: 54,
                decoration: BoxDecoration(
                  color: _isLoading ? _border : _green.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: _isLoading
                        ? Colors.transparent
                        : _green.withOpacity(0.4),
                  ),
                ),
                child: Center(
                  child: _isLoading
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(
                              color: _green, strokeWidth: 2.5),
                        )
                      : const Text(
                          'CREATE ACCOUNT',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.5,
                            color: _green,
                          ),
                        ),
                ),
              ),
            ),

            const SizedBox(height: 28),

            // ── Login link ────────────────────────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Already have an account? ',
                  style: TextStyle(color: Colors.grey[500], fontSize: 13),
                ),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: const Text(
                    'Login',
                    style: TextStyle(
                      color: _green,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────────────
  Widget _fieldLabel(String label) {
    return Text(
      label,
      style: TextStyle(
        color: Colors.grey[500],
        fontSize: 12,
        fontWeight: FontWeight.w500,
      ),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool obscure = false,
    VoidCallback? toggleObscure,
    String? Function(String?)? validator,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboardType,
      style: const TextStyle(color: Colors.white, fontSize: 15),
      validator: validator,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Colors.grey[700], fontSize: 14),
        prefixIcon: Icon(icon, color: Colors.grey[600], size: 20),
        suffixIcon: toggleObscure != null
            ? IconButton(
                icon: Icon(
                  obscure
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  color: Colors.grey[600],
                  size: 20,
                ),
                onPressed: toggleObscure,
              )
            : null,
        filled: true,
        fillColor: _card,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
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
          borderSide: const BorderSide(color: _green, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _red),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _red, width: 1.5),
        ),
        errorStyle: const TextStyle(color: _red),
      ),
    );
  }
}