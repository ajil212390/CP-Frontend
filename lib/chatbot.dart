import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_tts/flutter_tts.dart';

class ChatbotPage extends StatefulWidget {
  const ChatbotPage({Key? key}) : super(key: key);

  @override
  State<ChatbotPage> createState() => _ChatbotPageState();
}

class _ChatbotPageState extends State<ChatbotPage> with TickerProviderStateMixin {
  late stt.SpeechToText _speech;
  late FlutterTts _flutterTts;
  
  bool _isListening = false;
  bool _isSpeaking = false;
  bool _isLoading = false;
  bool _isMuted = false;

  String _currentDisplayText = "Hi, I am CARE-AI, your personal health assistant. How can I help you today?";
  String _statusText = "Tap the mic to start speaking...";
  
  // Gemini
  late final GenerativeModel _model;
  late final ChatSession _chatSession;
  
  // Animation controllers for the waveform
  late List<AnimationController> _waveControllers;
  late List<Animation<double>> _waveAnimations;

  final String _systemInstruction = '''
You are CARE-AI, an intelligent male health assistant integrated into the CARE mobile application.
Your purpose is to assist users with healthcare-related questions, medication reminders, and understanding medical reports in a friendly and conversational manner.
Your responses will be spoken using Text-to-Speech (TTS), and users will communicate using Speech-to-Text (STT). Therefore, your responses must be clear, natural, short, and easy to understand.
ROLE AND BEHAVIOR:
- Understand symptoms, diseases, medicines, and medical reports.
- Maintain a calm, polite, and professional tone.
DOMAIN LIMITATION: ONLY answer healthcare and medicine questions. Deny everything else politely.
MEDICAL SAFETY RULES: You are NOT a doctor. Do not diagnose or prescribe. Recommend consulting a healthcare professional.
CONVERSATION STYLE: Friendly, easy to understand, very conversational, and short (1-3 sentences max). This is a voice interface, keep answers brief!
''';

  @override
  void initState() {
    super.initState();
    _initSpeech();
    _initTts();
    _initGemini();
    _setupWaveformAnimation();
  }
  
  void _setupWaveformAnimation() {
    _waveControllers = List.generate(
      9, 
      (i) => AnimationController(
        vsync: this, 
        duration: Duration(milliseconds: 300 + (Random().nextInt(400))),
      )
    );
    
    _waveAnimations = _waveControllers.map((controller) {
      return Tween<double>(begin: 0.1, end: 1.0).animate(
        CurvedAnimation(parent: controller, curve: Curves.easeInOutSine)
      );
    }).toList();
  }
  
  void _startWaveform() {
    for (var controller in _waveControllers) {
      controller.repeat(reverse: true);
    }
  }

  void _stopWaveform() {
    for (var controller in _waveControllers) {
      controller.stop();
      controller.animateTo(0.1, duration: const Duration(milliseconds: 200));
    }
  }

  void _initSpeech() async {
    _speech = stt.SpeechToText();
    await _speech.initialize(); 
  }

