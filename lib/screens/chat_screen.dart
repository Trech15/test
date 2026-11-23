import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:livekit_client/livekit_client.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/api_config.dart';
import '../services/analysis_service.dart';
import '../services/mood_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_menu.dart';

class ChatPage extends StatefulWidget {
  const ChatPage({super.key});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  // ============================================================
  // SERVERS
  // ============================================================

  // LiveKit token server
  static const String tokenServerUrl = ApiConfig.tokenServerUrl;

  // LiveKit Cloud
  static const String liveKitUrl = ApiConfig.liveKitUrl;

  // Flask backend
  // Must match the IPv4 address Flask prints when it starts.
  static const String backendUrl = ApiConfig.backendUrl;

  // ============================================================
  // CONTROLLERS
  // ============================================================

  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  // ============================================================
  // CHAT STATE
  // ============================================================

  final List<Map<String, String>> _messages = [];

  // Prevent duplicate voice transcripts.
  final Set<String> _processedTranscripts = <String>{};

  // LiveKit sends the same transcription segment several times; remember
  // which ones we already handled.
  final Set<String> _seenSegmentIds = <String>{};

  // ============================================================
  // LIVEKIT
  // ============================================================

  Room? _room;
  EventsListener<RoomEvent>? _roomListener;

  // ============================================================
  // UI STATE
  // ============================================================

  bool _voiceMode = true;
  bool _isLoading = false;
  bool _isConnecting = false;
  bool _isConnected = false;
  bool _microphoneEnabled = false;

  String _voiceStatus = 'Tap Connect to start voice chat';

  // Analyze only looks at messages added after the old history loaded.
  int _sessionStart = 0;
  bool _isAnalyzing = false;

  // ============================================================
  // AUTH HEADERS FOR FLASK
  // ============================================================
  // Flask checks this token to know which user is asking, so the database
  // row-level security policies (auth.uid() = user_id) pass.

  Map<String, String> get _authHeaders => {
    'Content-Type': 'application/json',
    'Authorization':
        'Bearer ${Supabase.instance.client.auth.currentSession?.accessToken ?? ''}',
  };

  // ============================================================
  // INIT
  // ============================================================

  @override
  void initState() {
    super.initState();

    debugPrint('CHAT: ChatPage initialized');

    _loadHistory();
  }

  // ============================================================
  // MESSAGE HELPERS
  // ============================================================

