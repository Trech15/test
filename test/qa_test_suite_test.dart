import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:capstone/screens/assessment_history_screen.dart';
import 'package:capstone/screens/assessment_screen.dart';
import 'package:capstone/screens/chat_screen.dart';
import 'package:capstone/screens/dashboard_screen.dart';
import 'package:capstone/screens/help_options_screen.dart';
import 'package:capstone/screens/history_screen.dart';
import 'package:capstone/screens/login_screen.dart';
import 'package:capstone/screens/referral_screen.dart';
import 'package:capstone/screens/register_screen.dart';
import 'package:capstone/screens/text_input_screen.dart';
import 'package:capstone/screens/voice_input_screen.dart';
import 'package:capstone/theme/app_theme.dart';
import 'package:capstone/widgets/app_menu.dart';

class _MockHttpClient extends Mock implements http.Client {}

class _FakeBaseRequest extends Fake implements http.BaseRequest {}

const _userId = 'qa-user-id';
const _userEmail = 'qa.student@example.com';
const _userName = 'QA Student';
const _testDate = '2026-01-15T10:30:00.000Z';

final Map<String, List<Map<String, dynamic>>> _tableRows = {};
final List<http.BaseRequest> _requests = [];
final List<MethodCall> _launcherCalls = [];
late _MockHttpClient _supabaseHttp;
late Map<String, dynamic> _mockUser;

Map<String, dynamic> _userJson() => {
  'id': _userId,
  'app_metadata': {
    'provider': 'email',
    'providers': ['email'],
  },
  'user_metadata': Map<String, dynamic>.from(
    _mockUser['user_metadata'] as Map<String, dynamic>,
  ),
  'aud': 'authenticated',
  'created_at': '2025-01-01T00:00:00.000Z',
  'email': _userEmail,
  'phone': '',
  'role': 'authenticated',
};

Map<String, dynamic> _sessionJson() => {
  'access_token': 'qa-access-token',
  'token_type': 'bearer',
  'expires_in': 3600,
  'refresh_token': 'qa-refresh-token',
  'user': _userJson(),
};

Future<http.StreamedResponse> _respond(http.BaseRequest request) async {
  _requests.add(request);
  final path = request.url.path;
  final method = request.method;
  var statusCode = 200;
  Object? payload = <String, dynamic>{};

  if (path == '/auth/v1/token') {
    payload = _sessionJson();
  } else if (path == '/auth/v1/signup') {
    payload = {
      'user': {
        ..._userJson(),
        'id': 'new-qa-user-id',
      },
      'session': null,
    };
  } else if (path == '/auth/v1/logout') {
    statusCode = 204;
    payload = null;
  } else if (path == '/auth/v1/user') {
    if (method == 'PATCH' && request is http.Request) {
      final update = jsonDecode(request.body) as Map<String, dynamic>;
      final metadata = update['data'];
      if (metadata is Map<String, dynamic>) {
        final current = Map<String, dynamic>.from(
          _mockUser['user_metadata'] as Map<String, dynamic>,
        );
        current.addAll(metadata);
        _mockUser['user_metadata'] = current;
      }
    }
    payload = _userJson();
  } else if (path.startsWith('/rest/v1/')) {
    final table = path.substring('/rest/v1/'.length);
    if (method == 'PATCH' && table == 'emergency_contacts') {
      payload = [
        {'user_id': _userId},
      ];
    } else {
      payload = _tableRows[table] ?? <Map<String, dynamic>>[];
    }
  } else if (path.startsWith('/functions/v1/')) {
    payload = {'ok': true};
  } else if (path.startsWith('/storage/v1/')) {
    payload = {'Key': 'avatars/$_userId/avatar.jpg'};
  } else if (path.contains('/rpc/')) {
    payload = {};
  }

  final body = payload == null ? '' : jsonEncode(payload);
  return http.StreamedResponse(
    Stream<List<int>>.value(utf8.encode(body)),
    statusCode,
    request: request,
    headers: const {'content-type': 'application/json'},
  );
}

Future<void> _signInTestUser() async {
  await Supabase.instance.client.auth.signInWithPassword(
    email: _userEmail,
    password: 'qa-password',
  );
}

