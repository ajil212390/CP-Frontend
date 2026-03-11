import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_tts/flutter_tts.dart';
import 'package:dio/dio.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:google_mlkit_commons/google_mlkit_commons.dart';
import 'dart:typed_data';
import 'package:carepulseapp/login.dart';
import 'package:carepulseapp/loginApi.dart';

enum RoboEmotion { neutral, listening, thinking, speaking, happy, reminder, dizzy, surprised, tickled }

class RoboModeScreen extends StatefulWidget {
  const RoboModeScreen({Key? key}) : super(key: key);

  @override
  State<RoboModeScreen> createState() => _RoboModeScreenState();
}

class _RoboModeScreenState extends State<RoboModeScreen> with TickerProviderStateMixin {
  late stt.SpeechToText _speech;
  late FlutterTts _flutterTts;
  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 45),
  ));

  bool _isListening = false;
  RoboEmotion _emotion = RoboEmotion.neutral;
  
  // Intro animation
  bool _isIntro = true;
  bool _showExitButton = false;
  Timer? _exitButtonTimer;
  Timer? _emotionTimer;

  // Gemini
  late final GenerativeModel _model;
  late ChatSession _chatSession;

  String _currentText = "";
  String _robotResponseText = "";
  String _userContext = "";

  late AnimationController _eyeMovementController;
  late AnimationController _blinkController;
  late AnimationController _mouthController;
  late AnimationController _waveBackController; // For "waving" back motion

  // Camera & Gesture Detection
  CameraController? _cameraController;
  final PoseDetector _poseDetector = PoseDetector(options: PoseDetectorOptions(mode: PoseDetectionMode.stream));
  bool _isProcessingFrame = false;
  bool _isWavingBack = false;
  bool _isGenerating = false; // Flag to prevent double-requests
  int _waveDetections = 0;
  DateTime? _lastWaveTime;

  @override
  void initState() {
    super.initState();
    // Force Landscape & Fullscreen
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeRight,
      DeviceOrientation.landscapeLeft,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    _eyeMovementController = AnimationController(vsync: this, duration: const Duration(seconds: 4))..repeat(reverse: true);
    _blinkController = AnimationController(vsync: this, duration: const Duration(milliseconds: 300));
    _mouthController = AnimationController(vsync: this, duration: const Duration(milliseconds: 300));
    _waveBackController = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));
    
    _startRandomBlinking();

    _initSpeech();
    _initTts();
    _initCamera(); // Start "Vision" system
    _loadUserContextAndInitGemini();

    // Intro Sequence
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _isIntro = false;
          _emotion = RoboEmotion.happy;
        });
        _speak("Hi $userName! I am awake. I am your health companion. Touch me or shake your phone to see how I feel!");
        Future.delayed(const Duration(seconds: 5), () {
          if (mounted) {
            setState(() {
              _emotion = RoboEmotion.neutral;
            });
            _startListening();
          }
        });
      }
    });
  }

  Future<void> _loadUserContextAndInitGemini() async {
    String contextInfo = "User Name: $userName\n";
    
    try {
      final predRes = await _dio.get("$baseUrl/api/prediction-history/$lid/");
      if (predRes.statusCode == 200) {
        final history = predRes.data['prediction_history'] ?? [];
        if (history.isNotEmpty) {
          contextInfo += "Recent Health Predictions:\n";
          for (var item in history.take(3)) {
            contextInfo += "- ${item['result']} on ${item['createdAt']}\n";
          }
        }
      }

      final alertRes = await _dio.post("$baseUrl/api/alerts/", data: {"user_id": lid});
      if (alertRes.statusCode == 200) {
        final alerts = alertRes.data['alerts'] ?? [];
        if (alerts.isNotEmpty) {
          contextInfo += "Active Reminders/Alerts:\n";
          for (var alert in alerts.take(5)) {
            contextInfo += "- ${alert['title']}: ${alert['description']} (Time: ${alert['time']})\n";
          }
        }
      }
    } catch (e) {
      print("Error loading context: $e");
    }

    _userContext = contextInfo;
    _initGemini();
  }

  void _initGemini() {
    const apiKey = 'AIzaSyD-0HlmOHfk5GnL3K9kXKdTvgmRCDLUceE';
    _model = GenerativeModel(
      model: 'gemini-2.0-flash',
      apiKey: apiKey,
      systemInstruction: Content.system(
          'You are a highly advanced, empathetic male health assistant with calming light blue eyes called CARE-AI. '
          'You have a very natural, human-like voice and personality. '
          'You are talking to $userName. '
          'Here is the user\'s current health context:\n$_userContext\n'
          'You know their previous health data. Be conversational, empathy-driven, and proactive.'
      ),
    );
    _chatSession = _model.startChat(history: []);
  }

  void _initCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) return;
      
      final frontCamera = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      _cameraController = CameraController(
        frontCamera,
        ResolutionPreset.medium, // Better accuracy for gesture detection
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.yuv420,
      );

      await _cameraController!.initialize();
      if (!mounted) return;

      _cameraController!.startImageStream((CameraImage image) {
        if (_isProcessingFrame || _isIntro || _isWavingBack) return;
        
        // Performance Throttling: Only process pose detection every 500ms
        final now = DateTime.now();
        if (_lastWaveTime == null || now.difference(_lastWaveTime!) > const Duration(milliseconds: 500)) {
           _lastWaveTime = now;
           _processCameraImage(image);
        }
      });
    } catch (e) {
      debugPrint("Camera vision init failed: $e");
    }
  }

  void _processCameraImage(CameraImage image) async {
    _isProcessingFrame = true;
    try {
      final WriteBuffer allBytes = WriteBuffer();
      for (final Plane plane in image.planes) {
        allBytes.putUint8List(plane.bytes);
      }
      final bytes = allBytes.done().buffer.asUint8List();

      final Size imageSize = Size(image.width.toDouble(), image.height.toDouble());
      final camera = (await availableCameras()).firstWhere((c) => c.lensDirection == CameraLensDirection.front);
      
      // Fix ML Kit API for 0.8.x
      final imageRotation = InputImageRotationValue.fromRawValue(camera.sensorOrientation) ?? InputImageRotation.rotation0deg;
      final inputImageFormat = InputImageFormatValue.fromRawValue(image.format.raw) ?? InputImageFormat.yuv420;

      final inputImage = InputImage.fromBytes(
        bytes: bytes,
        metadata: InputImageMetadata(
          size: imageSize,
          rotation: imageRotation,
          format: inputImageFormat,
          bytesPerRow: image.planes[0].bytesPerRow, // Simplified for 0.8.x
        ),
      );
      final poses = await _poseDetector.processImage(inputImage);

      for (Pose pose in poses) {
        // Detect "Hand Raised" (Wave)
        // Check for either hand's wrist being above its respective shoulder
        final PoseLandmark? rightWrist = pose.landmarks[PoseLandmarkType.rightWrist];
        final PoseLandmark? rightShoulder = pose.landmarks[PoseLandmarkType.rightShoulder];
        final PoseLandmark? leftWrist = pose.landmarks[PoseLandmarkType.leftWrist];
        final PoseLandmark? leftShoulder = pose.landmarks[PoseLandmarkType.leftShoulder];

        bool waveDetected = false;
        
        // In ML Kit, Y increases downwards. So Wrist Y < Shoulder Y means hand is up.
        if (rightWrist != null && rightShoulder != null && rightWrist.y < rightShoulder.y - 30) {
          waveDetected = true;
        } else if (leftWrist != null && leftShoulder != null && leftWrist.y < leftShoulder.y - 30) {
          waveDetected = true;
        }

        if (waveDetected) {
          _onUserWaved();
          return; // Exit loop after first detection
        }
      }
    } catch (e) {
      // debugPrint("Pose processing error: $e");
    }
    _isProcessingFrame = false;
  }

  void _onUserWaved() {
    if (_isWavingBack || _emotion == RoboEmotion.thinking || _emotion == RoboEmotion.speaking) return;
    
    // Wave back logic
    setState(() {
      _isWavingBack = true;
    });

    _waveBackController.repeat(reverse: true);
    _speak("Hello there! I saw you wave. How are you doing today?");
    
    Timer(const Duration(seconds: 4), () {
      if (mounted) {
        setState(() {
          _isWavingBack = false;
          _waveBackController.stop();
          _waveBackController.animateTo(0.0);
        });
      }
    });
  }

  void _initSpeech() async {
    _speech = stt.SpeechToText();
    await _speech.initialize(
      onStatus: (status) {
        if (status == 'done' || status == 'notListening') {
          if (mounted) {
            setState(() {
              _isListening = false;
              if (_emotion == RoboEmotion.listening) {
                _emotion = RoboEmotion.neutral;
              }
            });
          }
          if (_emotion != RoboEmotion.speaking && _emotion != RoboEmotion.thinking) {
             Future.delayed(const Duration(milliseconds: 500), _startListening);
          }
        }
      },
    );
  }

  void _initTts() async {
    _flutterTts = FlutterTts();
    
    // Set logical defaults first
    await _flutterTts.setLanguage("en-US");
    await _flutterTts.setSpeechRate(0.45); // Slightly slower for more natural human-like clarity
    await _flutterTts.setVolume(1.0);
    await _flutterTts.setPitch(1.0); // Natural pitch (1.0 is human baseline)

    // Attempt to discover a high-quality "human-sounding" voice pack
    try {
      List<dynamic>? voices = await _flutterTts.getVoices;
      if (voices != null && voices.isNotEmpty) {
        // Broad search for high-quality English male voices (Persona: CARE-AI)
        // High quality voices often contain 'premium', 'enhanced', or 'network'
        // Common natural names: 'Daniel', 'James', 'Guy', 'Ava' (female), 'Samantha' (female)
        dynamic selectedVoice;
        
        // Priority 1: Premium/Enhanced/Network English Male voices
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
          // Priority 2: Any English Male voice
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
            // Priority 3: Large/Enhanced English voices (regardless of gender)
            try {
              selectedVoice = voices.firstWhere(
                (v) {
                  final name = v['name'].toString().toLowerCase();
                  final locale = v['locale'].toString().toLowerCase();
                  return locale.contains('en-us') && (name.contains('premium') || name.contains('enhanced'));
                }
              );
            } catch (_) {
              // Priority 4: Default to any en-US voice
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
      debugPrint("Error optimizing voice pack: $e");
    }

    _flutterTts.setStartHandler(() {
      if (mounted) {
        setState(() {
          _emotion = RoboEmotion.speaking;
        });
        _mouthController.repeat(reverse: true);
      }
    });

    _flutterTts.setCompletionHandler(() {
      if (mounted) {
        setState(() {
          _emotion = RoboEmotion.neutral;
        });
        _mouthController.stop();
        _mouthController.animateTo(0.0);
        _startListening();
      }
    });
  }

  void _startRandomBlinking() async {
    while (mounted) {
      await Future.delayed(Duration(seconds: Random().nextInt(4) + 2));
      if (mounted) {
        _blinkController.forward().then((_) => _blinkController.reverse());
      }
    }
  }

  Future<void> _speak(String text) async {
    await _flutterTts.speak(text);
  }

  void _startListening() async {
    if (!_speech.isAvailable || _emotion == RoboEmotion.speaking || _emotion == RoboEmotion.thinking || _emotion == RoboEmotion.dizzy || _emotion == RoboEmotion.surprised || _emotion == RoboEmotion.tickled) return;
    setState(() => _emotion = RoboEmotion.listening);
    await _speech.listen(
      onResult: (val) {
        if (mounted) {
          setState(() {
            _currentText = val.recognizedWords;
          });
        }
        if (val.finalResult && _currentText.isNotEmpty) {
          _handleSubmitted(_currentText);
        }
      },
      listenFor: const Duration(seconds: 30),
      pauseFor: const Duration(seconds: 4),
      partialResults: true,
    );
  }

  void _handleSubmitted(String text) async {
    if (_isGenerating || text.trim().isEmpty) return;
    _isGenerating = true;
    await _speech.stop();
    setState(() => _emotion = RoboEmotion.thinking);

    if (text.toLowerCase().contains("medicine") || text.toLowerCase().contains("remind") && !text.toLowerCase().contains("what")) {
       setState(() => _emotion = RoboEmotion.reminder);
       await _speak("Yes! It is time for your medicine. Please take your pills now!");
       _isGenerating = false;
       return;
    }

    try {
      final response = await _chatSession.sendMessage(Content.text(text));
      final responseText = (response.text ?? "").replaceAll('*', '');
      
      if (responseText.isNotEmpty) {
        if (mounted) {
          setState(() {
            _robotResponseText = responseText;
          });
        }
        await _speak(responseText);
      } else {
        _resetAfterSpeaking();
      }
    } catch (e) {
      debugPrint("Detailed Gemini Error in Robo Mode: $e");
      await _speak("I'm sorry, I'm having trouble connecting to my brain. Please check your internet.");
      _resetAfterSpeaking();
    } finally {
      _isGenerating = false;
    }
  }

  void _resetAfterSpeaking() {
    if (mounted) {
      setState(() => _emotion = RoboEmotion.neutral);
    }
    _startListening();
  }

  void _toggleExitButton() {
    if (mounted) {
      setState(() {
        _showExitButton = true;
      });
      _exitButtonTimer?.cancel();
      _exitButtonTimer = Timer(const Duration(seconds: 3), () {
        if (mounted) {
          setState(() {
            _showExitButton = false;
          });
        }
      });
    }
  }

  void _triggerEmotion(RoboEmotion emotion, {int duration = 2000}) {
    if (_emotion == RoboEmotion.speaking || _emotion == RoboEmotion.thinking) return;
    _emotionTimer?.cancel();
    setState(() {
      _emotion = emotion;
    });
    _emotionTimer = Timer(Duration(milliseconds: duration), () {
      if (mounted) {
        setState(() {
          _emotion = RoboEmotion.neutral;
        });
        _startListening();
      }
    });
  }

  @override
  void dispose() {
    _exitButtonTimer?.cancel();
    _emotionTimer?.cancel();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _flutterTts.stop();
    _speech.stop();
    _cameraController?.dispose();
    _poseDetector.close();
    _eyeMovementController.dispose();
    _blinkController.dispose();
    _mouthController.dispose();
    _waveBackController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        _toggleExitButton();
        _triggerEmotion(RoboEmotion.tickled);
      },
      onDoubleTap: () {
        _triggerEmotion(RoboEmotion.surprised);
      },
      onScaleUpdate: (details) {
        // High velocity/displacement movement simulates shake/swipe
        if (details.focalPointDelta.dx.abs() > 20 || details.focalPointDelta.dy.abs() > 20) {
          _triggerEmotion(RoboEmotion.dizzy, duration: 3000);
        }
        // Pinching (scaling) simulates surprise
        if (details.scale > 1.2 || details.scale < 0.8) {
           _triggerEmotion(RoboEmotion.surprised);
        }
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            // Premium Background Mesh/Glows (Static/Low-rebuild)
            RepaintBoundary(
              child: _buildPremiumBackground(),
            ),

            Center(
              child: RepaintBoundary(
                child: _isIntro ? _buildIntroSequence() : _buildFace(),
              ),
            ),

            _buildStatusIndicator(),

            Positioned(
              top: 20,
              left: 20,
              child: AnimatedOpacity(
                opacity: _showExitButton ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 300),
                child: IgnorePointer(
                  ignoring: !_showExitButton,
                  child: GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.05),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white.withOpacity(0.1)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.3),
                            blurRadius: 10,
                          )
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(30),
                        child: BackdropFilter(
                          filter: ColorFilter.mode(Colors.white.withOpacity(0.05), BlendMode.overlay),
                          child: const Icon(Icons.power_settings_new_rounded, color: Colors.white70, size: 24),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusIndicator() {
    if (_isIntro || _emotion == RoboEmotion.neutral) return const SizedBox.shrink();
    
    String label = "";
    IconData icon = Icons.auto_awesome;
    Color color = const Color(0xFF81D4FA);

    switch (_emotion) {
      case RoboEmotion.listening:
        label = "Listening...";
        icon = Icons.mic;
        break;
      case RoboEmotion.thinking:
        label = "Processing...";
        icon = Icons.psychology;
        break;
      case RoboEmotion.reminder:
        label = "Health Alert!";
        icon = Icons.notifications_active;
        color = Colors.orangeAccent;
        break;
      case RoboEmotion.dizzy:
        label = "Whoa!";
        icon = Icons.sync;
        break;
      case RoboEmotion.surprised:
        label = "Wow!";
        icon = Icons.bolt;
        break;
      case RoboEmotion.tickled:
        label = "Hehe!";
        icon = Icons.favorite;
        break;
      default:
        label = "Care-AI is talking...";
        icon = Icons.volume_up;
    }

    return Positioned(
      bottom: 40,
      left: 40,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.2)),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.05),
              blurRadius: 20,
              spreadRadius: 2,
            )
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color.withOpacity(0.8), size: 18),
            const SizedBox(width: 10),
            Text(
              label,
              style: TextStyle(
                color: Colors.white.withOpacity(0.8),
                fontSize: 14,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIntroSequence() {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.0, end: 1.0),
      duration: const Duration(seconds: 2),
      curve: Curves.elasticOut,
      builder: (context, value, child) {
        return Transform.scale(
          scale: value,
          child: _buildFace(isAwaking: true),
        );
      },
    );
  }

  Widget _buildFace({bool isAwaking = false}) {
    Color eyeColor = const Color(0xFF81D4FA); // Calming Light Blue
    double eyeHeight = 170;
    double eyeWidth = 180; 
    BorderRadius eyeRadius = BorderRadius.circular(45); 

    if (_emotion == RoboEmotion.happy || _emotion == RoboEmotion.tickled) {
      eyeWidth = 180;
      eyeHeight = 90;
      eyeRadius = const BorderRadius.only(
        topLeft: Radius.circular(45),
        topRight: Radius.circular(45),
        bottomLeft: Radius.circular(20),
        bottomRight: Radius.circular(20),
      );
    } else if (_emotion == RoboEmotion.surprised) {
      eyeWidth = 190;
      eyeHeight = 180;
      eyeRadius = BorderRadius.circular(45);
      eyeColor = const Color(0xFFB3E5FC); // Brighter light blue
    } else if (_emotion == RoboEmotion.dizzy) {
      eyeWidth = 160;
      eyeHeight = 160;
      eyeRadius = BorderRadius.circular(45);
      eyeColor = Colors.tealAccent;
    } else if (_emotion == RoboEmotion.thinking) {
      eyeWidth = 140;
      eyeHeight = 100; 
      eyeRadius = BorderRadius.circular(35);
    } else if (_emotion == RoboEmotion.reminder) {
      eyeColor = const Color(0xFF81D4FA);
      eyeWidth = 210;
      eyeHeight = 200;
      eyeRadius = BorderRadius.circular(50);
    }

    return AnimatedBuilder(
      animation: Listenable.merge([_eyeMovementController, _blinkController]),
      builder: (context, child) {
        double dx = sin(_eyeMovementController.value * pi * 2) * 5;
        double dy = cos(_eyeMovementController.value * pi * 2) * 10;
        
        if (_emotion == RoboEmotion.dizzy) {
          dx = Random().nextDouble() * 20 - 10;
          dy = Random().nextDouble() * 20 - 10;
        }

        double blinkScale = 1.0 - (_blinkController.value * 0.95);
        double waveTilt = _isWavingBack ? sin(_waveBackController.value * pi * 2) * 0.15 : 0.0;

        return Transform.rotate(
          angle: waveTilt,
          child: Transform.translate(
            offset: Offset(dx, dy),
            child: Stack(
              alignment: Alignment.center,
              clipBehavior: Clip.none,
              children: [
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Transform.scale(
                          scaleY: blinkScale,
                          child: _buildEye(eyeColor, eyeWidth, eyeHeight, eyeRadius, true),
                        ),
                        const SizedBox(width: 140),
                        Transform.scale(
                          scaleY: blinkScale,
                          child: _buildEye(eyeColor, eyeWidth, eyeHeight, eyeRadius, false),
                        ),
                      ],
                    ),
                    const SizedBox(height: 60),
                    _buildMouth(eyeColor),
                  ],
                ),
                
                // Waving Hand Emoji (The "Wave Back" UI)
                if (_isWavingBack)
                  Positioned(
                    right: -160,
                    top: -20,
                    child: Transform.rotate(
                      angle: -waveTilt * 5, // Faster, wider waving for the hand
                      child: Text(
                        "👋",
                        style: TextStyle(
                          fontSize: 120,
                          shadows: [
                            Shadow(color: const Color(0xFF81D4FA).withOpacity(0.3), blurRadius: 20)
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPremiumBackground() {
    return Stack(
      children: [
        // Multi-layered mesh glows
        Positioned(
          top: -100,
          right: -100,
          child: _buildGlow(300, const Color(0xFF0D47A1).withOpacity(0.15)),
        ),
        Positioned(
          bottom: -150,
          left: -50,
          child: _buildGlow(400, const Color(0xFF81D4FA).withOpacity(0.1)),
        ),
        
        // Dynamic floating medical icons with premium blue glow
        _buildFloatingElement(Icons.favorite_rounded, 0.15, 0.2, 8),
        _buildFloatingElement(Icons.medication_rounded, 0.75, 0.15, 10),
        _buildFloatingElement(Icons.health_and_safety_rounded, 0.25, 0.8, 9),
        _buildFloatingElement(Icons.opacity_rounded, 0.65, 0.75, 12),
        _buildFloatingElement(Icons.auto_awesome_rounded, 0.1, 0.85, 7),
        
        // Scanline effect (very subtle)
        Opacity(
          opacity: 0.03,
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.white, Colors.transparent, Colors.white],
                stops: [0.0, 0.5, 1.0],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGlow(double size, Color color) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: color,
            blurRadius: size / 2,
            spreadRadius: size / 4,
          )
        ],
      ),
    );
  }

  Widget _buildFloatingElement(IconData icon, double topPct, double leftPct, int durationSeconds) {
    Color iconColor = const Color(0xFF81D4FA); // Matching eye color
    
    return Positioned(
      top: MediaQuery.of(context).size.height * topPct,
      left: MediaQuery.of(context).size.width * leftPct,
      child: AnimatedBuilder(
        animation: _eyeMovementController,
        builder: (context, child) {
          // Optimized: Only translate, don't change decoration properties every frame
          double phase = (topPct + leftPct) * pi * 2;
          double offset = sin(_eyeMovementController.value * pi * 2 + phase) * 15;

          return Transform.translate(
            offset: Offset(0, offset),
            child: child,
          );
        },
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.04),
            shape: BoxShape.circle,
            border: Border.all(color: iconColor.withOpacity(0.06)),
          ),
          child: Icon(
            icon, 
            color: iconColor.withOpacity(0.3),
            size: 28,
          ),
        ),
      ),
    );
  }

  Widget _buildEye(Color color, double width, double height, BorderRadius radius, bool isLeft) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: color,
        borderRadius: radius,
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.5),
            blurRadius: 30,
            spreadRadius: 5,
          )
        ],
      ),
      child: Stack(
        children: [
          // Cute Inner Sparkle (The "Kawaii" look)
          Positioned(
            top: height * 0.15,
            left: isLeft ? width * 0.55 : width * 0.2,
            child: Container(
              width: width * 0.25,
              height: width * 0.25,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.8),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            top: height * 0.5,
            left: isLeft ? width * 0.75 : width * 0.1,
            child: Container(
              width: width * 0.1,
              height: width * 0.1,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.6),
                shape: BoxShape.circle,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMouth(Color color) {
    double mouthWidth = 120;
    double mouthHeight = 12;
    BorderRadius mouthRadius = BorderRadius.circular(10);
    double bottomOffset = 0;

    if (_emotion == RoboEmotion.happy || _emotion == RoboEmotion.tickled) {
      mouthWidth = 180;
      mouthHeight = 80; // Deeper smile
      mouthRadius = const BorderRadius.only(
        bottomLeft: Radius.circular(90),
        bottomRight: Radius.circular(90),
        topLeft: Radius.circular(20),
        topRight: Radius.circular(20),
      );
    } else if (_emotion == RoboEmotion.surprised) {
      mouthWidth = 70;
      mouthHeight = 70;
      mouthRadius = BorderRadius.circular(35);
    } else if (_emotion == RoboEmotion.dizzy) {
      mouthWidth = 90;
      mouthHeight = 15;
      mouthRadius = BorderRadius.circular(8);
    } else if (_emotion == RoboEmotion.speaking) {
      mouthWidth = 140 + (_mouthController.value * 50);
      mouthHeight = 25;
      mouthRadius = BorderRadius.circular(15);
    } else {
      // Neutral - make it a gentle curve
      mouthWidth = 100;
      mouthHeight = 20;
      mouthRadius = const BorderRadius.only(
        bottomLeft: Radius.circular(40),
        bottomRight: Radius.circular(40),
      );
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: mouthWidth,
      height: mouthHeight,
      decoration: BoxDecoration(
        color: color,
        borderRadius: mouthRadius,
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.4),
            blurRadius: 15,
          )
        ],
      ),
    );
  }
}

