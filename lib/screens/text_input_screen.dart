import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/api_config.dart';
import '../theme/app_theme.dart';
import '../widgets/app_menu.dart';

class TextInputScreen extends StatefulWidget {
  const TextInputScreen({Key? key}) : super(key: key);

  @override
  State<TextInputScreen> createState() => _TextInputScreenState();
}

class _TextInputScreenState extends State<TextInputScreen> {
  // IMPORTANT:
  // Make sure this matches the IPv4 address of the computer
  // running your Flask backend.
  static const String backendUrl = ApiConfig.backendUrl;

  late final TextEditingController _controller;

  final List<String> _moods = [
    'Anxious',
    'Overwhelmed',
    'Tired',
    'Stressed',
    'Unfocused',
  ];

  final List<String> _selectedMoods = [];

  bool _isLoading = false;
  String? _aiResponse;

  // ============================================================
  // AUTH HEADERS FOR FLASK
  // ============================================================
  // Flask checks this token to know which user is asking, so the database
  // row-level security policies (auth.uid() = user_id) pass.

  Map<String, String> get _authHeaders => {
    'Content-Type': 'application/json',
    'Authorization':
        'Bearer ${Supabase.instance.client.auth.currentSession?.accessToken ?? ''}',
  };

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final args = ModalRoute.of(context)?.settings.arguments;