  void _scrollToBottom({bool jump = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      final end = _scrollController.position.maxScrollExtent;
      if (jump) {
        _scrollController.jumpTo(end);
      } else {
        _scrollController.animateTo(
          end,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _addMessage(String sender, String text) {
    if (!mounted) return;
    setState(() => _messages.add({'sender': sender, 'text': text}));
    _scrollToBottom();
  }

  // ============================================================
  // LOAD CHAT HISTORY
  // ============================================================

  Future<void> _loadHistory() async {
    final user = Supabase.instance.client.auth.currentUser;

    if (user == null) {
      debugPrint('CHAT: No logged-in user while loading history');
      return;
    }

    debugPrint('CHAT: Loading chat history for user ${user.id}');

    try {
      final response = await Supabase.instance.client
          .from('chat_history')
          .select()
          .eq('user_id', user.id)
          .order('created_at');

      if (!mounted) {
        return;
      }

      setState(() {
        _messages.clear();

        for (final row in response) {
          final message = row['message']?.toString() ?? '';

          final reply = row['response']?.toString() ?? '';

          if (message.isNotEmpty) {
            _messages.add({'sender': 'You', 'text': message});
          }

          if (reply.isNotEmpty) {
            _messages.add({'sender': 'Bot', 'text': reply});
          }
        }

        // Only messages added after this point count for Analyze.
        _sessionStart = _messages.length;
      });

      _scrollToBottom(jump: true);

      debugPrint('CHAT: Loaded ${_messages.length} chat messages');
    } catch (error) {
      debugPrint('CHAT: Error loading chat history: $error');
    }
  }

  /// The speech-to-text service labels speakers, e.g. "<Jeff>hello</Jeff>".
  /// Remove those labels so only the spoken words are shown and sent.
  String _stripSpeakerTags(String text) {
    return text.replaceAll(RegExp(r'</?[A-Za-z0-9_ .\-]{1,40}>'), '').trim();
  }

  // ============================================================
  // LIVEKIT TOKEN
  // ============================================================

  Future<String> _getLiveKitToken() async {
    debugPrint('LIVEKIT: Requesting token from $tokenServerUrl');

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

    debugPrint('LIVEKIT: Token server status ${response.statusCode}');

    debugPrint('LIVEKIT: Token response ${response.body}');

    if (response.statusCode != 200) {
      throw Exception(
        'Token server returned ${response.statusCode}: '
        '${response.body}',
      );
    }

    final decoded = jsonDecode(response.body);

    if (decoded is! Map<String, dynamic>) {
      throw Exception('Invalid token server response');
    }

    final token = decoded['token'];

    if (token is! String || token.isEmpty) {
      throw Exception('Token was missing from response');
    }

    return token;
  }

  // ============================================================
  // SEND TEXT MESSAGE
  // ============================================================

  Future<void> _sendTextMessage() async {
    final userMessage = _messageController.text.trim();

    if (userMessage.isEmpty || _isLoading) {
      return;
    }

    final user = Supabase.instance.client.auth.currentUser;

    if (user == null) {
      _showError('You are not logged in.');
      return;
    }

    final detectedMood = MoodService.detect(userMessage);

    debugPrint('');
    debugPrint('========================================');
    debugPrint('TEXT CHAT');
    debugPrint('========================================');
    debugPrint('User ID: ${user.id}');
    debugPrint('Message: $userMessage');
    debugPrint('Detected mood: $detectedMood');
    debugPrint('Backend: $backendUrl/chat');
    debugPrint('========================================');

    setState(() {
      _messages.add({'sender': 'You', 'text': userMessage});

      _isLoading = true;
    });
    _scrollToBottom();

    _messageController.clear();

    try {
      final response = await http
          .post(
            Uri.parse('$backendUrl/chat'),
            headers: _authHeaders,
            body: jsonEncode({
              'message': userMessage,
              'user_id': user.id,
              'user_name':
                  (user.userMetadata?['full_name'] ??
                          user.userMetadata?['name'] ??
                          '')
                      .toString(),
              'mood': detectedMood,
              'selected_moods': detectedMood != null ? [detectedMood] : [],
            }),
          )
          .timeout(const Duration(seconds: 60));

      debugPrint('TEXT: Flask status = ${response.statusCode}');

      debugPrint('TEXT: Flask response = ${response.body}');

      if (response.statusCode != 200) {
        throw Exception(
          'Backend returned ${response.statusCode}: '
          '${response.body}',
        );
      }

      final decoded = jsonDecode(response.body);

      final botResponse =
          decoded['response']?.toString() ?? 'Sorry, I could not process that.';

      final chatSaved = decoded['chat_saved'] == true;

      final moodSaved = decoded['mood_saved'] == true;

      final returnedMood = decoded['mood']?.toString();

      debugPrint('TEXT: chat_saved = $chatSaved');

      debugPrint('TEXT: mood_saved = $moodSaved');

      debugPrint('TEXT: mood = $returnedMood');

      if (!mounted) {
        return;
      }

      setState(() {
        _messages.add({'sender': 'Bot', 'text': botResponse});

        _isLoading = false;
      });
      _scrollToBottom();

      // --------------------------------------------------------
      // FALLBACK MOOD SAVE
      // --------------------------------------------------------
      //
      // Flask should normally save the mood.
      // If Flask reports mood_saved=false, Flutter tries
      // directly so we can still get the mood into Supabase.
      //

      if (detectedMood != null && !moodSaved) {
        debugPrint(
          'MOOD: Flask did not save mood. '
          'Trying direct Supabase save...',
        );

        final directSaved = await MoodService.saveDirectly(
          mood: detectedMood,
          question: userMessage,
          aiResponse: botResponse,
        );

        debugPrint('MOOD: Direct fallback result = $directSaved');
      }

      if (!chatSaved) {
        debugPrint('WARNING: Flask reported chat_saved=false');
      }

      debugPrint('TEXT CHAT COMPLETE');
      debugPrint('========================================');
    } catch (error) {
      debugPrint('❌ TEXT CHAT ERROR: $error');

      // Flask unreachable: still save the mood so the dashboard works.
      if (detectedMood != null) {
        await MoodService.saveDirectly(
          mood: detectedMood,
          question: userMessage,
        );
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _isLoading = false;
      });

      _showError('Text chat failed: $error');
    }
  }

  // ============================================================
  // SEND VOICE TRANSCRIPT TO FLASK
  // ============================================================

  Future<void> _sendVoiceTranscript(String transcript) async {
    final message = transcript.trim();

    if (message.isEmpty) {
      return;
    }

    final user = Supabase.instance.client.auth.currentUser;

    if (user == null) {
      debugPrint('VOICE: ❌ No logged-in Supabase user');

      _processedTranscripts.remove(message);
      return;
    }

    final detectedMood = MoodService.detect(message);

    debugPrint('');
    debugPrint('========================================');
    debugPrint('VOICE TRANSCRIPT');
    debugPrint('========================================');
    debugPrint('User ID: ${user.id}');
    debugPrint('Message: $message');
    debugPrint('Detected mood: $detectedMood');
    debugPrint('Backend: $backendUrl/chat');
    debugPrint('========================================');

    try {
      // The user's bubble is already added by the transcription handler.
      if (mounted) {
        setState(() => _isLoading = true);
      }

      final response = await http
          .post(
            Uri.parse('$backendUrl/chat'),
            headers: _authHeaders,
            body: jsonEncode({
              'message': message,
              'user_id': user.id,
              'user_name':
                  (user.userMetadata?['full_name'] ??
                          user.userMetadata?['name'] ??
                          '')
                      .toString(),
              'mood': detectedMood,
              'selected_moods': detectedMood != null ? [detectedMood] : [],
            }),
          )
          .timeout(const Duration(seconds: 60));

      debugPrint('VOICE: Flask status = ${response.statusCode}');

      debugPrint('VOICE: Flask response = ${response.body}');

      if (response.statusCode != 200) {
        throw Exception(
          'Backend returned ${response.statusCode}: '
          '${response.body}',
        );
      }

      final decoded = jsonDecode(response.body);

      final botResponse =
          decoded['response']?.toString() ?? 'Sorry, I could not process that.';

      final chatSaved = decoded['chat_saved'] == true;

      final moodSaved = decoded['mood_saved'] == true;

      final returnedMood = decoded['mood']?.toString();

      debugPrint('VOICE: chat_saved = $chatSaved');

      debugPrint('VOICE: mood_saved = $moodSaved');

      debugPrint('VOICE: mood = $returnedMood');

      if (!mounted) {
        return;
      }

      // In voice mode the LiveKit agent already answers out loud and its
      // transcript is shown as the Bot bubble, so Flask's reply is only
      // used for saving chat/mood. Don't show it a second time.
      setState(() => _isLoading = false);

      // --------------------------------------------------------
      // FALLBACK MOOD SAVE
      // --------------------------------------------------------

      if (detectedMood != null && !moodSaved) {
        debugPrint('VOICE MOOD: Flask did not save mood.');

        debugPrint('VOICE MOOD: Trying direct Supabase save...');

        final directSaved = await MoodService.saveDirectly(
          mood: detectedMood,
          question: message,
          aiResponse: botResponse,
        );

        debugPrint('VOICE MOOD: Direct save result = $directSaved');
      }

      debugPrint('VOICE TRANSCRIPT COMPLETE');

      debugPrint('========================================');
    } catch (error) {
      debugPrint('❌ VOICE → FLASK ERROR: $error');

      // Flask unreachable: still save the mood so the dashboard works.
      if (detectedMood != null) {
        await MoodService.saveDirectly(mood: detectedMood, question: message);
      }

      // Allow this exact transcript to be retried.
      _processedTranscripts.remove(message);

      if (!mounted) {
        return;
      }

      setState(() {
        _isLoading = false;
      });

      _showError('Voice message failed: $error');
    }
  }

  // ============================================================
  // LIVEKIT EVENTS
  // ============================================================

  void _listenForRoomEvents(Room room) {
    _roomListener?.dispose();

    _roomListener = room.createListener();

    _roomListener!
      ..on<RoomConnectedEvent>((event) {
        debugPrint('LIVEKIT: room connected');
      })
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
          'participant=${event.participant.identity}, '
          'source=${event.publication.source}',
        );
      })
      // ========================================================
      // THIS IS THE IMPORTANT TRANSCRIPTION HANDLER
      // ========================================================
      ..on<TranscriptionEvent>((event) async {
        // LiveKit sends transcripts for EVERYONE in the room, including the
        // AI agent's own speech. Only the local user is "You".
        final myIdentity = room.localParticipant?.identity;
        final isMe = event.participant.identity == myIdentity;

        for (final segment in event.segments) {
          final text = _stripSpeakerTags(segment.text);

          if (text.isEmpty || !segment.isFinal) {
            continue;
          }

          // Same segment can arrive more than once.
          if (!_seenSegmentIds.add(segment.id)) {
            continue;
          }

          debugPrint(
            '🎤 TRANSCRIPT [${isMe ? 'USER' : 'AGENT'} '
            '${event.participant.identity}]: $text',
          );

          if (isMe) {
            _addMessage('You', text);

            // Only the user's own words go to Flask (mood + chat save).
            await _sendVoiceTranscript(text);
          } else {
            // AI agent speech: show as Bot, never send to Flask,
            // never run mood detection on it.
            _addMessage('Bot', text);
          }
        }
      })
      ..on<RoomDisconnectedEvent>((event) {
        debugPrint(
          'LIVEKIT: room disconnected: '
          '${event.reason}',
        );
      });
  }

