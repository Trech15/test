import 'package:capstone/services/emergency_contact_service.dart';
import 'package:flutter_test/flutter_test.dart';

/// Emergency contact number rules (no screen needed).
void main() {
  group('EmergencyContactService.normalizePhone', () {
    test('local number becomes international format', () {
      expect(
        EmergencyContactService.normalizePhone('09171234567'),
        '+639171234567',
      );
    });

    test('spaces and dashes are ignored', () {
      expect(
        EmergencyContactService.normalizePhone('0917-123 4567'),
        '+639171234567',
      );
    });

    test('number already in international format is kept', () {
      expect(
        EmergencyContactService.normalizePhone('+639171234567'),
        '+639171234567',
      );
    });

    test('letters are rejected', () {
      expect(EmergencyContactService.normalizePhone('abcdefgh'), isNull);
    });

    test('too short is rejected', () {
      expect(EmergencyContactService.normalizePhone('12345'), isNull);
    });

    test('empty is rejected', () {
      expect(EmergencyContactService.normalizePhone(''), isNull);
    });
  });
}
