import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/bubble_chat_service.dart';
import '../services/home_route.dart';
import '../theme/app_theme.dart';

/// Put this file in lib/widgets/chat_bubble_overlay.dart
///
/// Contains:
///  - [BubbleRouteTracker]: a NavigatorObserver that tells the bubble which
///    screen is on top and whether a dialog / bottom sheet is open.
///  - [ChatBubbleHost]: wraps the whole app (MaterialApp.builder) and floats
///    the draggable bubble above every screen.
///  - [_BubbleLayer]: the bubble itself plus the small chat window that pops
///    up when the bubble is tapped (no bottom sheet, no route).
///  - [_ChatPanel]: the chat window (messages + type box).

// ============================================================
// ROUTE TRACKER
// ============================================================

class BubbleRouteTracker extends NavigatorObserver {
  /// Name of the page currently on top (e.g. '/dashboard'). Null for pages
  /// opened with an unnamed MaterialPageRoute, which is fine.
  final ValueNotifier<String?> currentRoute = ValueNotifier<String?>(null);

  /// True while a dialog / bottom sheet is on top of the page.
  final ValueNotifier<bool> popupOpen = ValueNotifier<bool>(false);

  /// Asks the Navigator what is really on top instead of guessing from the
  /// push / pop / remove callbacks. This stays correct with
  /// pushNamedAndRemoveUntil, pushReplacement, etc.
  void _sync() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final nav = navigator;
      if (nav == null || !nav.mounted) return;

      Route<dynamic>? top;
      // The predicate returns true right away, so nothing is popped.
      nav.popUntil((route) {
        top = route;
        return true;
      });

      final t = top;
      if (t is PopupRoute) {
        popupOpen.value = true;
      } else {
        popupOpen.value = false;
        if (t is PageRoute) currentRoute.value = t.settings.name;
      }
    });
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) => _sync();

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) => _sync();

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _sync();

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) =>
      _sync();
}

// ============================================================
// OPEN THE CHAT FROM ANYWHERE
// ============================================================

/// Lets any screen open the chat window, e.g. `ChatBubble.open()`.
class ChatBubble {
  ChatBubble._();

  static Future<void> Function()? _opener;

  static Future<void> open() async => _opener?.call();
}

// ============================================================
// HOST (wraps the app)
// ============================================================

class ChatBubbleHost extends StatefulWidget {
  const ChatBubbleHost({
    super.key,
    required this.child,
    required this.navigatorKey,
    required this.tracker,
  });

  /// The app's Navigator (comes from MaterialApp.builder).
  final Widget child;
  final GlobalKey<NavigatorState> navigatorKey;
  final BubbleRouteTracker tracker;

  @override
  State<ChatBubbleHost> createState() => _ChatBubbleHostState();
}

class _ChatBubbleHostState extends State<ChatBubbleHost> {
  late final OverlayEntry _entry;

  @override
  void initState() {
    super.initState();
    _entry = OverlayEntry(
      builder: (_) => _BubbleLayer(
        navigatorKey: widget.navigatorKey,
        tracker: widget.tracker,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // The bubble layer gets its OWN Overlay. Widgets above the app's
    // Navigator have no Overlay, and TextField (copy / paste menu) and
    // tooltips need one. An empty Overlay lets touches pass through to the
    // app underneath.
    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        Positioned.fill(child: Overlay(initialEntries: [_entry])),
      ],
    );
  }
}

// ============================================================
// BUBBLE + POPUP WINDOW
// ============================================================

class _BubbleLayer extends StatefulWidget {
  const _BubbleLayer({required this.navigatorKey, required this.tracker});

  final GlobalKey<NavigatorState> navigatorKey;
  final BubbleRouteTracker tracker;

  @override
  State<_BubbleLayer> createState() => _BubbleLayerState();
}

class _BubbleLayerState extends State<_BubbleLayer> {
  static const double _size = 60;

  /// Screens where the bubble must not appear. If your dashboard is opened
  /// with `home:` instead of a named route, its name is '/', which is hidden
  /// here, so give it a real name or remove '/' from this set.
  static const Set<String> _hiddenOn = {
    '/', // splash
    '/splash',
    '/login',
    '/register',
    '/reset-password',
    '/chat', // the full chat page already is the chat
  };

  Offset? _pos; // top-left of the bubble
  bool _dragging = false;
  bool _open = false;
  bool _loggedIn = Supabase.instance.client.auth.currentSession != null;
  StreamSubscription<AuthState>? _authSub;
  String _lastLog = '';

  /// Only used on '/assessment': true while the student has never done an
  /// assessment (first time in the app), null while that is being checked.
  /// The bubble stays hidden unless this is false.
  bool? _assessmentFirstTime;

