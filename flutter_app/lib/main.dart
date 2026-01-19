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

// Gemini API Key (蹂댁븞???꾪빐 ?ㅼ젣 諛고룷 ?쒖뿉???④꺼????
const String _geminiKey = 'AIzaSyBtEtujomeYnJUc5ZlEi7CteLmapaEZ4MY';

// Server API URL (怨쇳븰???뚭퀬由ъ쬁 ?쒕쾭)
const String _serverUrl = 'https://solo-runner-api.onrender.com'; // Render.com 諛고룷 ??URL

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Supabase 珥덇린??
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
  
  // ?렞 ???紐⑺몴 ?ㅼ젙
  final TextEditingController _goalDistanceController = TextEditingController(text: "10");
  final TextEditingController _goalTimeController = TextEditingController(text: "60");
  
  String _level = "beginner";
  bool _useSelfGoal = false; // ???紐⑺몴 ?ъ슜 ?щ?
  
  // State
  List<Map<String, dynamic>> _plan = [];
  bool _isGenerating = false;
  Map<String, dynamic>? _currentRun; // ?꾩옱 ?좏깮??紐⑺몴 ?덈젴
  
  // ?뱤 ?곸쓳???뚭퀬由ъ쬁 ?곗씠??
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
  bool _isVoiceOn = true; // ?ㅻ뵒??肄붿묶 ON/OFF ?곹깭

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _initTTS();
    _geminiModel = GenerativeModel(model: 'gemini-pro', apiKey: _geminiKey);
    
    // ???쒖옉 ???꾨씫???덈젴 ?뺤씤
    Future.delayed(const Duration(seconds: 2), () {
      _checkMissedTrainings();
    });
  }

  void _initTTS() async {
    _tts = FlutterTts();
    await _tts.setLanguage("ko-KR");
    
    // ?먯뿰?ㅻ윭???⑥꽦 ?뚯꽦 ?ㅼ젙
    await _tts.setSpeechRate(0.5); // ?곷떦???띾룄
    await _tts.setPitch(0.95); // ?쎄컙 ??? ??(?먯뿰?ㅻ윭? ?좎?)
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
          NavigationDestination(icon: Icon(Icons.person_outline), label: '?꾨줈??),
          NavigationDestination(icon: Icon(Icons.directions_run), label: '?щ떇'),
          NavigationDestination(icon: Icon(Icons.calendar_month), label: '?뚮옖'),
        ],
      ),
    );
  }

  // --- 1. ?ㅼ젙 ?섏씠吏 ---
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
            // 硫붿씤 濡쒓퀬 - ?ㅼ삩 湲濡쒖슦 ?④낵
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
            const Text("?섎쭔??AI ?щ━湲?肄붿튂", 
              style: TextStyle(fontSize: 13, color: Colors.white38, letterSpacing: 0.5), 
              textAlign: TextAlign.center
            ),
            const SizedBox(height: 30),
            
            // ?낅젰 ?꾨뱶 - ?ㅼ삩 ?ㅽ???
            Row(children: [
              Expanded(child: _buildNeonInput(Icons.straighten, "??, "cm", _heightController)),
              const SizedBox(width: 10),
              Expanded(child: _buildNeonInput(Icons.monitor_weight, "紐몃Т寃?, "kg", _weightController)),
            ]),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: _buildNeonInput(Icons.access_time, "二쇨컙紐⑺몴", "遺?, _weeklyController)),
              const SizedBox(width: 10),
              Expanded(child: _buildNeonInput(Icons.timer, "10km湲곕줉", "遺?, _recordController)),
            ]),
            const SizedBox(height: 20),
            
            // ?렞 ???紐⑺몴 ?ㅼ젙 - ?ㅼ삩 諛뺤뒪 (?좉? 湲곕뒫 異붽?)
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
                        const Text("???紐⑺몴 ?ㅼ젙", 
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
                      Expanded(child: _buildNeonInput(Icons.straighten, "紐⑺몴嫄곕━", "km", _goalDistanceController)),
                      const SizedBox(width: 10),
                      Expanded(child: _buildNeonInput(Icons.timer, "紐⑺몴?쒓컙", "遺?, _goalTimeController)),
                    ]),
                    const SizedBox(height: 10),
                    Center(
                      child: Text(
                        _goalDistanceController.text.isNotEmpty && _goalTimeController.text.isNotEmpty
                          ? "紐⑺몴 ?섏씠?? ${_calculateTargetPace()}"
                          : "",
                        style: const TextStyle(color: Colors.white38, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 20),
            
            // 媛뺣룄 ?좏깮 - AI ?뚮옖 紐⑤뱶 (???紐⑺몴 ?좏깮 ??鍮꾪솢?깊솕)
            Opacity(
              opacity: _useSelfGoal ? 0.3 : 1.0,
              child: const Text("AI ?뚮옖 媛뺣룄", 
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
                    Expanded(child: _buildLevelBox("beginner", Icons.directions_walk, "?낅Ц??, "12二?)),
                    const SizedBox(width: 10),
                    Expanded(child: _buildLevelBox("intermediate", Icons.directions_run, "以묎툒??, "24二?)),
                    const SizedBox(width: 10),
                    Expanded(child: _buildLevelBox("advanced", Icons.bar_chart, "?곴툒??, "48二?)),
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
              _isGenerating ? "?앹꽦 以?.." : "AI 紐⑺몴移??ㅼ젙 ?앹꽦",
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

  // ?렓 ?ㅼ삩 ?ㅽ????낅젰 ?꾨뱶 (?먮낯 ?대?吏? ?묎컳??
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
  
  // ?렓 ?덈꺼 ?좏깮 諛뺤뒪 (?뺢킅 ?꾩씠肄??ㅽ???
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

  // ?렞 紐⑺몴 ?섏씠??怨꾩궛
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

  // ?뱤 VDOT 怨꾩궛 (Jack Daniels' Running Formula)
  double _calculateVDOT(double distanceKm, double timeMin) {
    // VDOT = (-4.60 + 0.182258 * v + 0.000104 * v^2) / (0.8 + 0.1894393 * e^(-0.012778 * t) + 0.2989558 * e^(-0.1932605 * t))
    // 媛꾩냼?붾맂 洹쇱궗???ъ슜
    double velocity = (distanceKm * 1000) / (timeMin * 60); // m/s
    double percent02Max = 0.8 + 0.1894393 * exp(-0.012778 * timeMin) + 0.2989558 * exp(-0.1932605 * timeMin);
    double vo2 = -4.60 + 0.182258 * velocity + 0.000104 * velocity * velocity;
    return vo2 / percent02Max;
  }

  void _generatePlan() async {
    setState(() => _isGenerating = true);
    
    // ?ъ슜???낅젰 ?뚯떛
    double height = double.tryParse(_heightController.text) ?? 175;
    double weight = double.tryParse(_weightController.text) ?? 70;
    double weeklyMin = double.tryParse(_weeklyController.text) ?? 120;
    double record10k = double.tryParse(_recordController.text) ?? 60;
    
    // ?렞 VDOT 怨꾩궛
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
    
    // ?뙋 ?쒕쾭 API ?몄텧 (怨쇳븰???뚭퀬由ъ쬁 ?ъ슜)
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
        
        // ?쒕쾭 ?묐떟??Flutter ?뺤떇?쇰줈 蹂??
        List<Map<String, dynamic>> serverPlan = [];
        for (var week in data['plan']) {
          // ?쒕쾭 ?뺤떇??Flutter ?뺤떇?쇰줈 蹂??
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
              content: Text("?렞 怨쇳븰 湲곕컲 ?뚮옖 ?앹꽦 ?꾨즺! (ACSM 媛?대뱶?쇱씤)"), 
              backgroundColor: Colors.teal
            )
          );
        }
        return;
      }
    } catch (e) {
      print('INFO: Server unavailable, using local algorithm - $e');
    }
    
    // ?뮲 ?쒕쾭 ?ㅽ뙣 ??濡쒖뺄 ?뚭퀬由ъ쬁 ?대갚
    await _generatePlanLocal(targetVDOT, weeklyMin, height, weight);
  }
  
  // 濡쒖뺄 ?뚮옖 ?앹꽦 (?쒕쾭 ?ㅽ뙣 ???대갚)
  Future<void> _generatePlanLocal(double targetVDOT, double weeklyMin, double height, double weight) async {
    // ?덈꺼蹂??ㅼ젙
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
        SnackBar(content: Text("?뮲 濡쒖뺄 ?뚮옖 ?앹꽦 ?꾨즺 (VDOT: ${targetVDOT.toStringAsFixed(1)})"), backgroundColor: Colors.orange)
      );
    }
  }
  
  // ?붿씪 紐?蹂??(English -> Korean)
  String _translateDay(String dayEn) {
    const map = {
      'Mon': '??, 'Tue': '??, 'Wed': '??, 
      'Thu': '紐?, 'Fri': '湲?, 'Sat': '??, 'Sun': '??
    };
    return map[dayEn] ?? dayEn;
  }
  
  // ?뱤 二쇱감蹂?媛뺣룄 怨꾩궛 (?쇰━?대떎?댁젣?댁뀡)
  double _calculateWeekIntensity(int week, int totalWeeks) {
    // 3二?利앷? + 1二??뚮났 ?ъ씠??
    int cycle = (week - 1) % 4;
    double baseIntensity = 0.6 + (week / totalWeeks) * 0.3; // ?먯쭊??利앷?
    
    if (cycle == 3) return baseIntensity * 0.7; // ?뚮났 二?
    return baseIntensity + (cycle * 0.1); // ?먯쭊??利앷?
  }
  
  String _getWeekFocus(int week, int totalWeeks) {
    double progress = week / totalWeeks;
    if (progress < 0.3) return "湲곗큹 泥대젰 諛??좎뿰??;
    if (progress < 0.6) return "吏援щ젰 ?μ긽";
    if (progress < 0.85) return "?ㅽ뵾??諛??쒗룷";
    return "紐⑺몴 ?ъ꽦 諛??뚯씠?쇰쭅";
  }
  
  // VDOT 湲곕컲 ?섏씠??怨꾩궛
  double _getPaceFromVDOT(double vdot, String type) {
    // Jack Daniels' formula 湲곕컲 洹쇱궗移?
    double basePace = 0;
    
    switch(type) {
      case 'easy':
        basePace = 65 / vdot; // E pace (遺?km)
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
  
  // 二쇱감蹂??덈젴 ?앹꽦 (媛쒖꽑: ?ъ슜???낅젰 諛섏쁺)
  List<Map<String, dynamic>> _generateWeekRuns(int week, int totalWeeks, double intensity, 
                                                  double levelMultiplier, double weeklyVolumeKm,
                                                  double easyPace, double tempoPace, double intervalPace) {
    List<Map<String, dynamic>> runs = [];
    
    // 吏꾪뻾?꾩뿉 ?곕Ⅸ 嫄곕━ 利앷? (1二쇱감 ??留덉?留?二쇱감濡?媛덉닔濡?
    double progression = week / totalWeeks;
    
    // 湲곕낯 嫄곕━ (?덈꺼怨?二쇨컙 ?덈젴??諛섏쁺)
    double baseEasyDist = (2.0 + weeklyVolumeKm * 0.05) * levelMultiplier;
    double baseTempoDist = (3.0 + weeklyVolumeKm * 0.07) * levelMultiplier;
    double baseLSDDist = (4.0 + weeklyVolumeKm * 0.1) * levelMultiplier;
    
    // ?룂 ?붿슂?? ?댁???
    runs.add({
      "day": "??,
      "type": "?댁???,
      "dist": double.parse((baseEasyDist + (progression * baseEasyDist * 0.5)).toStringAsFixed(1)),
      "targetPace": easyPace,
      "desc": "?몄븞???섏씠?ㅻ줈 (${_formatPace(easyPace)})",
      "completed": false,
    });
    
    if (week % 4 == 0) {
      // ?뱣 ?뚮났 二?(4二쇰쭏??
      runs.add({
        "day": "紐?,
        "type": "?뚮났??,
        "dist": double.parse((baseEasyDist * 0.7).toStringAsFixed(1)),
        "targetPace": easyPace * 1.15,
        "desc": "?꾩＜ 媛蹂띻쾶 (${_formatPace(easyPace * 1.15)})",
        "completed": false,
      });
    } else {
      // ?뮞 ?쇰컲 二?- ?명꽣踰??먮뒗 ?쒗룷
      runs.add({
        "day": "紐?,
        "type": week % 2 == 0 ? "?쒗룷?? : "?명꽣踰?,
        "dist": double.parse((baseTempoDist + (intensity * baseTempoDist * 0.3)).toStringAsFixed(1)),
        "targetPace": week % 2 == 0 ? tempoPace : intervalPace,
        "desc": week % 2 == 0 
          ? "吏??媛?ν븳 鍮좊Ⅸ ?섏씠??(${_formatPace(tempoPace)})"
          : "3遺?吏덉＜ + 2遺??뚮났 諛섎났 (${_formatPace(intervalPace)})",
        "completed": false,
      });
    }
    
    // ?룂?띯셽截??좎슂?? LSD (?κ굅由? - 二쇱감 吏꾪뻾???곕씪 利앷?
    runs.add({
      "day": "??,
      "type": "LSD (?κ굅由?",
      "dist": double.parse((baseLSDDist + (progression * baseLSDDist * 0.8)).toStringAsFixed(1)),
      "targetPace": easyPace * 1.1,
      "desc": "泥쒖쿇???ㅻ옒 ?щ━湲?(${_formatPace(easyPace * 1.1)})",
      "completed": false,
    });
    
    return runs;
  }
  
  String _formatPace(double pace) {
    int min = pace.toInt();
    int sec = ((pace - min) * 60).toInt();
    return "$min'${sec.toString().padLeft(2, '0')}\"";
  }

  // --- 2. ?щ떇 ?섏씠吏 (AI 蹂댁씠??肄붿묶 ?곸슜) ---
  bool _isRunning = false;
  String _gpsStatus = "GPS ?湲?以?..";
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
             // ?곹깭 ?띿뒪??- ?ㅼ삩 ?ㅽ???
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
             
             // ?ㅼ삩 ?먰삎 ??대㉧
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
             
             // ?듦퀎 ?뺣낫 - ?ㅼ삩 ?ㅽ???
             Row(
               mainAxisAlignment: MainAxisAlignment.spaceEvenly,
               children: [
                 _buildNeonStat("嫄곕━", "${_distKm.toStringAsFixed(2)}", "km"),
                 _buildNeonStat("?섏씠??, _pace, "/km"),
               ],
             ),
             
             const SizedBox(height: 15),
             Text(
               _gpsStatus,
               style: const TextStyle(fontSize: 11, color: Colors.white30, letterSpacing: 0.5),
             ),
             
             const SizedBox(height: 50),
             
             // 而⑦듃濡?踰꾪듉 - ?ㅼ삩 ?먰삎 踰꾪듉
             Row(
               mainAxisAlignment: MainAxisAlignment.center,
               children: [
                 // ?ㅻ뵒??ON/OFF 踰꾪듉
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
                       _tts.speak(_isVoiceOn ? "?ㅻ뵒??肄붿묶??耳?땲??" : "?ㅻ뵒??肄붿묶???뺣땲??");
                     },
                   ),
                 ),
                 const SizedBox(width: 30),
                 
                 // ?ъ깮/?뺤? 踰꾪듉 - ?ㅼ삩 湲濡쒖슦
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
                 // ?移?쓣 ?꾪븳 鍮?怨듦컙
                 const SizedBox(width: 50, height: 50),
               ],
             )
          ],
        ),
      ),
    );
  }
  
  // ?ㅼ삩 ?ㅽ????듦퀎 ?쒖떆
  Widget _buildNeonStat(String label, String value, String unit) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              label == "嫄곕━" ? Icons.straighten : Icons.speed,
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
      // 硫덉땄 -> ????뺤씤
      bool? confirm = await showDialog(
        context: context, 
        builder: (ctx) => AlertDialog(
          title: const Text("?щ떇 醫낅즺"),
          content: const Text("湲곕줉????ν븯怨??앸궡?쒓쿋?듬땲源?"),
          actions: [
             TextButton(onPressed: ()=>Navigator.pop(ctx, false), child: const Text("痍⑥냼")),
             TextButton(onPressed: ()=>Navigator.pop(ctx, true), child: const Text("醫낅즺")),
          ],
        )
      );
      
      if (confirm == true) {
          _timer?.cancel();
          _positionStream?.cancel();
          
          // ???以?濡쒕뵫 ?쒖떆
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (ctx) => const Center(child: CircularProgressIndicator()),
          );
          
          await _uploadRunData();
          
          if (mounted) {
             Navigator.pop(context); // 濡쒕뵫 ?リ린
          }

          setState(() => _isRunning = false);
      }
    } else {
      // ?쒖옉
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
             if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("GPS 沅뚰븳???꾩슂?⑸땲??")));
             return;
        }
      }
      
      setState(() {
        _isRunning = true;
        _seconds = 0;
        _distKm = 0.0;
        _gpsStatus = "GPS ?섏떊 以?..";
      });
      
      if (_isVoiceOn) _tts.speak("?щ떇???쒖옉?⑸땲?? 1遺꾨쭏???섏씠?ㅻ? ?뚮젮?쒕┫寃뚯슂.");

      _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        setState(() => _seconds++);
        
        // ?? 1遺?60珥?留덈떎 AI 肄붿묶 ?ㅽ뻾
        if (_seconds > 0 && _seconds % 60 == 0 && _isVoiceOn) {
            _runAiCoaching();
        }
      });
      
      // ?μ긽??GPS ?ㅼ젙
      LocationSettings locationSettings;
      if (Platform.isAndroid) {
        locationSettings = AndroidSettings(
            accuracy: LocationAccuracy.bestForNavigation,
            distanceFilter: 2, // 2誘명꽣留덈떎 媛깆떊 (???먯＜ 諛쏆븘??
            forceLocationManager: true,
            intervalDuration: const Duration(milliseconds: 1000), // 1珥덈쭏??媛뺤젣 媛깆떊 ?쒕룄
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
              // ?뺥솗?꾧? ?섏걶 ?좏샇(?ㅼ감 30m ?댁긽)??臾댁떆 (?ㅻ궡 ??????諛⑹?)
              if (position.accuracy > 30.0) {
                 // accuracy媛 ?덉쥕?쇰㈃ 臾댁떆?섎릺, UI?먮쭔 ?쒖떆?댁쨪 ???덉쓬
                 setState(() => _gpsStatus = "GPS ?좏샇 ?쏀븿: 짹${position.accuracy.toInt()}m");
                 return;
              }

              if (lastPos != null) {
                  double d = Geolocator.distanceBetween(lastPos!.latitude, lastPos!.longitude, position.latitude, position.longitude) / 1000.0;
                  
                  // ?덈Т 誘몄꽭???吏곸엫(?몄씠利?? 臾댁떆?섎릺, 鍮좊Ⅸ 嫄몄쓬(珥덉냽 1m=0.001km) ?댁긽? ?≪븘????
                  // 1珥?媛꾧꺽 媛깆떊?대㈃ 2m/s = 7.2km/h. 
                  // 0.002km = 2m. 
                  // ???媛??쒓컙?대룞 100m) ?꾪꽣留?
                  if (d > 0.002 && d < 0.1) { 
                      setState(() {
                          _distKm += d;
                          if (_distKm > 0) {
                              double paceVal = (_seconds / 60) / _distKm;
                              int pm = paceVal.toInt();
                              // ?섏씠?ㅺ? 鍮꾩젙?곸쟻?쇰줈 ?щ㈃(硫덉땄 ?? 泥섎━
                              if (pm < 30) { 
                                int ps = ((paceVal - pm) * 60).toInt();
                                _pace = "$pm'${ps.toString().padLeft(2,'0')}\"";
                              }
                          }
                      });
                  }
              }
              // ?곹깭 ?낅뜲?댄듃
              setState(() {
                 _gpsStatus = "GPS: 짹${position.accuracy.toInt()}m";
              });
              lastPos = position;
          }
      });
    }
  }
  
  // ?럺截?AI 蹂댁씠??肄붿묶 ?⑥닔
  Future<void> _runAiCoaching() async {
      // 1. ?⑥닚 ?뺣낫 ?뚮┝ (利됱떆 ?ㅽ뻾)
      String baseMsg = "${(_seconds ~/ 60)}遺?寃쎄낵. ?꾩옱 ?섏씠??$_pace ?낅땲??";
      await _tts.speak(baseMsg);
      
      // 2. Gemini?먭쾶 議곗뼵 ?붿껌 (鍮꾨룞湲?
      // ?덈Т ?먯＜ ?몄텧?섎㈃ ?덈릺誘濡?2遺?媛꾧꺽 ?뱀? ?꾩슂???몄텧 ??議곗젙 媛?ν븯?? ?붿껌?濡?1遺꾨쭏???몄텧.
      try {
          String type = _currentRun?['type'] ?? "?먯쑀 ?щ━湲?;
          String prompt = "?щ꼫媛 $type 以묒엯?덈떎. 1遺꾧컙 ?щ졇怨??꾩옱 ?섏씠?ㅻ뒗 $_pace ?낅땲?? 吏㏐쾶 ??臾몄옣?쇰줈 寃⑸젮???띾룄 議곗뼵?댁쨾. (諛섎쭚 湲덉?, 肄붿튂 ?ㅼ쑝濡?";
          
          final content = [Content.text(prompt)];
          final response = await _geminiModel.generateContent(content);
          
          if (response.text != null) {
              await Future.delayed(const Duration(seconds: 4)); // ??硫붿떆吏 ?앸굹湲?湲곕떎由?(???
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
          
          // ?뱤 ?곸쓳???뚭퀬由ъ쬁: ?щ떇 ?꾨즺 ??VDOT ?ш퀎??諛??뚮옖 議곗젙
          await _adjustTrainingPlan(_distKm, _seconds / 60.0);
      } catch (e) {
          // Supabase ?뚯씠釉붿씠 ?놁뼱??濡쒖뺄 ?곗씠?곕뒗 ?좎???
          print("INFO: Supabase sync skipped - $e");
          // 濡쒖뺄 ?곸쓳???뚭퀬由ъ쬁? 怨꾩냽 ?ㅽ뻾
          try {
            await _adjustTrainingPlan(_distKm, _seconds / 60.0);
          } catch (e2) {
            print("WARN: Plan adjustment failed - $e2");
          }
      }
      
      // ???꾩옱 ?덈젴???뚮옖?먯꽌 ?꾨즺濡??쒖떆
      if (_currentRun != null) {
        setState(() {
          _currentRun!['completed'] = true;
          _currentRun!['actualDist'] = _distKm;
          _currentRun!['actualTime'] = _seconds;
        });
      }
      
      // ??긽 ?깃났 硫붿떆吏 ?쒖떆 (Supabase ?숆린???ㅽ뙣?대룄 濡쒖뺄 ?곗씠?곕뒗 ?좏슚)
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _currentRun != null 
                ? "??湲곕줉 ????꾨즺! ?뚮옖 ?낅뜲?댄듃??
                : "??湲곕줉 ????꾨즺!"
            ), 
            backgroundColor: Colors.teal
          )
        );
      }
  }
  
  // ?봽 ?곸쓳???뚭퀬由ъ쬁: ?덈젴 ?뚮옖 ?먮룞 議곗젙
  Future<void> _adjustTrainingPlan(double distKm, double timeMin) async {
    if (_plan.isEmpty || distKm < 1.0) return;
    
    // 1. ?꾩옱 ?щ떇 湲곕컲 VDOT 怨꾩궛
    double newVDOT = _calculateVDOT(distKm, timeMin);
    double oldVDOT = _trainingProgress['currentVDOT'] ?? 0.0;
    
    // 2. VDOT 蹂?붿쑉 ?뺤씤
    double vdotChange = ((newVDOT - oldVDOT) / oldVDOT) * 100;
    
    print("?뱤 VDOT 蹂?? $oldVDOT -> $newVDOT (${vdotChange.toStringAsFixed(1)}%)");
    
    // 3. ?꾩옱 ?덈젴 ?꾨즺 泥섎━
    if (_currentRun != null) {
      _trainingProgress['completedRuns'].add({
        'date': DateTime.now().toIso8601String(),
        'distance': distKm,
        'time': timeMin,
        'vdot': newVDOT,
      });
      
      // ?꾩옱 二쇱감???대떦 ?덈젴???꾨즺濡??쒖떆
      for (var week in _plan) {
        for (var run in week['runs']) {
          if (run['type'] == _currentRun!['type'] && run['day'] == _currentRun!['day']) {
            run['completed'] = true;
          }
        }
      }
    }
    
    // 4. 二쇨컙 ?꾨즺??怨꾩궛
    int completedCount = (_trainingProgress['completedRuns'] as List).length;
    int expectedRuns = _plan.isNotEmpty ? _plan[0]['runs'].length : 3;
    _trainingProgress['weeklyCompletionRate'] = completedCount > 0 ? (completedCount % expectedRuns) / expectedRuns : 0.0;
    
    // 5. ?섏씠?ㅺ? ?ш쾶 媛쒖꽑?섏뿀?ㅻ㈃ (5% ?댁긽) -> ?뚮옖 ?쒖씠???곹뼢
    if (vdotChange > 5.0 && completedCount >= 3) {
      _trainingProgress['currentVDOT'] = newVDOT;
      await _regeneratePlanWithNewVDOT(newVDOT);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("?럦 ?ㅻ젰???μ긽?섏뿀?듬땲?? ?뚮옖???먮룞 議곗젙?섏뿀?듬땲?? (VDOT: ${newVDOT.toStringAsFixed(1)})"),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 4),
          )
        );
      }
    }
    // 6. ?섏씠?ㅺ? ?ш쾶 ??섎릺?덇굅??(10% ?댁긽) ?덈젴??留롮씠 鍮쇰㉨?덈떎硫?-> ?뚮옖 ?쒖씠???섑뼢
    else if (vdotChange < -10.0 || _trainingProgress['missedDays'] > 5) {
      _trainingProgress['currentVDOT'] = newVDOT * 0.95; // ?쎄컙 ??떠???덉쟾?섍쾶
      await _regeneratePlanWithNewVDOT(_trainingProgress['currentVDOT']);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text("?좑툘 而⑤뵒?섏뿉 留욎떠 ?뚮옖???ъ“?뺣릺?덉뒿?덈떎. 臾대━?섏? 留덉꽭??"),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 4),
          )
        );
      }
    }
    // 7. ?뺤긽 踰붿쐞 ?대씪硫??먯쭊???낅뜲?댄듃
    else {
      // ?대룞?됯퇏?쇰줈 遺?쒕읇寃??낅뜲?댄듃
      _trainingProgress['currentVDOT'] = (oldVDOT * 0.8) + (newVDOT * 0.2);
    }
  }
  
  // ?봽 ?덈줈??VDOT 湲곕컲?쇰줈 ?⑥? ?뚮옖 ?ъ깮??
  Future<void> _regeneratePlanWithNewVDOT(double newVDOT) async {
    if (_plan.isEmpty) return;
    
    int currentWeek = 1;
    // ?꾨즺??二쇱감 李얘린
    for (int i = 0; i < _plan.length; i++) {
      if (_plan[i]['completed'] == true) {
        currentWeek = i + 2; // ?ㅼ쓬 二쇰???
      }
    }
    
    // ?⑥? 二쇱감留??ъ깮??
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
  
  // ?뱟 ?꾨씫???덈젴 媛먯? (諛깃렇?쇱슫?쒖뿉??二쇨린?곸쑝濡??몄텧 媛??
  void _checkMissedTrainings() {
    if (_plan.isEmpty) return;
    
    DateTime now = DateTime.now();
    int missedCount = 0;
    
    // ?대쾲 二??덈젴 ?뺤씤
    var thisWeek = _plan.first;
    for (var run in thisWeek['runs']) {
      if (run['completed'] != true) {
        // ?붿씪 ?뺤씤 濡쒖쭅 (媛꾨떒??援ы쁽)
        String day = run['day'];
        int targetWeekday = _getDayOfWeek(day);
        
        // ?꾩옱 ?붿씪蹂대떎 怨쇨굅?쇰㈃ ?꾨씫
        if (now.weekday > targetWeekday) {
          missedCount++;
        }
      }
    }
    
    if (missedCount > 0) {
      _trainingProgress['missedDays'] = (_trainingProgress['missedDays'] ?? 0) + missedCount;
      print("?좑툘 ?꾨씫???덈젴: $missedCount媛?);
    }
  }
  
  int _getDayOfWeek(String day) {
    switch(day) {
      case '??: return 1;
      case '??: return 2;
      case '??: return 3;
      case '紐?: return 4;
      case '湲?: return 5;
      case '??: return 6;
      case '??: return 7;
      default: return 1;
    }
  }

  // --- 3. ?뚮옖 ?섏씠吏 ---
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
            "?ㅼ젙 ??뿉???뚮옖???앹꽦?섏꽭??",
            style: TextStyle(color: Colors.white30, fontSize: 14),
          ),
        ),
      );
    }
    
    // 1二쇱감 vs ?섎㉧吏
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
            
            // ?뱤 二쇨컙 吏꾪뻾 ?곹솴 - ?ㅼ삩 ?ㅽ???
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
                      const Text("二쇨컙 ?꾨즺??, style: TextStyle(color: Colors.white54, fontSize: 13)),
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
                          "?꾩옱 VDOT: ${(_trainingProgress['currentVDOT'] ?? 0.0).toStringAsFixed(1)}",
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
                            "?꾨씫: ${_trainingProgress['missedDays']}??,
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
          
          // 1二쇱감??湲곕낯?곸쑝濡??쇱퀜??蹂댁뿬以?
          _buildWeekCard(thisWeek, initiallyExpanded: true),
          
          const SizedBox(height: 20),
          
          // AI 肄붿묶 硫섑듃 - ?곸쓳???뚭퀬由ъ쬁 ?ㅻ챸 媛뺥솕
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
                        "?쨼 ?곸쓳??AI ?몃젅?대떇 ?쒖뒪??,
                        style: TextStyle(color: Colors.teal.shade100, fontSize: 14, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  "??Jack Daniels VDOT ?뚭퀬由ъ쬁 湲곕컲\n"
                  "???덈젴 ?꾨씫 ???먮룞 ?쒖씠??議곗젙\n"
                  "???섏씠??媛쒖꽑 媛먯??섏뿬 ?뚮옖 ?곹뼢\n"
                  "???ㅼ떆媛?泥대젰 吏??異붿쟻 諛?議곗젙",
                  style: TextStyle(color: Colors.teal.shade100.withOpacity(0.8), fontSize: 12, height: 1.5),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 30),
          
          // ?섎㉧吏 ?덈젴 (?묎린/?쇱튂湲?
          if (futureWeeks.isNotEmpty)
            Card(
              color: Colors.white12, // 諛곌꼍 ?쎄컙 ?ㅻⅤ寃?
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              child: ExpansionTile(
                iconColor: Colors.white70,
                collapsedIconColor: Colors.white54,
                title: Text(
                  "?댄썑 ?덈젴 ?쇱젙 (${futureWeeks.length}二?", 
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
        title: Text("${week['week']}二쇱감 : ${week['focus']}", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
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
             // 紐⑺몴 ?ㅼ젙
             setState(() {
                 _currentRun = r;
                 _selectedIndex = 1; // Go to Run tab
             });
             ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("?ㅻ뒛??紐⑺몴: ${r['type']} ?ㅼ젙??")));
           },
           onLongPress: () {
             // 湲멸쾶 ?뚮윭??吏곸젒 湲곕줉 ?낅젰
             _showManualInputDialog(r);
           },
        )).toList(),
      ),
    );
  }
  
  // ?뱤 二쇨컙 ?꾨즺??怨꾩궛
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
  // ?뱷 吏곸젒 湲곕줉 ?낅젰 ?ㅼ씠?쇰줈洹?
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
              '${run['type']} 湲곕줉 ?낅젰',
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
                labelText: '嫄곕━ (km)',
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
                labelText: '?쒓컙 (遺?',
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
            child: const Text('痍⑥냼', style: TextStyle(color: Colors.white54)),
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
                    content: Text('??${run['type']} 湲곕줉 ??λ맖 (${dist}km, ${time}遺?'),
                    backgroundColor: Colors.green,
                  ),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('???щ컮瑜??レ옄瑜??낅젰?댁＜?몄슂'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00FFF0),
              foregroundColor: const Color(0xFF0F0F1E),
            ),
            child: const Text('???, style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

}    / /   ? w? 駟狽? rn酪	? ? 뀺0? ? |1 ? 彫?m?  
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
                             ' $ { r u n [ ' t y p e ' ] }   rn酪	? ? 뀺0? ,  
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
                                 l a b e l T e x t :   ' 훋酪%  ( k m ) ' ,  
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
                                 l a b e l T e x t :   ' ? 벮睦  ( z? ' ,  
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
                         c h i l d :   c o n s t   T e x t ( ' ?e$喚' ,   s t y l e :   T e x t S t y l e ( c o l o r :   C o l o r s . w h i t e 5 4 ) ) ,  
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
                                         c o n t e n t :   T e x t ( ' ? ? $ { r u n [ ' t y p e ' ] }   rn酪	? ?  ? ?岺  ( $ { d i s t } k m ,   $ { t i m e } z? ' ) ,  
                                         b a c k g r o u n d C o l o r :   C o l o r s . g r e e n ,  
                                     ) ,  
                                 ) ;  
                             }   e l s e   {  
                                 S c a f f o l d M e s s e n g e r . o f ( c o n t e x t ) . s h o w S n a c k B a r (  
                                     c o n s t   S n a c k B a r (  
                                         c o n t e n t :   T e x t ( ' ? ? ? I躇\t? ? ??t? ? 뀺0? ?? 꽯궰' ) ,  
                                         b a c k g r o u n d C o l o r :   C o l o r s . r e d ,  
                                     ) ,  
                                 ) ;  
                             }  
                         } ,  
                         s t y l e :   E l e v a t e d B u t t o n . s t y l e F r o m (  
                             b a c k g r o u n d C o l o r :   c o n s t   C o l o r ( 0 x F F 0 0 F F F 0 ) ,  
                             f o r e g r o u n d C o l o r :   c o n s t   C o l o r ( 0 x F F 0 F 0 F 1 E ) ,  
                         ) ,  
                         c h i l d :   c o n s t   T e x t ( ' ?  ? ? ,   s t y l e :   T e x t S t y l e ( f o n t W e i g h t :   F o n t W e i g h t . b o l d ) ) ,  
                     ) ,  
                 ] ,  
             ) ,  
         ) ;  
     }  
  
 }  