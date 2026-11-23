import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme/app_theme.dart';
import '../services/home_route.dart';
import '../services/auth_service.dart';
import '../services/emergency_contact_service.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({Key? key}) : super(key: key);

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();

  // The emergency contact section has its own form key, so the Google
  // sign-up button can check just these fields.
  final _emergencyKey = GlobalKey<FormState>();

  // A real-looking email address: name@domain.tld (letters, digits, . _ % + -)
  static final RegExp _emailPattern = RegExp(
    r'^[A-Za-z0-9._%+\-]+@[A-Za-z0-9\-]+(\.[A-Za-z0-9\-]+)*\.[A-Za-z]{2,}$',
  );

  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _studentIdController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  final _contactNameController = TextEditingController();
  final _contactPhoneController = TextEditingController();
  String _relationship = '';
  bool _consent = false;

  static const List<String> _relationships = [
    'Parent',
    'Guardian',
    'Sibling',
    'Other relative',
    'Friend',
    'Partner',
    'Other',
  ];

  bool _isLoading = false;
  bool _isGoogleLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;

  bool get _busy => _isLoading || _isGoogleLoading;

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _studentIdController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _contactNameController.dispose();
    _contactPhoneController.dispose();
    super.dispose();
  }

  // ============================================================
  // EMERGENCY CONTACT HELPERS
  // ============================================================

  /// Saves the contact right away when there is a login session. If this
  /// fails, the copy kept in the account profile is saved at first login.
  Future<void> _saveEmergencyContact(String name, String phone) async {
    try {
      await EmergencyContactService.save(
        name: name,
        relationship: _relationship,
        phone: phone,
      );
      await EmergencyContactService.clearMetadataCopy();
    } catch (e) {
      debugPrint('Emergency contact save failed (will retry at login): $e');
    }
  }

  // ============================================================
  // EMAIL REGISTRATION
  // ============================================================

  void _register() async {
    // Check both sections so every missing field shows its error.
    final accountOk = _formKey.currentState!.validate();
    final contactOk = _emergencyKey.currentState!.validate();

    if (!accountOk || !contactOk) return;

    setState(() => _isLoading = true);

    try {
      final fullName = _fullNameController.text.trim();
      final email = _emailController.text.trim();
      final studentId = _studentIdController.text.trim();

      final contactName = _contactNameController.text.trim();
      final contactPhone =
          EmergencyContactService.normalizePhone(
            _contactPhoneController.text,
          ) ??
          '';

      final res = await Supabase.instance.client.auth.signUp(
        email: email,
        password: _passwordController.text,
        // The verification link opens the app.
        emailRedirectTo: 'io.supabase.chatress://login-callback/',
        data: {
          'full_name': fullName,
          'student_id': studentId,
          // Kept here until the first login if the email must be verified.
          'emergency_contact_name': contactName,
          'emergency_relationship': _relationship,
          'emergency_phone': contactPhone,
          'emergency_consent': true,
        },
      );

      final user = res.user;

      if (user == null) {
        throw Exception('Registration failed.');
      }

      // Supabase does not say outright that an email is taken. An empty
      // identities list means an account with this email already exists.
      if (user.identities != null && user.identities!.isEmpty) {
        throw Exception(
          'This email is already registered. Please log in or reset your '
          'password.',
        );
      }

      if (res.session != null) {
        await AuthService.ensureProfile(
          userId: user.id,
          email: email,
          fullName: fullName,
          studentId: studentId,
        );

        await _saveEmergencyContact(contactName, contactPhone);
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            res.session == null
                ? 'We sent a verification link to $email. Open it to '
                      'activate your account, then log in.'
                : 'Successfully registered!',
          ),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 7),
        ),
      );

      Navigator.of(context).pushReplacementNamed('/login');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Registration failed: ${e.toString().replaceFirst('Exception: ', '')}',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // ============================================================
  // GOOGLE SIGN UP
  // ============================================================

  Future<void> _registerWithGoogle() async {
    // Google sign-up skips the password fields, but the emergency contact
    // is still required.
    if (!_emergencyKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please complete your emergency contact first.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isGoogleLoading = true);

    try {
      final signedIn = await AuthService.signInWithGoogle();

      if (signedIn) {
        await _saveEmergencyContact(
          _contactNameController.text.trim(),
          EmergencyContactService.normalizePhone(
                _contactPhoneController.text,
              ) ??
              '',
        );
      }

      if (signedIn && mounted) {
        final route = await HomeRoute.resolve();
        if (!mounted) return;
        Navigator.of(context).pushReplacementNamed(route);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Google registration failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isGoogleLoading = false);
      }
    }
  }

  // ============================================================
  // EMERGENCY CONTACT SECTION (UI)
  // ============================================================

  Widget _buildEmergencySection() {
    return Form(
      key: _emergencyKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Emergency contact',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppTheme.darkColor,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Someone we can call if you may be in danger. Choose a person '
            'you trust. It does not have to be family.',
            style: GoogleFonts.poppins(
              fontSize: 13,
              height: 1.4,
              color: const Color(0xFF999999),
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _contactNameController,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              hintText: 'Contact name',
              prefixIcon: Icon(Icons.person_outline),
            ),
            validator: (value) {
              if (value?.trim().isEmpty ?? true) {
                return 'Please enter your contact\'s name';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.family_restroom_outlined),
            ),
            hint: const Text('Relationship'),
            items: _relationships
                .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                .toList(),
            onChanged: (value) => setState(() => _relationship = value ?? ''),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please choose a relationship';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _contactPhoneController,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              hintText: 'Mobile number, e.g. 09171234567',
              prefixIcon: Icon(Icons.phone_outlined),
            ),
            validator: (value) {
              if (EmergencyContactService.normalizePhone(value ?? '') == null) {
                return 'Enter a valid number, e.g. 09171234567 or +639171234567';
              }
              return null;
            },
          ),
          const SizedBox(height: 8),
          FormField<bool>(
            initialValue: false,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            validator: (_) => _consent ? null : 'You need to agree to continue',
            builder: (state) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CheckboxListTile(
                    value: _consent,
                    onChanged: (value) {
                      setState(() => _consent = value ?? false);
                      state.didChange(_consent);
                    },
                    controlAffinity: ListTileControlAffinity.leading,
                    contentPadding: EdgeInsets.zero,
                    activeColor: AppTheme.primaryColor,
                    title: Text(
                      'I agree that if I type or say something that suggests '
                      'I may hurt myself or end my life, ChaTress may call '
                      'my emergency contact and alert my campus guidance '
                      'office so they can check on me.',
                      style: GoogleFonts.poppins(fontSize: 12, height: 1.45),
                    ),
                  ),
                  if (state.hasError)
                    Padding(
                      padding: const EdgeInsets.only(left: 12),
                      child: Text(
                        state.errorText ?? '',
                        style: const TextStyle(color: Colors.red, fontSize: 12),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  // ============================================================
  // UI
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppTheme.darkColor),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Create Account',
                style: GoogleFonts.poppins(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.darkColor,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Fill in your details to register',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: const Color(0xFF999999),
                ),
              ),
              const SizedBox(height: 32),
              TextFormField(
                controller: _fullNameController,
                decoration: const InputDecoration(
                  hintText: 'Full Name',
                  prefixIcon: Icon(Icons.person_outline),
                ),
                validator: (value) {
                  if (value?.isEmpty ?? true) {
                    return 'Please enter your full name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(
                  hintText: 'Email Address',
                  prefixIcon: Icon(Icons.email_outlined),
                ),
                keyboardType: TextInputType.emailAddress,
                validator: (value) {
                  if (value?.isEmpty ?? true) {
                    return 'Please enter your email';
                  }
                  if (!_emailPattern.hasMatch(value!.trim())) {
                    return 'Please enter a valid email address';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _studentIdController,
                decoration: const InputDecoration(
                  hintText: 'ID Number',
                  prefixIcon: Icon(Icons.badge_outlined),
                ),
                validator: (value) {
                  if (value?.isEmpty ?? true) {
                    return 'Please enter your ID';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _passwordController,
                decoration: InputDecoration(
                  hintText: 'Password',
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                    ),
                    onPressed: () =>
                        setState(() => _obscurePassword = !_obscurePassword),
                  ),
                ),
                obscureText: _obscurePassword,
                validator: (value) {
                  if (value?.isEmpty ?? true) {
                    return 'Please enter a password';
                  }
                  if ((value?.length ?? 0) < 6) {
                    return 'Password must be at least 6 characters';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _confirmPasswordController,
                decoration: InputDecoration(
                  hintText: 'Confirm Password',
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureConfirm
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                    ),
                    onPressed: () =>
                        setState(() => _obscureConfirm = !_obscureConfirm),
                  ),
                ),
                obscureText: _obscureConfirm,
                validator: (value) {
                  if (value?.isEmpty ?? true) {
                    return 'Please confirm your password';
                  }
                  if (value != _passwordController.text) {
                    return 'Passwords do not match';
                  }
                  return null;
                },
              ),

              // ---------------- EMERGENCY CONTACT ----------------
              const SizedBox(height: 32),
              _buildEmergencySection(),

              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _busy ? null : _register,
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('Register'),
                ),
              ),

              // ---------------- OR DIVIDER ----------------
              const SizedBox(height: 24),
              Row(
                children: [
                  const Expanded(child: Divider()),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text(
                      'OR',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: const Color(0xFF999999),
                      ),
                    ),
                  ),
                  const Expanded(child: Divider()),
                ],
              ),
              const SizedBox(height: 24),

              // ---------------- GOOGLE BUTTON ----------------
              SizedBox(
                width: double.infinity,
                height: 56,
                child: OutlinedButton.icon(
                  onPressed: _busy ? null : _registerWithGoogle,
                  style: OutlinedButton.styleFrom(
                    backgroundColor: Colors.white,
                    side: const BorderSide(color: Color(0xFFE0E0E0)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: _isGoogleLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text(
                          'G',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFDB4437),
                          ),
                        ),
                  label: Text(
                    'Sign up with Google',
                    style: GoogleFonts.poppins(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.darkColor,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Already have an account? ',
                    style: GoogleFonts.poppins(fontSize: 14),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.pushNamed(context, '/login'),
                    child: Text(
                      'Login',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}