import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'dart:async';
import 'dart:math';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'dart:convert';

// Gemini API Key (ë³´ì•ˆ???„í•´ ?¤ì œ ë°°í¬ ?œì—???¨ê²¨????
const String _geminiKey = 'AIzaSyBtEtujomeYnJUc5ZlEi7CteLmapaEZ4MY';

// Server API URL (ê³¼í•™???Œê³ ë¦¬ì¦˜ ?œë²„)
const String _serverUrl = 'https://solo-runner-api.onrender.com'; // Render.com ë°°í¬ ??URL

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Supabase ì´ˆê¸°??
  await Supabase.initialize(
    url: 'https://cigtumbiljofgwnjeegu.supabase.co',
    anonKey: 'sb_secret_B_cW2gyjQ5oCYYtaeB493g_JEYvoJkO', 
  );
  
  runApp(const SoloRunnerApp());
}

class SoloRunnerApp extends StatelessWidget {
  const SoloRunnerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Solo Runner',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal, brightness: Brightness.dark),
        useMaterial3: true,
        fontFamily: 'Roboto',
      ),
      home: const MainScreen(),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;
  late PageController _pageController;
  
  // Data Controllers
  final TextEditingController _heightController = TextEditingController(text: "175");
  final TextEditingController _weightController = TextEditingController(text: "70");
  final TextEditingController _weeklyController = TextEditingController(text: "120");
  final TextEditingController _recordController = TextEditingController(text: "60");
  
  // ?¯ ?€??ëª©í‘œ ?¤ì •
  final TextEditingController _goalDistanceController = TextEditingController(text: "10");
  final TextEditingController _goalTimeController = TextEditingController(text: "60");
  
  String _level = "beginner";
  bool _useSelfGoal = false; // ?€??ëª©í‘œ ?¬ìš© ?¬ë?
  
  // State
  List<Map<String, dynamic>> _plan = [];
  bool _isGenerating = false;
  Map<String, dynamic>? _currentRun; // ?„ì¬ ? íƒ??ëª©í‘œ ?ˆë ¨
  
  // ?“Š ?ì‘???Œê³ ë¦¬ì¦˜ ?°ì´??
  Map<String, dynamic> _trainingProgress = {
    'completedRuns': [],
    'missedDays': 0,
    'currentVDOT': 0.0,
    'lastCalculatedVDOT': 0.0,
    'weeklyCompletionRate': 0.0,
  };
  
  // AI & TTS
  late FlutterTts _tts;
  late GenerativeModel _geminiModel;
  bool _isVoiceOn = true; // ?¤ë””??ì½”ì¹­ ON/OFF ?íƒœ

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _initTTS();
    _geminiModel = GenerativeModel(model: 'gemini-pro', apiKey: _geminiKey);
    
    // ???œì‘ ???„ë½???ˆë ¨ ?•ì¸
    Future.delayed(const Duration(seconds: 2), () {
      _checkMissedTrainings();
    });
  }

  void _initTTS() async {
    _tts = FlutterTts();
    await _tts.setLanguage("ko-KR");
    
    // ?ì—°?¤ëŸ¬???¨ì„± ?Œì„± ?¤ì •
    await _tts.setSpeechRate(0.5); // ?ë‹¹???ë„
    await _tts.setPitch(0.95); // ?½ê°„ ??? ??(?ì—°?¤ëŸ¬?€ ? ì?)
    await _tts.setVolume(1.0);
  }

  // Navigation
  void _onItemTapped(int index) {
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> pages = [
      _buildSetupPage(),
      _buildRunPage(),
      _buildPlanPage(),
    ];

    return Scaffold(
      body: SafeArea(
        child: PageView(
          controller: _pageController,
          onPageChanged: (index) {
            setState(() {
              _selectedIndex = index;
            });
          },
          children: pages,
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: _onItemTapped,
        destinations: const [
          NavigationDestination(icon: Icon(Icons.person_outline), label: '?„ë¡œ??),
          NavigationDestination(icon: Icon(Icons.directions_run), label: '?¬ë‹'),
          NavigationDestination(icon: Icon(Icons.calendar_month), label: '?Œëœ'),
        ],
      ),
    );
  }

  // --- 1. ?¤ì • ?˜ì´ì§€ ---
  Widget _buildSetupPage() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF1A1A2E), Color(0xFF0F0F1E)],
        ),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 20),
            // ë©”ì¸ ë¡œê³  - ?¤ì˜¨ ê¸€ë¡œìš° ?¨ê³¼
            ShaderMask(
              shaderCallback: (bounds) => const LinearGradient(
                colors: [Color(0xFF00FFF0), Color(0xFF00D9FF), Color(0xFF0099FF)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ).createShader(bounds),
              child: Text("SOLO", 
                style: TextStyle(
                  fontSize: 45, 
                  fontWeight: FontWeight.w900,
                  fontStyle: FontStyle.italic,
                  color: Colors.white,
                  letterSpacing: 3,
                  shadows: [
                    Shadow(color: const Color(0xFF00FFF0).withOpacity(0.6), blurRadius: 20),
                    Shadow(color: const Color(0xFF0099FF).withOpacity(0.4), blurRadius: 30),
                  ],
                ),
                textAlign: TextAlign.center,
              ),
            ),
            ShaderMask(
              shaderCallback: (bounds) => const LinearGradient(
                colors: [Color(0xFF00FFF0), Color(0xFF00D9FF), Color(0xFF0099FF)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ).createShader(bounds),
              child: Text("RUNNER", 
                style: TextStyle(
                  fontSize: 45, 
                  fontWeight: FontWeight.w900,
                  fontStyle: FontStyle.italic,
                  color: Colors.white,
                  letterSpacing: 3,
                  height: 0.85,
                  shadows: [
                    Shadow(color: const Color(0xFF00FFF0).withOpacity(0.6), blurRadius: 20),
                    Shadow(color: const Color(0xFF0099FF).withOpacity(0.4), blurRadius: 30),
                  ],
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 8),
            const Text("?˜ë§Œ??AI ?¬ë¦¬ê¸?ì½”ì¹˜", 
              style: TextStyle(fontSize: 13, color: Colors.white38, letterSpacing: 0.5), 
              textAlign: TextAlign.center
            ),
            const SizedBox(height: 30),
            
            // ?…ë ¥ ?„ë“œ - ?¤ì˜¨ ?¤í???
            Row(children: [
              Expanded(child: _buildNeonInput(Icons.straighten, "??, "cm", _heightController)),
              const SizedBox(width: 10),
              Expanded(child: _buildNeonInput(Icons.monitor_weight, "ëª¸ë¬´ê²?, "kg", _weightController)),
            ]),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: _buildNeonInput(Icons.access_time, "ì£¼ê°„ëª©í‘œ", "ë¶?, _weeklyController)),
              const SizedBox(width: 10),
              Expanded(child: _buildNeonInput(Icons.timer, "10kmê¸°ë¡", "ë¶?, _recordController)),
            ]),
            const SizedBox(height: 20),
            
            // ?¯ ?€??ëª©í‘œ ?¤ì • - ?¤ì˜¨ ë°•ìŠ¤ (? ê? ê¸°ëŠ¥ ì¶”ê?)
            InkWell(
              onTap: () {
                setState(() {
                  _useSelfGoal = !_useSelfGoal;
                });
              },
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: _useSelfGoal
                    ? LinearGradient(
                        colors: [
                          const Color(0xFF1A3A3A).withOpacity(0.6),
                          const Color(0xFF1A2A3A).withOpacity(0.5),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : null,
                  color: !_useSelfGoal ? const Color(0xFF1A3A3A).withOpacity(0.4) : null,
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(
                    width: _useSelfGoal ? 2.5 : 2,
                    color: Colors.transparent,
                  ),
                  boxShadow: [
                    if (_useSelfGoal) ..[
                      BoxShadow(
                        color: const Color(0xFF00FFF0).withOpacity(0.3),
                        blurRadius: 20,
                        spreadRadius: 1,
                      ),
                      BoxShadow(
                        color: const Color(0xFF0099FF).withOpacity(0.2),
                        blurRadius: 15,
                        spreadRadius: 2,
                      ),
                    ] else ..[
                      BoxShadow(
                        color: const Color(0xFF00FFF0).withOpacity(0.15),
                        blurRadius: 15,
                        spreadRadius: 1,
                      ),
                    ],
                  ],
                ),
                foregroundDecoration: _useSelfGoal ? BoxDecoration(
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(
                    width: 2.5,
                  ),
                  gradient: const LinearGradient(
                    colors: [Color(0xFF00FFF0), Color(0xFF00D9FF), Color(0xFF0099FF)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ) : BoxDecoration(
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(
                    color: const Color(0xFF00FFF0).withOpacity(0.5),
                    width: 2,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          _useSelfGoal ? Icons.check_circle : Icons.flag_outlined, 
                          color: const Color(0xFF00FFF0), 
                          size: 20
                        ),
                        const SizedBox(width: 8),
                        const Text("?€??ëª©í‘œ ?¤ì •", 
                          style: TextStyle(
                            color: Color(0xFF00FFF0), 
                            fontWeight: FontWeight.bold, 
                            fontSize: 15
                          )
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(children: [
                      Expanded(child: _buildNeonInput(Icons.straighten, "ëª©í‘œê±°ë¦¬", "km", _goalDistanceController)),
                      const SizedBox(width: 10),
                      Expanded(child: _buildNeonInput(Icons.timer, "ëª©í‘œ?œê°„", "ë¶?, _goalTimeController)),
                    ]),
                    const SizedBox(height: 10),
                    Center(
                      child: Text(
                        _goalDistanceController.text.isNotEmpty && _goalTimeController.text.isNotEmpty
                          ? "ëª©í‘œ ?˜ì´?? ${_calculateTargetPace()}"
                          : "",
                        style: const TextStyle(color: Colors.white38, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 20),
            
            // ê°•ë„ ? íƒ - AI ?Œëœ ëª¨ë“œ (?€??ëª©í‘œ ? íƒ ??ë¹„í™œ?±í™”)
            Opacity(
              opacity: _useSelfGoal ? 0.3 : 1.0,
              child: const Text("AI ?Œëœ ê°•ë„", 
                style: TextStyle(
                  color: Colors.white54, 
                  fontSize: 13, 
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.5
                )
              ),
            ),
            const SizedBox(height: 10),
            IgnorePointer(
              ignoring: _useSelfGoal,
              child: Opacity(
                opacity: _useSelfGoal ? 0.3 : 1.0,
                child: Row(
                  children: [
                    Expanded(child: _buildLevelBox("beginner", Icons.directions_walk, "?…ë¬¸??, "12ì£?)),
                    const SizedBox(width: 10),
                    Expanded(child: _buildLevelBox("intermediate", Icons.directions_run, "ì¤‘ê¸‰??, "24ì£?)),
                    const SizedBox(width: 10),
                    Expanded(child: _buildLevelBox("advanced", Icons.bar_chart, "?ê¸‰??, "48ì£?)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 25),
          Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF00FFF0), Color(0xFF00D9FF), Color(0xFF0099FF)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF00FFF0).withOpacity(0.4),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
                BoxShadow(
                  color: const Color(0xFF0099FF).withOpacity(0.3),
                  blurRadius: 15,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ElevatedButton(
              onPressed: _isGenerating ? null : _generatePlan,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 18),
                backgroundColor: Colors.transparent,
                foregroundColor: const Color(0xFF0F0F1E),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 0,
                shadowColor: Colors.transparent,
              ).copyWith(
                overlayColor: MaterialStateProperty.all(Colors.white.withOpacity(0.1)),
              ),
            child: Text(
              _isGenerating ? "?ì„± ì¤?.." : "AI ëª©í‘œì¹??¤ì • ?ì„±",
              style: const TextStyle(
                fontSize: 16, 
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ],
      ),
      ),
    );
  }

  // ?¨ ?¤ì˜¨ ?¤í????…ë ¥ ?„ë“œ (?ë³¸ ?´ë?ì§€?€ ?‘ê°™??
  Widget _buildNeonInput(IconData icon, String label, String unit, TextEditingController ctrl) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF1A3A3A).withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF00FFF0).withOpacity(0.4), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF00FFF0).withOpacity(0.1),
            blurRadius: 8,
            spreadRadius: 0,
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF00FFF0), size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label, 
                  style: const TextStyle(
                    color: Colors.white38, 
                    fontSize: 10,
                    fontWeight: FontWeight.w400,
                  )
                ),
                const SizedBox(height: 2),
                TextField(
                  controller: ctrl,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(
                    color: Colors.white, 
                    fontSize: 18, 
                    fontWeight: FontWeight.w700,
                    height: 1.0,
                  ),
                  decoration: const InputDecoration(
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                    border: InputBorder.none,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          Text(
            unit, 
            style: const TextStyle(
              color: Colors.white30, 
              fontSize: 13,
              fontWeight: FontWeight.w400,
            )
          ),
        ],
      ),
    );
  }
  
  // ?¨ ?ˆë²¨ ? íƒ ë°•ìŠ¤ (?•ê´‘ ?„ì´ì½??¤í???
  Widget _buildLevelBox(String value, IconData icon, String label, String duration) {
    bool isSelected = _level == value;
    return InkWell(
      onTap: () => setState(() => _level = value),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected 
            ? const Color(0xFF00FFF0).withOpacity(0.15)
            : const Color(0xFF1A3A3A).withOpacity(0.3),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected 
              ? const Color(0xFF00FFF0).withOpacity(0.6)
              : const Color(0xFF00FFF0).withOpacity(0.2),
            width: isSelected ? 2 : 1.5,
          ),
          boxShadow: isSelected ? [
            BoxShadow(
              color: const Color(0xFF00FFF0).withOpacity(0.3),
              blurRadius: 12,
              spreadRadius: 0,
            ),
          ] : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: isSelected 
                  ? const Color(0xFF00FFF0).withOpacity(0.2)
                  : Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(10),
              ),
              alignment: Alignment.center,
              child: Icon(
                icon,
                size: 28,
                color: isSelected ? const Color(0xFF00FFF0) : Colors.white60,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? const Color(0xFF00FFF0) : Colors.white70,
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              duration,
              style: TextStyle(
                color: isSelected 
                  ? const Color(0xFF00FFF0).withOpacity(0.7)
                  : Colors.white38,
                fontSize: 11,
              ),
            ),
            if (isSelected) ...[
              const SizedBox(height: 4),
              Icon(
                Icons.check_circle,
                color: const Color(0xFF00FFF0),
                size: 16,
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ?¯ ëª©í‘œ ?˜ì´??ê³„ì‚°
  String _calculateTargetPace() {
    try {
      double dist = double.parse(_goalDistanceController.text);
      double time = double.parse(_goalTimeController.text);
      if (dist > 0) {
        double paceMin = time / dist;
        int min = paceMin.toInt();
        int sec = ((paceMin - min) * 60).toInt();
        return "$min'${sec.toString().padLeft(2, '0')}\" /km";
      }
    } catch (e) {}
    return "--'--\" /km";
  }

  // ?“Š VDOT ê³„ì‚° (Jack Daniels' Running Formula)
  double _calculateVDOT(double distanceKm, double timeMin) {
    // VDOT = (-4.60 + 0.182258 * v + 0.000104 * v^2) / (0.8 + 0.1894393 * e^(-0.012778 * t) + 0.2989558 * e^(-0.1932605 * t))
    // ê°„ì†Œ?”ëœ ê·¼ì‚¬???¬ìš©
    double velocity = (distanceKm * 1000) / (timeMin * 60); // m/s
    double percent02Max = 0.8 + 0.1894393 * exp(-0.012778 * timeMin) + 0.2989558 * exp(-0.1932605 * timeMin);
    double vo2 = -4.60 + 0.182258 * velocity + 0.000104 * velocity * velocity;
    return vo2 / percent02Max;
  }

  void _generatePlan() async {
    setState(() => _isGenerating = true);
    
    // ?¬ìš©???…ë ¥ ?Œì‹±
    double height = double.tryParse(_heightController.text) ?? 175;
    double weight = double.tryParse(_weightController.text) ?? 70;
    double weeklyMin = double.tryParse(_weeklyController.text) ?? 120;
    double record10k = double.tryParse(_recordController.text) ?? 60;
    
    // ?¯ VDOT ê³„ì‚°
    double targetVDOT = 0;
    if (_useSelfGoal) {
      try {
        double goalDist = double.parse(_goalDistanceController.text);
        double goalTime = double.parse(_goalTimeController.text);
        targetVDOT = _calculateVDOT(goalDist, goalTime);
      } catch (e) {
        targetVDOT = _calculateVDOT(10, record10k);
      }
    } else {
      targetVDOT = _calculateVDOT(10, record10k);
    }
    
    _trainingProgress['currentVDOT'] = targetVDOT;
    _trainingProgress['lastCalculatedVDOT'] = targetVDOT;
    
    // ?Œ ?œë²„ API ?¸ì¶œ (ê³¼í•™???Œê³ ë¦¬ì¦˜ ?¬ìš©)
    try {
      final response = await http.post(
        Uri.parse('$_serverUrl/generate'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'level': _level,
          'record_10km': record10k,
          'weekly_min': weeklyMin.toInt(),
          'height': height.toInt(),
          'weight': weight.toInt(),
        }),
      ).timeout(const Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        // ?œë²„ ?‘ë‹µ??Flutter ?•ì‹?¼ë¡œ ë³€??
        List<Map<String, dynamic>> serverPlan = [];
        for (var week in data['plan']) {
          // ?œë²„ ?•ì‹??Flutter ?•ì‹?¼ë¡œ ë³€??
          List<Map<String, dynamic>> runs = [];
          for (var run in week['schedule']) {
            if (run['dist'] > 0) {
              runs.add({
                'day': _translateDay(run['day_nm']),
                'type': run['type'],
                'dist': run['dist'].toDouble(),
                'targetPace': run['pace'].toDouble(),
                'desc': run['desc'],
                'completed': false,
              });
            }
          }
          
          serverPlan.add({
            'week': week['week'],
            'focus': week['focus'],
            'intensity': week.containsKey('intensity') ? week['intensity'] : 0.5,
            'targetVDOT': targetVDOT,
            'completed': false,
            'runs': runs,
          });
        }
        
        setState(() {
          _plan = serverPlan;
          _isGenerating = false;
          _selectedIndex = 2; // Move to Plan tab
        });
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("?¯ ê³¼í•™ ê¸°ë°˜ ?Œëœ ?ì„± ?„ë£Œ! (ACSM ê°€?´ë“œ?¼ì¸)"), 
              backgroundColor: Colors.teal
            )
          );
        }
        return;
      }
    } catch (e) {
      print('INFO: Server unavailable, using local algorithm - $e');
    }
    
    // ?’» ?œë²„ ?¤íŒ¨ ??ë¡œì»¬ ?Œê³ ë¦¬ì¦˜ ?´ë°±
    await _generatePlanLocal(targetVDOT, weeklyMin, height, weight);
  }
  
  // ë¡œì»¬ ?Œëœ ?ì„± (?œë²„ ?¤íŒ¨ ???´ë°±)
  Future<void> _generatePlanLocal(double targetVDOT, double weeklyMin, double height, double weight) async {
    // ?ˆë²¨ë³??¤ì •
    int totalWeeks = _level == "beginner" ? 12 : (_level == "intermediate" ? 24 : 48);
    double baseDistanceMultiplier = _level == "beginner" ? 0.7 : (_level == "intermediate" ? 1.0 : 1.3);
    double weeklyVolumeKm = (weeklyMin / 60) * 10;
    
    List<Map<String, dynamic>> newPlan = [];
    
    for(int i=1; i<=totalWeeks; i++) {
        double intensity = _calculateWeekIntensity(i, totalWeeks);
        String focus = _getWeekFocus(i, totalWeeks);
        
        double easyPace = _getPaceFromVDOT(targetVDOT, 'easy');
        double tempoPace = _getPaceFromVDOT(targetVDOT, 'tempo');
        double intervalPace = _getPaceFromVDOT(targetVDOT, 'interval');
        
        newPlan.add({
          "week": i,
          "focus": focus,
          "intensity": intensity,
          "targetVDOT": targetVDOT,
          "completed": false,
          "runs": _generateWeekRuns(i, totalWeeks, intensity, baseDistanceMultiplier, weeklyVolumeKm, easyPace, tempoPace, intervalPace),
        });
    }

    setState(() {
      _plan = newPlan;
      _isGenerating = false;
      _selectedIndex = 2;
    });
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("?’» ë¡œì»¬ ?Œëœ ?ì„± ?„ë£Œ (VDOT: ${targetVDOT.toStringAsFixed(1)})"), backgroundColor: Colors.orange)
      );
    }
  }
  
  // ?”ì¼ ëª?ë³€??(English -> Korean)
  String _translateDay(String dayEn) {
    const map = {
      'Mon': '??, 'Tue': '??, 'Wed': '??, 
      'Thu': 'ëª?, 'Fri': 'ê¸?, 'Sat': '??, 'Sun': '??
    };
    return map[dayEn] ?? dayEn;
  }
  
  // ?“Š ì£¼ì°¨ë³?ê°•ë„ ê³„ì‚° (?¼ë¦¬?´ë‹¤?´ì œ?´ì…˜)
  double _calculateWeekIntensity(int week, int totalWeeks) {
    // 3ì£?ì¦ê? + 1ì£??Œë³µ ?¬ì´??
    int cycle = (week - 1) % 4;
    double baseIntensity = 0.6 + (week / totalWeeks) * 0.3; // ?ì§„??ì¦ê?
    
    if (cycle == 3) return baseIntensity * 0.7; // ?Œë³µ ì£?
    return baseIntensity + (cycle * 0.1); // ?ì§„??ì¦ê?
  }
  
  String _getWeekFocus(int week, int totalWeeks) {
    double progress = week / totalWeeks;
    if (progress < 0.3) return "ê¸°ì´ˆ ì²´ë ¥ ë°?? ì—°??;
    if (progress < 0.6) return "ì§€êµ¬ë ¥ ?¥ìƒ";
    if (progress < 0.85) return "?¤í”¼??ë°??œí¬";
    return "ëª©í‘œ ?¬ì„± ë°??Œì´?¼ë§";
  }
  
  // VDOT ê¸°ë°˜ ?˜ì´??ê³„ì‚°
  double _getPaceFromVDOT(double vdot, String type) {
    // Jack Daniels' formula ê¸°ë°˜ ê·¼ì‚¬ì¹?
    double basePace = 0;
    
    switch(type) {
      case 'easy':
        basePace = 65 / vdot; // E pace (ë¶?km)
        break;
      case 'tempo':
        basePace = 55 / vdot; // T pace
        break;
      case 'interval':
        basePace = 48 / vdot; // I pace
        break;
      default:
        basePace = 60 / vdot;
    }
    
    return basePace;
  }
  
  // ì£¼ì°¨ë³??ˆë ¨ ?ì„± (ê°œì„ : ?¬ìš©???…ë ¥ ë°˜ì˜)
  List<Map<String, dynamic>> _generateWeekRuns(int week, int totalWeeks, double intensity, 
                                                  double levelMultiplier, double weeklyVolumeKm,
                                                  double easyPace, double tempoPace, double intervalPace) {
    List<Map<String, dynamic>> runs = [];
    
    // ì§„í–‰?„ì— ?°ë¥¸ ê±°ë¦¬ ì¦ê? (1ì£¼ì°¨ ??ë§ˆì?ë§?ì£¼ì°¨ë¡?ê°ˆìˆ˜ë¡?
    double progression = week / totalWeeks;
    
    // ê¸°ë³¸ ê±°ë¦¬ (?ˆë²¨ê³?ì£¼ê°„ ?ˆë ¨??ë°˜ì˜)
    double baseEasyDist = (2.0 + weeklyVolumeKm * 0.05) * levelMultiplier;
    double baseTempoDist = (3.0 + weeklyVolumeKm * 0.07) * levelMultiplier;
    double baseLSDDist = (4.0 + weeklyVolumeKm * 0.1) * levelMultiplier;
    
    // ?ƒ ?”ìš”?? ?´ì???
    runs.add({
      "day": "??,
      "type": "?´ì???,
      "dist": double.parse((baseEasyDist + (progression * baseEasyDist * 0.5)).toStringAsFixed(1)),
      "targetPace": easyPace,
      "desc": "?¸ì•ˆ???˜ì´?¤ë¡œ (${_formatPace(easyPace)})",
      "completed": false,
    });
    
    if (week % 4 == 0) {
      // ?“‰ ?Œë³µ ì£?(4ì£¼ë§ˆ??
      runs.add({
        "day": "ëª?,
        "type": "?Œë³µ??,
        "dist": double.parse((baseEasyDist * 0.7).toStringAsFixed(1)),
        "targetPace": easyPace * 1.15,
        "desc": "?„ì£¼ ê°€ë³ê²Œ (${_formatPace(easyPace * 1.15)})",
        "completed": false,
      });
    } else {
      // ?’ª ?¼ë°˜ ì£?- ?¸í„°ë²??ëŠ” ?œí¬
      runs.add({
        "day": "ëª?,
        "type": week % 2 == 0 ? "?œí¬?? : "?¸í„°ë²?,
        "dist": double.parse((baseTempoDist + (intensity * baseTempoDist * 0.3)).toStringAsFixed(1)),
        "targetPace": week % 2 == 0 ? tempoPace : intervalPace,
        "desc": week % 2 == 0 
          ? "ì§€??ê°€?¥í•œ ë¹ ë¥¸ ?˜ì´??(${_formatPace(tempoPace)})"
          : "3ë¶?ì§ˆì£¼ + 2ë¶??Œë³µ ë°˜ë³µ (${_formatPace(intervalPace)})",
        "completed": false,
      });
    }
    
    // ?ƒ?â™‚ï¸?? ìš”?? LSD (?¥ê±°ë¦? - ì£¼ì°¨ ì§„í–‰???°ë¼ ì¦ê?
    runs.add({
      "day": "??,
      "type": "LSD (?¥ê±°ë¦?",
      "dist": double.parse((baseLSDDist + (progression * baseLSDDist * 0.8)).toStringAsFixed(1)),
      "targetPace": easyPace * 1.1,
      "desc": "ì²œì²œ???¤ë˜ ?¬ë¦¬ê¸?(${_formatPace(easyPace * 1.1)})",
      "completed": false,
    });
    
    return runs;
  }
  
  String _formatPace(double pace) {
    int min = pace.toInt();
    int sec = ((pace - min) * 60).toInt();
    return "$min'${sec.toString().padLeft(2, '0')}\"";
  }

  // --- 2. ?¬ë‹ ?˜ì´ì§€ (AI ë³´ì´??ì½”ì¹­ ?ìš©) ---
  bool _isRunning = false;
  String _gpsStatus = "GPS ?€ê¸?ì¤?..";
  double _distKm = 0.0;
  String _pace = "-'--\"";
  Timer? _timer;
  int _seconds = 0;
  StreamSubscription<Position>? _positionStream;

  Widget _buildRunPage() {
    String timeStr = "${(_seconds~/60).toString().padLeft(2,'0')}:${(_seconds%60).toString().padLeft(2,'0')}";
    
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF1A2A3A), Color(0xFF0F0F1E)],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
             // ?íƒœ ?ìŠ¤??- ?¤ì˜¨ ?¤í???
             Text(
               _isRunning ? "RUNNING" : "READY", 
               style: TextStyle(
                 fontSize: 28, 
                 fontWeight: FontWeight.w900,
                 color: const Color(0xFF00FFF0),
                 letterSpacing: 4,
                 shadows: [
                   Shadow(color: const Color(0xFF00FFF0).withOpacity(0.6), blurRadius: 15),
                   Shadow(color: const Color(0xFF00FFF0).withOpacity(0.3), blurRadius: 30),
                 ],
               )
             ),
             const SizedBox(height: 40),
             
             // ?¤ì˜¨ ?í˜• ?€?´ë¨¸
             Container(
               width: 240,
               height: 240,
               decoration: BoxDecoration(
                 shape: BoxShape.circle,
                 border: Border.all(
                   color: _isRunning ? const Color(0xFF00FFF0) : const Color(0xFF00FFF0).withOpacity(0.3),
                   width: 6,
                 ),
                 boxShadow: _isRunning ? [
                   BoxShadow(
                     color: const Color(0xFF00FFF0).withOpacity(0.5),
                     blurRadius: 30,
                     spreadRadius: 5,
                   ),
                   BoxShadow(
                     color: const Color(0xFF00FFF0).withOpacity(0.3),
                     blurRadius: 50,
                     spreadRadius: 10,
                   ),
                 ] : [
                   BoxShadow(
                     color: const Color(0xFF00FFF0).withOpacity(0.2),
                     blurRadius: 20,
                     spreadRadius: 2,
                   ),
                 ],
               ),
               alignment: Alignment.center,
               child: Text(
                 timeStr,
                 style: TextStyle(
                   fontSize: 62,
                   fontFamily: 'monospace',
                   fontWeight: FontWeight.w900,
                   color: Colors.white,
                   shadows: [
                     Shadow(color: const Color(0xFF00FFF0).withOpacity(0.3), blurRadius: 10),
                   ],
                 ),
               ),
             ),
             
             const SizedBox(height: 50),
             
             // ?µê³„ ?•ë³´ - ?¤ì˜¨ ?¤í???
             Row(
               mainAxisAlignment: MainAxisAlignment.spaceEvenly,
               children: [
                 _buildNeonStat("ê±°ë¦¬", "${_distKm.toStringAsFixed(2)}", "km"),
                 _buildNeonStat("?˜ì´??, _pace, "/km"),
               ],
             ),
             
             const SizedBox(height: 15),
             Text(
               _gpsStatus,
               style: const TextStyle(fontSize: 11, color: Colors.white30, letterSpacing: 0.5),
             ),
             
             const SizedBox(height: 50),
             
             // ì»¨íŠ¸ë¡?ë²„íŠ¼ - ?¤ì˜¨ ?í˜• ë²„íŠ¼
             Row(
               mainAxisAlignment: MainAxisAlignment.center,
               children: [
                 // ?¤ë””??ON/OFF ë²„íŠ¼
                 Container(
                   width: 50,
                   height: 50,
                   decoration: BoxDecoration(
                     shape: BoxShape.circle,
                     border: Border.all(
                       color: _isVoiceOn ? const Color(0xFF00FFF0).withOpacity(0.6) : Colors.white24,
                       width: 2,
                     ),
                     color: _isVoiceOn 
                       ? const Color(0xFF00FFF0).withOpacity(0.15)
                       : Colors.white.withOpacity(0.05),
                   ),
                   child: IconButton(
                     icon: Icon(_isVoiceOn ? Icons.volume_up : Icons.volume_off),
                     color: _isVoiceOn ? const Color(0xFF00FFF0) : Colors.white38,
                     iconSize: 24,
                     padding: EdgeInsets.zero,
                     onPressed: () {
                       setState(() {
                         _isVoiceOn = !_isVoiceOn;
                       });
                       _tts.speak(_isVoiceOn ? "?¤ë””??ì½”ì¹­??ì¼?‹ˆ??" : "?¤ë””??ì½”ì¹­???•ë‹ˆ??");
                     },
                   ),
                 ),
                 const SizedBox(width: 30),
                 
                 // ?¬ìƒ/?•ì? ë²„íŠ¼ - ?¤ì˜¨ ê¸€ë¡œìš°
                 GestureDetector(
                   onTap: _toggleRun,
                   child: Container(
                     width: 90,
                     height: 90,
                     decoration: BoxDecoration(
                       color: _isRunning 
                         ? const Color(0xFFFF3366)
                         : const Color(0xFF00FFF0),
                       shape: BoxShape.circle,
                       boxShadow: [
                         BoxShadow(
                           color: _isRunning 
                             ? const Color(0xFFFF3366).withOpacity(0.5)
                             : const Color(0xFF00FFF0).withOpacity(0.6),
                           blurRadius: 25,
                           spreadRadius: 3,
                         ),
                       ],
                     ),
                     child: Icon(
                       _isRunning ? Icons.pause : Icons.play_arrow,
                       size: 45,
                       color: const Color(0xFF0F0F1E),
                     ),
                   ),
                 ),
                 
                 const SizedBox(width: 30),
                 // ?€ì¹?„ ?„í•œ ë¹?ê³µê°„
                 const SizedBox(width: 50, height: 50),
               ],
             )
          ],
        ),
      ),
    );
  }
  
  // ?¤ì˜¨ ?¤í????µê³„ ?œì‹œ
  Widget _buildNeonStat(String label, String value, String unit) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              label == "ê±°ë¦¬" ? Icons.straighten : Icons.speed,
              color: const Color(0xFF00FFF0).withOpacity(0.6),
              size: 16,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white38,
                fontSize: 12,
                fontWeight: FontWeight.w500,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        RichText(
          text: TextSpan(
            children: [
              TextSpan(
                text: value,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  fontFamily: 'monospace',
                ),
              ),
              TextSpan(
                text: " $unit",
                style: const TextStyle(
                  color: Colors.white38,
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _toggleRun() async {
    if (_isRunning) {
      // ë©ˆì¶¤ -> ?€???•ì¸
      bool? confirm = await showDialog(
        context: context, 
        builder: (ctx) => AlertDialog(
          title: const Text("?¬ë‹ ì¢…ë£Œ"),
          content: const Text("ê¸°ë¡???€?¥í•˜ê³??ë‚´?œê² ?µë‹ˆê¹?"),
          actions: [
             TextButton(onPressed: ()=>Navigator.pop(ctx, false), child: const Text("ì·¨ì†Œ")),
             TextButton(onPressed: ()=>Navigator.pop(ctx, true), child: const Text("ì¢…ë£Œ")),
          ],
        )
      );
      
      if (confirm == true) {
          _timer?.cancel();
          _positionStream?.cancel();
          
          // ?€??ì¤?ë¡œë”© ?œì‹œ
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (ctx) => const Center(child: CircularProgressIndicator()),
          );
          
          await _uploadRunData();
          
          if (mounted) {
             Navigator.pop(context); // ë¡œë”© ?«ê¸°
          }

          setState(() => _isRunning = false);
      }
    } else {
      // ?œì‘
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
             if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("GPS ê¶Œí•œ???„ìš”?©ë‹ˆ??")));
             return;
        }
      }
      
      setState(() {
        _isRunning = true;
        _seconds = 0;
        _distKm = 0.0;
        _gpsStatus = "GPS ?˜ì‹  ì¤?..";
      });
      
      if (_isVoiceOn) _tts.speak("?¬ë‹???œì‘?©ë‹ˆ?? 1ë¶„ë§ˆ???˜ì´?¤ë? ?Œë ¤?œë¦´ê²Œìš”.");

      _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        setState(() => _seconds++);
        
        // ?? 1ë¶?60ì´?ë§ˆë‹¤ AI ì½”ì¹­ ?¤í–‰
        if (_seconds > 0 && _seconds % 60 == 0 && _isVoiceOn) {
            _runAiCoaching();
        }
      });
      
      // ?¥ìƒ??GPS ?¤ì •
      LocationSettings locationSettings;
      if (Platform.isAndroid) {
        locationSettings = AndroidSettings(
            accuracy: LocationAccuracy.bestForNavigation,
            distanceFilter: 2, // 2ë¯¸í„°ë§ˆë‹¤ ê°±ì‹  (???ì£¼ ë°›ì•„??
            forceLocationManager: true,
            intervalDuration: const Duration(milliseconds: 1000), // 1ì´ˆë§ˆ??ê°•ì œ ê°±ì‹  ?œë„
        );
      } else if (Platform.isIOS) {
        locationSettings = AppleSettings(
            accuracy: LocationAccuracy.bestForNavigation,
            activityType: ActivityType.fitness,
            distanceFilter: 2,
            pauseLocationUpdatesAutomatically: false,
            showBackgroundLocationIndicator: true,
        );
      } else {
        locationSettings = const LocationSettings(
            accuracy: LocationAccuracy.bestForNavigation,
            distanceFilter: 2,
        );
      }

      Position? lastPos;
      _positionStream = Geolocator.getPositionStream(locationSettings: locationSettings).listen((Position? position) {
          if (position != null) {
              // ?•í™•?„ê? ?˜ìœ ? í˜¸(?¤ì°¨ 30m ?´ìƒ)??ë¬´ì‹œ (?¤ë‚´ ??????ë°©ì?)
              if (position.accuracy > 30.0) {
                 // accuracyê°€ ?ˆì¢‹?¼ë©´ ë¬´ì‹œ?˜ë˜, UI?ë§Œ ?œì‹œ?´ì¤„ ???ˆìŒ
                 setState(() => _gpsStatus = "GPS ? í˜¸ ?½í•¨: Â±${position.accuracy.toInt()}m");
                 return;
              }

              if (lastPos != null) {
                  double d = Geolocator.distanceBetween(lastPos!.latitude, lastPos!.longitude, position.latitude, position.longitude) / 1000.0;
                  
                  // ?ˆë¬´ ë¯¸ì„¸???€ì§ì„(?¸ì´ì¦??€ ë¬´ì‹œ?˜ë˜, ë¹ ë¥¸ ê±¸ìŒ(ì´ˆì† 1m=0.001km) ?´ìƒ?€ ?¡ì•„????
                  // 1ì´?ê°„ê²© ê°±ì‹ ?´ë©´ 2m/s = 7.2km/h. 
                  // 0.002km = 2m. 
                  // ?€??ê°??œê°„?´ë™ 100m) ?„í„°ë§?
                  if (d > 0.002 && d < 0.1) { 
                      setState(() {
                          _distKm += d;
                          if (_distKm > 0) {
                              double paceVal = (_seconds / 60) / _distKm;
                              int pm = paceVal.toInt();
                              // ?˜ì´?¤ê? ë¹„ì •?ì ?¼ë¡œ ?¬ë©´(ë©ˆì¶¤ ?? ì²˜ë¦¬
                              if (pm < 30) { 
                                int ps = ((paceVal - pm) * 60).toInt();
                                _pace = "$pm'${ps.toString().padLeft(2,'0')}\"";
                              }
                          }
                      });
                  }
              }
              // ?íƒœ ?…ë°?´íŠ¸
              setState(() {
                 _gpsStatus = "GPS: Â±${position.accuracy.toInt()}m";
              });
              lastPos = position;
          }
      });
    }
  }
  
  // ?™ï¸?AI ë³´ì´??ì½”ì¹­ ?¨ìˆ˜
  Future<void> _runAiCoaching() async {
      // 1. ?¨ìˆœ ?•ë³´ ?Œë¦¼ (ì¦‰ì‹œ ?¤í–‰)
      String baseMsg = "${(_seconds ~/ 60)}ë¶?ê²½ê³¼. ?„ì¬ ?˜ì´??$_pace ?…ë‹ˆ??";
      await _tts.speak(baseMsg);
      
      // 2. Gemini?ê²Œ ì¡°ì–¸ ?”ì²­ (ë¹„ë™ê¸?
      // ?ˆë¬´ ?ì£¼ ?¸ì¶œ?˜ë©´ ?ˆë˜ë¯€ë¡?2ë¶?ê°„ê²© ?¹ì? ?„ìš”???¸ì¶œ ??ì¡°ì • ê°€?¥í•˜?? ?”ì²­?€ë¡?1ë¶„ë§ˆ???¸ì¶œ.
      try {
          String type = _currentRun?['type'] ?? "?ìœ  ?¬ë¦¬ê¸?;
          String prompt = "?¬ë„ˆê°€ $type ì¤‘ì…?ˆë‹¤. 1ë¶„ê°„ ?¬ë ¸ê³??„ì¬ ?˜ì´?¤ëŠ” $_pace ?…ë‹ˆ?? ì§§ê²Œ ??ë¬¸ì¥?¼ë¡œ ê²©ë ¤???ë„ ì¡°ì–¸?´ì¤˜. (ë°˜ë§ ê¸ˆì?, ì½”ì¹˜ ?¤ìœ¼ë¡?";
          
          final content = [Content.text(prompt)];
          final response = await _geminiModel.generateContent(content);
          
          if (response.text != null) {
              await Future.delayed(const Duration(seconds: 4)); // ??ë©”ì‹œì§€ ?ë‚˜ê¸?ê¸°ë‹¤ë¦?(?€??
              await _tts.speak(response.text!);
          }
      } catch (e) {
          print("AI Error: $e");
      }
  }

  Future<void> _uploadRunData() async {
      try {
          final data = {
             'date': DateTime.now().toIso8601String(),
             'distance_km': double.parse(_distKm.toStringAsFixed(2)),
             'duration_sec': _seconds,
             'pace': _pace,
             'user_id': 'user_android'
          };
          await Supabase.instance.client.from('run_logs').insert(data);
          
          // ?“Š ?ì‘???Œê³ ë¦¬ì¦˜: ?¬ë‹ ?„ë£Œ ??VDOT ?¬ê³„??ë°??Œëœ ì¡°ì •
          await _adjustTrainingPlan(_distKm, _seconds / 60.0);
      } catch (e) {
          // Supabase ?Œì´ë¸”ì´ ?†ì–´??ë¡œì»¬ ?°ì´?°ëŠ” ? ì???
          print("INFO: Supabase sync skipped - $e");
          // ë¡œì»¬ ?ì‘???Œê³ ë¦¬ì¦˜?€ ê³„ì† ?¤í–‰
          try {
            await _adjustTrainingPlan(_distKm, _seconds / 60.0);
          } catch (e2) {
            print("WARN: Plan adjustment failed - $e2");
          }
      }
      
      // ???„ì¬ ?ˆë ¨???Œëœ?ì„œ ?„ë£Œë¡??œì‹œ
      if (_currentRun != null) {
        setState(() {
          _currentRun!['completed'] = true;
          _currentRun!['actualDist'] = _distKm;
          _currentRun!['actualTime'] = _seconds;
        });
      }
      
      // ??ƒ ?±ê³µ ë©”ì‹œì§€ ?œì‹œ (Supabase ?™ê¸°???¤íŒ¨?´ë„ ë¡œì»¬ ?°ì´?°ëŠ” ? íš¨)
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _currentRun != null 
                ? "??ê¸°ë¡ ?€???„ë£Œ! ?Œëœ ?…ë°?´íŠ¸??
                : "??ê¸°ë¡ ?€???„ë£Œ!"
            ), 
            backgroundColor: Colors.teal
          )
        );
      }
  }
  
  // ?”„ ?ì‘???Œê³ ë¦¬ì¦˜: ?ˆë ¨ ?Œëœ ?ë™ ì¡°ì •
  Future<void> _adjustTrainingPlan(double distKm, double timeMin) async {
    if (_plan.isEmpty || distKm < 1.0) return;
    
    // 1. ?„ì¬ ?¬ë‹ ê¸°ë°˜ VDOT ê³„ì‚°
    double newVDOT = _calculateVDOT(distKm, timeMin);
    double oldVDOT = _trainingProgress['currentVDOT'] ?? 0.0;
    
    // 2. VDOT ë³€?”ìœ¨ ?•ì¸
    double vdotChange = ((newVDOT - oldVDOT) / oldVDOT) * 100;
    
    print("?“Š VDOT ë³€?? $oldVDOT -> $newVDOT (${vdotChange.toStringAsFixed(1)}%)");
    
    // 3. ?„ì¬ ?ˆë ¨ ?„ë£Œ ì²˜ë¦¬
    if (_currentRun != null) {
      _trainingProgress['completedRuns'].add({
        'date': DateTime.now().toIso8601String(),
        'distance': distKm,
        'time': timeMin,
        'vdot': newVDOT,
      });
      
      // ?„ì¬ ì£¼ì°¨???´ë‹¹ ?ˆë ¨???„ë£Œë¡??œì‹œ
      for (var week in _plan) {
        for (var run in week['runs']) {
          if (run['type'] == _currentRun!['type'] && run['day'] == _currentRun!['day']) {
            run['completed'] = true;
          }
        }
      }
    }
    
    // 4. ì£¼ê°„ ?„ë£Œ??ê³„ì‚°
    int completedCount = (_trainingProgress['completedRuns'] as List).length;
    int expectedRuns = _plan.isNotEmpty ? _plan[0]['runs'].length : 3;
    _trainingProgress['weeklyCompletionRate'] = completedCount > 0 ? (completedCount % expectedRuns) / expectedRuns : 0.0;
    
    // 5. ?˜ì´?¤ê? ?¬ê²Œ ê°œì„ ?˜ì—ˆ?¤ë©´ (5% ?´ìƒ) -> ?Œëœ ?œì´???í–¥
    if (vdotChange > 5.0 && completedCount >= 3) {
      _trainingProgress['currentVDOT'] = newVDOT;
      await _regeneratePlanWithNewVDOT(newVDOT);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("?‰ ?¤ë ¥???¥ìƒ?˜ì—ˆ?µë‹ˆ?? ?Œëœ???ë™ ì¡°ì •?˜ì—ˆ?µë‹ˆ?? (VDOT: ${newVDOT.toStringAsFixed(1)})"),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 4),
          )
        );
      }
    }
    // 6. ?˜ì´?¤ê? ?¬ê²Œ ?€?˜ë˜?ˆê±°??(10% ?´ìƒ) ?ˆë ¨??ë§ì´ ë¹¼ë¨¹?ˆë‹¤ë©?-> ?Œëœ ?œì´???˜í–¥
    else if (vdotChange < -10.0 || _trainingProgress['missedDays'] > 5) {
      _trainingProgress['currentVDOT'] = newVDOT * 0.95; // ?½ê°„ ??¶°???ˆì „?˜ê²Œ
      await _regeneratePlanWithNewVDOT(_trainingProgress['currentVDOT']);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text("? ï¸ ì»¨ë””?˜ì— ë§ì¶° ?Œëœ???¬ì¡°?•ë˜?ˆìŠµ?ˆë‹¤. ë¬´ë¦¬?˜ì? ë§ˆì„¸??"),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 4),
          )
        );
      }
    }
    // 7. ?•ìƒ ë²”ìœ„ ?´ë¼ë©??ì§„???…ë°?´íŠ¸
    else {
      // ?´ë™?‰ê· ?¼ë¡œ ë¶€?œëŸ½ê²??…ë°?´íŠ¸
      _trainingProgress['currentVDOT'] = (oldVDOT * 0.8) + (newVDOT * 0.2);
    }
  }
  
  // ?”„ ?ˆë¡œ??VDOT ê¸°ë°˜?¼ë¡œ ?¨ì? ?Œëœ ?¬ìƒ??
  Future<void> _regeneratePlanWithNewVDOT(double newVDOT) async {
    if (_plan.isEmpty) return;
    
    int currentWeek = 1;
    // ?„ë£Œ??ì£¼ì°¨ ì°¾ê¸°
    for (int i = 0; i < _plan.length; i++) {
      if (_plan[i]['completed'] == true) {
        currentWeek = i + 2; // ?¤ìŒ ì£¼ë???
      }
    }
    
    // ?¨ì? ì£¼ì°¨ë§??¬ìƒ??
    int totalWeeks = _plan.length;
    for (int i = currentWeek - 1; i < totalWeeks; i++) {
      int week = i + 1;
      double intensity = _calculateWeekIntensity(week, totalWeeks);
      
      double easyPace = _getPaceFromVDOT(newVDOT, 'easy');
      double tempoPace = _getPaceFromVDOT(newVDOT, 'tempo');
      double intervalPace = _getPaceFromVDOT(newVDOT, 'interval');
      
      setState(() {
        _plan[i]['targetVDOT'] = newVDOT;
        _plan[i]['runs'] = _generateWeekRuns(week, totalWeeks, intensity, easyPace, tempoPace, intervalPace);
      });
    }
  }
  
  // ?“… ?„ë½???ˆë ¨ ê°ì? (ë°±ê·¸?¼ìš´?œì—??ì£¼ê¸°?ìœ¼ë¡??¸ì¶œ ê°€??
  void _checkMissedTrainings() {
    if (_plan.isEmpty) return;
    
    DateTime now = DateTime.now();
    int missedCount = 0;
    
    // ?´ë²ˆ ì£??ˆë ¨ ?•ì¸
    var thisWeek = _plan.first;
    for (var run in thisWeek['runs']) {
      if (run['completed'] != true) {
        // ?”ì¼ ?•ì¸ ë¡œì§ (ê°„ë‹¨??êµ¬í˜„)
        String day = run['day'];
        int targetWeekday = _getDayOfWeek(day);
        
        // ?„ì¬ ?”ì¼ë³´ë‹¤ ê³¼ê±°?¼ë©´ ?„ë½
        if (now.weekday > targetWeekday) {
          missedCount++;
        }
      }
    }
    
    if (missedCount > 0) {
      _trainingProgress['missedDays'] = (_trainingProgress['missedDays'] ?? 0) + missedCount;
      print("? ï¸ ?„ë½???ˆë ¨: $missedCountê°?);
    }
  }
  
  int _getDayOfWeek(String day) {
    switch(day) {
      case '??: return 1;
      case '??: return 2;
      case '??: return 3;
      case 'ëª?: return 4;
      case 'ê¸?: return 5;
      case '??: return 6;
      case '??: return 7;
      default: return 1;
    }
  }

  // --- 3. ?Œëœ ?˜ì´ì§€ ---
  Widget _buildPlanPage() {
    if (_plan.isEmpty) {
      return Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF1A1A2E), Color(0xFF0F0F1E)],
          ),
        ),
        child: const Center(
          child: Text(
            "?¤ì • ??—???Œëœ???ì„±?˜ì„¸??",
            style: TextStyle(color: Colors.white30, fontSize: 14),
          ),
        ),
      );
    }
    
    // 1ì£¼ì°¨ vs ?˜ë¨¸ì§€
    var thisWeek = _plan.first;
    var futureWeeks = _plan.length > 1 ? _plan.sublist(1) : [];

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF1A1A2E), Color(0xFF0F0F1E)],
        ),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              "THIS WEEK",
              style: TextStyle(
                color: const Color(0xFF00FFF0),
                fontWeight: FontWeight.w900,
                letterSpacing: 2,
                fontSize: 16,
                shadows: [
                  Shadow(color: const Color(0xFF00FFF0).withOpacity(0.5), blurRadius: 10),
                ],
              ),
            ),
            const SizedBox(height: 15),
            
            // ?“Š ì£¼ê°„ ì§„í–‰ ?í™© - ?¤ì˜¨ ?¤í???
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1A3A3A).withOpacity(0.3),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF00FFF0).withOpacity(0.3), width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF00FFF0).withOpacity(0.1),
                    blurRadius: 10,
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("ì£¼ê°„ ?„ë£Œ??, style: TextStyle(color: Colors.white54, fontSize: 13)),
                      Text(
                        _getWeeklyCompletionText(),
                        style: const TextStyle(
                          color: Color(0xFF00FFF0),
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: _getWeeklyCompletionRate(),
                  backgroundColor: Colors.white.withOpacity(0.1),
                  valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF00FFF0)),
                  minHeight: 6,
                  borderRadius: BorderRadius.circular(3),
                ),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.trending_up, color: const Color(0xFF00FFF0).withOpacity(0.7), size: 15),
                        const SizedBox(width: 5),
                        Text(
                          "?„ì¬ VDOT: ${(_trainingProgress['currentVDOT'] ?? 0.0).toStringAsFixed(1)}",
                          style: const TextStyle(color: Colors.white54, fontSize: 11),
                        ),
                      ],
                    ),
                    if (_trainingProgress['missedDays'] > 0)
                      Row(
                        children: [
                          const Icon(Icons.warning_amber, color: Color(0xFFFF6B35), size: 15),
                          const SizedBox(width: 5),
                          Text(
                            "?„ë½: ${_trainingProgress['missedDays']}??,
                            style: const TextStyle(color: Color(0xFFFF6B35), fontSize: 11),
                          ),
                        ],
                      ),
                  ],
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 15),
          
          // 1ì£¼ì°¨??ê¸°ë³¸?ìœ¼ë¡??¼ì³??ë³´ì—¬ì¤?
          _buildWeekCard(thisWeek, initiallyExpanded: true),
          
          const SizedBox(height: 20),
          
          // AI ì½”ì¹­ ë©˜íŠ¸ - ?ì‘???Œê³ ë¦¬ì¦˜ ?¤ëª… ê°•í™”
          Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: Colors.teal.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.teal.withOpacity(0.3))
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.auto_awesome, color: Colors.tealAccent, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        "?¤– ?ì‘??AI ?¸ë ˆ?´ë‹ ?œìŠ¤??,
                        style: TextStyle(color: Colors.teal.shade100, fontSize: 14, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  "??Jack Daniels VDOT ?Œê³ ë¦¬ì¦˜ ê¸°ë°˜\n"
                  "???ˆë ¨ ?„ë½ ???ë™ ?œì´??ì¡°ì •\n"
                  "???˜ì´??ê°œì„  ê°ì??˜ì—¬ ?Œëœ ?í–¥\n"
                  "???¤ì‹œê°?ì²´ë ¥ ì§€??ì¶”ì  ë°?ì¡°ì •",
                  style: TextStyle(color: Colors.teal.shade100.withOpacity(0.8), fontSize: 12, height: 1.5),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 30),
          
          // ?˜ë¨¸ì§€ ?ˆë ¨ (?‘ê¸°/?¼ì¹˜ê¸?
          if (futureWeeks.isNotEmpty)
            Card(
              color: Colors.white12, // ë°°ê²½ ?½ê°„ ?¤ë¥´ê²?
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              child: ExpansionTile(
                iconColor: Colors.white70,
                collapsedIconColor: Colors.white54,
                title: Text(
                  "?´í›„ ?ˆë ¨ ?¼ì • (${futureWeeks.length}ì£?", 
                  style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.bold)
                ),
                children: futureWeeks.map((w) => _buildWeekCard(w)).toList(),
              ),
            ),
            
           const SizedBox(height: 50),
        ],
      ),
      ),
    );
  }

  Widget _buildWeekCard(Map<String, dynamic> week, {bool initiallyExpanded = false}) {
    return Card(
      color: Colors.white10,
      margin: const EdgeInsets.only(bottom: 10),
      child: ExpansionTile(
        initiallyExpanded: initiallyExpanded,
        title: Text("${week['week']}ì£¼ì°¨ : ${week['focus']}", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        children: (week['runs'] as List).map<Widget>((r) => ListTile(
           leading: CircleAvatar(
             backgroundColor: r['completed'] == true ? Colors.green.withOpacity(0.3) : Colors.teal.withOpacity(0.3), 
             child: r['completed'] == true 
               ? const Icon(Icons.check, color: Colors.greenAccent, size: 18)
               : Text(r['day'][0], style: const TextStyle(color: Colors.white))
           ),
           title: Row(
             children: [
               Text(r['type'], style: const TextStyle(color: Colors.white)),
               const SizedBox(width: 8),
               if (r['completed'] == true)
                 const Icon(Icons.check_circle, color: Colors.greenAccent, size: 16),
             ],
           ),
           subtitle: Text(r['desc'], style: const TextStyle(color: Colors.white70)),
           trailing: Text("${r['dist']} km", style: const TextStyle(color: Colors.tealAccent)),
           onTap: () {
             // ëª©í‘œ ?¤ì •
             setState(() {
                 _currentRun = r;
                 _selectedIndex = 1; // Go to Run tab
             });
             ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("?¤ëŠ˜??ëª©í‘œ: ${r['type']} ?¤ì •??")));
           },
           onLongPress: () {
             // ê¸¸ê²Œ ?ŒëŸ¬??ì§ì ‘ ê¸°ë¡ ?…ë ¥
             _showManualInputDialog(r);
           },
        )).toList(),
      ),
    );
  }
  
  // ?“Š ì£¼ê°„ ?„ë£Œ??ê³„ì‚°
  double _getWeeklyCompletionRate() {
    if (_plan.isEmpty) return 0.0;
    
    var thisWeek = _plan.first;
    List runs = thisWeek['runs'] ?? [];
    if (runs.isEmpty) return 0.0;
    
    int completed = runs.where((r) => r['completed'] == true).length;
    return completed / runs.length;
  }
  
  String _getWeeklyCompletionText() {
    if (_plan.isEmpty) return "0/0";
    
    var thisWeek = _plan.first;
    List runs = thisWeek['runs'] ?? [];
    int completed = runs.where((r) => r['completed'] == true).length;
    return "$completed/${runs.length}";
  }
  // ?“ ì§ì ‘ ê¸°ë¡ ?…ë ¥ ?¤ì´?¼ë¡œê·?
  void _showManualInputDialog(Map<String, dynamic> run) {
    final distController = TextEditingController();
    final timeController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A2A3A),
        title: Row(
          children: [
            const Icon(Icons.edit, color: Color(0xFF00FFF0), size: 20),
            const SizedBox(width: 8),
            Text(
              '${run['type']} ê¸°ë¡ ?…ë ¥',
              style: const TextStyle(color: Colors.white, fontSize: 18),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: distController,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'ê±°ë¦¬ (km)',
                labelStyle: const TextStyle(color: Color(0xFF00FFF0)),
                hintText: '?? 5.2',
                hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
                enabledBorder: const UnderlineInputBorder(
                  borderSide: BorderSide(color: Color(0xFF00FFF0)),
                ),
                focusedBorder: const UnderlineInputBorder(
                  borderSide: BorderSide(color: Color(0xFF00FFF0), width: 2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: timeController,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: '?œê°„ (ë¶?',
                labelStyle: const TextStyle(color: Color(0xFF00FFF0)),
                hintText: '?? 30',
                hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
                enabledBorder: const UnderlineInputBorder(
                  borderSide: BorderSide(color: Color(0xFF00FFF0)),
                ),
                focusedBorder: const UnderlineInputBorder(
                  borderSide: BorderSide(color: Color(0xFF00FFF0), width: 2),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('ì·¨ì†Œ', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () {
              final dist = double.tryParse(distController.text);
              final time = int.tryParse(timeController.text);
              
              if (dist != null && time != null) {
                setState(() {
                  run['completed'] = true;
                  run['actualDist'] = dist;
                  run['actualTime'] = time * 60;
                });
                
                Navigator.pop(context);
                
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('??${run['type']} ê¸°ë¡ ?€?¥ë¨ (${dist}km, ${time}ë¶?'),
                    backgroundColor: Colors.green,
                  ),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('???¬ë°”ë¥??«ìë¥??…ë ¥?´ì£¼?¸ìš”'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00FFF0),
              foregroundColor: const Color(0xFF0F0F1E),
            ),
            child: const Text('?€??, style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

}    / /   ? w¼  Şùø¬È  rnÕ¬	É  ? …°0È  ? |1 Å? ğÁÉ9m?  
     v o i d   _ s h o w M a n u a l I n p u t D i a l o g ( M a p < S t r i n g ,   d y n a m i c >   r u n )   {  
         f i n a l   d i s t C o n t r o l l e r   =   T e x t E d i t i n g C o n t r o l l e r ( ) ;  
         f i n a l   t i m e C o n t r o l l e r   =   T e x t E d i t i n g C o n t r o l l e r ( ) ;  
          
         s h o w D i a l o g (  
             c o n t e x t :   c o n t e x t ,  
             b u i l d e r :   ( c o n t e x t )   = >   A l e r t D i a l o g (  
                 b a c k g r o u n d C o l o r :   c o n s t   C o l o r ( 0 x F F 1 A 2 A 3 A ) ,  
                 t i t l e :   R o w (  
                     c h i l d r e n :   [  
                         c o n s t   I c o n ( I c o n s . e d i t ,   c o l o r :   C o l o r ( 0 x F F 0 0 F F F 0 ) ,   s i z e :   2 0 ) ,  
                         c o n s t   S i z e d B o x ( w i d t h :   8 ) ,  
                         T e x t (  
                             ' $ { r u n [ ' t y p e ' ] }   rnÕ¬	É  ? …°0È' ,  
                             s t y l e :   c o n s t   T e x t S t y l e ( c o l o r :   C o l o r s . w h i t e ,   f o n t S i z e :   1 8 ) ,  
                         ) ,  
                     ] ,  
                 ) ,  
                 c o n t e n t :   C o l u m n (  
                     m a i n A x i s S i z e :   M a i n A x i s S i z e . m i n ,  
                     c h i l d r e n :   [  
                         T e x t F i e l d (  
                             c o n t r o l l e r :   d i s t C o n t r o l l e r ,  
                             k e y b o a r d T y p e :   T e x t I n p u t T y p e . n u m b e r ,  
                             s t y l e :   c o n s t   T e x t S t y l e ( c o l o r :   C o l o r s . w h i t e ) ,  
                             d e c o r a t i o n :   I n p u t D e c o r a t i o n (  
                                 l a b e l T e x t :   ' ÄZÕ¬%  ( k m ) ' ,  
                                 l a b e l S t y l e :   c o n s t   T e x t S t y l e ( c o l o r :   C o l o r ( 0 x F F 0 0 F F F 0 ) ) ,  
                                 h i n t T e x t :   ' ? ?   5 . 2 ' ,  
                                 h i n t S t y l e :   T e x t S t y l e ( c o l o r :   C o l o r s . w h i t e . w i t h O p a c i t y ( 0 . 3 ) ) ,  
                                 e n a b l e d B o r d e r :   c o n s t   U n d e r l i n e I n p u t B o r d e r (  
                                     b o r d e r S i d e :   B o r d e r S i d e ( c o l o r :   C o l o r ( 0 x F F 0 0 F F F 0 ) ) ,  
                                 ) ,  
                                 f o c u s e d B o r d e r :   c o n s t   U n d e r l i n e I n p u t B o r d e r (  
                                     b o r d e r S i d e :   B o r d e r S i d e ( c o l o r :   C o l o r ( 0 x F F 0 0 F F F 0 ) ,   w i d t h :   2 ) ,  
                                 ) ,  
                             ) ,  
                         ) ,  
                         c o n s t   S i z e d B o x ( h e i g h t :   1 6 ) ,  
                         T e x t F i e l d (  
                             c o n t r o l l e r :   t i m e C o n t r o l l e r ,  
                             k e y b o a r d T y p e :   T e x t I n p u t T y p e . n u m b e r ,  
                             s t y l e :   c o n s t   T e x t S t y l e ( c o l o r :   C o l o r s . w h i t e ) ,  
                             d e c o r a t i o n :   I n p u t D e c o r a t i o n (  
                                 l a b e l T e x t :   ' ? “ÄÙÎ  ( z? ' ,  
                                 l a b e l S t y l e :   c o n s t   T e x t S t y l e ( c o l o r :   C o l o r ( 0 x F F 0 0 F F F 0 ) ) ,  
                                 h i n t T e x t :   ' ? ?   3 0 ' ,  
                                 h i n t S t y l e :   T e x t S t y l e ( c o l o r :   C o l o r s . w h i t e . w i t h O p a c i t y ( 0 . 3 ) ) ,  
                                 e n a b l e d B o r d e r :   c o n s t   U n d e r l i n e I n p u t B o r d e r (  
                                     b o r d e r S i d e :   B o r d e r S i d e ( c o l o r :   C o l o r ( 0 x F F 0 0 F F F 0 ) ) ,  
                                 ) ,  
                                 f o c u s e d B o r d e r :   c o n s t   U n d e r l i n e I n p u t B o r d e r (  
                                     b o r d e r S i d e :   B o r d e r S i d e ( c o l o r :   C o l o r ( 0 x F F 0 0 F F F 0 ) ,   w i d t h :   2 ) ,  
                                 ) ,  
                             ) ,  
                         ) ,  
                     ] ,  
                 ) ,  
                 a c t i o n s :   [  
                     T e x t B u t t o n (  
                         o n P r e s s e d :   ( )   = >   N a v i g a t o r . p o p ( c o n t e x t ) ,  
                         c h i l d :   c o n s t   T e x t ( ' Íue$ü°' ,   s t y l e :   T e x t S t y l e ( c o l o r :   C o l o r s . w h i t e 5 4 ) ) ,  
                     ) ,  
                     E l e v a t e d B u t t o n (  
                         o n P r e s s e d :   ( )   {  
                             f i n a l   d i s t   =   d o u b l e . t r y P a r s e ( d i s t C o n t r o l l e r . t e x t ) ;  
                             f i n a l   t i m e   =   i n t . t r y P a r s e ( t i m e C o n t r o l l e r . t e x t ) ;  
                              
                             i f   ( d i s t   ! =   n u l l   & &   t i m e   ! =   n u l l )   {  
                                 s e t S t a t e ( ( )   {  
                                     r u n [ ' c o m p l e t e d ' ]   =   t r u e ;  
                                     r u n [ ' a c t u a l D i s t ' ]   =   d i s t ;  
                                     r u n [ ' a c t u a l T i m e ' ]   =   t i m e   *   6 0 ;  
                                 } ) ;  
                                  
                                 N a v i g a t o r . p o p ( c o n t e x t ) ;  
                                  
                                 S c a f f o l d M e s s e n g e r . o f ( c o n t e x t ) . s h o w S n a c k B a r (  
                                     S n a c k B a r (  
                                         c o n t e n t :   T e x t ( ' ? ? $ { r u n [ ' t y p e ' ] }   rnÕ¬	É  ? € ? »Ö¹  ( $ { d i s t } k m ,   $ { t i m e } z? ' ) ,  
                                         b a c k g r o u n d C o l o r :   C o l o r s . g r e e n ,  
                                     ) ,  
                                 ) ;  
                             }   e l s e   {  
                                 S c a f f o l d M e s s e n g e r . o f ( c o n t e x t ) . s h o w S n a c k B a r (  
                                     c o n s t   S n a c k B a r (  
                                         c o n t e n t :   T e x t ( ' ? ? ? IîÎ\t? ? ì0Æ\t? ? …°0È? ³ÿ? „º‚Â' ) ,  
                                         b a c k g r o u n d C o l o r :   C o l o r s . r e d ,  
                                     ) ,  
                                 ) ;  
                             }  
                         } ,  
                         s t y l e :   E l e v a t e d B u t t o n . s t y l e F r o m (  
                             b a c k g r o u n d C o l o r :   c o n s t   C o l o r ( 0 x F F 0 0 F F F 0 ) ,  
                             f o r e g r o u n d C o l o r :   c o n s t   C o l o r ( 0 x F F 0 F 0 F 1 E ) ,  
                         ) ,  
                         c h i l d :   c o n s t   T e x t ( ' ? € ? ? ,   s t y l e :   T e x t S t y l e ( f o n t W e i g h t :   F o n t W e i g h t . b o l d ) ) ,  
                     ) ,  
                 ] ,  
             ) ,  
         ) ;  
     }  
  
 }  
 