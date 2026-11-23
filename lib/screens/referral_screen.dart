import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/guidance_config.dart';
import '../theme/app_theme.dart';
import '../widgets/app_menu.dart';

/// Put this file in lib/screens/referral_screen.dart
///
/// Lets a student ask the guidance office for help. The main button notifies
/// guidance automatically (Supabase edge function "notify-guidance"). Calling
/// and emailing directly are still available as extra options.
class ReferralScreen extends StatefulWidget {
  const ReferralScreen({Key? key, this.stressSummary}) : super(key: key);

  /// Optional latest result, for example "Moderate stress (45%)".
  final String? stressSummary;

  @override
  State<ReferralScreen> createState() => _ReferralScreenState();
}

class _ReferralScreenState extends State<ReferralScreen> {
  final _noteController = TextEditingController();
  bool _includeAssessment = true;
  bool _sending = false;
  bool _sent = false;

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  User? get _user => Supabase.instance.client.auth.currentUser;

  String get _userName {
    final meta = _user?.userMetadata;
    final name = (meta?['full_name'] ?? meta?['name'] ?? '').toString().trim();
    if (name.isNotEmpty) return name;
    return _user?.email?.split('@').first ?? 'A student';
  }

  String _buildEmailBody() {
    final email = _user?.email;
    final who = email == null ? _userName : '$_userName ($email)';

    final lines = <String>[
      'Hello ${GuidanceConfig.officeName},',
      '',
      'My name is $who.',
      'I would like to ask for guidance and support.',
    ];

    if (_includeAssessment && widget.stressSummary != null) {
      lines.add('');
      lines.add('My latest stress assessment result: ${widget.stressSummary}.');
    }

    final note = _noteController.text.trim();
    if (note.isNotEmpty) {
      lines.add('');
      lines.add('Message from me:');
      lines.add(note);
    }

    lines.add('');
    lines.add('Sent from the ChaTress app.');

    return lines.join('\n');
  }

