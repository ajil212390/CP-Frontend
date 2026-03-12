import 'dart:math';
import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_tts/flutter_tts.dart';
import 'package:dio/dio.dart';
import 'package:carepulseapp/login.dart';
import 'package:carepulseapp/loginApi.dart';
import 'package:audioplayers/audioplayers.dart';
import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

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

  String _currentDisplayText = "How can I help you today?";
  String _statusText = "Tap the mic to speak...";
  
  final Dio _dio = Dio();
  final AudioPlayer _audioPlayer = AudioPlayer();
  
  // Animation controllers for the waveform
  late List<AnimationController> _waveControllers;
  late List<Animation<double>> _waveAnimations;

  String _userContext = "";
  final String _commonInstructions = """
Instructions:
1. For simple questions, give a very short 1-2 sentence answer.
2. Only provide a 3-sentence response if the user specifically asks for details, history, or a full health status.
3. Strictly NO long paragraphs. Keep it punchy and empathetic.
""";

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
    _loadUserContext(); // Load health history for context
    _setupWaveformAnimation();
    
    // Auto-speak the first message using local TTS
    Future.delayed(const Duration(milliseconds: 500), () {
      if (!_isMuted) _speak(_currentDisplayText);
    });
  }

  Future<void> _loadUserContext() async {
    String contextInfo = "User: You\n";
    try {
      // Fetch Predictions
      final predRes = await _dio.get("$baseUrl/api/prediction-history/$lid/");
      if (predRes.statusCode == 200) {
        final history = predRes.data['prediction_history'] ?? [];
        if (history.isNotEmpty) {
          contextInfo += "\nRecent Health History:\n";
          for (var item in (history as List).take(3)) {
            contextInfo += "- ${item['result']} (Date: ${item['createdAt']})\n";
          }
        }
      }
      // Fetch Alerts
      final alertRes = await _dio.post("$baseUrl/api/alerts/", data: {"user_id": lid});
      if (alertRes.statusCode == 200) {
        final alerts = alertRes.data['alerts'] ?? [];
        if (alerts.isNotEmpty) {
          contextInfo += "\nActive Medication Alerts:\n";
          for (var alert in (alerts as List).take(3)) {
             contextInfo += "- ${alert['title']}: ${alert['description']} (Time: ${alert['start_time']})\n";
          }
        }
      }
    } catch (e) {
      debugPrint("Context load error: $e");
    }
    _userContext = contextInfo;
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
    // Auto-speak the first message using local TTS for greeting only
    Future.delayed(const Duration(milliseconds: 500), () {
      if (!_isMuted) _speak(_currentDisplayText);
    });
  }

  Future<void> _playServerAudio(String base64Audio) async {
    try {
      final bytes = base64Decode(base64Audio);
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/ai_resp_${DateTime.now().millisecondsSinceEpoch}.mp3');
      await file.writeAsBytes(bytes);
      
      // Stop any current speaking
      await _stopSpeaking();
      
      _startWaveform();
      setState(() {
        _isSpeaking = true;
        _statusText = "AI is speaking (Studio Cloud)...";
      });

      await _audioPlayer.play(DeviceFileSource(file.path));
      
      _audioPlayer.onPlayerComplete.listen((_) {
        if (mounted) {
          setState(() {
             _isSpeaking = false;
             _statusText = "Tap the mic to reply...";
          });
          _stopWaveform();
        }
      });
    } catch (e) {
      debugPrint("Audio playback error: $e");
      // Fallback to local TTS if playback fails
      _speak(_currentDisplayText);
    }
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
      _currentDisplayText = text; 
    });
    
    _startWaveform(); 

    // 1. Try Local Ollama First
    try {
      final response = await _dio.post(
        "$ollamaBaseUrl/api/generate",
        data: {
          "model": "llama3.2:1b",
          "prompt": """SYSTEM: You are CARE-AI, an empathetic and intelligent robotic healthcare assistant.
Your name is strictly CARE-AI. Never say you are Llama or any other model.
PERSONALITY: Friendly, helpful, professional, and slightly robotic but caring.
CONVERSATION RULES:
1. Refer to the user as 'you', never as 'Patient'.
2. Keep responses very short (1-3 sentences max).
3. Answer the user's question directly. Do not repeat greeting phrases like 'How can I assist you today' unless it is part of a natural conversation.
4. Use the health history below to give better advice.

User Health History:
$_userContext

User Message: $text
REPLY:""",
          "stream": false
        },
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final responseText = response.data['response'] as String?;
        setState(() {
          _isLoading = false;
          _currentDisplayText = responseText ?? "No response received.";
        });
        if (!_isMuted) _speak(_currentDisplayText);
        return; 
      }
    } catch (e) {
      debugPrint("Ollama Chatbot Fallback: $e");
    }

    // 2. Fallback to Cloud Brain
    try {
      final response = await _dio.post(
        "$baseUrl/api/ai/chat/",
        data: {
          "user_id": lid,
          "text": text,
          "mode": "chat"
        },
      );

      if (response.statusCode == 200) {
        final responseText = response.data['response'] as String?;
        final base64Audio = response.data['audio'] as String?;
        
        setState(() {
          _isLoading = false;
          _currentDisplayText = responseText ?? "No response received.";
        });

        if (!_isMuted) {
          if (base64Audio != null && base64Audio.isNotEmpty) {
            _playServerAudio(base64Audio);
          } else {
            _speak(_currentDisplayText);
          }
        } else {
           _stopWaveform();
           setState(() {
             _statusText = "Response ready.";
           });
        }
      } else {
        throw Exception("Server Error: ${response.statusCode}");
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
  final Dio _dio = Dio();
  final AudioPlayer _audioPlayer = AudioPlayer();

  String _userContext = "";
  final String _commonInstructions = """
Instructions:
1. For simple questions, give a very short 1-2 sentence answer.
2. Only provide a 3-sentence response if the user specifically asks for details, history, or a full health status.
3. Strictly NO long paragraphs. Keep it punchy and empathetic.
""";

  @override
  void initState() {
    super.initState();
    // Greeting
    _messages.add({'role': 'ai', 'text': 'How can I help you today? 👋'});
    _loadHistory();
    _loadUserContext();
  }

  Future<void> _loadUserContext() async {
    String contextInfo = "User: You\n";
    try {
      final predRes = await _dio.get("$baseUrl/api/prediction-history/$lid/");
      if (predRes.statusCode == 200) {
        final history = predRes.data['prediction_history'] ?? [];
        if (history.isNotEmpty) {
          contextInfo += "\nRecent Health History:\n";
          for (var item in (history as List).take(3)) {
            contextInfo += "- ${item['result']} (Date: ${item['createdAt']})\n";
          }
        }
      }
    } catch (_) {}
    _userContext = contextInfo;
  }

  Future<void> _loadHistory() async {
    try {
      final response = await _dio.get("$baseUrl/dietchat/?user_id=$lid");
      if (response.statusCode == 200) {
        final List<dynamic> data = response.data;
        if (mounted) {
          setState(() {
            for (var item in data) {
              if (item['question'] != null) {
                _messages.add({'role': 'user', 'text': item['question']});
              }
              if (item['response'] != null) {
                _messages.add({'role': 'ai', 'text': item['response']});
              }
            }
          });
          _scrollToBottom();
        }
      }
    } catch (e) {
      debugPrint("Error loading chat history: $e");
    }
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

    // 1. Try Local Ollama First
    try {
      final response = await _dio.post(
        "$ollamaBaseUrl/api/generate",
        data: {
          "model": "llama3.2:1b",
          "prompt": """SYSTEM: You are CARE-AI, an empathetic and intelligent robotic healthcare assistant.
Your name is strictly CARE-AI. Never say you are Llama or any other model.
PERSONALITY: Friendly, helpful, professional, and slightly robotic but caring.
CONVERSATION RULES:
1. Refer to the user as 'you', never as 'Patient'.
2. Keep responses very short (1-3 sentences max).
3. Answer the user's question directly. Do not repeat greeting phrases like 'How can I assist you today' unless it is part of a natural conversation.
4. Use the health history below to give better advice.

User Health History:
$_userContext

User Message: $text
REPLY:""",
          "stream": false
        },
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final reply = response.data['response'] ?? 'Sorry, I couldn\'t understand that.';
        setState(() {
          _messages.add({'role': 'ai', 'text': reply});
          _isTyping = false;
        });
        _scrollToBottom();
        return;
      }
    } catch (e) {
      debugPrint("Ollama Text Chat Fallback: $e");
    }

    // 2. Fallback to Cloud Brain
    try {
      final response = await _dio.post(
        "$baseUrl/api/ai/chat/",
        data: {
          "user_id": lid,
          "text": text,
          "mode": "chat"
        },
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final reply = response.data['response'] ?? 'Sorry, I couldn\'t understand that.';
        final base64Audio = response.data['audio'] as String?;

        setState(() {
          _messages.add({'role': 'ai', 'text': reply});
          _isTyping = false;
        });

        // Play audio in text mode too for premium experience
        if (base64Audio != null && base64Audio.isNotEmpty) {
           _playStaticAudio(base64Audio);
        }
      }
    } catch (_) {
      setState(() {
        _messages.add({'role': 'ai', 'text': 'I\'m having trouble connecting. Please try again.'});
        _isTyping = false;
      });
    }
    _scrollToBottom();
  }

  Future<void> _playStaticAudio(String base64Audio) async {
    try {
      final bytes = base64Decode(base64Audio);
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/chat_resp_${DateTime.now().millisecondsSinceEpoch}.mp3');
      await file.writeAsBytes(bytes);
      await _audioPlayer.play(DeviceFileSource(file.path));
    } catch (e) {
      debugPrint("Static audio error: $e");
    }
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