    if (args is String && _controller.text.isEmpty) {
      _controller.text = args;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // ============================================================
  // SEND TEXT TO FLASK BACKEND
  // ============================================================

  Future<void> _submitResponse() async {
    final message = _controller.text.trim();
    final user = Supabase.instance.client.auth.currentUser;

    // ------------------------------------------------------------
    // Validate message
    // ------------------------------------------------------------

    if (message.isEmpty) {
      _showError('Please enter what is on your mind.');
      return;
    }

    // ------------------------------------------------------------
    // Validate mood
    // ------------------------------------------------------------

    if (_selectedMoods.isEmpty) {
      _showError('Please select at least one mood.');
      return;
    }

    // ------------------------------------------------------------
    // Validate logged-in user
    // ------------------------------------------------------------

    if (user == null) {
      _showError('You are not logged in.');
      return;
    }

    setState(() {
      _isLoading = true;
      _aiResponse = null;
    });

    try {
      // The first selected mood becomes the primary mood.
      final String primaryMood = _selectedMoods.first;

      // ----------------------------------------------------------
      // Debug information
      // ----------------------------------------------------------

      debugPrint('========================================');
      debugPrint('TEXT INPUT → FLASK BACKEND');
      debugPrint('Backend: $backendUrl/chat');
      debugPrint('User ID: ${user.id}');
      debugPrint('Message: $message');
      debugPrint('Primary Mood: $primaryMood');
      debugPrint('Selected Moods: $_selectedMoods');
      debugPrint('========================================');

      // ----------------------------------------------------------
      // Send request to Flask
      // ----------------------------------------------------------

      final response = await http
          .post(
            Uri.parse('$backendUrl/chat'),
            headers: _authHeaders,
            body: jsonEncode({
              'message': message,
              'user_id': user.id,
              'user_name':
                  (user.userMetadata?['full_name'] ??
                          user.userMetadata?['name'] ??
                          '')
                      .toString(),
              'mood': primaryMood,
              'selected_moods': _selectedMoods,
            }),
          )
          .timeout(const Duration(seconds: 60));

      // ----------------------------------------------------------
      // Debug backend response
      // ----------------------------------------------------------

      debugPrint('Backend status: ${response.statusCode}');

      debugPrint('Backend response: ${response.body}');

      // ----------------------------------------------------------
      // Check HTTP status
      // ----------------------------------------------------------

      if (response.statusCode != 200) {
        throw Exception(
          'Backend returned ${response.statusCode}: ${response.body}',
        );
      }

      // ----------------------------------------------------------
      // Decode JSON
      // ----------------------------------------------------------

      final dynamic decoded = jsonDecode(response.body);

      if (decoded is! Map<String, dynamic>) {
        throw Exception('Invalid response from backend.');
      }

      // ----------------------------------------------------------
      // Get AI response
      // ----------------------------------------------------------

      final String? aiResponse = decoded['response']?.toString().trim();

      if (aiResponse == null || aiResponse.isEmpty) {
        throw Exception('The backend returned an empty AI response.');
      }

      // ----------------------------------------------------------
      // Get database save status from Flask
      // ----------------------------------------------------------

      final bool chatSaved = decoded['chat_saved'] == true;

      final bool moodSaved = decoded['mood_saved'] == true;

      final String savedMood = decoded['mood']?.toString() ?? primaryMood;

      debugPrint('========================================');
      debugPrint('FLASK SAVE RESULT');
      debugPrint('Chat saved: $chatSaved');
      debugPrint('Mood saved: $moodSaved');
      debugPrint('Mood: $savedMood');
      debugPrint('========================================');

      if (!mounted) {
        return;
      }

      // ----------------------------------------------------------
      // Display AI response
      // ----------------------------------------------------------

      setState(() {
        _aiResponse = aiResponse;
        _isLoading = false;
      });

      // ----------------------------------------------------------
      // Show database result
      // ----------------------------------------------------------

      if (chatSaved && moodSaved) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('AI response and mood saved successfully.'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
      } else if (chatSaved && !moodSaved) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'AI response was saved, but the mood could not be saved.',
            ),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 4),
          ),
        );
      } else if (!chatSaved && moodSaved) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Mood was saved, but chat history could not be saved.',
            ),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 4),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('AI responded, but the data could not be saved.'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 4),
          ),
        );
      }
    } catch (error) {
      debugPrint('========================================');
      debugPrint('❌ TEXT INPUT ERROR');
      debugPrint('$error');
      debugPrint('========================================');

      if (!mounted) {
        return;
      }

      setState(() {
        _isLoading = false;
      });

      _showError('Could not get AI response: $error');
    }
  }

  // ============================================================
  // OPEN ADVICE SCREEN
  // ============================================================

  void _openAdvice() {
    Navigator.pushNamed(
      context,
      '/advice',
      arguments: {
        'text': _controller.text.trim(),
        'moods': List<String>.from(_selectedMoods),
        'aiResponse': _aiResponse,
      },
    );
  }

  // ============================================================
  // SHOW ERROR
  // ============================================================

  void _showError(String message) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  // ============================================================
  // BUILD UI
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: AppTheme.lightColor,

      // ----------------------------------------------------------
      // APP BAR
      // ----------------------------------------------------------
      appBar: AppBar(
        backgroundColor: AppTheme.primaryColor,
        elevation: 0,

        leading: AppMenuButton(backEnabled: !_isLoading),
        leadingWidth: AppMenu.leadingWidthFor(context),

        title: Text(
          'Text Input',
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ),

      // ----------------------------------------------------------
      // BODY
      // ----------------------------------------------------------
      body: SafeArea(
        child: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --------------------------------------------------
              // TITLE
              // --------------------------------------------------
              Text(
                "What's on your mind?",
                style: GoogleFonts.poppins(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.darkColor,
                ),
              ),

              const SizedBox(height: 8),

              Text(
                'Write freely and our AI assistant will respond.',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: const Color(0xFF999999),
                ),
              ),

              const SizedBox(height: 24),

              // --------------------------------------------------
              // TEXT INPUT
              // --------------------------------------------------
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.primaryColor, width: 2),
                ),
                child: TextField(
                  controller: _controller,
                  enabled: !_isLoading,
                  maxLines: 6,

                  decoration: InputDecoration(
                    hintText:
                        'I\'ve been feeling really overwhelmed with all my deadlines. The pressure from exams is building up and I find it hard to focus on anything...',

                    hintStyle: GoogleFonts.poppins(
                      color: const Color(0xFFCCCCCC),
                      fontSize: 14,
                    ),

                    border: InputBorder.none,

                    contentPadding: const EdgeInsets.all(16),
                  ),

                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: AppTheme.darkColor,
                  ),
                ),
              ),

              const SizedBox(height: 32),

              // --------------------------------------------------
              // MOOD TITLE
              // --------------------------------------------------
              Text(
                'TAG YOUR MOOD',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF999999),
                  letterSpacing: 0.5,
                ),
              ),

              const SizedBox(height: 16),

              // --------------------------------------------------
              // MOOD BUTTONS
              // --------------------------------------------------
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: _moods.map((mood) {
                  final bool isSelected = _selectedMoods.contains(mood);

                  return GestureDetector(
                    onTap: _isLoading
                        ? null
                        : () {
                            setState(() {
                              if (isSelected) {
                                _selectedMoods.remove(mood);
                              } else {
                                _selectedMoods.add(mood);
                              }
                            });
                          },

                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),

                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppTheme.primaryColor
                            : Colors.white,

                        border: Border.all(
                          color: isSelected
                              ? AppTheme.primaryColor
                              : const Color(0xFFE0E0E0),
                        ),

                        borderRadius: BorderRadius.circular(20),
                      ),

                      child: Text(
                        mood,
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: isSelected ? Colors.white : AppTheme.darkColor,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),

              const SizedBox(height: 32),

              // --------------------------------------------------
              // SEND BUTTON
              // --------------------------------------------------
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _submitResponse,

                  child: _isLoading
                      ? const SizedBox(
                          width: 22,
                          height: 22,

                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        )
                      : Text(
                          'Send to AI Assistant',
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),

              // --------------------------------------------------
              // AI RESPONSE
              // --------------------------------------------------
              if (_aiResponse != null) ...[
                const SizedBox(height: 28),

                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),

                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),

                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),

                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,

                    children: [
                      // ------------------------------------------
                      // AI HEADER
                      // ------------------------------------------
                      Row(
                        children: [
                          Icon(
                            Icons.auto_awesome,
                            color: AppTheme.primaryColor,
                          ),

                          const SizedBox(width: 8),

                          Text(
                            'AI Assistant',
                            style: GoogleFonts.poppins(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.darkColor,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 12),

                      // ------------------------------------------
                      // AI TEXT
                      // ------------------------------------------
                      Text(
                        _aiResponse!,
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          height: 1.5,
                          color: AppTheme.darkColor,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // ----------------------------------------------
                // ADVICE BUTTON
                // ----------------------------------------------
                SizedBox(
                  width: double.infinity,

                  child: OutlinedButton(
                    onPressed: _isLoading ? null : _openAdvice,

                    child: Text(
                      'View Personalized Advice →',
                      style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}