  @override
  void initState() {
    super.initState();
    ChatBubble._opener = _openPanel;
    widget.tracker.currentRoute.addListener(_onRouteChanged);
    _authSub = Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      final loggedIn = data.session != null;
      if (loggedIn != _loggedIn && mounted) {
        setState(() {
          _loggedIn = loggedIn;
          if (!loggedIn) _open = false;
        });
      }
    });
  }

  @override
  void dispose() {
    widget.tracker.currentRoute.removeListener(_onRouteChanged);
    if (ChatBubble._opener == _openPanel) ChatBubble._opener = null;
    _authSub?.cancel();
    super.dispose();
  }

  void _onRouteChanged() {
    if (widget.tracker.currentRoute.value == '/assessment') {
      _checkFirstTime();
    }
  }

  /// A first-time student must not see the bubble on the assessment.
  /// Uses the same rule as HomeRoute (no assessment saved yet).
  Future<void> _checkFirstTime() async {
    if (!mounted) return;
    setState(() => _assessmentFirstTime = null); // hidden while checking

    final route = await HomeRoute.resolve();
    if (!mounted) return;

    setState(() => _assessmentFirstTime = route == HomeRoute.firstTime);
  }

  Future<void> _openPanel() async {
    if (!mounted || !_loggedIn) return;
    setState(() => _open = true);
  }

  void _closePanel() {
    FocusManager.instance.primaryFocus?.unfocus();
    if (mounted) setState(() => _open = false);
  }

  void _openVoice() {
    _closePanel();
    // Already on the voice screen? Just close the window.
    if (widget.tracker.currentRoute.value == '/voice_input') return;
    widget.navigatorKey.currentState?.pushNamed('/voice_input');
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final screen = media.size;
    final safe = media.padding;

    const minX = 8.0;
    final maxX = screen.width - _size - 8;
    final minY = safe.top + 8;
    final maxY = screen.height - _size - safe.bottom - 8;

    _pos ??= Offset(maxX, screen.height * 0.65);
    final pos = Offset(
      _pos!.dx.clamp(minX, maxX).toDouble(),
      _pos!.dy.clamp(minY, maxY).toDouble(),
    );

    return AnimatedBuilder(
      animation: Listenable.merge([
        widget.tracker.currentRoute,
        widget.tracker.popupOpen,
      ]),
      builder: (context, _) {
        final route = widget.tracker.currentRoute.value;
        final popup = widget.tracker.popupOpen.value;
        final hiddenOnAssessment =
            route == '/assessment' && _assessmentFirstTime != false;
        final visible =
            _loggedIn &&
            !popup &&
            !_hiddenOn.contains(route) &&
            !hiddenOnAssessment;

        // Shows in the debug console why the bubble is or is not visible.
        if (kDebugMode) {
          final log =
              'route=$route loggedIn=$_loggedIn popup=$popup visible=$visible';
          if (log != _lastLog) {
            _lastLog = log;
            debugPrint('BUBBLE: $log');
          }
        }

        if (!visible) return const SizedBox.shrink();

        // ---------------- chat window ----------------
        if (_open) {
          final bottomPad =
              math.max(media.viewInsets.bottom, safe.bottom) + 12;
          final available = screen.height - bottomPad - safe.top - 16;
          final height = math.min(
            math.max(240.0, screen.height * 0.6),
            available,
          );

          return Stack(
            children: [
              Positioned(
                left: 12,
                right: 12,
                bottom: bottomPad,
                height: height,
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.85, end: 1),
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOut,
                  builder: (context, v, child) => Opacity(
                    opacity: ((v - 0.85) / 0.15).clamp(0.0, 1.0).toDouble(),
                    child: Transform.scale(
                      scale: v,
                      alignment: Alignment.bottomRight,
                      child: child,
                    ),
                  ),
                  child: _ChatPanel(
                    onClose: _closePanel,
                    onOpenVoice: _openVoice,
                  ),
                ),
              ),
            ],
          );
        }

        // ---------------- floating bubble ----------------
        return Stack(
          children: [
            AnimatedPositioned(
              // No animation while dragging, a smooth snap to the edge after.
              duration: _dragging
                  ? Duration.zero
                  : const Duration(milliseconds: 200),
              curve: Curves.easeOut,
              left: pos.dx,
              top: pos.dy,
              child: GestureDetector(
                onTap: _openPanel,
                onPanStart: (_) => setState(() => _dragging = true),
                onPanUpdate: (d) => setState(() {
                  _pos = Offset(
                    (pos.dx + d.delta.dx).clamp(minX, maxX).toDouble(),
                    (pos.dy + d.delta.dy).clamp(minY, maxY).toDouble(),
                  );
                }),
                onPanEnd: (_) => setState(() {
                  _dragging = false;
                  // Snap to the nearest left/right edge.
                  final snapRight = (_pos!.dx + _size / 2) > screen.width / 2;
                  _pos = Offset(snapRight ? maxX : minX, _pos!.dy);
                }),
                child: Material(
                  type: MaterialType.transparency,
                  child: Container(
                    width: _size,
                    height: _size,
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.25),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.chat_bubble_rounded,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

// ============================================================
// CHAT WINDOW
// ============================================================

class _ChatPanel extends StatefulWidget {
  const _ChatPanel({required this.onClose, required this.onOpenVoice});

  final VoidCallback onClose;
  final VoidCallback onOpenVoice;

  @override
  State<_ChatPanel> createState() => _ChatPanelState();
}

class _ChatPanelState extends State<_ChatPanel> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scroll = ScrollController();
  final FocusNode _focus = FocusNode();

  final List<Map<String, String>> _messages = [];
  bool _loadingHistory = true;
  bool _sending = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  @override
  void dispose() {
    _controller.dispose();
    _scroll.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _loadHistory() async {
    // Reloaded every time the window opens, so messages sent from the full
    // chat page or by voice show up here too.
    final history = await BubbleChatService.loadHistory();
    if (!mounted) return;
    setState(() {
      _messages
        ..clear()
        ..addAll(history);
      _loadingHistory = false;
    });
    _scrollToBottom(jump: true);
  }

  void _scrollToBottom({bool jump = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      final end = _scroll.position.maxScrollExtent;
      if (jump) {
        _scroll.jumpTo(end);
      } else {
        _scroll.animateTo(
          end,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending) return;

    setState(() {
      _messages.add({'sender': 'You', 'text': text});
      _sending = true;
      _error = null;
    });
    _controller.clear();
    _focus.requestFocus(); // keep the keyboard open for the next question
    _scrollToBottom();

    try {
      final reply = await BubbleChatService.send(text);
      if (!mounted) return;
      setState(() {
        _messages.add({'sender': 'Bot', 'text': reply});
        _sending = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _sending = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
    _scrollToBottom();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      elevation: 16,
      shadowColor: Colors.black54,
      borderRadius: BorderRadius.circular(24),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // ---------------- header ----------------
          Container(
            color: AppTheme.primaryColor,
            padding: const EdgeInsets.fromLTRB(16, 8, 4, 8),
            child: Row(
              children: [
                const CircleAvatar(
                  radius: 16,
                  backgroundColor: Colors.white24,
                  child: Icon(Icons.auto_awesome, color: Colors.white, size: 18),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Chat with AI',
                    style: GoogleFonts.poppins(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: widget.onClose,
                ),
              ],
            ),
          ),

          // ---------------- messages ----------------
          Expanded(child: _buildMessages()),

          if (_error != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
              child: Text(
                _error!,
                style: GoogleFonts.poppins(fontSize: 12, color: Colors.red),
              ),
            ),

          // ---------------- type box ----------------
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 4, 10, 10),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    focusNode: _focus,
                    autofocus: true,
                    minLines: 1,
                    maxLines: 4,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _send(),
                    style: GoogleFonts.poppins(fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'Type your question...',
                      hintStyle: GoogleFonts.poppins(
                        fontSize: 14,
                        color: Colors.grey[500],
                      ),
                      filled: true,
                      fillColor: const Color(0xFFF1F1F1),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      border: _pill,
                      enabledBorder: _pill,
                      focusedBorder: _pill,
                      disabledBorder: _pill,
                      suffixIcon: IconButton(
                        tooltip: 'Talk by voice',
                        icon: Icon(Icons.mic, color: AppTheme.primaryColor),
                        onPressed: widget.onOpenVoice,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Material(
                  color: _sending ? Colors.grey[400] : AppTheme.primaryColor,
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: _sending ? null : _send,
                    child: const SizedBox(
                      width: 44,
                      height: 44,
                      child: Icon(Icons.send_rounded, color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static final OutlineInputBorder _pill = OutlineInputBorder(
    borderRadius: BorderRadius.circular(24),
    borderSide: BorderSide.none,
  );

  Widget _buildMessages() {
    if (_loadingHistory) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_messages.isEmpty && !_sending) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Ask me anything, or tap the mic to talk.',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(color: Colors.grey[500]),
          ),
        ),
      );
    }

    final count = _messages.length + (_sending ? 1 : 0);

    return ListView.builder(
      controller: _scroll,
      padding: const EdgeInsets.all(12),
      itemCount: count,
      itemBuilder: (context, index) {
        // Last item while waiting for the reply: a "typing" bubble.
        if (index == _messages.length) {
          return _bubble(
            isUser: false,
            child: Text(
              'Typing...',
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontStyle: FontStyle.italic,
                color: Colors.grey[600],
              ),
            ),
          );
        }

        final message = _messages[index];
        final isUser = message['sender'] == 'You';

        return _bubble(
          isUser: isUser,
          child: Text(
            message['text'] ?? '',
            style: GoogleFonts.poppins(
              fontSize: 14,
              height: 1.4,
              color: isUser ? Colors.white : Colors.black87,
            ),
          ),
        );
      },
    );
  }

  /// One speech bubble. The corner next to the sender is squared off.
  Widget _bubble({required bool isUser, required Widget child}) {
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.72,
        ),
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isUser ? AppTheme.primaryColor : const Color(0xFFEDEDED),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(isUser ? 18 : 4),
            bottomRight: Radius.circular(isUser ? 4 : 18),
          ),
        ),
        child: child,
      ),
    );
  }
}