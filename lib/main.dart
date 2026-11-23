import 'package:flutter/material.dart';
import 'screens/splash_screen.dart';
import 'screens/register_screen.dart';
import 'screens/login_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/assessment_screen.dart';
import 'screens/detection_screen.dart';
import 'screens/input_choice_screen.dart';
import 'screens/voice_input_screen.dart';
import 'screens/text_input_screen.dart';
import 'screens/advice_screen.dart';
import 'screens/history_screen.dart';
import 'screens/chat_screen.dart';
import 'screens/reset_password_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'services/emergency_contact_service.dart';
import 'services/password_recovery.dart';
import 'theme/app_theme.dart';
import 'widgets/chat_bubble_overlay.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

// Tells the floating chat bubble which screen is showing.
final BubbleRouteTracker bubbleTracker = BubbleRouteTracker();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: "https://apgamtwmvydccbawcqty.supabase.co",
    anonKey: "sb_publishable_pVm16hmxL-qmMD-iEkcY0w_6DCI-zZz",
  );

  // Opens the "set new password" screen when the user taps the reset
  // link in their email. If the app was closed when the link was tapped,
  // the splash screen picks it up instead (see PasswordRecovery).
  PasswordRecovery.listen(navigatorKey);

  // After any login (email, Google, or the email verification link), save the
  // emergency contact that was kept in the account profile at registration.
  Supabase.instance.client.auth.onAuthStateChange.listen((data) {
    if (data.event == AuthChangeEvent.signedIn) {
      EmergencyContactService.saveFromMetadataIfMissing();
    }
  });

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ChaTress',
      navigatorKey: navigatorKey,
      navigatorObservers: [bubbleTracker],
      theme: AppTheme.lightTheme,
      debugShowCheckedModeBanner: false,

      // Floats the chat bubble above every screen.
      builder: (context, child) => ChatBubbleHost(
        navigatorKey: navigatorKey,
        tracker: bubbleTracker,
        child: child ?? const SizedBox.shrink(),
      ),

      home: const SplashScreen(),
      routes: {
        '/splash': (context) => const SplashScreen(),
        '/register': (context) => const RegisterScreen(),
        '/login': (context) => const LoginScreen(),
        '/dashboard': (context) => const DashboardScreen(),
        '/assessment': (context) => const AssessmentScreen(),
        '/detection': (context) => const DetectionScreen(),
        '/input_choice': (context) => const InputChoiceScreen(),
        '/voice_input': (context) => const VoiceInputScreen(),
        '/text_input': (context) => const TextInputScreen(),
        '/advice': (context) => const AdviceScreen(),
        '/history': (context) => const HistoryScreen(),
        '/chat': (context) => const ChatPage(),
        '/reset-password': (context) => const ResetPasswordScreen(),
      },
    );
  }
}