  // ============================================================
  // CONNECT LIVEKIT
  // ============================================================

  Future<void> _connectToLiveKit() async {
    if (_isConnecting || _isConnected) {
      return;
    }

    Room? connectingRoom;

    if (mounted) {
      setState(() {
        _isConnecting = true;
        _voiceStatus = 'Requesting LiveKit token...';
      });
    }

    try {
      final token = await _getLiveKitToken();

      if (!mounted) {
        return;
      }

      setState(() {
        _voiceStatus = 'Connecting to LiveKit...';
      });

      connectingRoom = Room(
        roomOptions: const RoomOptions(adaptiveStream: true, dynacast: true),
      );

      _listenForRoomEvents(connectingRoom);

      debugPrint('LIVEKIT: Connecting to $liveKitUrl');

      await connectingRoom.connect(liveKitUrl, token);

      debugPrint('LIVEKIT: Connected successfully');

      final localParticipant = connectingRoom.localParticipant;

      if (localParticipant == null) {
        throw Exception('Local participant was not created');
      }

      await localParticipant.setMicrophoneEnabled(true);

      debugPrint('LIVEKIT: Microphone enabled');

      if (!mounted) {
        await connectingRoom.disconnect();
        return;
      }

      _room = connectingRoom;

      setState(() {
        _isConnecting = false;
        _isConnected = true;
        _microphoneEnabled = true;
        _voiceStatus = 'Connected. Speak now.';
      });

      debugPrint('LIVEKIT: chat voice room connected');
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
        _voiceStatus = 'Connection failed';
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
  // TOGGLE MICROPHONE
  // ============================================================

  Future<void> _toggleMicrophone() async {
    final participant = _room?.localParticipant;

    if (participant == null) {
      debugPrint('LIVEKIT: No local participant');
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

        _voiceStatus = enabled
            ? 'Microphone on. Speak now.'
            : 'Microphone muted.';
      });

      debugPrint('LIVEKIT: Microphone enabled = $enabled');
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
  // DISPOSE LISTENER
  // ============================================================

  Future<void> _disposeRoomListener() async {
    final listener = _roomListener;

    _roomListener = null;

    listener?.dispose();
  }

  // ============================================================
  // DISCONNECT LIVEKIT
  // ============================================================

  Future<void> _disconnectFromLiveKit({bool showStatus = true}) async {
    debugPrint('LIVEKIT: manually disconnecting chat room');

    final room = _room;

    _room = null;

    await _disposeRoomListener();

    if (room != null) {
      await room.disconnect();
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _isConnected = false;
      _isConnecting = false;
      _microphoneEnabled = false;

      if (showStatus) {
        _voiceStatus = 'Disconnected';
      }
    });
  }

  // ============================================================
  // ANALYZE THE CONVERSATION (voice AND typed messages)
  // ============================================================

  Future<void> _analyzeConversation() async {
    if (_isAnalyzing) return;

    final start = _sessionStart.clamp(0, _messages.length);

    // Only what was said since this page opened (not the old history).
    final turns = _messages
        .sublist(start)
        .where((m) => (m['text'] ?? '').trim().isNotEmpty)
        .map(
          (m) => <String, String>{
            'role': m['sender'] == 'You' ? 'user' : 'ai',
            'text': (m['text'] ?? '').trim(),
          },
        )
        .toList();

    final hasUserMessage = turns.any((t) => t['role'] == 'user');

    debugPrint(
      '🧠 CHAT ANALYZE tapped | turns=${turns.length} | '
      'userMessages=$hasUserMessage',
    );

    if (!hasUserMessage) {
      _showError('Talk or type to the AI first, then tap Analyze.');
      return;
    }

    setState(() => _isAnalyzing = true);

    try {
      final result = await AnalysisService.analyze(turns);

      String? saveError;

      try {
        await AnalysisService.saveSession(
          turns: turns,
          moods: result.moods,
          advice: result.advice,
        );
      } catch (e) {
        saveError = e.toString();
        debugPrint('❌ Could not save session: $e');
      }

      if (!mounted) return;

      setState(() => _isAnalyzing = false);

      final userText = turns
          .where((t) => t['role'] == 'user')
          .map((t) => t['text'])
          .join(' ');

      _showAnalysisSheet(result, userText, saveError);
    } catch (error) {
      debugPrint('❌ Chat analyze error: $error');

      if (!mounted) return;

      setState(() => _isAnalyzing = false);

      _showError('Could not analyze: $error');
    }
  }

  void _showAnalysisSheet(
    AnalysisResult result,
    String userText,
    String? saveError,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.4,
          maxChildSize: 0.95,
          expand: false,
          builder: (context, controller) {
            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: ListView(
                controller: controller,
                padding: const EdgeInsets.all(24),
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
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
                    result.advice,
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
                        saveError == null
                            ? Icons.check_circle
                            : Icons.info_outline,
                        size: 16,
                        color: saveError == null
                            ? AppTheme.primaryColor
                            : Colors.orange,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          saveError == null
                              ? 'Saved. You can read it again in History.'
                              : 'Not saved: $saveError',
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
                      onPressed: () {
                        Navigator.of(sheetContext).pop();

                        if (!mounted) return;

                        Navigator.pushNamed(
                          context,
                          '/advice',
                          arguments: {
                            'text': userText,
                            'moods': result.moods,
                            'aiResponse': result.advice,
                          },
                        );
                      },
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
          },
        );
      },
    );
  }

  Widget _buildAnalyzeBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
      child: SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: _isAnalyzing ? null : _analyzeConversation,
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
    );
  }

  // ============================================================
  // ERROR MESSAGE
  // ============================================================

  void _showError(String message) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  // ============================================================
  // MESSAGE LIST
  // ============================================================

  Widget _buildMessageList() {
    if (_messages.isEmpty) {
      return Center(
        child: Text(
          _voiceMode
              ? 'Connect to start a voice conversation'
              : 'Start a conversation',
          textAlign: TextAlign.center,
          style: GoogleFonts.poppins(color: Colors.grey[500]),
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(12),
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        final message = _messages[index];

        final isUser = message['sender'] == 'You';

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
              message['text'] ?? '',
              style: TextStyle(color: isUser ? Colors.white : Colors.black87),
            ),
          ),
        );
      },
    );
  }

  // ============================================================
  // VOICE CONTROLS
  // ============================================================

  Widget _buildVoiceControls() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Text(
            _voiceStatus,
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
                  onPressed: () => _disconnectFromLiveKit(),
                  icon: const Icon(Icons.call_end),
                  label: const Text('End'),
                ),
            ],
          ),
        ],
      ),
    );
  }

  // ============================================================
  // TEXT CONTROLS
  // ============================================================

  Widget _buildTextControls() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _messageController,
              enabled: !_isLoading,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _sendTextMessage(),
              decoration: InputDecoration(
                hintText: 'Type a message',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),

          const SizedBox(width: 8),

          IconButton(
            onPressed: _isLoading ? null : _sendTextMessage,
            icon: const Icon(Icons.send),
            color: AppTheme.primaryColor,
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
          onBack: () => _disconnectFromLiveKit(showStatus: false),
          onBeforeNavigate: () => _disconnectFromLiveKit(showStatus: false),
        ),
        leadingWidth: AppMenu.leadingWidthFor(context),

        title: Text(
          'Chat with AI',
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
            SwitchListTile(
              title: const Text('LiveKit Voice Mode'),
              subtitle: Text(
                _voiceMode
                    ? 'Talk directly with the LiveKit agent'
                    : 'Use typed chat through Flask',
              ),
              value: _voiceMode,
              onChanged: (value) async {
                if (_voiceMode && !value) {
                  await _disconnectFromLiveKit();
                }

                if (!mounted) {
                  return;
                }

                setState(() {
                  _voiceMode = value;
                });
              },
            ),

            Expanded(child: _buildMessageList()),

            if (_isLoading)
              const Padding(
                padding: EdgeInsets.all(8),
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(
                    AppTheme.primaryColor,
                  ),
                ),
              ),

            _buildAnalyzeBar(),

            if (_voiceMode) _buildVoiceControls() else _buildTextControls(),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // DISPOSE
  // ============================================================

  @override
  void dispose() {
    debugPrint('LIVEKIT: ChatPage disposed');

    final room = _room;

    _room = null;

    _roomListener?.dispose();

    _roomListener = null;

    room?.disconnect();

    _messageController.dispose();

    _scrollController.dispose();

    super.dispose();
  }
}