Widget _app(Widget home) {
  return MaterialApp(
    theme: AppTheme.lightTheme,
    home: home,
    routes: {
      '/dashboard': (_) => const DashboardScreen(),
      '/assessment': (_) => const AssessmentScreen(),
      '/voice_input': (_) => const VoiceInputScreen(),
      '/text_input': (_) => const TextInputScreen(),
      '/chat': (_) => const ChatPage(),
      '/history': (_) => const HistoryScreen(),
      '/login': (_) => const Scaffold(body: Text('Login destination')),
      '/advice': (_) => const Scaffold(body: Text('Advice destination')),
    },
  );
}

Future<void> _openMenu(WidgetTester tester) async {
  await tester.tap(find.byTooltip('Menu'));
  await tester.pumpAndSettle();
}

Future<void> _showProfileSheet(WidgetTester tester) async {
  await _openMenu(tester);
  await tester.tap(find.text('Profile'));
  await tester.pumpAndSettle();
}

Future<void> _submitRegistration(WidgetTester tester) async {
  final button = find.widgetWithText(ElevatedButton, 'Register');
  await tester.ensureVisible(button);
  await tester.tap(button);
  await tester.pumpAndSettle();
}

Future<void> _enterRegistrationField(
  WidgetTester tester,
  int index,
  String value,
) async {
  final field = find.byType(TextFormField).at(index);
  await tester.ensureVisible(field);
  await tester.enterText(field, value);
}

