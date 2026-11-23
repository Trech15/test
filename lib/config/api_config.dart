/// Every server address the app talks to lives here.
///
/// 1. Deploy the backend on Render and copy its URL.
/// 2. Paste it into [renderUrl] below (no slash at the end).
/// 3. Build:  flutter build apk --release
///
/// To test against a laptop instead, override at build time:
///   flutter build apk --release \
///     --dart-define=BACKEND_URL=http://192.168.1.20:5000 \
///     --dart-define=TOKEN_SERVER_URL=http://192.168.1.20:5000/token
/// (plain http also needs android:usesCleartextTraffic="true" in the manifest)

/// Central configuration for all CalmCampus server addresses.
///
/// Production:
/// - Flask backend: chatress-backend on Render
/// - LiveKit token server: separate Render service
///
/// For local testing, you can override URLs using --dart-define.

class ApiConfig {
  ApiConfig._();

  /// Deployed Flask backend.
  static const String renderUrl = 'https://chatress-backend.onrender.com';

  /// Flask backend (/chat, /history, /test).
  static const String backendUrl = String.fromEnvironment(
    'BACKEND_URL',
    defaultValue: renderUrl,
  );

  /// Separately deployed LiveKit token server.
  ///
  /// IMPORTANT: Replace YOUR-TOKEN-SERVER with your actual
  /// Render token server service name.
  static const String tokenServerUrl = String.fromEnvironment(
    'TOKEN_SERVER_URL',
    defaultValue: 'https://calmcampus-token-server.onrender.com/token',
  );

  /// Existing LiveKit Cloud project.
  static const String liveKitUrl = String.fromEnvironment(
    'LIVEKIT_URL',
    defaultValue: 'wss://jarvis-new-tfbvlg3q.livekit.cloud',
  );
}
