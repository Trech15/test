import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:livekit_client/livekit_client.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/api_config.dart';
import '../services/mood_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_menu.dart';

/// One line of the live conversation (the user or the AI agent).
class _Turn {
  _Turn({required this.isUser, required this.text, required this.isFinal});

  final bool isUser;
  String text;
  bool isFinal;
}

class VoiceInputScreen extends StatefulWidget {
  const VoiceInputScreen({super.key});

  @override
  State<VoiceInputScreen> createState() => _VoiceInputScreenState();
}

class _VoiceInputScreenState extends State<VoiceInputScreen>
    with SingleTickerProviderStateMixin {
  // ============================================================
  // SERVER CONFIGURATION
  // ============================================================

  static const String tokenServerUrl = ApiConfig.tokenServerUrl;

  static const String liveKitUrl = ApiConfig.liveKitUrl;

  static const String backendUrl = ApiConfig.backendUrl;

  // ============================================================
  // AUTH HEADERS FOR FLASK
  // ============================================================
  // Flask checks this token to know which user is asking. Without it every
  // request to /chat is rejected with 401.

  Map<String, String> get _authHeaders => {
    'Content-Type': 'application/json',
    'Authorization':
        'Bearer ${Supabase.instance.client.auth.currentSession?.accessToken ?? ''}',
  };

  // ============================================================
  // LIVEKIT
  // ============================================================

  Room? _room;
  EventsListener<RoomEvent>? _roomListener;

  bool _isConnecting = false;
  bool _isConnected = false;
  bool _microphoneEnabled = false;

  String _status = 'Tap Connect to start voice chat';

  // ============================================================
  // CONVERSATION / ANALYSIS
  // ============================================================

  // Keyed by transcription segment id (insertion ordered).
  final Map<String, _Turn> _turns = {};

  // LiveKit repeats the same segment; remember which ones were handled.
  final Set<String> _seenSegmentIds = {};

  final ScrollController _chatScroll = ScrollController();

  bool _isAnalyzing = false;
  String _advice = '';
  List<String> _analysisMoods = [];

  late final AnimationController _waveController;

  // Real microphone / voice level (0..1) that drives the waveform.
  final ValueNotifier<double> _level = ValueNotifier<double>(0);
  Timer? _levelTimer;

  final ScrollController _pageScroll = ScrollController();

  bool _savedToHistory = false;
  String _saveError = '';

  bool get _isListening => _isConnected && _microphoneEnabled;

  List<_Turn> get _finalTurns =>
      _turns.values.where((t) => t.isFinal && t.text.isNotEmpty).toList();

  bool get _hasUserSpeech => _finalTurns.any((t) => t.isUser);

  @override
  void initState() {
    super.initState();
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
  }

  // ============================================================
  // SEND EACH FINAL USER TRANSCRIPT TO FLASK (saves mood + chat)
  // ============================================================

  Future<void> _sendVoiceTranscript(String transcript) async {
    final text = transcript.trim();

    if (text.isEmpty) {
      return;
    }

    final user = Supabase.instance.client.auth.currentUser;

    if (user == null) {
      debugPrint('❌ No logged-in user');
      return;
    }

    final mood = MoodService.detect(text);

    debugPrint('========================================');
    debugPrint('🎤 VOICE TRANSCRIPT');
    debugPrint('Text: $text');
    debugPrint('Detected mood: $mood');
    debugPrint('User ID: ${user.id}');
    debugPrint('Sending to: $backendUrl/chat');
    debugPrint('========================================');

    try {
      final response = await http
          .post(
            Uri.parse('$backendUrl/chat'),
            headers: _authHeaders,
            body: jsonEncode({
              'message': text,
              'user_id': user.id,
              'user_name':
                  (user.userMetadata?['full_name'] ??
                          user.userMetadata?['name'] ??
                          '')
                      .toString(),
              'mood': mood,
              'selected_moods': mood != null ? [mood] : [],
            }),
          )
          .timeout(const Duration(seconds: 60));

      debugPrint('📥 Flask response: ${response.statusCode}');
      debugPrint('📥 Flask body: ${response.body}');

      if (response.statusCode != 200) {
        debugPrint('❌ Flask returned error: ${response.statusCode}');
        return;
      }

      final decoded = jsonDecode(response.body);

      if (decoded is! Map<String, dynamic>) {
        debugPrint('❌ Invalid Flask response format');
        return;
      }

      final aiResponse = decoded['response']?.toString() ?? '';
      final moodSaved = decoded['mood_saved'] == true;

      debugPrint('🤖 AI response: $aiResponse');
      debugPrint('💾 Mood saved: $moodSaved');
      debugPrint('💾 Chat saved: ${decoded['chat_saved']}');

      // Flask could not save the mood (e.g. bad key): save it directly.
      if (mood != null && !moodSaved) {
        await MoodService.saveDirectly(
          mood: mood,
          question: text,
          aiResponse: aiResponse,
        );
      }
    } catch (error, stackTrace) {
      debugPrint('❌ Voice transcript error: $error');

      debugPrintStack(stackTrace: stackTrace);

      // Flask unreachable: still save the mood.
      if (mood != null) {
        await MoodService.saveDirectly(mood: mood, question: text);
      }
    }
  }

  // ============================================================
  // ANALYZE: whole conversation -> advice
  // ============================================================

  Future<void> _analyze() async {
    if (_isAnalyzing) return;

    debugPrint(
      '🧠 ANALYZE tapped | turns=${_turns.length} | '
      'userSpeech=$_hasUserSpeech',
    );

    final finalTurns = _finalTurns;

    final userText = finalTurns
        .where((t) => t.isUser)
        .map((t) => t.text)
        .join(' ')
        .trim();

    if (userText.isEmpty) {
      _showError('Talk to the AI first, then tap Analyze.');
      return;
    }

    final user = Supabase.instance.client.auth.currentUser;

    if (user == null) {
      _showError('You are not logged in.');
      return;
    }

    // Every mood the student mentioned during the conversation.
    final moods = <String>[];
    for (final t in finalTurns.where((t) => t.isUser)) {
      final m = MoodService.detect(t.text);
      if (m != null && !moods.contains(m)) moods.add(m);
    }

    final conversation = finalTurns
        .map((t) => '${t.isUser ? 'Student' : 'AI'}: ${t.text}')
        .join('\n');

    final message =
        'Below is a voice conversation between a student and a supportive '
        'AI assistant. Based on what the student shared, explain what the '
        'main problem is and give clear, practical steps the student can '
        'do now to deal with it.\n\n$conversation';

    setState(() {
      _isAnalyzing = true;
      _advice = '';
      _analysisMoods = moods;
      _savedToHistory = false;
      _saveError = '';
    });

    _scrollPageToBottom();

    try {
      debugPrint('🧠 ANALYZE → $backendUrl/chat | moods=$moods');

      final response = await http
          .post(
            Uri.parse('$backendUrl/chat'),
            headers: _authHeaders,
            body: jsonEncode({
              'message': message,
              'user_id': user.id,
              // No mood is sent so this request is not counted as a new
              // mood entry. 'save': false and 'analysis': true tell the
              // backend not to store this request or add it to its memory.
              'mood': null,
              'selected_moods': [],
              'save': false,
              'analysis': true,
            }),
          )
          // Render's free tier can take a while to wake up.
          .timeout(const Duration(seconds: 90));

      debugPrint('📥 Flask ${response.statusCode}: ${response.body}');

      if (response.statusCode != 200) {
        throw Exception(
          'Backend returned ${response.statusCode}: ${response.body}',
        );
      }

      final decoded = jsonDecode(response.body);

      if (decoded is! Map<String, dynamic>) {
        throw Exception('Invalid response from backend');
      }

      final advice = decoded['response']?.toString().trim() ?? '';

      if (advice.isEmpty) {
        throw Exception('The backend returned an empty response');
      }

      if (!mounted) return;

      setState(() {
        _advice = advice;
        _isAnalyzing = false;
      });

      _scrollPageToBottom();

      // Keep the advice so the student can read it again in History.
      await _saveSession(turns: finalTurns, moods: moods, advice: advice);

      _scrollPageToBottom();
    } catch (error, stackTrace) {
      debugPrint('❌ Analyze error: $error');
      debugPrintStack(stackTrace: stackTrace);

      if (!mounted) return;

      setState(() => _isAnalyzing = false);

      _showError('Could not analyze: $error');
    }
  }

  // ============================================================
  // RE-RECORD (clears the conversation shown + advice)
  // ============================================================

  void _reRecord() {
    setState(() {
      _turns.clear();
      _advice = '';
      _analysisMoods = [];
    });
  }

  void _openAdvice() {
    final userText = _finalTurns
        .where((t) => t.isUser)
        .map((t) => t.text)
        .join(' ')
        .trim();

    Navigator.pushNamed(
      context,
      '/advice',
      arguments: {
        'text': userText,
        'moods': _analysisMoods,
        'aiResponse': _advice,
      },
    );
  }

  // ============================================================
  // REAL WAVEFORM: follow the actual voice level (you + the AI)
  // ============================================================

  void _startLevelMeter() {
    _levelTimer?.cancel();

    _levelTimer = Timer.periodic(const Duration(milliseconds: 80), (_) {
      final room = _room;

      if (room == null) {
        _level.value = 0;
        return;
      }

      double target = 0;

      final local = room.localParticipant;
      if (local != null && _microphoneEnabled) {
        target = math.max(target, local.audioLevel);
      }

      for (final participant in room.remoteParticipants.values) {
        target = math.max(target, participant.audioLevel);
      }

      // Raw levels are small, so boost them, then smooth the movement.
      target = (target * 3).clamp(0.0, 1.0);
      _level.value = _level.value * 0.55 + target * 0.45;
    });
  }

  void _stopLevelMeter() {
    _levelTimer?.cancel();
    _levelTimer = null;
    _level.value = 0;
  }

  // ============================================================
  // SAVE THE ANALYZED SESSION (shows up in History)
  // ============================================================

  Future<void> _saveSession({
    required List<_Turn> turns,
    required List<String> moods,
    required String advice,
  }) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    try {
      await Supabase.instance.client.from('voice_sessions').insert({
        'user_id': user.id,
        'conversation': turns
            .map((t) => {'role': t.isUser ? 'user' : 'ai', 'text': t.text})
            .toList(),
        'mood': moods.isNotEmpty ? moods.first : null,
        'advice': advice,
      });

      debugPrint('💾 voice session saved to history');

      if (!mounted) return;
      setState(() {
        _savedToHistory = true;
        _saveError = '';
      });
    } catch (e) {
      debugPrint('❌ voice_sessions save failed: $e');

      if (!mounted) return;
      setState(() {
        _savedToHistory = false;
        _saveError = e.toString();
      });
    }
  }

  void _scrollPageToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_pageScroll.hasClients) return;
      _pageScroll.animateTo(
        _pageScroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOut,
      );
    });
  }

  void _showError(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  void _scrollChatToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_pageScroll.hasClients) return;
      _pageScroll.animateTo(
        _pageScroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    });
  }

  // ============================================================
  // GET LIVEKIT TOKEN
  // ============================================================

  Future<String> _getToken() async {
    final response = await http
        .get(
          Uri.parse(tokenServerUrl).replace(
            queryParameters: {
              // Tells the voice agent WHO is calling, so it can remember them.
              if (Supabase.instance.client.auth.currentUser != null)
                'user_id': Supabase.instance.client.auth.currentUser!.id,
              if (Supabase.instance.client.auth.currentUser != null)
                'name':
                    (Supabase
                                .instance
                                .client
                                .auth
                                .currentUser!
                                .userMetadata?['full_name'] ??
                            '')
                        .toString(),
            },
          ),
        )
        .timeout(const Duration(seconds: 75));

    if (response.statusCode != 200) {
      throw Exception(
        'Token server returned '
        '${response.statusCode}: ${response.body}',
      );
    }

    final decoded = jsonDecode(response.body);

    if (decoded is! Map<String, dynamic>) {
      throw Exception('Invalid token server response');
    }

    final token = decoded['token'];

    if (token is! String || token.isEmpty) {
      throw Exception('Token server did not return a token');
    }

    return token;
  }

  // ============================================================
  // LIVEKIT ROOM EVENTS
  // ============================================================

  void _listenForRoomEvents(Room room) {
    _roomListener = room.createListener();

    _roomListener!
      ..on<ParticipantConnectedEvent>((event) {
        debugPrint(
          'LIVEKIT: participant connected: '
          '${event.participant.identity}',
        );
      })
      ..on<ParticipantDisconnectedEvent>((event) {
        debugPrint(
          'LIVEKIT: participant disconnected: '
          '${event.participant.identity}',
        );
      })
      ..on<TrackSubscribedEvent>((event) {
        debugPrint(
          'LIVEKIT: remote track subscribed: '
          'participant=${event.participant.identity}, '
          'source=${event.publication.source}, '
          'track=${event.track.runtimeType}',
        );
      })
      ..on<TrackUnsubscribedEvent>((event) {
        debugPrint(
          'LIVEKIT: remote track unsubscribed: '
          '${event.participant.identity}, '
          'source=${event.publication.source}',
        );
      })
      // ----------------------------------------------------------
      // VOICE TRANSCRIPTION: both sides of the conversation.
      //  - the student  -> shown + final lines saved through Flask
      //  - the AI agent -> shown only
      // ----------------------------------------------------------
      ..on<TranscriptionEvent>((event) async {
        final isMe =
            event.participant.identity == room.localParticipant?.identity;

        for (final segment in event.segments) {
          final text = segment.text.trim();

          if (text.isEmpty) {
            continue;
          }

          debugPrint(
            '🎤 TRANSCRIPT [${isMe ? 'USER' : 'AGENT'}]: $text '
            '| FINAL: ${segment.isFinal}',
          );

          if (!mounted) return;

          setState(() {
            final existing = _turns[segment.id];

            if (existing != null) {
              existing.text = text;
              existing.isFinal = segment.isFinal;
            } else {
              _turns[segment.id] = _Turn(
                isUser: isMe,
                text: text,
                isFinal: segment.isFinal,
              );
            }
          });

          _scrollChatToBottom();

          // Only the student's final lines go to Flask.
          if (!isMe || !segment.isFinal) {
            continue;
          }

          // Same segment can arrive more than once.
          if (!_seenSegmentIds.add(segment.id)) {
            continue;
          }

          debugPrint('✅ FINAL TRANSCRIPT: $text');

          await _sendVoiceTranscript(text);
        }
      })
      ..on<RoomDisconnectedEvent>((event) {
        debugPrint('LIVEKIT: room disconnected: ${event.reason}');
      });
  }

  // ============================================================
  // CONNECT TO LIVEKIT (unchanged)
  // ============================================================

  Future<void> _connectToLiveKit() async {
    if (_isConnecting || _isConnected) {
      return;
    }

    Room? connectingRoom;

    setState(() {
      _isConnecting = true;
      _status = 'Requesting microphone permission...';
      _turns.clear();
      _advice = '';
      _analysisMoods = [];
      _seenSegmentIds.clear();
    });

    try {
      final permission = await Permission.microphone.request();

      if (!permission.isGranted) {
        throw Exception('Microphone permission was denied');
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _status = 'Requesting LiveKit token...';
      });

      final token = await _getToken();

      if (!mounted) {
        return;
      }

      setState(() {
        _status = 'Connecting to LiveKit...';
      });

      connectingRoom = Room(
        roomOptions: const RoomOptions(adaptiveStream: true, dynacast: true),
      );

      // IMPORTANT:
      // Register event listeners BEFORE connecting.
      _listenForRoomEvents(connectingRoom);

      await connectingRoom.connect(liveKitUrl, token);

      final localParticipant = connectingRoom.localParticipant;

      if (localParticipant == null) {
        throw Exception('Local participant was not created');
      }

      await localParticipant.setMicrophoneEnabled(true);

      if (!mounted) {
        await connectingRoom.disconnect();
        return;
      }

      _room = connectingRoom;

      setState(() {
        _isConnecting = false;
        _isConnected = true;
        _microphoneEnabled = true;
        _status = 'Connected. You can speak now.';
      });

      debugPrint('LIVEKIT: voice room connected');

      _startLevelMeter();
    } catch (error, stackTrace) {
      debugPrint('LIVEKIT connection error: $error');

      debugPrintStack(stackTrace: stackTrace);

      await connectingRoom?.disconnect();
      await _disposeRoomListener();

      if (!mounted) {
        return;
      }

      setState(() {
        _isConnecting = false;
        _isConnected = false;
        _microphoneEnabled = false;
        _status = 'Connection failed';
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 10),
          content: Text('LiveKit error: $error'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // ============================================================
  // MICROPHONE TOGGLE (unchanged)
  // ============================================================

  Future<void> _toggleMicrophone() async {
    final participant = _room?.localParticipant;

    if (participant == null) {
      return;
    }

    try {
      final enabled = !_microphoneEnabled;

      await participant.setMicrophoneEnabled(enabled);

      if (!mounted) {
        return;
      }

      setState(() {
        _microphoneEnabled = enabled;

        _status = enabled
            ? 'Microphone on. You can speak now.'
            : 'Microphone muted.';
      });
    } catch (error) {
      debugPrint('LIVEKIT microphone error: $error');

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Microphone error: $error'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // ============================================================
  // DISPOSE ROOM LISTENER (unchanged)
  // ============================================================

  Future<void> _disposeRoomListener() async {
    final listener = _roomListener;

    _roomListener = null;

    listener?.dispose();
  }

  // ============================================================
  // DISCONNECT (unchanged)
  // ============================================================

  Future<void> _disconnect({bool showStatus = true}) async {
    debugPrint('LIVEKIT: disconnecting voice room');

    final room = _room;

    _room = null;

    _stopLevelMeter();

    await _disposeRoomListener();

    if (mounted) {
      setState(() {
        _isConnected = false;
        _isConnecting = false;
        _microphoneEnabled = false;

        if (showStatus) {
          _status = 'Disconnecting...';
        }
      });
    }

    if (room != null) {
      await room.disconnect();
    }

    if (mounted && showStatus) {
      setState(() {
        _status = 'Disconnected. Tap Connect to start again.';
      });
    }
  }

  // ============================================================
  // UI PIECES (same design as the voice mode in chat_screen.dart)
  // ============================================================

  Widget _buildMessageList() {
    final turns = _turns.values.toList();
    final hasAdvice = _advice.isNotEmpty;

    if (turns.isEmpty && !hasAdvice) {
      return Center(
        child: Text(
          'Connect to start a voice conversation',
          textAlign: TextAlign.center,
          style: GoogleFonts.poppins(color: Colors.grey[500]),
        ),
      );
    }

    return ListView(
      controller: _pageScroll,
      padding: const EdgeInsets.all(12),
      children: [
        ...turns.map(_buildTurn),
        if (hasAdvice) ...[const SizedBox(height: 12), _buildAdviceCard()],
      ],
    );
  }

  Widget _buildTurn(_Turn turn) {
    final isUser = turn.isUser;

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 320),
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isUser ? AppTheme.primaryColor : Colors.grey[300],
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          turn.text,
          style: TextStyle(
            // Words still being recognised are shown a little lighter.
            color: (isUser ? Colors.white : Colors.black87).withOpacity(
              turn.isFinal ? 1.0 : 0.65,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWaveform() {
    const barCount = 17;

    return SizedBox(
      height: 40,
      child: ValueListenableBuilder<double>(
        valueListenable: _level,
        builder: (context, level, _) {
          return AnimatedBuilder(
            animation: _waveController,
            builder: (context, _) {
              return Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(barCount, (i) {
                  // Bars ripple, but only grow when someone is really talking.
                  final phase = _waveController.value * 2 * math.pi + i * 0.7;
                  final ripple = 0.35 + 0.65 * math.sin(phase).abs();
                  final amount = (0.08 + level * ripple).clamp(0.08, 1.0);
                  final height = 5 + 31 * amount;

                  final distance =
                      (i - (barCount - 1) / 2).abs() / (barCount / 2);
                  final opacity = 0.35 + 0.65 * (1 - distance);

                  return Container(
                    width: 5,
                    height: height,
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withOpacity(opacity),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  );
                }),
              );
            },
          );
        },
      ),
    );
  }

  /// Analyze conversation  |  Re-record
  Widget _buildAnalyzeBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _isAnalyzing ? null : _analyze,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.primaryColor,
                side: BorderSide(color: AppTheme.primaryColor),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: _isAnalyzing
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.insights_rounded),
              label: Text(
                _isAnalyzing ? 'Analyzing...' : 'Analyze conversation →',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
              ),
            ),
          ),
          const SizedBox(width: 8),
          OutlinedButton(
            onPressed: (_turns.isNotEmpty && !_isAnalyzing) ? _reRecord : null,
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.grey[700],
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              'Re-record',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  /// Status text + Connect / Mute / Unmute + End
  Widget _buildVoiceControls() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Text(
            _status,
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              color: _isConnected ? AppTheme.primaryColor : Colors.grey[600],
            ),
          ),

          const SizedBox(height: 16),

          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton.icon(
                onPressed: _isConnecting
                    ? null
                    : _isConnected
                    ? _toggleMicrophone
                    : _connectToLiveKit,
                icon: Icon(
                  _isConnected && !_microphoneEnabled
                      ? Icons.mic_off
                      : Icons.mic,
                ),
                label: Text(
                  _isConnecting
                      ? 'Connecting...'
                      : _isConnected
                      ? _microphoneEnabled
                            ? 'Mute'
                            : 'Unmute'
                      : 'Connect',
                ),
              ),

              const SizedBox(width: 12),

              if (_isConnected)
                OutlinedButton.icon(
                  onPressed: () => _disconnect(),
                  icon: const Icon(Icons.call_end),
                  label: const Text('End'),
                ),
            ],
          ),
        ],
      ),
    );
  }

  /// "What you can do" card (same look as the analysis sheet in chat_screen)
  Widget _buildAdviceCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.primaryColor.withOpacity(0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.lightbulb_outline_rounded,
                color: AppTheme.primaryColor,
              ),
              const SizedBox(width: 8),
              Text(
                'What you can do',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.darkColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            _advice,
            style: GoogleFonts.poppins(
              fontSize: 14,
              height: 1.55,
              color: AppTheme.darkColor,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                _savedToHistory ? Icons.check_circle : Icons.info_outline,
                size: 16,
                color: _savedToHistory ? AppTheme.primaryColor : Colors.orange,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  _savedToHistory
                      ? 'Saved. You can read it again in History.'
                      : (_saveError.isEmpty
                            ? 'Saving...'
                            : 'Not saved: $_saveError'),
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    height: 1.4,
                    color: Colors.grey[600],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: _openAdvice,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.primaryColor,
                side: BorderSide(color: AppTheme.primaryColor),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                'View Personalized Advice →',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        backgroundColor: AppTheme.primaryColor,
        elevation: 0,
        leading: AppMenuButton(
          onBack: () => _disconnect(showStatus: false),
          onBeforeNavigate: () => _disconnect(showStatus: false),
        ),
        leadingWidth: AppMenu.leadingWidthFor(context),
        title: Text(
          'Voice Chat',
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ),

      // SafeArea keeps the bottom controls above the phone's back/home
      // buttons or gesture bar, on every phone.
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Expanded(child: _buildMessageList()),

            if (_isConnected)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: _buildWaveform(),
              ),

            _buildAnalyzeBar(),

            _buildVoiceControls(),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // SCREEN DISPOSE
  // ============================================================

  @override
  void dispose() {
    debugPrint('LIVEKIT: VoiceInputScreen disposed');

    _levelTimer?.cancel();
    _level.dispose();
    _pageScroll.dispose();
    _waveController.dispose();
    _chatScroll.dispose();

    final room = _room;

    _room = null;

    _roomListener?.dispose();

    _roomListener = null;

    room?.disconnect();

    super.dispose();
  }
}