Future<void> _fillRegistration(WidgetTester tester) async {
  await _enterRegistrationField(tester, 0, _userName);
  await _enterRegistrationField(tester, 1, _userEmail);
  await _enterRegistrationField(tester, 2, 'QA-2026');
  await _enterRegistrationField(tester, 3, 'qa-password');
  await _enterRegistrationField(tester, 4, 'qa-password');
  await _enterRegistrationField(tester, 5, 'Alex Contact');
  await tester.ensureVisible(find.byType(DropdownButtonFormField<String>));
  await tester.tap(find.byType(DropdownButtonFormField<String>));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Parent').last);
  await tester.pumpAndSettle();
  await _enterRegistrationField(tester, 6, '09171234567');
  await tester.ensureVisible(find.byType(CheckboxListTile));
  await tester.tap(find.byType(CheckboxListTile));
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    registerFallbackValue(_FakeBaseRequest());
    SharedPreferences.setMockInitialValues({});
    _supabaseHttp = _MockHttpClient();
    when(() => _supabaseHttp.send(any())).thenAnswer((invocation) {
      final request = invocation.positionalArguments.single as http.BaseRequest;
      return _respond(request);
    });

    await Supabase.initialize(
      url: 'https://qa-test.supabase.co',
      anonKey: 'qa-test-anon-key',
      httpClient: _supabaseHttp,
      debug: false,
    );

    _mockUser = {
      'user_metadata': {'full_name': _userName},
    };

    const launcher = MethodChannel('plugins.flutter.io/url_launcher');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(launcher, (call) async {
          _launcherCalls.add(call);
          return true;
        });
  });

  setUp(() async {
    _tableRows.clear();
    _requests.clear();
    _launcherCalls.clear();
    _mockUser = {
      'user_metadata': {'full_name': _userName},
    };
    await _signInTestUser();
    _requests.clear();
  });

  group('Link Verification', () {
    testWidgets(
      'CASE-015: valid verification link redirects with success',
      (tester) async {},
      skip: 'The app has no email-verification link screen or route.',
    );

    testWidgets(
      'CASE-016: expired verification link shows the expired-link error',
      (tester) async {},
      skip: 'The app has no email-verification link screen or route.',
    );
  });

  group('Registration', () {
    testWidgets('CASE-017: mismatched passwords show the current validator', (
      tester,
    ) async {
      await tester.pumpWidget(_app(const RegisterScreen()));
      await _enterRegistrationField(tester, 3, 'first-password');
      await _enterRegistrationField(tester, 4, 'different-password');
      await _submitRegistration(tester);
      expect(find.text('Passwords do not match'), findsOneWidget);
    });

    testWidgets('CASE-018: blank emergency contact name is rejected', (
      tester,
    ) async {
      await tester.pumpWidget(_app(const RegisterScreen()));
      await _submitRegistration(tester);
      expect(find.text("Please enter your contact's name"), findsOneWidget);
    });

    testWidgets('CASE-019: non-empty emergency contact name is accepted', (
      tester,
    ) async {
      await tester.pumpWidget(_app(const RegisterScreen()));
      await _enterRegistrationField(tester, 5, 'Alex Contact');
      await _submitRegistration(tester);
      expect(find.text("Please enter your contact's name"), findsNothing);
    });

    testWidgets('CASE-020: blank emergency contact relationship is rejected', (
      tester,
    ) async {
      await tester.pumpWidget(_app(const RegisterScreen()));
      await _enterRegistrationField(tester, 5, 'Alex Contact');
      await _submitRegistration(tester);
      expect(find.text('Please choose a relationship'), findsOneWidget);
    });

    testWidgets('CASE-021: selecting a relationship is accepted', (
      tester,
    ) async {
      await tester.pumpWidget(_app(const RegisterScreen()));
      await tester.ensureVisible(find.byType(DropdownButtonFormField<String>));
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Parent').last);
      await tester.pumpAndSettle();
      await _submitRegistration(tester);
      expect(find.text('Please choose a relationship'), findsNothing);
    });

    testWidgets('CASE-022: blank emergency contact number is rejected', (
      tester,
    ) async {
      await tester.pumpWidget(_app(const RegisterScreen()));
      await _enterRegistrationField(tester, 5, 'Alex Contact');
      await tester.ensureVisible(find.byType(DropdownButtonFormField<String>));
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Parent').last);
      await tester.pumpAndSettle();
      await _submitRegistration(tester);
      expect(
        find.text('Enter a valid number, e.g. 09171234567 or +639171234567'),
        findsOneWidget,
      );
    });

    testWidgets('CASE-023: malformed emergency contact number is rejected', (
      tester,
    ) async {
      await tester.pumpWidget(_app(const RegisterScreen()));
      await _enterRegistrationField(tester, 5, 'Alex Contact');
      await tester.ensureVisible(find.byType(DropdownButtonFormField<String>));
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Parent').last);
      await tester.pumpAndSettle();
      await _enterRegistrationField(tester, 6, '123');
      await _submitRegistration(tester);
      expect(
        find.text('Enter a valid number, e.g. 09171234567 or +639171234567'),
        findsOneWidget,
      );
    });

    testWidgets('CASE-024: valid emergency contact number is accepted', (
      tester,
    ) async {
      await tester.pumpWidget(_app(const RegisterScreen()));
      await _enterRegistrationField(tester, 5, 'Alex Contact');
      await tester.ensureVisible(find.byType(DropdownButtonFormField<String>));
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Parent').last);
      await tester.pumpAndSettle();
      await _enterRegistrationField(tester, 6, '09171234567');
      await _submitRegistration(tester);
      expect(
        find.text('Enter a valid number, e.g. 09171234567 or +639171234567'),
        findsNothing,
      );
    });

    testWidgets('CASE-025: complete emergency contact registers and persists', (
      tester,
    ) async {
      await tester.pumpWidget(_app(const RegisterScreen()));
      await _fillRegistration(tester);
      await _submitRegistration(tester);
      expect(find.text('Login destination'), findsOneWidget);
      expect(
        find.text('Please verify your email to complete registration.'),
        findsOneWidget,
      );
      final signUpRequest = _requests.where(
        (request) => request.url.path == '/auth/v1/signup',
      );
      expect(signUpRequest, isNotEmpty);
      final body = jsonDecode((signUpRequest.first as http.Request).body);
      final metadata = body['data'] as Map<String, dynamic>;
      expect(metadata['emergency_contact_name'], 'Alex Contact');
      expect(metadata['emergency_relationship'], 'Parent');
      expect(metadata['emergency_phone'], '+639171234567');
    });
  });

  group('Login', () {
    testWidgets(
      'CASE-026: valid Google account redirects to home',
      (tester) async {},
      skip: 'GoogleSignIn is constructed directly and has no injectable platform test seam.',
    );

    testWidgets(
      'CASE-027: closing Google Sign-In leaves login open without an error',
      (tester) async {},
      skip: 'GoogleSignIn is constructed directly and has no injectable platform test seam.',
    );

    testWidgets(
      'CASE-028: offline Google Sign-In shows the requested connection error',
      (tester) async {},
      skip: 'GoogleSignIn is constructed directly and has no injectable platform test seam.',
    );

    testWidgets('CASE-029: first-time login routes to Assessment', (
      tester,
    ) async {
      _tableRows['stress_assessments'] = [];
      await tester.pumpWidget(_app(const LoginScreen()));
      await tester.enterText(find.byType(TextFormField).at(0), _userEmail);
      await tester.enterText(find.byType(TextFormField).at(1), 'qa-password');
      await tester.tap(find.text('Log In'));
      await tester.pumpAndSettle();
      expect(find.byType(AssessmentScreen), findsOneWidget);
    });

    testWidgets('CASE-030: returning login routes directly to Voice', (
      tester,
    ) async {
      _tableRows['stress_assessments'] = [
        {'id': 42},
      ];
      await tester.pumpWidget(_app(const LoginScreen()));
      await tester.enterText(find.byType(TextFormField).at(0), _userEmail);
      await tester.enterText(find.byType(TextFormField).at(1), 'qa-password');
      await tester.tap(find.text('Log In'));
      await tester.pumpAndSettle();
      expect(find.byType(VoiceInputScreen), findsOneWidget);
    });
  });

  group('Assessment', () {
    testWidgets('CASE-031: Next without an answer is blocked', (tester) async {
      await tester.pumpWidget(_app(const AssessmentScreen()));
      await tester.ensureVisible(find.text('Next Question →'));
      await tester.tap(find.text('Next Question →'));
      await tester.pump();
      expect(find.text('Please select an answer'), findsOneWidget);
      expect(find.text('1 of 10'), findsOneWidget);
    });

    testWidgets('CASE-032: answering and selecting Next advances the question', (
      tester,
    ) async {
      await tester.pumpWidget(_app(const AssessmentScreen()));
      const options = [
        'Never',
        'Rarely',
        'Sometimes',
        'Often',
        'Almost always',
        'Very Poor',
        'Poor',
        'Fair',
        'Good',
        'Very Good',
        'Not at all',
        'A little',
        'Moderately',
        'Very',
        'Extremely',
        'Daily',
        '4-5 times/week',
        '2-3 times/week',
        'Once a week',
        'Very Unsatisfied',
        'Unsatisfied',
        'Neutral',
        'Satisfied',
        'Very Satisfied',
      ];
      final option = options
          .map(find.text)
          .firstWhere((finder) => finder.evaluate().isNotEmpty);
      await tester.ensureVisible(option);
      await tester.tap(option);
      await tester.ensureVisible(find.text('Next Question →'));
      await tester.tap(find.text('Next Question →'));
      await tester.pumpAndSettle();
      expect(find.text('2 of 10'), findsOneWidget);
    });
  });

  group('AI Voice Agent', () {
    testWidgets(
      'CASE-033: microphone input produces an AI audio response',
      (tester) async {},
      skip: 'LiveKit rooms, microphone capture, and voice audio are not injectable in this app.',
    );

    testWidgets(
      'CASE-034: opening Voice without microphone permission prompts or errors',
      (tester) async {},
      skip: 'Permission handling is triggered only by Connect and has no injected permission service.',
    );

    testWidgets(
      'CASE-035: muting or ending a voice session updates audio state',
      (tester) async {},
      skip: 'LiveKit session controls require a real Room and audio participant.',
    );

    testWidgets(
      'CASE-036: voice stress concern receives relevant advice',
      (tester) async {},
      skip: 'The LiveKit transcript and AI backend have no injectable client.',
    );

    testWidgets(
      'CASE-037: Analyze displays personalized voice suggestions',
      (tester) async {},
      skip: 'The LiveKit transcript and AI backend have no injectable client.',
    );
  });

  group('AI Chat', () {
    testWidgets(
      'CASE-038: valid chat message displays and receives an AI response',
      (tester) async {},
      skip: 'Chat sends through the top-level HTTP client, which the app does not inject.',
    );

    testWidgets('CASE-039: empty or whitespace chat message is blocked', (
      tester,
    ) async {
      await tester.pumpWidget(_app(const ChatPage()));
      await tester.pumpAndSettle();
      final messageField = find.byType(TextField).last;
      await tester.enterText(messageField, '   ');
      final send = find.byTooltip('Send');
      if (send.evaluate().isNotEmpty) {
        await tester.tap(send);
      } else {
        final sendButton = find.byIcon(Icons.send);
        expect(sendButton, findsWidgets);
        await tester.tap(sendButton.last);
      }
      await tester.pump();
      expect(find.text('   '), findsNothing);
      expect(find.text('You are not logged in.'), findsNothing);
    });

    testWidgets(
      'CASE-040: disconnected chat displays a connection error',
      (tester) async {},
      skip: 'Chat sends through the top-level HTTP client, which the app does not inject.',
    );

    testWidgets(
      'CASE-041: stress concern receives supportive chat advice',
      (tester) async {},
      skip: 'Chat sends through the top-level HTTP client, which the app does not inject.',
    );

    testWidgets(
      'CASE-042: Analyze shows tailored analysis after chat',
      (tester) async {},
      skip: 'AnalysisService uses the top-level HTTP client, which the app does not inject.',
    );

    testWidgets('CASE-043: Analyze with no chat history is blocked', (
      tester,
    ) async {
      await tester.pumpWidget(_app(const ChatPage()));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Analyze conversation →'));
      await tester.pump();
      expect(
        find.text('Talk or type to the AI first, then tap Analyze.'),
        findsOneWidget,
      );
    });

    testWidgets(
      'CASE-044: dismissing analysis returns to the active chat',
      (tester) async {},
      skip: 'The analysis sheet can only be opened after a backend response.',
    );
  });

  group('Navigation (9-Dots App Launcher)', () {
    testWidgets('CASE-045: launcher shows user identity and options', (
      tester,
    ) async {
      await tester.pumpWidget(_app(const TextInputScreen()));
      await _openMenu(tester);
      expect(find.text(_userName), findsOneWidget);
      expect(find.text(_userEmail), findsOneWidget);
      for (final item in [
        'Dashboard',
        'Voice',
        'Start Assessment',
        'Past Assessments',
        'History',
        'Get Help',
        'Profile',
      ]) {
        expect(find.text(item), findsOneWidget);
      }
    });

    testWidgets('CASE-046: Dashboard menu item navigates and closes drawer', (
      tester,
    ) async {
      await tester.pumpWidget(_app(const TextInputScreen()));
      await _openMenu(tester);
      await tester.tap(find.text('Dashboard'));
      await tester.pumpAndSettle();
      expect(find.byType(DashboardScreen), findsOneWidget);
      expect(find.text('Profile'), findsNothing);
    });

    testWidgets('CASE-047: Voice menu item navigates and closes drawer', (
      tester,
    ) async {
      await tester.pumpWidget(_app(const TextInputScreen()));
      await _openMenu(tester);
      await tester.tap(find.text('Voice'));
      await tester.pumpAndSettle();
      expect(find.byType(VoiceInputScreen), findsOneWidget);
      expect(find.text('Profile'), findsNothing);
    });

    testWidgets('CASE-048: Start Assessment opens the assessment screen', (
      tester,
    ) async {
      await tester.pumpWidget(_app(const TextInputScreen()));
      await _openMenu(tester);
      await tester.tap(find.text('Start Assessment'));
      await tester.pumpAndSettle();
      expect(find.byType(AssessmentScreen), findsOneWidget);
      expect(find.text('Profile'), findsNothing);
    });

    testWidgets('CASE-049: Past Assessments opens the assessment list', (
      tester,
    ) async {
      await tester.pumpWidget(_app(const TextInputScreen()));
      await _openMenu(tester);
      await tester.tap(find.text('Past Assessments'));
      await tester.pumpAndSettle();
      expect(find.byType(AssessmentHistoryScreen), findsOneWidget);
    });

    testWidgets('CASE-050: History menu item opens session history', (
      tester,
    ) async {
      await tester.pumpWidget(_app(const TextInputScreen()));
      await _openMenu(tester);
      await tester.tap(find.text('History'));
      await tester.pumpAndSettle();
      expect(find.byType(HistoryScreen), findsOneWidget);
    });

    testWidgets('CASE-051: Get Help menu item opens help options', (
      tester,
    ) async {
      await tester.pumpWidget(_app(const TextInputScreen()));
      await _openMenu(tester);
      await tester.tap(find.text('Get Help'));
      await tester.pumpAndSettle();
      expect(find.byType(HelpOptionsScreen), findsOneWidget);
    });

    testWidgets('CASE-052: Profile menu item opens the profile sheet', (
      tester,
    ) async {
      await tester.pumpWidget(_app(const TextInputScreen()));
      await _showProfileSheet(tester);
      expect(find.text('Upload a photo'), findsOneWidget);
      expect(find.text('Emergency contact'), findsOneWidget);
    });

    testWidgets('CASE-053: tapping outside the launcher dismisses it', (
      tester,
    ) async {
      await tester.pumpWidget(_app(const TextInputScreen()));
      await _openMenu(tester);
      expect(find.text('Past Assessments'), findsOneWidget);
      await tester.tapAt(const Offset(390, 500));
      await tester.pumpAndSettle();
      expect(find.text('Past Assessments'), findsNothing);
    });
  });

  group('Dashboard', () {
    testWidgets('CASE-054: dashboard back arrow returns to Voice', (
      tester,
    ) async {
      await tester.pumpWidget(_app(const VoiceInputScreen()));
      final navigator = Navigator.of(tester.element(find.byType(VoiceInputScreen)));
      navigator.push(
        MaterialPageRoute<void>(builder: (_) => const DashboardScreen()),
      );
      await tester.pumpAndSettle();
      expect(find.byType(DashboardScreen), findsOneWidget);
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      expect(find.byType(VoiceInputScreen), findsOneWidget);
    });

    testWidgets('CASE-055: dashboard profile avatar opens the profile sheet', (
      tester,
    ) async {
      await tester.pumpWidget(_app(const DashboardScreen()));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(UserAvatar).last);
      await tester.pumpAndSettle();
      expect(find.text('Emergency contact'), findsOneWidget);
      expect(find.text('Log out'), findsOneWidget);
    });
  });

  group('Past Assessments', () {
    testWidgets('CASE-056: completed assessments show dates and scores', (
      tester,
    ) async {
      _tableRows['stress_assessments'] = [
        {
          'id': 1,
          'score': 65,
          'created_at': _testDate,
          'answers': [
            {
              'question': 'How are you feeling?',
              'options': ['Calm', 'Stressed'],
              'answer_index': 1,
            },
          ],
        },
      ];
      await tester.pumpWidget(_app(const AssessmentHistoryScreen()));
      await tester.pumpAndSettle();
      expect(find.text('65%'), findsOneWidget);
      expect(find.text('Jan 15, 2026'), findsOneWidget);
      expect(find.text('Moderate stress · 1 answers'), findsOneWidget);
    });

    testWidgets('CASE-057: selecting an assessment shows answer breakdown', (
      tester,
    ) async {
      _tableRows['stress_assessments'] = [
        {
          'id': 1,
          'score': 65,
          'created_at': _testDate,
          'answers': [
            {
              'question': 'How are you feeling?',
              'options': ['Calm', 'Stressed'],
              'answer_index': 1,
            },
          ],
        },
      ];
      await tester.pumpWidget(_app(const AssessmentHistoryScreen()));
      await tester.pumpAndSettle();
      await tester.tap(find.text('65%'));
      await tester.pumpAndSettle();
      expect(find.text('How are you feeling?'), findsOneWidget);
      expect(find.text('Stressed'), findsOneWidget);
      expect(find.text('65%'), findsOneWidget);
    });

    testWidgets('CASE-058: no assessments shows the current empty state', (
      tester,
    ) async {
      _tableRows['stress_assessments'] = [];
      await tester.pumpWidget(_app(const AssessmentHistoryScreen()));
      await tester.pumpAndSettle();
      expect(find.text('No assessments yet'), findsOneWidget);
      expect(find.text('No past assessments found.'), findsNothing);
    });
  });

  group('Session History', () {
    testWidgets('CASE-059: saved voice sessions show date and stress context', (
      tester,
    ) async {
      _tableRows['stress_assessments'] = [];
      _tableRows['voice_sessions'] = [
        {
          'id': 7,
          'conversation': [
            {'role': 'user', 'text': 'I feel stressed about exams.'},
            {'role': 'ai', 'text': 'Try a short breathing exercise.'},
          ],
          'mood': 'Stressed',
          'advice': 'Try a short breathing exercise.',
          'created_at': _testDate,
        },
      ];
      await tester.pumpWidget(_app(const HistoryScreen()));
      await tester.pumpAndSettle();
      expect(find.text('Voice Session'), findsOneWidget);
      expect(find.text('Mood: Stressed'), findsOneWidget);
      expect(find.text('Try a short breathing exercise.'), findsOneWidget);
    });

    testWidgets('CASE-060: selecting a session shows the conversation and advice', (
      tester,
    ) async {
      _tableRows['stress_assessments'] = [];
      _tableRows['voice_sessions'] = [
        {
          'id': 7,
          'conversation': [
            {'role': 'user', 'text': 'I feel stressed about exams.'},
            {'role': 'ai', 'text': 'Try a short breathing exercise.'},
          ],
          'mood': 'Stressed',
          'advice': 'Take a mindful break.',
          'created_at': _testDate,
        },
      ];
      await tester.pumpWidget(_app(const HistoryScreen()));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Voice Session'));
      await tester.pumpAndSettle();
      expect(find.text('I feel stressed about exams.'), findsOneWidget);
      expect(find.text('Take a mindful break.'), findsOneWidget);
      expect(find.text('CONVERSATION'), findsOneWidget);
    });

    testWidgets('CASE-061: no saved sessions shows the current empty state', (
      tester,
    ) async {
      _tableRows['stress_assessments'] = [];
      _tableRows['voice_sessions'] = [];
      await tester.pumpWidget(_app(const HistoryScreen()));
      await tester.pumpAndSettle();
      expect(find.text('No history yet'), findsOneWidget);
      expect(
        find.text('Your past stress check-ins will appear here'),
        findsOneWidget,
      );
      expect(find.text('No session history available.'), findsNothing);
    });
  });

  group('Get Help', () {
    testWidgets('CASE-062: Talk to Guidance shows its form and contact info', (
      tester,
    ) async {
      await tester.pumpWidget(_app(const HelpOptionsScreen()));
      await tester.tap(find.text('Talk to Guidance'));
      await tester.pumpAndSettle();
      expect(find.byType(ReferralScreen), findsOneWidget);
      expect(find.text('Talk to Guidance'), findsOneWidget);
      expect(find.text('Send request to guidance'), findsOneWidget);
      expect(find.text('Call guidance'), findsOneWidget);
      expect(find.text('Write an email myself'), findsOneWidget);
    });

    testWidgets('CASE-063: guidance request accepts an optional message', (
      tester,
    ) async {
      await tester.pumpWidget(_app(const ReferralScreen()));
      await tester.enterText(
        find.byType(TextField),
        'I would like to talk about exam stress.',
      );
      await tester.tap(find.text('Send request to guidance'));
      await tester.pumpAndSettle();
      expect(find.text('Request sent'), findsOneWidget);
      expect(
        _requests.any((request) => request.url.path.endsWith('/notify-guidance')),
        isTrue,
      );
    });

    testWidgets('CASE-064: guidance request accepts an empty optional message', (
      tester,
    ) async {
      await tester.pumpWidget(_app(const ReferralScreen()));
      await tester.tap(find.text('Send request to guidance'));
      await tester.pumpAndSettle();
      expect(find.text('Request sent'), findsOneWidget);
    });

    testWidgets('CASE-065: Call guidance launches a tel URI', (tester) async {
      await tester.pumpWidget(_app(const ReferralScreen()));
      await tester.tap(find.text('Call guidance'));
      await tester.pumpAndSettle();
      expect(
        _launcherCalls.any((call) => call.arguments.toString().contains('tel:')),
        isTrue,
      );
    });

    testWidgets('CASE-066: email option launches a mailto URI', (
      tester,
    ) async {
      await tester.pumpWidget(_app(const ReferralScreen()));
      await tester.tap(find.text('Write an email myself'));
      await tester.pumpAndSettle();
      expect(
        _launcherCalls.any(
          (call) => call.arguments.toString().contains('mailto:'),
        ),
        isTrue,
      );
    });
  });

  group('Profile', () {
    testWidgets(
      'CASE-067: Upload photo opens picker and updates profile image',
      (tester) async {},
      skip: 'ImagePicker has no injected picker or upload service; upload requires native image bytes.',
    );

    testWidgets(
      'CASE-068: Change photo replaces the saved profile image',
      (tester) async {},
      skip: 'ImagePicker has no injected picker or upload service; upload requires native image bytes.',
    );

    testWidgets('CASE-069: Emergency contact opens the current contact sheet', (
      tester,
    ) async {
      _tableRows['emergency_contacts'] = [
        {
          'contact_name': 'Alex Contact',
          'relationship': 'Parent',
          'phone': '+639171234567',
          'consent': true,
        },
      ];
      await tester.pumpWidget(_app(const TextInputScreen()));
      await _showProfileSheet(tester);
      await tester.tap(find.text('Emergency contact'));
      await tester.pumpAndSettle();
      expect(find.text('Emergency contact'), findsOneWidget);
      expect(find.text('Alex Contact'), findsOneWidget);
      expect(find.text('+639171234567'), findsOneWidget);
    });

    testWidgets('CASE-070: valid emergency contact changes save successfully', (
      tester,
    ) async {
      _tableRows['emergency_contacts'] = [
        {
          'contact_name': 'Alex Contact',
          'relationship': 'Parent',
          'phone': '+639171234567',
          'consent': true,
        },
      ];
      await tester.pumpWidget(_app(const TextInputScreen()));
      await _showProfileSheet(tester);
      await tester.tap(find.text('Emergency contact'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).at(0), 'Jamie Contact');
      await tester.enterText(find.byType(TextFormField).at(1), '09181234567');
      await tester.tap(find.text('Save changes'));
      await tester.pumpAndSettle();
      expect(find.text('Emergency contact updated'), findsOneWidget);
      final update = _requests.firstWhere(
        (request) =>
            request.url.path.endsWith('/emergency_contacts') &&
            request.method == 'PATCH',
      );
      expect(update, isNotNull);
    });

    testWidgets('CASE-071: confirmed logout ends the session and opens Login', (
      tester,
    ) async {
      await tester.pumpWidget(_app(const TextInputScreen()));
      await _showProfileSheet(tester);
      await tester.tap(find.text('Log out'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Logout').last);
      await tester.pumpAndSettle();
      expect(find.text('Login destination'), findsOneWidget);
      expect(Supabase.instance.client.auth.currentUser, isNull);
    });

    testWidgets('CASE-072: cancelling account removal keeps Profile open', (
      tester,
    ) async {
      await tester.pumpWidget(_app(const TextInputScreen()));
      await _showProfileSheet(tester);
      await tester.tap(find.text('Remove account'));
      await tester.pumpAndSettle();
      expect(find.text('Remove account?'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.text('Upload a photo'), findsOneWidget);
      expect(find.text('Remove account?'), findsNothing);
    });

    testWidgets('CASE-073: confirmed account removal invokes deletion and Login', (
      tester,
    ) async {
      await tester.pumpWidget(_app(const TextInputScreen()));
      await _showProfileSheet(tester);
      await tester.tap(find.text('Remove account'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, 'DELETE');
      await tester.pump();
      await tester.tap(find.text('Delete forever'));
      await tester.pumpAndSettle();
      expect(find.text('Login destination'), findsOneWidget);
      expect(
        _requests.any((request) => request.url.path.endsWith('/rpc/delete_user')),
        isTrue,
      );
    });
  });
}
