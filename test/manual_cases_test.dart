import 'package:flutter_test/flutter_test.dart';

/// Put this file in test/manual_cases_test.dart
///
/// These cases cannot be checked by an automatic test inside VS Code: they
/// need your real Supabase login, the microphone, Google, your inbox, the
/// phone dialer or the photo picker, or the feature is not in the app.
/// They show up as "skipped" in the Testing panel so nothing is silently
/// missing. Test them by hand and write down what you really see.
void main() {
  const manual = <String, String>{
    'CASE-001 login with an invalid email': 'Needs a real Supabase login',
    'CASE-004 login with valid credentials': 'Needs a real Supabase login',
    'CASE-005 sign in with Google': 'Needs a real phone and Google account',
    'CASE-006 wrong password': 'Needs a real Supabase login',
    'CASE-007 first-time user goes to the Assessment': 'Needs a real login',
    'CASE-008 returning user goes to Voice': 'Needs a real login',
    'CASE-009 forgot password, unregistered email': 'Needs the database',
    'CASE-010 forgot password, registered email': 'Needs the database + email',
    'CASE-011 expired verification link': 'Message not found in the app',
    'CASE-012 valid verification link': 'Needs your inbox and a phone',
    'CASE-017 password changed successfully': 'Needs a real session',
        'CASE-040 complete the assessment': 'Saves to the database',
    'CASE-041 answer and press Next': 'Questions are random; check by hand',
    'CASE-042 view previous answers': 'Check by hand',
    'CASE-043 dashboard shows user status': 'Needs real data',
    'CASE-044 dashboard back arrow': 'Check by hand',
    'CASE-045 Profile icon on the dashboard': 'Opens the profile sheet; check by hand',
    'CASE-046 microphone permission': 'Needs a real device',
    'CASE-047 speak to the voice agent': 'Needs microphone + LiveKit',
    'CASE-048 mute or end the voice session': 'Needs LiveKit',
    'CASE-049 stress concern by voice': 'Needs microphone + LiveKit',
    'CASE-051 Analyze after a voice conversation': 'Needs the backend',
    'CASE-052 text message in the chat bubble': 'Needs the backend',
    'CASE-053 message with no internet': 'Needs a device with no internet',
    'CASE-054 stress concern in the chat bubble': 'Needs the backend',
    'CASE-055 check previous assessment': 'Needs real data',
    'CASE-056 open a past assessment': 'Needs real data',
    'CASE-057 History list': 'Needs real data',
    'CASE-058 open a saved session': 'Needs real data',
    'CASE-059 empty History message': 'Message not found in the app',
    'CASE-060 Talk to Guidance': 'Needs a real device',
    'CASE-061 Call Guidance': 'Needs the phone dialer',
    'CASE-062 Write an Email Myself': 'Needs an email app',
    'CASE-063 Send Request with a message': 'Needs the database',
    'CASE-064 Send Request without a message': 'Needs the database',
    'CASE-065 Upload Photo': 'Needs the photo picker and a real login',
    'CASE-066 Change Photo': 'Needs the photo picker and a real login',
    'CASE-067 open Emergency Contact': 'Loads from the database; needs a real login',
    'CASE-068 update Emergency Contact': 'Saves to the database; needs a real login',
    'CASE-069 Logout with confirmation': 'Confirming signs out of Supabase; the dialog is tested',
    'CASE-071 Remove Account, confirm': 'Permanently deletes data; needs a real login',
  };

  for (final entry in manual.entries) {
    test(entry.key, () {}, skip: entry.value);
  }
}