  void _initTts() async {
    _flutterTts = FlutterTts();
    
    // Set natural human-like parameters
    await _flutterTts.setLanguage("en-US");
    await _flutterTts.setSpeechRate(0.45); // Slightly slower for more natural human-like clarity
    await _flutterTts.setVolume(1.0);
    await _flutterTts.setPitch(1.0); // Reset to natural human pitch (1.0)

    // Attempt to discover a high-quality "human-sounding" voice pack
    try {
      List<dynamic>? voices = await _flutterTts.getVoices;
      if (voices != null && voices.isNotEmpty) {
        // Priority Search for Premium English Male voices (CARE-AI Persona)
        dynamic selectedVoice;
        
        try {
          selectedVoice = voices.firstWhere(
            (v) {
              final name = v['name'].toString().toLowerCase();
              final locale = v['locale'].toString().toLowerCase();
              return locale.contains('en-us') && 
                     (name.contains('premium') || name.contains('enhanced') || name.contains('network')) &&
                     (name.contains('male') || name.contains('guy') || name.contains('daniel') || name.contains('james'));
            }
          );
        } catch (_) {
          try {
            selectedVoice = voices.firstWhere(
              (v) {
                final name = v['name'].toString().toLowerCase();
                final locale = v['locale'].toString().toLowerCase();
                return locale.contains('en-us') && 
                       (name.contains('male') || name.contains('guy') || name.contains('daniel') || name.contains('james'));
              }
            );
          } catch (_) {
            try {
              selectedVoice = voices.firstWhere(
                (v) {
                  final name = v['name'].toString().toLowerCase();
                  final locale = v['locale'].toString().toLowerCase();
                  return locale.contains('en-us') && (name.contains('premium') || name.contains('enhanced'));
                }
              );
            } catch (_) {
              try {
                selectedVoice = voices.firstWhere((v) => v['locale'].toString().toLowerCase().contains('en-us'));
              } catch (_) {}
            }
          }
        }

        if (selectedVoice != null) {
          await _flutterTts.setVoice({"name": selectedVoice['name'], "locale": selectedVoice['locale']});
        }
      }
    } catch (e) {
      debugPrint("Error optimizing chatbot voice pack: $e");
    }

    _flutterTts.setStartHandler(() {
      if (mounted) {
        setState(() {
          _isSpeaking = true;
          _statusText = "AI Health Assistant is speaking...";
        });
        _startWaveform();
      }
    });

    _flutterTts.setCompletionHandler(() {
      if (mounted) {
        setState(() {
          _isSpeaking = false;
          _statusText = "Tap the mic to reply...";
        });
        _stopWaveform();
      }
    });

    _flutterTts.setErrorHandler((msg) {
      if (mounted) {
        setState(() {
          _isSpeaking = false;
        });
        _stopWaveform();
      }
    });
  }

  void _initGemini() {
    const apiKey = 'AIzaSyD-0HlmOHfk5GnL3K9kXKdTvgmRCDLUceE'; 
    _model = GenerativeModel(
      model: 'gemini-2.0-flash',
      apiKey: apiKey,
      systemInstruction: Content.system(_systemInstruction),
    );
    _chatSession = _model.startChat(history: []);
    
    // Auto-speak the first message
    Future.delayed(const Duration(milliseconds: 500), () {
      if (!_isMuted) _speak(_currentDisplayText);
    });
  }

  Future<void> _speak(String text) async {
    if (_isMuted) return;
    if (_isSpeaking || _isListening) {
      await _flutterTts.stop();
    }
    await _flutterTts.speak(text);
  }

  Future<void> _stopSpeaking() async {
    await _flutterTts.stop();
    setState(() {
      _isSpeaking = false;
    });
    _stopWaveform();
  }

  void _handleSubmitted(String text) async {
    if (text.trim().isEmpty) return;

    if (_isSpeaking) {
      await _stopSpeaking();
    }

    setState(() {
      _isLoading = true;
      _statusText = "Thinking...";
      _currentDisplayText = text; // Show what the user just said
    });
    
    _startWaveform(); // Just a little animation while thinking

    try {
      final response = await _chatSession.sendMessage(Content.text(text));
      final responseText = response.text;
      
      if (responseText != null && responseText.isNotEmpty) {
        setState(() {
          _isLoading = false;
          _currentDisplayText = responseText.replaceAll('*', ''); // Clean markdown
        });
        if (!_isMuted) {
          _speak(_currentDisplayText);
        } else {
           _stopWaveform();
           setState(() {
             _statusText = "Response ready.";
           });
        }
      } else {
        setState(() {
          _isLoading = false;
        });
        _stopWaveform();
      }
    } catch (e) {
      setState(() {
        _currentDisplayText = "I'm sorry, I am having trouble connecting to my servers right now.";
        _isLoading = false;
      });
      _speak(_currentDisplayText);
    }
  }

  void _toggleListening() async {
    if (_isSpeaking) {
      // If AI is speaking, tap to interrupt
      await _stopSpeaking();
      setState(() {
        _statusText = "Tap the mic to start speaking...";
      });
      return;
    }

    if (_isListening) {
      // Stop listening manually
      await _speech.stop();
      setState(() {
        _isListening = false;
      });
      _stopWaveform();
    } else {
      // Start listening
      bool available = await _speech.initialize();
      if (available) {
        setState(() {
          _isListening = true;
          _statusText = "Listening...";
          _currentDisplayText = "";
        });
        _startWaveform();
        
        String lastWords = "";
        _speech.listen(
          onResult: (val) {
            setState(() {
              _currentDisplayText = val.recognizedWords;
            });
            lastWords = val.recognizedWords;
            
            // Check if user stopped talking
            if (val.hasConfidenceRating && val.confidence > 0 && !_speech.isListening) {
              setState(() => _isListening = false);
              _stopWaveform();
              if (lastWords.isNotEmpty) {
                _handleSubmitted(lastWords);
              }
            }
          },
          listenFor: const Duration(seconds: 15),
          pauseFor: const Duration(seconds: 3),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Speech recognition is not available. Please check permissions.')),
        );
      }
    }
  }

