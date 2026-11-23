import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Put this file in lib/services/emergency_contact_service.dart
///
/// Saves the student's emergency contact (the person ChaTress may call if the
/// student shows signs of suicidal thoughts). The contact is only used if
/// `consent` is true, which the registration screen sets after the student
/// ticks the consent box.
class EmergencyContactService {
  /// Turns what the student typed into international format
  /// (for example 09171234567 -> +639171234567).
  /// Returns null if it does not look like a valid phone number.
  static String? normalizePhone(String raw) {
    var phone = raw.trim().replaceAll(RegExp(r'[\s\-().]'), '');

    if (phone.isEmpty) return null;

    // Philippine mobile numbers typed the local way.
    if (phone.startsWith('09') && phone.length == 11) {
      phone = '+63${phone.substring(1)}';
    } else if (phone.startsWith('639') && phone.length == 12) {
      phone = '+$phone';
    } else if (phone.startsWith('9') && phone.length == 10) {
      phone = '+63$phone';
    }

    // Anything else must already be international: + country code + number.
    return RegExp(r'^\+[1-9][0-9]{7,14}$').hasMatch(phone) ? phone : null;
  }

  /// Saves (or replaces) the signed-in student's emergency contact.
  /// Throws if the student is not logged in or the save fails.
  static Future<void> save({
    required String name,
    required String relationship,
    required String phone,
  }) async {
    final user = Supabase.instance.client.auth.currentUser;

    if (user == null) {
      throw Exception('You are not logged in.');
    }

    final now = DateTime.now().toUtc().toIso8601String();

    await Supabase.instance.client.from('emergency_contacts').upsert({
      'user_id': user.id,
      'contact_name': name,
      'relationship': relationship,
      'phone': phone,
      'consent': true,
      'consent_at': now,
      'updated_at': now,
    });

    debugPrint('💾 emergency contact saved');
  }

  /// The signed-in student's saved contact (contact_name, relationship,
  /// phone, consent), or null if there is none yet.
  static Future<Map<String, dynamic>?> load() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return null;

    return await Supabase.instance.client
        .from('emergency_contacts')
        .select('contact_name, relationship, phone, consent')
        .eq('user_id', user.id)
        .maybeSingle();
  }

  /// Changes the name, relationship and number of an EXISTING contact. The
  /// consent the student already gave is left as it is.
  /// Throws if nothing was updated.
  static Future<void> updateDetails({
    required String name,
    required String relationship,
    required String phone,
  }) async {
    final user = Supabase.instance.client.auth.currentUser;

    if (user == null) {
      throw Exception('You are not logged in.');
    }

    final rows = await Supabase.instance.client
        .from('emergency_contacts')
        .update({
          'contact_name': name,
          'relationship': relationship,
          'phone': phone,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('user_id', user.id)
        .select('user_id');

    if (rows.isEmpty) {
      throw Exception('Your contact could not be updated.');
    }

    debugPrint('💾 emergency contact updated');
  }

  /// Removes the temporary copy of the contact kept in the account profile.
  static Future<void> clearMetadataCopy() async {
    try {
      await Supabase.instance.client.auth.updateUser(
        UserAttributes(
          data: {
            'emergency_contact_name': null,
            'emergency_relationship': null,
            'emergency_phone': null,
            'emergency_consent': null,
          },
        ),
      );
    } catch (e) {
      debugPrint('Could not clear emergency contact copy: $e');
    }
  }

  /// When a student registers but must verify their email first, there is no
  /// login yet, so the contact cannot be saved to the database. It is kept in
  /// the account profile instead, and this saves it on the first login.
  /// Safe to call on every login: it does nothing if there is nothing to save.
  static Future<void> saveFromMetadataIfMissing() async {
    final client = Supabase.instance.client;
    final user = client.auth.currentUser;

    if (user == null) return;

    final meta = user.userMetadata ?? {};
    final phone = meta['emergency_phone']?.toString() ?? '';

    if (phone.isEmpty || meta['emergency_consent'] != true) return;

    try {
      final existing = await client
          .from('emergency_contacts')
          .select('user_id')
          .eq('user_id', user.id)
          .maybeSingle();

      if (existing == null) {
        await save(
          name: meta['emergency_contact_name']?.toString() ?? '',
          relationship: meta['emergency_relationship']?.toString() ?? '',
          phone: phone,
        );
      }

      await clearMetadataCopy();
    } catch (e) {
      debugPrint('Could not save emergency contact from profile: $e');
    }
  }
}