  void _snack(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  // ---------------- AUTOMATIC NOTIFICATION ----------------

  Future<void> _sendRequest() async {
    if (_sending || _sent) return;
    setState(() => _sending = true);

    try {
      await Supabase.instance.client.functions.invoke(
        'notify-guidance',
        body: {
          'note': _noteController.text.trim(),
          'stress_summary': _includeAssessment ? widget.stressSummary : null,
        },
      );
      if (!mounted) return;
      setState(() => _sent = true);
    } on FunctionException catch (e) {
      if (!mounted) return;
      if (e.status == 429) {
        _snack(
          'You already sent a request a few minutes ago. Guidance has it.',
        );
      } else if (e.status == 401) {
        _snack('Please sign in again, then try once more.');
      } else {
        _snack(
          'We could not notify guidance right now. '
          'Please try again, or use the call or email option.',
        );
      }
    } catch (_) {
      if (!mounted) return;
      _snack(
        'We could not notify guidance right now. '
        'Please check your connection and try again.',
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  // ---------------- CALL / EMAIL (OPTIONAL EXTRAS) ----------------

  Future<void> _open(Uri uri, String failMessage) async {
    try {
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok && mounted) _snack(failMessage);
    } catch (_) {
      if (mounted) _snack(failMessage);
    }
  }

  void _call() {
    final number = GuidanceConfig.phone.replaceAll(RegExp(r'[^0-9+]'), '');
    _open(
      Uri(scheme: 'tel', path: number),
      'Could not open the phone app. The number is ${GuidanceConfig.phone}',
    );
  }

  void _sendEmail() {
    final subject = 'Request for guidance - $_userName';
    final uri = Uri.parse(
      'mailto:${GuidanceConfig.email}'
      '?subject=${Uri.encodeComponent(subject)}'
      '&body=${Uri.encodeComponent(_buildEmailBody())}',
    );
    _open(
      uri,
      'Could not open an email app. You can write to ${GuidanceConfig.email}',
    );
  }

  Future<void> _copy(String text, String label) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    _snack('$label copied');
  }

  @override
  Widget build(BuildContext context) {
    final hasContact = GuidanceConfig.hasPhone || GuidanceConfig.hasEmail;

    return Scaffold(
      backgroundColor: AppTheme.lightColor,
      appBar: AppBar(
        backgroundColor: AppTheme.primaryColor,
        elevation: 0,
        leading: const AppMenuButton(),
        leadingWidth: AppMenu.leadingWidthFor(context),
        title: Text(
          'Talk to Guidance',
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ---------------- INTRO ----------------
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppTheme.primaryColor.withOpacity(0.25),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.support_agent, color: AppTheme.primaryColor),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'You do not have to go through this alone. The guidance office can talk with you about stress, school, or anything on your mind.',
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          height: 1.5,
                          color: AppTheme.darkColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              if (_sent)
                _sentCard()
              else ...[
                // ---------------- OPTIONAL MESSAGE ----------------
                Text(
                  'ADD A MESSAGE (OPTIONAL)',
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF999999),
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _noteController,
                  maxLines: 4,
                  maxLength: 500,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    hintText: 'Tell them briefly what is going on...',
                  ),
                ),
                if (widget.stressSummary != null)
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: _includeAssessment,
                    onChanged: (value) =>
                        setState(() => _includeAssessment = value),
                    title: Text(
                      'Include my latest assessment result',
                      style: GoogleFonts.poppins(fontSize: 13),
                    ),
                    subtitle: Text(
                      widget.stressSummary!,
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: const Color(0xFF999999),
                      ),
                    ),
                  ),

                const SizedBox(height: 12),

                // ---------------- MAIN ACTION ----------------
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _sending ? null : _sendRequest,
                    icon: _sending
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.send),
                    label: Text(
                      _sending ? 'Sending...' : 'Send request to guidance',
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'This sends your name, your account email, your message and, if switched on, your assessment result to the guidance office.',
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    height: 1.5,
                    color: const Color(0xFF999999),
                  ),
                ),
              ],

              // ---------------- DIRECT CONTACT (EXTRA) ----------------
              if (hasContact) ...[
                const SizedBox(height: 28),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Or reach them directly',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF999999),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        GuidanceConfig.officeName,
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.darkColor,
                        ),
                      ),
                      if (GuidanceConfig.hours.trim().isNotEmpty)
                        Text(
                          GuidanceConfig.hours,
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: const Color(0xFF999999),
                          ),
                        ),
                      const SizedBox(height: 12),
                      if (GuidanceConfig.hasPhone)
                        _contactRow(
                          Icons.phone_outlined,
                          GuidanceConfig.phone,
                          'Number',
                        ),
                      if (GuidanceConfig.hasEmail)
                        _contactRow(
                          Icons.email_outlined,
                          GuidanceConfig.email,
                          'Email address',
                        ),
                      const SizedBox(height: 4),
                      if (GuidanceConfig.hasPhone)
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: _call,
                            style: _outlinedStyle(),
                            icon: const Icon(Icons.phone),
                            label: const Text('Call guidance'),
                          ),
                        ),
                      if (GuidanceConfig.hasPhone && GuidanceConfig.hasEmail)
                        const SizedBox(height: 12),
                      if (GuidanceConfig.hasEmail)
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: _sendEmail,
                            style: _outlinedStyle(),
                            icon: const Icon(Icons.email_outlined),
                            label: const Text('Write an email myself'),
                          ),
                        ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 24),

              Text(
                'If you or someone else is in immediate danger, contact your local emergency services right away.',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  height: 1.5,
                  color: const Color(0xFF999999),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  ButtonStyle _outlinedStyle() {
    return OutlinedButton.styleFrom(
      foregroundColor: AppTheme.primaryColor,
      side: BorderSide(color: AppTheme.primaryColor),
      padding: const EdgeInsets.symmetric(vertical: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );
  }

  Widget _sentCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF2ECC71).withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF2ECC71).withOpacity(0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.check_circle, color: Color(0xFF2ECC71)),
              const SizedBox(width: 10),
              Text(
                'Request sent',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.darkColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'The guidance office has been notified and will reach out to you. You can also talk to the AI assistant while you wait.',
            style: GoogleFonts.poppins(
              fontSize: 13,
              height: 1.5,
              color: AppTheme.darkColor,
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => Navigator.of(context).pushNamed('/input_choice'),
              icon: const Icon(Icons.chat_bubble_outline),
              label: const Text('Talk to the AI Assistant'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _contactRow(IconData icon, String value, String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppTheme.primaryColor),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: AppTheme.darkColor,
              ),
            ),
          ),
          IconButton(
            tooltip: 'Copy',
            icon: const Icon(Icons.copy, size: 18),
            color: const Color(0xFF999999),
            onPressed: () => _copy(value, label),
          ),
        ],
      ),
    );
  }
}