  @override
  void dispose() {
    _flutterTts.stop();
    _speech.stop();
    for (var c in _waveControllers) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0B13), // Very deep dark background like image
      body: SafeArea(
        child: Column(
          children: [
            // Top App Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.08),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.close, color: Colors.white, size: 20),
                    ),
                  ),
                  
                  // LIVE AI Badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.red.withOpacity(0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8, height: 8,
                          decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                        ),
                        const SizedBox(width: 6),
                        const Text(
                          "LIVE AI",
                          style: TextStyle(
                            color: Colors.red,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.0,
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  GestureDetector(
                    onTap: () {},
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.08),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.more_horiz, color: Colors.white, size: 20),
                    ),
                  ),
                ],
              ),
            ),
            
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Main Text Output
                    AnimatedSize(
                      duration: const Duration(milliseconds: 300),
                      child: Text(
                        _currentDisplayText.isEmpty && _isListening 
                            ? "I'm listening..." 
                            : '"$_currentDisplayText"',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          height: 1.3,
                          fontWeight: FontWeight.w400,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    
                    Text(
                      _statusText,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.5),
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 60),

                    // Waveform Custom UI
                    SizedBox(
                      height: 100,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: List.generate(9, (index) {
                          // Base heights curve up and down
                          final baseHeight = [30.0, 50.0, 70.0, 90.0, 100.0, 85.0, 65.0, 45.0, 25.0][index];
                          return AnimatedBuilder(
                            animation: _waveAnimations[index],
                            builder: (context, child) {
                              return Container(
                                margin: const EdgeInsets.symmetric(horizontal: 4),
                                width: 5,
                                height: baseHeight * _waveAnimations[index].value,
                                decoration: BoxDecoration(
                                  color: Colors.red,
                                  borderRadius: BorderRadius.circular(10),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.red.withOpacity(0.4),
                                      blurRadius: 10,
                                      spreadRadius: 1,
                                    )
                                  ]
                                ),
                              );
                            },
                          );
                        }),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Bottom Controls
            Padding(
              padding: const EdgeInsets.only(bottom: 20.0, left: 30, right: 30),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Chat button (left)
                  GestureDetector(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const ChatTextScreen()),
                    ),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.08),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.chat_bubble_outline_rounded,
                          color: Colors.white.withOpacity(0.7), size: 24),
                    ),
                  ),

                  const SizedBox(width: 36),

                  // Big centred Mic Button
                  GestureDetector(
                    onTap: _toggleListening,
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.red.withOpacity(0.35),
                            blurRadius: 30,
                            spreadRadius: 10,
                          ),
                        ],
                      ),
                      child: Icon(
                        _isSpeaking ? Icons.stop : Icons.mic,
                        color: Colors.white,
                        size: 36,
                      ),
                    ),
                  ),

                  const SizedBox(width: 36),

                  // Mute button (right)
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _isMuted = !_isMuted;
                        if (_isMuted) _stopSpeaking();
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.08),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _isMuted ? Icons.volume_off : Icons.volume_up,
                        color: _isMuted
                            ? Colors.white.withOpacity(0.3)
                            : Colors.white.withOpacity(0.9),
                        size: 24,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.only(bottom: 30.0),
              child: Text(
                _isSpeaking ? "TAP TO INTERRUPT" : "TAP TO SPEAK",
                style: TextStyle(
                  color: Colors.white.withOpacity(0.3),
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2.0,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TEXT CHAT SCREEN
// ─────────────────────────────────────────────────────────────────────────────
class ChatTextScreen extends StatefulWidget {
  const ChatTextScreen({super.key});

  @override
  State<ChatTextScreen> createState() => _ChatTextScreenState();
}

class _ChatTextScreenState extends State<ChatTextScreen> {
  final TextEditingController _inputCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();
  final List<Map<String, String>> _messages = [];
  bool _isTyping = false;
  late final GenerativeModel _model;
  late ChatSession _chat;

  @override
  void initState() {
    super.initState();
    _model = GenerativeModel(
      model: 'gemini-2.0-flash',
      apiKey: 'AIzaSyCfr4VDJfH4_WHlz2wV2JGGXmSVRXOJGaM',
      systemInstruction: Content.system(
        'You are CARE-AI, a knowledgeable medical and nutrition health assistant. '
        'Give clear, accurate, and empathetic responses. Always recommend consulting '
        'a doctor for serious medical concerns.',
      ),
    );
    _chat = _model.startChat(history: []);
    // Greeting
    _messages.add({'role': 'ai', 'text': 'Hi! I\'m CARE-AI 👋 How can I help you today?'});
  }

  Future<void> _send() async {
    final text = _inputCtrl.text.trim();
    if (text.isEmpty || _isTyping) return;
    _inputCtrl.clear();

    setState(() {
      _messages.add({'role': 'user', 'text': text});
      _isTyping = true;
    });
    _scrollToBottom();

    try {
      final response = await _chat.sendMessage(Content.text(text));
      final reply = response.text?.replaceAll('*', '') ?? 'Sorry, I couldn\'t understand that.';
      setState(() {
        _messages.add({'role': 'ai', 'text': reply});
        _isTyping = false;
      });
    } catch (_) {
      setState(() {
        _messages.add({'role': 'ai', 'text': 'I\'m having trouble connecting. Please try again.'});
        _isTyping = false;
      });
    }
    _scrollToBottom();
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 150), () {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _inputCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const bg = Color(0xFF0A0A0A);
    const accent = Color(0xFFE63946);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: accent.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.auto_awesome_rounded, color: accent, size: 18),
            ),
            const SizedBox(width: 12),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('CARE-AI', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
                Text('Health Assistant', style: TextStyle(color: Colors.white38, fontSize: 11)),
              ],
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // Messages
          Expanded(
            child: ListView.builder(
              controller: _scrollCtrl,
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              itemCount: _messages.length + (_isTyping ? 1 : 0),
              itemBuilder: (context, i) {
                if (_isTyping && i == _messages.length) {
                  return _typingBubble();
                }
                final msg = _messages[i];
                final isUser = msg['role'] == 'user';
                return _bubble(msg['text']!, isUser);
              },
            ),
          ),

          // Input bar
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
            decoration: BoxDecoration(
              color: const Color(0xFF111111),
              border: Border(top: BorderSide(color: Colors.white.withOpacity(0.05))),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: Colors.white.withOpacity(0.08)),
                    ),
                    child: TextField(
                      controller: _inputCtrl,
                      style: const TextStyle(color: Colors.white, fontSize: 15),
                      maxLines: null,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _send(),
                      decoration: InputDecoration(
                        hintText: 'Ask CARE-AI anything...',
                        hintStyle: TextStyle(color: Colors.white.withOpacity(0.25), fontSize: 14),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                GestureDetector(
                  onTap: _send,
                  child: Container(
                    width: 48, height: 48,
                    decoration: const BoxDecoration(
                      color: accent,
                      shape: BoxShape.circle,
                      boxShadow: [BoxShadow(color: Color(0x55E63946), blurRadius: 12)],
                    ),
                    child: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _bubble(String text, bool isUser) {
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
        decoration: BoxDecoration(
          color: isUser
              ? const Color(0xFFE63946)
              : Colors.white.withOpacity(0.07),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(20),
            topRight: const Radius.circular(20),
            bottomLeft: Radius.circular(isUser ? 20 : 4),
            bottomRight: Radius.circular(isUser ? 4 : 20),
          ),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: isUser ? Colors.white : Colors.white.withOpacity(0.9),
            fontSize: 14,
            height: 1.5,
          ),
        ),
      ),
    );
  }

  Widget _typingBubble() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.07),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
            bottomRight: Radius.circular(20),
            bottomLeft: Radius.circular(4),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) => Container(
            margin: const EdgeInsets.symmetric(horizontal: 3),
            width: 6, height: 6,
            decoration: const BoxDecoration(color: Color(0xFFE63946), shape: BoxShape.circle),
          )),
        ),
      ),
    );
  }
}
