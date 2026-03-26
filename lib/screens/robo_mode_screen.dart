import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_tts/flutter_tts.dart';
import 'package:dio/dio.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:google_mlkit_commons/google_mlkit_commons.dart';
import 'dart:typed_data';
import 'package:carepulseapp/login.dart';
import 'package:carepulseapp/loginApi.dart';
import 'package:audioplayers/audioplayers.dart';
import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

enum RoboEmotion { neutral, listening, thinking, speaking, happy, reminder, dizzy, surprised, tickled }

class RoboModeScreen extends StatefulWidget {
  const RoboModeScreen({Key? key}) : super(key: key);

  @override
  State<RoboModeScreen> createState() => _RoboModeScreenState();
}

class _RoboModeScreenState extends State<RoboModeScreen> with TickerProviderStateMixin {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  late stt.SpeechToText _speech;
  late FlutterTts _flutterTts;
  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 45),
  ));
  final AudioPlayer _audioPlayer = AudioPlayer();

  bool _isListening = false;
  RoboEmotion _emotion = RoboEmotion.neutral;
  
  // Intro animation
  bool _isIntro = true;
  bool _showExitButton = false;
  InputImageRotation? _rotation;
  Timer? _exitButtonTimer;
  Timer? _emotionTimer;

  String _currentText = "";
  String _recognizedSpeech = ""; // For subtitles
  String _robotResponseText = "";
  String _userContext = "";

  late AnimationController _eyeMovementController;
  late AnimationController _blinkController;
  // Camera & Gesture Detection
  CameraController? _cameraController;
  final PoseDetector _poseDetector = PoseDetector(options: PoseDetectorOptions(mode: PoseDetectionMode.stream));
  bool _isProcessingFrame = false;
  bool _isWavingBack = false;
  bool _isGenerating = false;
  bool _hasIntroduced = false; 
  DateTime? _lastWaveTime;
  Offset _visionOffset = Offset.zero; 
  bool _isUserPresent = false;
  Color _selectedEyeColor = const Color(0xFF81D4FA); // Default Cyber Blue
  bool _isAdaptiveMode = false; // New Adaptive Theme toggle
  late AnimationController _waveBackController;
  late AnimationController _thinkingDotsController;
  Timer? _reminderCheckTimer;
  Timer? _contextRefreshTimer;
  List<dynamic> _reminders = [];
  String _lastRemindedAlertId = "";

  // Logic to determine robotic color based on health status if adaptive is ON
  Color get _effectiveEyeColor {
    if (_isAdaptiveMode) {
      bool hasRisk = _userContext.toLowerCase().contains("bad") || 
                     _userContext.toLowerCase().contains("risk") || 
                     _userContext.toLowerCase().contains("critical") ||
                     _userContext.toLowerCase().contains("low") || 
                     _userContext.toLowerCase().contains("high");
      return hasRisk ? const Color(0xFFEF5350) : const Color(0xFF81D4FA);
    }
    return _selectedEyeColor;
  }

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeRight,
      DeviceOrientation.landscapeLeft,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    _eyeMovementController = AnimationController(vsync: this, duration: const Duration(seconds: 4))..repeat(reverse: true);
    _blinkController = AnimationController(vsync: this, duration: const Duration(milliseconds: 300));
    _waveBackController = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));
    _thinkingDotsController = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat();
    
    _startRandomBlinking();
    _initSpeech();
    _initTts();
    _initCamera();
    _loadUserContextAndInitBrain();
    _startAutonomousTimers();

    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() => _isIntro = false);
        _speak("How can I help you today?");
        setState(() => _hasIntroduced = true);
        Future.delayed(const Duration(seconds: 4), () {
          if (mounted) _startListening();
        });
      }
    });
  }


  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        _toggleExitButton();
      },
      onDoubleTap: () {
        _triggerEmotion(RoboEmotion.surprised);
      },
      onLongPress: () {
        _triggerEmotion(RoboEmotion.tickled, duration: 3000);
        _speak("Hehe, that tickles!");
      },
      onScaleUpdate: (details) {
        if (details.focalPointDelta.dx.abs() > 20 || details.focalPointDelta.dy.abs() > 20) {
          _triggerEmotion(RoboEmotion.dizzy, duration: 3000);
        }
        if (details.scale > 1.2 || details.scale < 0.8) {
           _triggerEmotion(RoboEmotion.surprised);
        }
      },
      child: Scaffold(
        key: _scaffoldKey,
        backgroundColor: Colors.black, // Pure black
        drawer: _buildSettingsDrawer(),
        body: Stack(
          children: [
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _isIntro ? _buildIntroSequence() : _buildFace(),
                  const SizedBox(height: 40),
                  // Subtitles - Restored as requested
                  if (_recognizedSpeech.isNotEmpty || _robotResponseText.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 40),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.white.withOpacity(0.1)),
                        ),
                        child: Builder(builder: (context) {
                          // Clamp displayed text to avoid subtitle overflow
                          final String displayText = _emotion == RoboEmotion.speaking
                              ? _robotResponseText
                              : _recognizedSpeech;
                          final String truncated = displayText.length > 120
                              ? '${displayText.substring(0, 120)}...'
                              : displayText;
                          return RichText(
                            textAlign: TextAlign.center,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            text: TextSpan(
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.9),
                                fontSize: 16,
                                fontWeight: FontWeight.w300,
                                fontFamily: 'Inter',
                              ),
                              children: [
                                if (_emotion == RoboEmotion.speaking)
                                  TextSpan(
                                    text: "CARE-AI: ",
                                    style: TextStyle(fontWeight: FontWeight.bold, color: _effectiveEyeColor),
                                  ),
                                TextSpan(text: truncated),
                              ],
                            ),
                          );
                        }),
                      ),
                    ),
                ],
              ),
            ),

            Positioned(
              top: 20,
              left: 20,
              child: AnimatedOpacity(
                opacity: _showExitButton ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 300),
                child: IgnorePointer(
                  ignoring: !_showExitButton,
                  child: GestureDetector(
                    onTap: () => _scaffoldKey.currentState?.openDrawer(),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.05),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white.withOpacity(0.1)),
                      ),
                      child: const Icon(Icons.settings_rounded, color: Colors.white70, size: 24),
                    ),
                  ),
                ),
              ),
            ),
            // Small Blue Waving Hand Greeting
            if (_isWavingBack)
              Positioned(
                bottom: 80,
                right: 40,
                child: Transform.rotate(
                  angle: sin(_waveBackController.value * pi * 2) * 0.4,
                  child: Icon(Icons.waving_hand_rounded, color: _effectiveEyeColor, size: 40),
                ),
              ),
          ],
        ),
      ),
    );
  }


  Future<void> _loadUserContextAndInitBrain() async {
    String contextInfo = "User: You\n";
    
    try {
      // 1. Fetch Prediction History
      final predRes = await _dio.get("$baseUrl/api/prediction-history/$lid/");
      if (predRes.statusCode == 200) {
        final history = predRes.data['prediction_history'] ?? [];
        if (history.isNotEmpty) {
          contextInfo += "\nRecent Health Predictions:\n";
          for (var item in (history as List).take(3)) {
            contextInfo += "- ${item['result']} (Date: ${item['createdAt']})\n";
          }
        }
      }

      // 2. Fetch Active Medication Alerts
      final alertRes = await _dio.post("$baseUrl/api/alerts/", data: {"user_id": lid});
      if (alertRes.statusCode == 200) {
        final alerts = alertRes.data['alerts'] ?? [];
        _reminders = alerts; // Store raw alerts for autonomous checking
        if (alerts.isNotEmpty) {
          contextInfo += "\nUser Medications / Reminders:\n";
          for (var alert in (alerts as List).take(5)) {
             contextInfo += "- ${alert['title']}: ${alert['description']} (Time: ${alert['start_time']})\n";
          }
        }
      }
      
      // 3. Fetch Health Score
      final scoreRes = await _dio.get("$baseUrl/api/health-score/?userid=$lid");
      if (scoreRes.statusCode == 200) {
         contextInfo += "\nOverall Health Status: ${scoreRes.data['status']} - ${scoreRes.data['message']}\n";
      }
    } catch (e) {
      debugPrint("Error loading Robo Context: $e");
    }

    _userContext = contextInfo;
    debugPrint("Robo Brain Context Ready: ${contextInfo.length} chars");
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
      
      _rotation = InputImageRotationValue.fromRawValue(frontCamera.sensorOrientation) ?? InputImageRotation.rotation0deg;

      _cameraController!.startImageStream((CameraImage image) {
        if (_isProcessingFrame || _isIntro || _isWavingBack || !mounted) return;
        
        // Performance Throttling: High responsiveness
        final now = DateTime.now();
        if (_lastWaveTime == null || now.difference(_lastWaveTime!) > const Duration(milliseconds: 300)) {
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
      
      // OPTIMIZED: Use cached rotation, do not call availableCameras() in loop
      final imageRotation = _rotation ?? InputImageRotation.rotation0deg;
      final inputImageFormat = InputImageFormatValue.fromRawValue(image.format.raw) ?? InputImageFormat.yuv420;

      final inputImage = InputImage.fromBytes(
        bytes: bytes,
        metadata: InputImageMetadata(
          size: imageSize,
          rotation: imageRotation,
          format: inputImageFormat,
          bytesPerRow: image.planes[0].bytesPerRow,
        ),
      );
      
      final poses = await _poseDetector.processImage(inputImage);
      
      for (Pose pose in poses) {
        // 1. Presence Detection
        if (!_isUserPresent) {
          setState(() => _isUserPresent = true);
        }

        // 2. Eye Tracking (Follow the Nose)
        final PoseLandmark? nose = pose.landmarks[PoseLandmarkType.nose];
        if (nose != null) {
          // Map camera coordinates (usually 480x640 or 720x1280) to eye movement range (-15 to 15)
          // Note: Image is usually rotated/flipped due to front camera
          double normalizedX = (nose.x / image.width) - 0.5; // -0.5 to 0.5
          double normalizedY = (nose.y / image.height) - 0.5;

          setState(() {
            _visionOffset = Offset(
              normalizedX * 40, // Horizontal range
              normalizedY * 30  // Vertical range
            );
          });
        }

        // 3. Waving Detection
        final PoseLandmark? rightWrist = pose.landmarks[PoseLandmarkType.rightWrist];
        final PoseLandmark? rightIndex = pose.landmarks[PoseLandmarkType.rightIndex];
        final PoseLandmark? leftWrist = pose.landmarks[PoseLandmarkType.leftWrist];
        final PoseLandmark? leftIndex = pose.landmarks[PoseLandmarkType.leftIndex];

        bool waveDetected = false;
        if ((rightWrist != null && rightWrist.y < (nose?.y ?? 0)) || 
            (leftWrist != null && leftWrist.y < (nose?.y ?? 0))) {
          waveDetected = true;
        }

        if (waveDetected) {
          _onUserWaved();
          return; 
        }
      }
      
      if (poses.isEmpty && _isUserPresent) {
        setState(() {
          _isUserPresent = false;
          _visionOffset = Offset.zero;
        });
      }
    } catch (e) {
      debugPrint("Vision error: $e");
    }
    _isProcessingFrame = false;
  }

  void _onUserWaved() {
    if (_isWavingBack || _emotion == RoboEmotion.thinking || _emotion == RoboEmotion.speaking) return;
    
    // Hand/Palm showed logic with emotion
    setState(() {
      _isWavingBack = true;
      _emotion = RoboEmotion.happy;
    });

    _waveBackController.repeat(reverse: true);
    _speak("Hello");
    
    Timer(const Duration(seconds: 3), () {
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
      onError: (err) => debugPrint("Speech Error: ${err.errorMsg}"),
      onStatus: (status) {
        if (status == 'done' || status == 'notListening') {
          if (mounted) {
            setState(() {
              _isListening = false;
              if (_emotion == RoboEmotion.listening) _emotion = RoboEmotion.neutral;
            });
            // Loop listening if not busy
            if (_emotion != RoboEmotion.speaking && _emotion != RoboEmotion.thinking) {
               Future.delayed(const Duration(milliseconds: 300), _startListening);
            }
          }
        }
      },
    );
  }

  void _initTts() async {
    _flutterTts = FlutterTts();
    
    // Set logical defaults for a warmer, human tone
    await _flutterTts.setLanguage("en-US");
    await _flutterTts.setSpeechRate(0.40); // User-optimized slow pacing
    await _flutterTts.setVolume(1.0);
    await _flutterTts.setPitch(1.0); 

    // We no longer call setVoice here to ensure the system-default voice 
    // you selected in your phone settings is used as the primary voice.

    _flutterTts.setStartHandler(() {
      if (mounted) {
        setState(() {
          _emotion = RoboEmotion.speaking;
        });
      }
    });

    _flutterTts.setCompletionHandler(() {
      if (mounted) {
        setState(() {
          _emotion = RoboEmotion.neutral;
        });
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

  Future<void> _playServerAudio(String base64Audio) async {
    try {
      final bytes = base64Decode(base64Audio);
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/robo_resp_${DateTime.now().millisecondsSinceEpoch}.mp3');
      await file.writeAsBytes(bytes);

      setState(() {
        _emotion = RoboEmotion.speaking;
      });

      await _audioPlayer.play(DeviceFileSource(file.path));
      
      _audioPlayer.onPlayerComplete.listen((_) {
        if (mounted) {
          setState(() {
            _emotion = RoboEmotion.neutral;
          });
          _startListening();
        }
      });
    } catch (e) {
      debugPrint("Robo Audio Error: $e");
      // Fallback
      await _speak(_robotResponseText);
    }
  }

  void _startListening() async {
    if (!_speech.isAvailable || _emotion == RoboEmotion.speaking || _emotion == RoboEmotion.thinking || _emotion == RoboEmotion.dizzy || _emotion == RoboEmotion.surprised || _emotion == RoboEmotion.tickled) return;
    setState(() => _emotion = RoboEmotion.listening);
    await _speech.listen(
      onResult: (val) {
        if (mounted) {
          setState(() {
            _currentText = val.recognizedWords;
            _recognizedSpeech = val.recognizedWords; // Update subtitles
          });
        }
        if (val.finalResult && _currentText.trim().length > 1) {
           // Clear "Me:" subtitle after 2 seconds regardless of state
           Timer(const Duration(seconds: 2), () {
             if (mounted) setState(() => _recognizedSpeech = "");
           });
           _handleSubmitted(_currentText);
        }
      },
      listenFor: const Duration(seconds: 30),
      pauseFor: const Duration(seconds: 12),
      partialResults: true,
    );
  }

  void _handleSubmitted(String text) async {
    if (_isGenerating || text.trim().isEmpty) return;
    _isGenerating = true;
    await _speech.stop();
    setState(() {
      _emotion = RoboEmotion.thinking;
      _robotResponseText = ""; 
    });
    
    // 1. Try Local Ollama First (Low Latency, Offline Capable)
    try {
      final response = await _dio.post(
        "$ollamaBaseUrl/api/generate",
        data: {
          "model": "llama3.2:1b", // Faster 1B parameter model
          "prompt": """You are CARE-AI, a robotic healthcare assistant already in conversation.
Context (User health data): 
$_userContext
Current Time: ${DateTime.now().hour}:${DateTime.now().minute}

User says: $text

Rules (follow strictly):
- NEVER say "How can I help you" or introduce yourself again. You already did that.
- For simple fact questions (e.g. temperature, heart rate, medication), answer in ONE short sentence only. Example: "Your temperature is 37.2°C."
- Only elaborate if the user explicitly asks for details or explanation.
- No bullet points. No long paragraphs. Max 2 sentences.""",
          "stream": false
        },
      ).timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) {
        final String responseText = response.data['response'] ?? "";
        if (mounted) {
          setState(() {
            _robotResponseText = responseText;
            _emotion = RoboEmotion.speaking; 
          });
        }
        await _speak(responseText);
        _resetAfterSpeaking();
        _isGenerating = false;
        return;
      }
    } catch (e) {
      debugPrint("Ollama Local Brain Error (llama3.2:1b): $e");
    }

    // 2. Fallback to Django Cloud Brain
    try {
      final response = await _dio.post(
        "$baseUrl/api/ai/chat/",
        data: {
          "user_id": lid,
          "text": text,
          "mode": "robo"
        },
      );
      
      if (response.statusCode == 200) {
        final String responseText = response.data['response'] ?? "";
        final String? audioBase64 = response.data['audio'];

        if (mounted) {
          setState(() {
            _robotResponseText = responseText;
          });
        }

        if (audioBase64 != null && audioBase64.isNotEmpty) {
           await _playServerAudio(audioBase64);
        } else {
           await _speak(responseText);
        }
      }
    } catch (e) {
      debugPrint("Server Error: $e");
      if (mounted) {
        setState(() => _robotResponseText = "Brain Connection Timeout. Please check server.");
      }
      if (text.length > 5) {
        await _speak("My brain is offline. Please check your internet connection.");
      }
      _resetAfterSpeaking();
    } finally {
      _isGenerating = false;
    }
  }

  void _resetAfterSpeaking() {
    if (mounted) {
      setState(() {
        _emotion = RoboEmotion.neutral;
        // Keep subtitles visible for a few seconds after speaking ends, then clear
        Timer(const Duration(seconds: 4), () {
          if (mounted && _emotion != RoboEmotion.speaking) {
            setState(() => _robotResponseText = "");
          }
        });
      });
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

  void _startAutonomousTimers() {
    // Check for reminders every 30 seconds
    _reminderCheckTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      _checkForReminders();
    });

    // Refresh medical data every 5 minutes
    _contextRefreshTimer = Timer.periodic(const Duration(minutes: 5), (timer) {
      _loadUserContextAndInitBrain();
    });
  }

  void _checkForReminders() {
    if (_reminders.isEmpty || _emotion == RoboEmotion.speaking || _emotion == RoboEmotion.thinking) return;

    final now = DateTime.now();
    final currentTimeStr = "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}";

    for (var alert in _reminders) {
      String alertTimeStr = alert['start_time'].toString();
      // Ensure time matches format HH:mm
      if (alertTimeStr.contains("T")) {
        // Handle ISO strings if coming from backend as such
        alertTimeStr = alertTimeStr.split("T")[1].substring(0, 5);
      } else if (alertTimeStr.length > 5) {
        alertTimeStr = alertTimeStr.substring(0, 5);
      }

      if (currentTimeStr == alertTimeStr && _lastRemindedAlertId != alert['id'].toString()) {
        _lastRemindedAlertId = alert['id'].toString();
        _triggerMedicationAlert(alert['title'], alert['description']);
        break; 
      }
    }
  }

  void _triggerMedicationAlert(String title, String description) {
    debugPrint("AUTONOMOUS REMINDER TRIGGERED: $title");
    _speech.stop(); // Stop listening to announce immediately
    
    setState(() {
      _emotion = RoboEmotion.reminder;
      _robotResponseText = "REMINDER: $title - $description";
    });

    _speak("Attention. It is time for your medication: $title. $description");
    
    // Resume listening after 10 seconds
    Timer(const Duration(seconds: 10), () {
      if (mounted && _emotion == RoboEmotion.reminder) {
         _resetAfterSpeaking();
      }
    });
  }

  @override
  void dispose() {
    _exitButtonTimer?.cancel();
    _emotionTimer?.cancel();
    _reminderCheckTimer?.cancel();
    _contextRefreshTimer?.cancel();
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
    _waveBackController.dispose();
    _thinkingDotsController.dispose();
    super.dispose();
  }


  Widget _buildStatusIndicator() {
    if (_isIntro || _emotion == RoboEmotion.neutral || _emotion == RoboEmotion.listening || _emotion == RoboEmotion.thinking) return const SizedBox.shrink();
    
    String label = "";
    IconData icon = Icons.auto_awesome;
    Color color = _effectiveEyeColor; // Changed from const Color(0xFF81D4FA)

    switch (_emotion) {
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
        label = "Talking...";
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
    Color eyeColor = _effectiveEyeColor; 
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
    } else if (_emotion == RoboEmotion.reminder) {
      eyeColor = _effectiveEyeColor;
      eyeWidth = 210;
      eyeHeight = 200;
      eyeRadius = BorderRadius.circular(50);
    }

    return AnimatedBuilder(
      animation: Listenable.merge([_eyeMovementController, _blinkController]),
      builder: (context, child) {
        // Base idle movement
        double dx = sin(_eyeMovementController.value * pi * 2) * 5;
        double dy = cos(_eyeMovementController.value * pi * 2) * 8;

        // Apply Live Vision Tracking Offset if user is present
        if (_isUserPresent && _emotion != RoboEmotion.thinking) {
          dx = _visionOffset.dx;
          dy = _visionOffset.dy;
        }
        
        // Pulse/Thinking Animation Enhancement
        double pulse = 8 + sin(_eyeMovementController.value * pi * 4) * 12;
        
        if (_emotion == RoboEmotion.thinking) {
          pulse = 10; 
          // Thinking Gaze: Natural horizontal "searching" movement with subtle height
          dx = sin(_eyeMovementController.value * pi * 4) * 15; 
          dy = -10 + cos(_eyeMovementController.value * pi * 2) * 4;
          // Add a subtle high-frequency jitter for "processing" feel
          dx += (Random().nextDouble() * 2 - 1);
          dy += (Random().nextDouble() * 2 - 1);
        } else if (_emotion == RoboEmotion.speaking) {
          // Centered but 'pulsing' with speech rhythm
          dx = sin(_eyeMovementController.value * pi * 8) * 2; 
          dy = cos(_eyeMovementController.value * pi * 8) * 2;
          pulse = 15 + sin(_eyeMovementController.value * pi * 10) * 15;
        }
        
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
                          child: _buildEye(eyeColor, eyeWidth, eyeHeight, eyeRadius, true, pulse),
                        ),
                        const SizedBox(width: 140),
                        Transform.scale(
                          scaleY: blinkScale,
                          child: _buildEye(eyeColor, eyeWidth, eyeHeight, eyeRadius, false, pulse),
                        ),
                      ],
                    ),
                  ],
                ),
                
                // Blue Waving Hand Icon
                if (_isWavingBack)
                  Positioned(
                    right: -70,
                    top: -20,
                    child: Transform.rotate(
                      angle: -waveTilt * 5, // Faster, wider waving for the hand
                      child: Icon(
                        Icons.waving_hand_rounded,
                        color: _effectiveEyeColor, // Use selected eye color
                        size: 50,
                        shadows: [
                          Shadow(color: _effectiveEyeColor.withOpacity(0.8), blurRadius: 20) // Use selected eye color for shadow
                        ],
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
        // Dynamic floating medical icons
        _buildFloatingElement(Icons.favorite_rounded, 0.15, 0.2, 8),
        _buildFloatingElement(Icons.medication_rounded, 0.75, 0.15, 10),
        _buildFloatingElement(Icons.health_and_safety_rounded, 0.25, 0.8, 9),
        _buildFloatingElement(Icons.opacity_rounded, 0.65, 0.75, 12),
        _buildFloatingElement(Icons.auto_awesome_rounded, 0.1, 0.85, 7),
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
    Color iconColor = _effectiveEyeColor; 
    
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

  Widget _buildEye(Color color, double width, double height, BorderRadius radius, bool isLeft, double pulse) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: color,
        borderRadius: radius,
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(_emotion == RoboEmotion.thinking ? 0.3 : 0.6),
            blurRadius: _emotion == RoboEmotion.thinking ? 20 : 40 + pulse,
            spreadRadius: _emotion == RoboEmotion.thinking ? 2 : 10 + pulse / 1.5,
          )
        ],
      ),
      child: Stack(
        children: [
          if (_emotion == RoboEmotion.thinking)
            _buildThinkingPattern(width, height)
          else ...[
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
        ],
      ),
    );
  }

  Widget _buildThinkingPattern(double width, double height) {
    return AnimatedBuilder(
      animation: _thinkingDotsController,
      builder: (context, child) {
        return Stack(
          alignment: Alignment.center,
          children: [
            // Subtly visible digital background
            Opacity(
              opacity: 0.05,
              child: GridView.builder(
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.all(20),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 5,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                ),
                itemCount: 25,
                itemBuilder: (context, index) => Container(
                  decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                ),
              ),
            ),
            
            // Dynamic Floating "Synapse" Balls
            ...List.generate(5, (index) {
              // Each ball has its own unique speed and orbital path
              double speedMultiplier = 1.0 + (index * 0.3);
              double t = _thinkingDotsController.value * 2 * pi * speedMultiplier;
              double offsetPhase = index * (2 * pi / 5);
              
              // Complex Lissajous-like movement
              double dx = sin(t + offsetPhase) * (width * 0.28);
              double dy = cos(t * 0.7 + offsetPhase) * (height * 0.22);
              
              // Dynamic sizing and glow
              double size = 12 + sin(t * 1.5 + index) * 4;
              double glowIntensity = 0.4 + (sin(t * 2) + 1.0) * 0.3;

              return Transform.translate(
                offset: Offset(dx, dy),
                child: Container(
                  width: size,
                  height: size,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.9),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.white.withOpacity(glowIntensity),
                        blurRadius: 15,
                        spreadRadius: 2,
                      )
                    ],
                  ),
                ),
              );
            }),
          ],
        );
      },
    );
  }

  Widget _buildSettingsDrawer() {
    return Drawer(
      backgroundColor: Colors.transparent,
      elevation: 0,
      width: MediaQuery.of(context).size.width * 0.28,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF0F0B13),
          border: Border(right: BorderSide(color: Colors.white.withOpacity(0.1))),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 40, 16, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "ROBO SET",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    width: 20,
                    height: 2,
                    decoration: BoxDecoration(
                      color: _effectiveEyeColor,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSideColorOption(const Color(0xFF81D4FA), "Cyan"),
                  _buildSideColorOption(const Color(0xFF26A69A), "Teal"),
                  _buildSideColorOption(const Color(0xFFAB47BC), "Iris"),
                  _buildSideColorOption(const Color(0xFFFFA726), "Gold"),
                  _buildSideColorOption(const Color(0xFFEF5350), "Ruby"),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: GestureDetector(
                onTap: () => setState(() => _isAdaptiveMode = !_isAdaptiveMode),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: _isAdaptiveMode ? _effectiveEyeColor.withOpacity(0.1) : Colors.white.withOpacity(0.03),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: _isAdaptiveMode ? _effectiveEyeColor.withOpacity(0.3) : Colors.white.withOpacity(0.05)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        _isAdaptiveMode ? Icons.auto_awesome_rounded : Icons.auto_awesome_outlined,
                        color: _isAdaptiveMode ? _effectiveEyeColor : Colors.white24,
                        size: 14,
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        "AUTO",
                        style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  debugPrint("🚀 Exiting Robo Mode...");
                  Navigator.of(context).pop(); // Close Drawer
                  Navigator.of(context).pop(); // Exit Robo Mode
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.03),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.white.withOpacity(0.05)),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.power_settings_new_rounded, color: Colors.white38, size: 12),
                      SizedBox(width: 6),
                      Text(
                        "EXIT",
                        style: TextStyle(color: Colors.white38, fontSize: 8, fontWeight: FontWeight.bold, letterSpacing: 1.0),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildSideColorOption(Color color, String label) {
    bool isSelected = _selectedEyeColor.value == color.value;
    return GestureDetector(
      onTap: () {
        setState(() => _selectedEyeColor = color);
        Navigator.pop(context); // Close Drawer
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 18),
        child: Row(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(color: color.withOpacity(0.4), blurRadius: 8, spreadRadius: 1)
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label.toUpperCase(),
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.white24,
                  fontSize: 9,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  letterSpacing: 0.5
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

}

