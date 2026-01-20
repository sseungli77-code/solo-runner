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
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';

// Gemini API Key (보안을 위해 실제 배포 시에는 숨겨야 함)
const String _geminiKey = 'AIzaSyBtEtujomeYnJUc5ZlEi7CteLmapaEZ4MY';
const String _serverUrl = 'https://solo-runner-api.onrender.com';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // 네이버 맵 초기화
  await NaverMapSdk.instance.initialize(
    clientId: '35sazlmvtf',
    onAuthFailed: (ex) => print("********* 네이버 맵 인증 실패: $ex *********"),
  );
  
  // Supabase 초기화
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
  
  // 🎯 셀프 목표 설정
  final TextEditingController _goalDistanceController = TextEditingController(text: "10");
  final TextEditingController _goalTimeController = TextEditingController(text: "60");
  
  String _level = "beginner";
  bool _useSelfGoal = false; // 셀프 목표 사용 여부
  
  // State
  List<Map<String, dynamic>> _plan = [];
  bool _isGenerating = false;
  Map<String, dynamic>? _currentRun; // 현재 선택된 목표 훈련
  
  // 📊 적응형 알고리즘 데이터
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
  bool _isVoiceOn = true; // 오디오 코칭 ON/OFF 상태

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _initTTS();
    _geminiModel = GenerativeModel(model: 'gemini-pro', apiKey: _geminiKey);
    _loadData(); // 📂 저장된 데이터 로드
  }

  // 💾 데이터 저장
  Future<void> _saveData() async {
    final prefs = await SharedPreferences.getInstance();
    
    // 1. 프로필 정보 저장
    await prefs.setString('level', _level);
    await prefs.setString('height', _heightController.text);
    await prefs.setString('weight', _weightController.text);
    await prefs.setString('weekly', _weeklyController.text);
    await prefs.setString('record', _recordController.text);
    await prefs.setBool('useSelfGoal', _useSelfGoal);
    await prefs.setString('goalDist', _goalDistanceController.text);
    await prefs.setString('goalTime', _goalTimeController.text);
    
    // 2. 플랜 데이터 저장 (JSON 변환)
    if (_plan.isNotEmpty) {
      String jsonPlan = jsonEncode(_plan);
      await prefs.setString('training_plan', jsonPlan);
    }
    
    // 3. 진행 상황 저장
    await prefs.setString('training_progress', jsonEncode(_trainingProgress));
    
    print("✅ 데이터가 로컬에 저장되었습니다.");
  }

  // 📂 데이터 불러오기
  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    
    setState(() {
      // 1. 프로필 로드
      _level = prefs.getString('level') ?? 'beginner';
      _heightController.text = prefs.getString('height') ?? '175';
      _weightController.text = prefs.getString('weight') ?? '70';
      _weeklyController.text = prefs.getString('weekly') ?? '120';
      _recordController.text = prefs.getString('record') ?? '60';
      _useSelfGoal = prefs.getBool('useSelfGoal') ?? false;
      _goalDistanceController.text = prefs.getString('goalDist') ?? '5';
      _goalTimeController.text = prefs.getString('goalTime') ?? '30';
      
      // 2. 플랜 로드
      String? jsonPlan = prefs.getString('training_plan');
      if (jsonPlan != null) {
        List<dynamic> decoded = jsonDecode(jsonPlan);
        _plan = decoded.cast<Map<String, dynamic>>();
      }
      
      // 3. 진행 상황 로드
      String? jsonProgress = prefs.getString('training_progress');
      if (jsonProgress != null) {
        _trainingProgress = jsonDecode(jsonProgress);
      }
    });
    print("📂 데이터를 불러왔습니다.");
  }
    
    // 앱 시작 시 누락된 훈련 확인
    Future.delayed(const Duration(seconds: 2), () {
      _checkMissedTrainings();
    });
  }

  void _initTTS() async {
    _tts = FlutterTts();
    await _tts.setLanguage("ko-KR");
    
    // 고급 남자 목소리 설정
    await _tts.setSpeechRate(0.45); // 약간 느리고 차분하게
    await _tts.setPitch(0.8); // 낮은 톤 (남성적)
    await _tts.setVolume(1.0); // 최대 볼륨
    
    // 안드로이드: Google TTS 남성 음성 시도
    try {
      // 사용 가능한 음성 목록에서 한국어 남성 음성 선택
      var voices = await _tts.getVoices;
      if (voices != null) {
        // "ko-kr-x-" 또는 "ko-KR-" 로 시작하는 남성 음성 찾기
        var maleVoice = voices.firstWhere(
          (voice) => (voice['locale'].toString().toLowerCase().contains('ko') && 
                     (voice['name'].toString().toLowerCase().contains('male') ||
                      voice['name'].toString().toLowerCase().contains('wavenet-c') ||
                      voice['name'].toString().toLowerCase().contains('wavenet-d'))),
          orElse: () => voices.first
        );
        await _tts.setVoice({"name": maleVoice['name'], "locale": maleVoice['locale']});
      }
    } catch (e) {
      print("INFO: Using default voice - $e");
    }
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
          NavigationDestination(icon: Icon(Icons.person_outline), label: '프로필'),
          NavigationDestination(icon: Icon(Icons.directions_run), label: '러닝'),
          NavigationDestination(icon: Icon(Icons.calendar_month), label: '플랜'),
        ],
      ),
    );
  }

  // --- 1. 설정 페이지 ---
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
            // 메인 로고 - 네온 글로우 효과
            Text("SOLO", 
              style: TextStyle(
                fontSize: 45, 
                fontWeight: FontWeight.w900,
                fontStyle: FontStyle.italic,
                color: const Color(0xFF00FFF0),
                letterSpacing: 3,
                shadows: [
                  Shadow(color: const Color(0xFF00FFF0).withOpacity(0.6), blurRadius: 20),
                  Shadow(color: const Color(0xFF00FFF0).withOpacity(0.3), blurRadius: 40),
                ],
              ),
              textAlign: TextAlign.center,
            ),
            Text("RUNNER", 
              style: TextStyle(
                fontSize: 45, 
                fontWeight: FontWeight.w900,
                fontStyle: FontStyle.italic,
                color: const Color(0xFF00FFF0),
                letterSpacing: 3,
                height: 0.85,
                shadows: [
                  Shadow(color: const Color(0xFF00FFF0).withOpacity(0.6), blurRadius: 20),
                  Shadow(color: const Color(0xFF00FFF0).withOpacity(0.3), blurRadius: 40),
                ],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text("나만의 AI 달리기 코치", 
              style: TextStyle(fontSize: 13, color: Colors.white38, letterSpacing: 0.5), 
              textAlign: TextAlign.center
            ),
            const SizedBox(height: 30),
            
            // 입력 필드 - 네온 스타일
            Row(children: [
              Expanded(child: _buildNeonInput(Icons.straighten, "키", "cm", _heightController)),
              const SizedBox(width: 10),
              Expanded(child: _buildNeonInput(Icons.monitor_weight, "몸무게", "kg", _weightController)),
            ]),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: _buildNeonInput(Icons.access_time, "주간목표", "분", _weeklyController)),
              const SizedBox(width: 10),
              Expanded(child: _buildNeonInput(Icons.timer, "10km기록", "분", _recordController)),
            ]),
            const SizedBox(height: 20),
            
            // 🎯 셀프 목표 설정 - 네온 박스 (토글 기능 추가)
            InkWell(
              onTap: () {
                setState(() {
                  _useSelfGoal = !_useSelfGoal;
                });
              },
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _useSelfGoal 
                    ? const Color(0xFF1A3A3A).withOpacity(0.6)
                    : const Color(0xFF1A3A3A).withOpacity(0.4),
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(
                    color: _useSelfGoal 
                      ? const Color(0xFF00FFF0).withOpacity(0.8)
                      : const Color(0xFF00FFF0).withOpacity(0.5), 
                    width: _useSelfGoal ? 2.5 : 2
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF00FFF0).withOpacity(_useSelfGoal ? 0.4 : 0.2),
                      blurRadius: _useSelfGoal ? 20 : 15,
                      spreadRadius: _useSelfGoal ? 2 : 1,
                    ),
                  ],
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
                        const Text("셀프 목표 설정", 
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
                      Expanded(child: _buildNeonInput(Icons.straighten, "목표거리", "km", _goalDistanceController)),
                      const SizedBox(width: 10),
                      Expanded(child: _buildNeonInput(Icons.timer, "목표시간", "분", _goalTimeController)),
                    ]),
                    const SizedBox(height: 10),
                    Center(
                      child: Text(
                        _goalDistanceController.text.isNotEmpty && _goalTimeController.text.isNotEmpty
                          ? "목표 페이스: ${_calculateTargetPace()}"
                          : "",
                        style: const TextStyle(color: Colors.white38, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 20),
            
            // 강도 선택 - AI 플랜 모드 (셀프 목표 선택 시 비활성화)
            Opacity(
              opacity: _useSelfGoal ? 0.3 : 1.0,
              child: const Text("AI 플랜 강도", 
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
                    Expanded(child: _buildLevelBox("beginner", Icons.directions_walk, "입문자", "12주")),
                    const SizedBox(width: 10),
                    Expanded(child: _buildLevelBox("intermediate", Icons.directions_run, "중급자", "24주")),
                    const SizedBox(width: 10),
                    Expanded(child: _buildLevelBox("advanced", Icons.bar_chart, "상급자", "48주")),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 25),
          ElevatedButton(
            onPressed: _isGenerating ? null : _generatePlan,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 18),
              backgroundColor: const Color(0xFF00FFF0),
              foregroundColor: const Color(0xFF0F0F1E),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              elevation: 0,
              shadowColor: const Color(0xFF00FFF0).withOpacity(0.5),
            ).copyWith(
              overlayColor: MaterialStateProperty.all(Colors.white.withOpacity(0.1)),
            ),
            child: Text(
              _isGenerating ? "생성 중..." : "AI 목표치 설정 생성",
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

  // 🎨 네온 스타일 입력 필드 (원본 이미지와 똑같이)
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
  
  // 🎨 레벨 선택 박스 (형광 아이콘 스타일)
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

  // 🎯 목표 페이스 계산
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

  // 📊 VDOT 계산 (Jack Daniels' Running Formula)
  double _calculateVDOT(double distanceKm, double timeMin) {
    // VDOT = (-4.60 + 0.182258 * v + 0.000104 * v^2) / (0.8 + 0.1894393 * e^(-0.012778 * t) + 0.2989558 * e^(-0.1932605 * t))
    // 간소화된 근사식 사용
    double velocity = (distanceKm * 1000) / (timeMin * 60); // m/s
    double percent02Max = 0.8 + 0.1894393 * exp(-0.012778 * timeMin) + 0.2989558 * exp(-0.1932605 * timeMin);
    double vo2 = -4.60 + 0.182258 * velocity + 0.000104 * velocity * velocity;
    return vo2 / percent02Max;
  }


  void _generatePlan() async {
    setState(() => _isGenerating = true);
    await Future.delayed(const Duration(milliseconds: 500));
    
    // 사용자 입력 수집
    Map<String, dynamic> userData = {
      'level': _level,
      'record_10k': double.tryParse(_recordController.text) ?? 60.0,
      'weekly_minutes': int.tryParse(_weeklyController.text) ?? 120,
      'height_cm': double.tryParse(_heightController.text) ?? 175.0,
      'weight_kg': double.tryParse(_weightController.text) ?? 70.0,
    };
    
    // VDOT 계산
    double targetVDOT = 0;
    try {
      if (_useSelfGoal) {
        double goalDist = double.parse(_goalDistanceController.text);
        double goalTime = double.parse(_goalTimeController.text);
        targetVDOT = _calculateVDOT(goalDist, goalTime);
      } else {
        targetVDOT = _calculateVDOT(10, userData['record_10k']);
      }
      userData['target_vdot'] = targetVDOT;
    } catch (e) {
      targetVDOT = 45.0;
      userData['target_vdot'] = targetVDOT;
    }
    
    List<Map<String, dynamic>> newPlan = [];
    
    try {
      // 🌐 서버 API 호출 시도
      print('📡 Calling server API: $_serverUrl/generate');
      
      final response = await http.post(
        Uri.parse('$_serverUrl/generate'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(userData),
      ).timeout(const Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        print('✅ Server response success');
        final data = json.decode(response.body);
        
        // 서버 응답을 Flutter 형식으로 변환
        for (var week in data['weeks']) {
          List<Map<String, dynamic>> runs = [];
          for (var run in week['runs']) {
            runs.add({
              'day': _translateDay(run['day']),
              'type': run['type'],
              'distance': run['distance'],
              'targetPace': run['target_pace'],
              'description': run['description'] ?? '',
              'completed': false,
            });
          }
          
          newPlan.add({
            'week': week['week'],
            'focus': week['focus'] ?? '',
            'intensity': week['intensity'] ?? 0.7,
            'targetVDOT': targetVDOT,
            'completed': false,
            'runs': runs,
          });
        }
        
        setState(() {
          _plan = newPlan;
          _isGenerating = false;
          _selectedIndex = 2;
        });
        
        _saveData(); // 💾 저장
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('🎯 서버 플랜 생성 완료! (VDOT: ${targetVDOT.toStringAsFixed(1)})'),
            backgroundColor: Colors.green,
          ),
        );
        return;
      }
    } catch (e) {
      print('❌ Server error: $e');
      print('🔄 Falling back to local algorithm');
    }
    
    // ⚠️ 로컬 알고리즘 폴백 (오프라인/에러 시)
    // 1. BMI 및 안전성 계수 계산
    double heightM = (userData['height_cm'] ?? 175.0) / 100;
    double weightKg = userData['weight_kg'] ?? 70.0;
    double bmi = weightKg / (heightM * heightM);
    
    double volumeModifier = 1.0;
    // ACSM 가이드라인: BMI 30 이상은 부상 위험으로 볼륨 50% 권장
    if (bmi >= 30) {
      volumeModifier = 0.5;
    } else if (bmi >= 25) {
      volumeModifier = 0.7; // 서버 로직과 통일 (기존 0.8 -> 0.7)
    }
    
    // 초보자는 기본적으로 약간 적게 시작
    if (_level == "beginner") volumeModifier *= 0.9;
    
    int weeklyMinutes = int.tryParse(_weeklyController.text) ?? 120; // 주간 훈련량
    int totalWeeks = _level == "beginner" ? 12 : (_level == "intermediate" ? 24 : 48);
    
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
        "runs": _generateWeekRuns(i, totalWeeks, intensity, easyPace, tempoPace, intervalPace, volumeModifier, weeklyMinutes),
      });
    }

    setState(() {
      _plan = newPlan;
      _isGenerating = false;
      _selectedIndex = 2;
    });
    
    _saveData(); // 💾 저장
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('🎯 로컬 플랜 생성 완료! (VDOT: ${targetVDOT.toStringAsFixed(1)})'),
        backgroundColor: Colors.orange,
      ),
    );
  }
  
  // 📊 주차별 강도 계산 (피리어다이제이션)
  double _calculateWeekIntensity(int week, int totalWeeks) {
    // 3주 증가 + 1주 회복 사이클
    int cycle = (week - 1) % 4;
    double baseIntensity = 0.6 + (week / totalWeeks) * 0.3; // 점진적 증가
    
    if (cycle == 3) return baseIntensity * 0.7; // 회복 주
    return baseIntensity + (cycle * 0.1); // 점진적 증가
  }
  
  String _getWeekFocus(int week, int totalWeeks) {
    double progress = week / totalWeeks;
    if (progress < 0.3) return "기초 체력 및 유연성";
    if (progress < 0.6) return "지구력 향상";
    if (progress < 0.85) return "스피드 및 템포";
    return "목표 달성 및 테이퍼링";
  }
  
  // VDOT 기반 페이스 계산
  double _getPaceFromVDOT(double vdot, String type) {
    // Jack Daniels' formula 기반 근사치
    double basePace = 0;
    
    switch(type) {
      case 'easy':
        basePace = 65 / vdot; // E pace (분/km)
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
  
  // 주차별 훈련 생성 (서버 로직 100% 이식)
  List<Map<String, dynamic>> _generateWeekRuns(int week, int totalWeeks, double intensity, double easyPace, double tempoPace, double intervalPace, double volumeModifier, int weeklyMinutes) {
    List<Map<String, dynamic>> runs = [];
    
    // 1. 이번 주 총 목표 훈련 시간 (분)
    double targetMinutes = weeklyMinutes.toDouble() * volumeModifier * intensity;
    
    // 2. 요일별 배분 (서버와 동일: 화 25%, 목 35%, 토 40%)
    double minTue = targetMinutes * 0.25;
    double minThu = targetMinutes * 0.35;
    double minSat = targetMinutes * 0.40;
    
    // 3. 거리 계산 (시간 / 페이스)
    // 화요일: Easy Run
    double distTue = minTue / easyPace;
    
    runs.add({
      "day": "화",
      "type": "이지런",
      "dist": double.parse(distTue.toStringAsFixed(1)),
      "targetPace": easyPace,
      "desc": "편안한 페이스로 (${_formatPace(easyPace)})",
      "completed": false,
    });
    
    // 목요일: Quality Run or Recovery
    if (week % 4 == 0) {
      // 회복 주
      double distRecovery = minThu / (easyPace * 1.15); // 더 느린 페이스
      runs.add({
        "day": "목",
        "type": "회복런",
        "dist": double.parse(distRecovery.toStringAsFixed(1)),
        "targetPace": easyPace * 1.15,
        "desc": "아주 가볍게 (${_formatPace(easyPace * 1.15)})",
        "completed": false,
      });
    } else {
      // 일반 주
      double targetPace = week % 2 == 0 ? tempoPace : intervalPace;
      double distThu = minThu / targetPace;
      
      runs.add({
        "day": "목",
        "type": week % 2 == 0 ? "템포런" : "인터벌",
        "dist": double.parse(distThu.toStringAsFixed(1)),
        "targetPace": targetPace,
        "desc": week % 2 == 0 
          ? "지속 가능한 빠른 페이스 (${_formatPace(tempoPace)})"
          : "3분 질주 + 2분 회복 반복 (${_formatPace(intervalPace)})",
        "completed": false,
      });
    }
    
    // 토요일: LSD
    // LSD 페이스는 Easy Pace보다 10% 느림 (시간은 더 오래 걸림)
    double lsdPace = easyPace * 1.1;
    double distSat = minSat / lsdPace; 
    
    runs.add({
      "day": "토",
      "type": "LSD (장거리)",
      "dist": double.parse(distSat.toStringAsFixed(1)),
      "targetPace": lsdPace,
      "desc": "천천히 오래 달리기 (${_formatPace(lsdPace)})",
      "completed": false,
    });
    
    return runs;
  }
  
  String _formatPace(double pace) {
    int min = pace.toInt();
    int sec = ((pace - min) * 60).toInt();
    return "$min'${sec.toString().padLeft(2, '0')}\"";
  }

  // --- 2. 러닝 페이지 (AI 보이스 코칭 적용) ---
  bool _isRunning = false;
  String _gpsStatus = "GPS 대기 중...";
  double _distKm = 0.0;
  String _pace = "-'--\"";
  Timer? _timer;
  int _seconds = 0;
  StreamSubscription<Position>? _positionStream;

  Widget _buildRunPage() {
    String timeStr = "${(_seconds~/60).toString().padLeft(2,'0')}:${(_seconds%60).toString().padLeft(2,'0')}";
    
    return Stack(
      children: [
        // 1. 네이버 지도 (배경)
        NaverMap(
          options: const NaverMapViewOptions(
            locationButtonEnable: true, // 현위치 버튼
            indoorEnable: true,
            consumeSymbolTapEvents: false,
            mapType: NMapType.basic,
            nightModeEnable: true, // 다크 모드
          ),
          onMapReady: (controller) {
             print("🗺️ 네이버 지도 준비 완료");
          },
        ),
        
        // 2. 상단 그라데이션 (가독성용)
        Positioned(
          top: 0, left: 0, right: 0,
          height: 200,
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.black.withOpacity(0.8), Colors.transparent],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
        ),

        // 3. 중앙 타이머 (상단 배치)
        Positioned(
            top: 80, left: 0, right: 0,
            child: Column(
              children: [
                Text(
                  _isRunning ? "RUNNING" : "READY",
                  style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.bold, 
                    color: Color(0xFF00FFF0), letterSpacing: 2
                  )
                ),
                Text(
                    timeStr,
                    style: TextStyle(
                        fontSize: 70, 
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.w900, 
                        color: Colors.white,
                        shadows: [Shadow(color: Colors.black.withOpacity(0.8), blurRadius: 20)]
                    )
                ),
              ],
            )
        ),
        
        // 4. 하단 컨트롤 패널 (Glassmorphism)
        Positioned(
          bottom: 30, left: 20, right: 20,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
            decoration: BoxDecoration(
              color: const Color(0xFF0F0F1E).withOpacity(0.85),
              borderRadius: BorderRadius.circular(25),
              border: Border.all(color: Colors.white12, width: 1),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 20, spreadRadius: 5)
              ]
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 통계 (거리, 페이스)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildNeonStat("거리", "${_distKm.toStringAsFixed(2)}", "km"),
                    Container(width: 1, height: 40, color: Colors.white24),
                    _buildNeonStat("페이스", _pace, "/km"),
                  ],
                ),
                const SizedBox(height: 25),
                
                // 버튼
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                     // 소리 버튼
                     IconButton(
                        icon: Icon(_isVoiceOn ? Icons.volume_up : Icons.volume_off, color: Colors.white54),
                        onPressed: () {
                          setState(() => _isVoiceOn = !_isVoiceOn);
                        }
                     ),
                     const SizedBox(width: 20),
                     
                     // 메인 버튼 Start/Stop
                     GestureDetector(
                       onTap: _toggleRun,
                       child: Container(
                         width: 80, height: 80,
                         decoration: BoxDecoration(
                           shape: BoxShape.circle,
                           color: _isRunning ? const Color(0xFFFF3366) : const Color(0xFF00FFF0),
                           boxShadow: [
                             BoxShadow(
                               color: _isRunning ? const Color(0xFFFF3366).withOpacity(0.5) : const Color(0xFF00FFF0).withOpacity(0.5),
                               blurRadius: 20, spreadRadius: 2
                             )
                           ]
                         ),
                         child: Icon(
                           _isRunning ? Icons.pause : Icons.play_arrow,
                           color: const Color(0xFF0F0F1E), size: 40
                         ),
                       ),
                     ),
                     
                     const SizedBox(width: 20),
                     // 대칭용 더미 (또는 설정 버튼)
                     IconButton(
                        icon: const Icon(Icons.settings, color: Colors.transparent), // 안 보이게
                        onPressed: null,
                     ),
                  ],
                )
              ],
            ),
          ),
        ),
      ],
    );
  }
  
  // 네온 스타일 통계 표시
  Widget _buildNeonStat(String label, String value, String unit) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              label == "거리" ? Icons.straighten : Icons.speed,
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
      // 멈춤 -> 저장 확인
      bool? confirm = await showDialog(
        context: context, 
        builder: (ctx) => AlertDialog(
          title: const Text("러닝 종료"),
          content: const Text("기록을 저장하고 끝내시겠습니까?"),
          actions: [
             TextButton(onPressed: ()=>Navigator.pop(ctx, false), child: const Text("취소")),
             TextButton(onPressed: ()=>Navigator.pop(ctx, true), child: const Text("종료")),
          ],
        )
      );
      
      if (confirm == true) {
          _timer?.cancel();
          _positionStream?.cancel();
          
          // 저장 중 로딩 표시
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (ctx) => const Center(child: CircularProgressIndicator()),
          );
          
          await _uploadRunData();
          
          if (mounted) {
             Navigator.pop(context); // 로딩 닫기
          }

          setState(() => _isRunning = false);
      }
    } else {
      // 시작
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
             if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("GPS 권한이 필요합니다.")));
             return;
        }
      }
      
      setState(() {
        _isRunning = true;
        _seconds = 0;
        _distKm = 0.0;
        _gpsStatus = "GPS 수신 중...";
      });
      
      if (_isVoiceOn) _tts.speak("러닝을 시작합니다. 1분마다 페이스를 알려드릴게요.");

      _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        setState(() => _seconds++);
        
        // 🚀 1분(60초)마다 AI 코칭 실행
        if (_seconds > 0 && _seconds % 60 == 0 && _isVoiceOn) {
            _runAiCoaching();
        }
      });
      
      // 향상된 GPS 설정
      LocationSettings locationSettings;
      if (Platform.isAndroid) {
        locationSettings = AndroidSettings(
            accuracy: LocationAccuracy.bestForNavigation,
            distanceFilter: 2, // 2미터마다 갱신 (더 자주 받아옴)
            forceLocationManager: true,
            intervalDuration: const Duration(milliseconds: 1000), // 1초마다 강제 갱신 시도
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
              // 정확도가 나쁜 신호(오차 30m 이상)는 무시 (실내 등 튈 때 방지)
              if (position.accuracy > 30.0) {
                 // accuracy가 안좋으면 무시하되, UI에만 표시해줄 수 있음
                 setState(() => _gpsStatus = "GPS 신호 약함: ±${position.accuracy.toInt()}m");
                 return;
              }

              if (lastPos != null) {
                  double d = Geolocator.distanceBetween(lastPos!.latitude, lastPos!.longitude, position.latitude, position.longitude) / 1000.0;
                  
                  // 너무 미세한 움직임(노이즈)은 무시하되, 빠른 걸음(초속 1m=0.001km) 이상은 잡아야 함.
                  // 1초 간격 갱신이면 2m/s = 7.2km/h. 
                  // 0.002km = 2m. 
                  // 튀는 값(순간이동 100m) 필터링
                  if (d > 0.002 && d < 0.1) { 
                      setState(() {
                          _distKm += d;
                          if (_distKm > 0) {
                              double paceVal = (_seconds / 60) / _distKm;
                              int pm = paceVal.toInt();
                              // 페이스가 비정상적으로 크면(멈춤 등) 처리
                              if (pm < 30) { 
                                int ps = ((paceVal - pm) * 60).toInt();
                                _pace = "$pm'${ps.toString().padLeft(2,'0')}\"";
                              }
                          }
                      });
                  }
              }
              // 상태 업데이트
              setState(() {
                 _gpsStatus = "GPS: ±${position.accuracy.toInt()}m";
              });
              lastPos = position;
          }
      });
    }
  }
  
  // 🎙️ AI 보이스 코칭 함수
  Future<void> _runAiCoaching() async {
      // 1. 단순 정보 알림 (즉시 실행)
      String baseMsg = "${(_seconds ~/ 60)}분 경과. 현재 페이스 $_pace 입니다.";
      await _tts.speak(baseMsg);
      
      // 2. Gemini에게 조언 요청 (비동기)
      // 너무 자주 호출하면 안되므로 2분 간격 혹은 필요시 호출 등 조정 가능하나, 요청대로 1분마다 호출.
      try {
          String type = _currentRun?['type'] ?? "자유 달리기";
          String prompt = "러너가 $type 중입니다. 1분간 달렸고 현재 페이스는 $_pace 입니다. 짧게 한 문장으로 격려나 속도 조언해줘. (반말 금지, 코치 톤으로)";
          
          final content = [Content.text(prompt)];
          final response = await _geminiModel.generateContent(content);
          
          if (response.text != null) {
              await Future.delayed(const Duration(seconds: 4)); // 앞 메시지 끝나길 기다림 (대략)
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
          
          // 📊 적응형 알고리즘: 러닝 완료 후 VDOT 재계산 및 플랜 조정
          await _adjustTrainingPlan(_distKm, _seconds / 60.0);
      } catch (e) {
          // Supabase 테이블이 없어도 로컬 데이터는 유지됨
          print("INFO: Supabase sync skipped - $e");
          // 로컬 적응형 알고리즘은 계속 실행
          try {
            await _adjustTrainingPlan(_distKm, _seconds / 60.0);
          } catch (e2) {
            print("WARN: Plan adjustment failed - $e2");
          }
      }
      
      _saveData(); // 💾 데이터 영구 저장
      
      // 항상 성공 메시지 표시 (Supabase 동기화 실패해도 로컬 데이터는 유효)
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("✅ 기록 저장 완료!"), backgroundColor: Colors.teal)
        );
      }
  }
  
  // 🔄 적응형 알고리즘: 훈련 플랜 자동 조정
  Future<void> _adjustTrainingPlan(double distKm, double timeMin) async {
    if (_plan.isEmpty || distKm < 1.0) return;
    
    // 1. 현재 러닝 기반 VDOT 계산
    double newVDOT = _calculateVDOT(distKm, timeMin);
    double oldVDOT = _trainingProgress['currentVDOT'] ?? 0.0;
    
    // 2. VDOT 변화율 확인
    double vdotChange = ((newVDOT - oldVDOT) / oldVDOT) * 100;
    
    print("📊 VDOT 변화: $oldVDOT -> $newVDOT (${vdotChange.toStringAsFixed(1)}%)");
    
    // 3. 현재 훈련 완료 처리
    if (_currentRun != null) {
      _trainingProgress['completedRuns'].add({
        'date': DateTime.now().toIso8601String(),
        'distance': distKm,
        'time': timeMin,
        'vdot': newVDOT,
      });
      
      // 현재 주차의 해당 훈련을 완료로 표시
      for (var week in _plan) {
        for (var run in week['runs']) {
          if (run['type'] == _currentRun!['type'] && run['day'] == _currentRun!['day']) {
            run['completed'] = true;
          }
        }
      }
    }
    
    // 4. 주간 완료율 계산
    int completedCount = (_trainingProgress['completedRuns'] as List).length;
    int expectedRuns = _plan.isNotEmpty ? _plan[0]['runs'].length : 3;
    _trainingProgress['weeklyCompletionRate'] = completedCount > 0 ? (completedCount % expectedRuns) / expectedRuns : 0.0;
    
    // 5. 페이스가 크게 개선되었다면 (5% 이상) -> 플랜 난이도 상향
    if (vdotChange > 5.0 && completedCount >= 3) {
      _trainingProgress['currentVDOT'] = newVDOT;
      await _regeneratePlanWithNewVDOT(newVDOT);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("🎉 실력이 향상되었습니다! 플랜이 자동 조정되었습니다. (VDOT: ${newVDOT.toStringAsFixed(1)})"),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 4),
          )
        );
      }
    }
    // 6. 페이스가 크게 저하되었거나 (10% 이상) 훈련을 많이 빼먹었다면 -> 플랜 난이도 하향
    else if (vdotChange < -10.0 || _trainingProgress['missedDays'] > 5) {
      _trainingProgress['currentVDOT'] = newVDOT * 0.95; // 약간 낮춰서 안전하게
      await _regeneratePlanWithNewVDOT(_trainingProgress['currentVDOT']);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text("⚠️ 컨디션에 맞춰 플랜이 재조정되었습니다. 무리하지 마세요!"),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 4),
          )
        );
      }
    }
    // 7. 정상 범위 내라면 점진적 업데이트
    else {
      // 이동평균으로 부드럽게 업데이트
      _trainingProgress['currentVDOT'] = (oldVDOT * 0.8) + (newVDOT * 0.2);
    }
  }
  
  // 🔄 새로운 VDOT 기반으로 남은 플랜 재생성
  Future<void> _regeneratePlanWithNewVDOT(double newVDOT) async {
    if (_plan.isEmpty) return;
    
    // 1. 필요한 변수 계산 (BMI, Volume Modifier)
    // 컨트롤러 값이 있으면 사용, 없으면 기본값
    double heightM = (double.tryParse(_heightController.text) ?? 175.0) / 100;
    double weightKg = double.tryParse(_weightController.text) ?? 70.0;
    double bmi = weightKg / (heightM * heightM);
    
    double volumeModifier = 1.0;
    if (bmi >= 30) {
      volumeModifier = 0.5;
    } else if (bmi >= 25) {
      volumeModifier = 0.7;
    }
    
    if (_level == "beginner") volumeModifier *= 0.9;
    
    int weeklyMinutes = int.tryParse(_weeklyController.text) ?? 120;
    
    int currentWeek = 1;
    // 완료된 주차 찾기
    for (int i = 0; i < _plan.length; i++) {
      if (_plan[i]['completed'] == true) {
        currentWeek = i + 2; // 다음 주부터
      }
    }
    
    // 남은 주차만 재생성
    int totalWeeks = _plan.length;
    for (int i = currentWeek - 1; i < totalWeeks; i++) {
      int week = i + 1;
      double intensity = _calculateWeekIntensity(week, totalWeeks);
      
      double easyPace = _getPaceFromVDOT(newVDOT, 'easy');
      double tempoPace = _getPaceFromVDOT(newVDOT, 'tempo');
      double intervalPace = _getPaceFromVDOT(newVDOT, 'interval');
      
      setState(() {
        _plan[i]['targetVDOT'] = newVDOT;
        _plan[i]['runs'] = _generateWeekRuns(week, totalWeeks, intensity, easyPace, tempoPace, intervalPace, volumeModifier, weeklyMinutes);
      });
    }
  }
  
  // 📅 누락된 훈련 감지 (백그라운드에서 주기적으로 호출 가능)
  void _checkMissedTrainings() {
    if (_plan.isEmpty) return;
    
    DateTime now = DateTime.now();
    int missedCount = 0;
    
    // 이번 주 훈련 확인
    var thisWeek = _plan.first;
    for (var run in thisWeek['runs']) {
      if (run['completed'] != true) {
        // 요일 확인 로직 (간단히 구현)
        String day = run['day'];
        int targetWeekday = _getDayOfWeek(day);
        
        // 현재 요일보다 과거라면 누락
        if (now.weekday > targetWeekday) {
          missedCount++;
        }
      }
    }
    
    if (missedCount > 0) {
      _trainingProgress['missedDays'] = (_trainingProgress['missedDays'] ?? 0) + missedCount;
      print("⚠️ 누락된 훈련: $missedCount개");
    }
  }
  
  int _getDayOfWeek(String day) {
    switch(day) {
      case '월': return 1;
      case '화': return 2;
      case '수': return 3;
      case '목': return 4;
      case '금': return 5;
      case '토': return 6;
      case '일': return 7;
      default: return 1;
    }
  }

  // --- 3. 플랜 페이지 ---
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
            "설정 탭에서 플랜을 생성하세요.",
            style: TextStyle(color: Colors.white30, fontSize: 14),
          ),
        ),
      );
    }
    
    // 1주차 vs 나머지
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
            
            // 🤖 AI 코치 메시지
            Container(
              margin: const EdgeInsets.only(bottom: 20),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF2A2A4E).withOpacity(0.5),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFBB86FC).withOpacity(0.5)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.auto_awesome, color: Color(0xFFBB86FC), size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      "AI 코치: 매주 수행 결과를 분석하여 다음 주 프로그램을 자동으로 재조정해 드립니다. 지금처럼만 달려주세요! 🏃‍♂️",
                      style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 13, height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
            
            // 📊 주간 진행 상황 - 네온 스타일
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
                      const Text("주간 완료율", style: TextStyle(color: Colors.white54, fontSize: 13)),
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
                          "현재 VDOT: ${(_trainingProgress['currentVDOT'] ?? 0.0).toStringAsFixed(1)}",
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
                            "누락: ${_trainingProgress['missedDays']}일",
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
          
          // 1주차는 기본적으로 펼쳐서 보여줌
          _buildWeekCard(context, thisWeek, initiallyExpanded: true),
          
          const SizedBox(height: 20),
          
          // AI 코칭 멘트 - 적응형 알고리즘 설명 강화
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
                        "🤖 적응형 AI 트레이닝 시스템",
                        style: TextStyle(color: Colors.teal.shade100, fontSize: 14, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  "• Jack Daniels VDOT 알고리즘 기반\n"
                  "• 훈련 누락 시 자동 난이도 조정\n"
                  "• 페이스 개선 감지하여 플랜 상향\n"
                  "• 실시간 체력 지수 추적 및 조정",
                  style: TextStyle(color: Colors.teal.shade100.withOpacity(0.8), fontSize: 12, height: 1.5),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 30),
          
          // 나머지 훈련 (접기/펼치기)
          if (futureWeeks.isNotEmpty)
            Card(
              color: Colors.white12, // 배경 약간 다르게
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              child: ExpansionTile(
                iconColor: Colors.white70,
                collapsedIconColor: Colors.white54,
                title: Text(
                  "이후 훈련 일정 (${futureWeeks.length}주)", 
                  style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.bold)
                ),
                children: futureWeeks.map((w) => _buildWeekCard(context, w)).toList(),
              ),
            ),
            
           const SizedBox(height: 50),
        ],
      ),
      ),
    );
  }

  Widget _buildWeekCard(BuildContext context, Map<String, dynamic> week, {bool initiallyExpanded = false}) {
    return Card(
      color: Colors.white10,
      margin: const EdgeInsets.only(bottom: 10),
      child: ExpansionTile(
        initiallyExpanded: initiallyExpanded,
        title: Text("${week['week']}주차 : ${week['focus']}", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
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
             // 목표 설정
             setState(() {
                 _currentRun = r;
                 _selectedIndex = 1; // Go to Run tab
             });
             ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("오늘의 목표: ${r['type']} 설정됨!")));
           },
        )).toList(),
      ),
    );
  }
  
  // 📊 주간 완료율 계산

  
  // Helper: 영어 요일 → 한글
  String _translateDay(String day) {
    const days = {
      'Mon': '월', 'Tue': '화', 'Wed': '수', 'Thu': '목',
      'Fri': '금', 'Sat': '토', 'Sun': '일'
    };
    return days[day] ?? day;
  }
}