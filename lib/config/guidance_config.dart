/// Put this file in lib/config/guidance_config.dart
///
/// Guidance office contact details. The referral screen only shows the Call
/// and Email options for the details that are filled in.
///
/// The automatic "Send request to guidance" email goes to the address set in
/// the Supabase secret GUIDANCE_EMAIL, not to the value below.
class GuidanceConfig {
  GuidanceConfig._();

  static const String officeName = 'Guidance Office';

  static const String phone = '09913591407';

  static const String email = 'trechoyao15@gmail.com';

  /// Shown under the office name. Example: 'Mon-Fri, 8:00 AM - 5:00 PM'
  static const String hours = '';

  static bool get hasPhone => phone.trim().isNotEmpty;
  static bool get hasEmail => email.trim().isNotEmpty;
}
