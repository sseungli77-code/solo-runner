import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'dart:async';
import 'dart:math';

// Gemini API Key (보안을 위해 실제 배포 시에는 숨겨야 함)
const String _geminiKey = 'AIzaSyBtEtujomeYnJUc5ZlEi7CteLmapaEZ4MY';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
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
  
  // Data Controllers
  final TextEditingController _heightController = TextEditingController(text: "175");
  final TextEditingController _weightController = TextEditingController(text: "70");
  final TextEditingController _weeklyController = TextEditingController(text: "120");
  final TextEditingController _recordController = TextEditingController(text: "60");
  String _level = "beginner";
  
  // State
  List<Map<String, dynamic>> _plan = [];
  bool _isGenerating = false;
  Map<String, dynamic>? _currentRun; // 현재 선택된 목표 훈련
  
  // AI & TTS
  late FlutterTts _tts;
  late GenerativeModel _geminiModel;
  bool _isVoiceOn = true; // 오디오 코칭 ON/OFF 상태

  @override
  void initState() {
    super.initState();
    _initTTS();
    _geminiModel = GenerativeModel(model: 'gemini-pro', apiKey: _geminiKey);
  }

  void _initTTS() async {
    _tts = FlutterTts();
    await _tts.setLanguage("ko-KR");
    await _tts.setSpeechRate(0.5); // 천천히 또박또박
    await _tts.setPitch(1.0);
  }

  // Navigation
  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> pages = [
      _buildSetupPage(),
      _buildRunPage(),
      _buildPlanPage(),
    ];

    return Scaffold(
      body: SafeArea(child: pages[_selectedIndex]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: _onItemTapped,
        destinations: const [
          NavigationDestination(icon: Icon(Icons.settings), label: '설정'),
          NavigationDestination(icon: Icon(Icons.directions_run), label: '러닝'),
          NavigationDestination(icon: Icon(Icons.calendar_month), label: '플랜'),
        ],
      ),
    );
  }

  // --- 1. 설정 페이지 ---
  Widget _buildSetupPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 20),
          const Text("SOLO RUNNER", 
            style: TextStyle(fontSize: 40, fontWeight: FontWeight.bold, color: Colors.tealAccent),
            textAlign: TextAlign.center,
          ),
          const Text("AI 보이스 코칭 에디션", 
            style: TextStyle(fontSize: 16, color: Colors.white70), 
            textAlign: TextAlign.center
          ),
          const SizedBox(height: 40),
          Row(children: [
            Expanded(child: _buildInput("키 (cm)", _heightController)),
            const SizedBox(width: 10),
            Expanded(child: _buildInput("몸무게 (kg)", _weightController)),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: _buildInput("주간 목표 (분)", _weeklyController)),
            const SizedBox(width: 10),
            Expanded(child: _buildInput("10km 기록 (분)", _recordController)),
          ]),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(10)),
            child: Column(children: [
              RadioListTile(value: "beginner", groupValue: _level, onChanged: (v){setState(()=>_level=v.toString());}, title: const Text("입문자 (12주)", style: TextStyle(color: Colors.white))),
              RadioListTile(value: "intermediate", groupValue: _level, onChanged: (v){setState(()=>_level=v.toString());}, title: const Text("중급자 (24주)", style: TextStyle(color: Colors.white))),
              RadioListTile(value: "advanced", groupValue: _level, onChanged: (v){setState(()=>_level=v.toString());}, title: const Text("상급자 (48주)", style: TextStyle(color: Colors.white))),
            ]),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _isGenerating ? null : _generatePlan,
            style: ElevatedButton.styleFrom(padding: const EdgeInsets.all(20), backgroundColor: Colors.teal, foregroundColor: Colors.white),
            child: Text(_isGenerating ? "생성 중..." : "AI 플랜 생성"),
          )
        ],
      ),
    );
  }

  Widget _buildInput(String label, TextEditingController ctrl) {
    return TextField(
      controller: ctrl,
      keyboardType: TextInputType.number,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(labelText: label, labelStyle: const TextStyle(color: Colors.white70), border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))),
    );
  }

  void _generatePlan() async {
    setState(() => _isGenerating = true);
    await Future.delayed(const Duration(milliseconds: 500));
    
    // 단순화된 로직 (실제로는 여기서 복잡한 계산 수행)
    List<Map<String, dynamic>> newPlan = [];
    for(int i=1; i<=12; i++) {
        newPlan.add({
          "week": i,
          "focus": i < 5 ? "기초 다지기" : "지구력 향상",
          "runs": [
             {"day": "화", "type": "조깅", "dist": 3.0 + (i*0.2), "desc": "가볍게 뛰세요"},
             {"day": "목", "type": "인터벌", "dist": 4.0, "desc": "1분 뛰고 1분 걷기"},
             {"day": "토", "type": "LSD", "dist": 5.0 + i, "desc": "천천히 오래 뛰기"},
          ]
        });
    }

    setState(() {
      _plan = newPlan;
      _isGenerating = false;
      _selectedIndex = 2; // Move to Plan tab
    });
    
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("플랜 생성 완료!")));
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
    
    return Container(
      decoration: const BoxDecoration(
         gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF263238), Color(0xFF000000)])
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
             // 상단: 목표 훈련 표시
             if (_currentRun != null)
               Container(
                 padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                 margin: const EdgeInsets.only(bottom: 20),
                 decoration: BoxDecoration(color: Colors.teal.withOpacity(0.2), borderRadius: BorderRadius.circular(20)),
                 child: Text("오늘의 목표: ${_currentRun!['type']} (${_currentRun!['dist']}km)", style: const TextStyle(color: Colors.tealAccent, fontWeight: FontWeight.bold)),
               ),

             Text(_isRunning ? "RUNNING" : "READY", style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.tealAccent, letterSpacing: 2)),
             const SizedBox(height: 20),
             
             // 원형 타이머
             Container(
               width: 220, height: 220,
               decoration: BoxDecoration(
                 shape: BoxShape.circle,
                 border: Border.all(color: _isRunning ? Colors.tealAccent : Colors.grey, width: 4),
                 boxShadow: [BoxShadow(color: _isRunning ? Colors.teal.withOpacity(0.5) : Colors.transparent, blurRadius: 20)]
               ),
               alignment: Alignment.center,
               child: Text(timeStr, style: const TextStyle(fontSize: 55, fontFamily: 'monospace', fontWeight: FontWeight.bold, color: Colors.white)),
             ),
             
             const SizedBox(height: 30),
             Row(
               mainAxisAlignment: MainAxisAlignment.spaceEvenly,
               children: [
                 _buildStatItem("거리", "${_distKm.toStringAsFixed(2)} km"),
                 _buildStatItem("페이스", "$_pace /km"),
               ],
             ),
             const SizedBox(height: 10),
             Text(_gpsStatus, style: const TextStyle(fontSize: 12, color: Colors.grey)),
             
             const SizedBox(height: 30),
             
             // 컨트롤 버튼들 (재생/정지 + 오디오)
             Row(
               mainAxisAlignment: MainAxisAlignment.center,
               children: [
                 // 오디오 ON/OFF 버튼
                 IconButton(
                   icon: Icon(_isVoiceOn ? Icons.volume_up : Icons.volume_off),
                   color: _isVoiceOn ? Colors.tealAccent : Colors.grey,
                   iconSize: 30,
                   onPressed: () {
                     setState(() {
                       _isVoiceOn = !_isVoiceOn;
                     });
                     _tts.speak(_isVoiceOn ? "오디오 코칭을 켭니다." : "오디오 코칭을 끕니다.");
                   },
                 ),
                 const SizedBox(width: 20),
                 
                 // 재생/정지 버튼
                 GestureDetector(
                   onTap: _toggleRun,
                   child: Container(
                     width: 80, height: 80,
                     decoration: BoxDecoration(
                       color: _isRunning ? Colors.redAccent : Colors.teal,
                       shape: BoxShape.circle,
                       boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 10, offset: Offset(0, 5))]
                     ),
                     child: Icon(_isRunning ? Icons.pause : Icons.play_arrow, size: 40, color: Colors.white),
                   ),
                 ),
                 
                 const SizedBox(width: 20),
                 // 대칭을 위한 빈 공간 (또는 나중에 음악 버튼 등 추가 가능)
                 const SizedBox(width: 30, height: 30),
               ],
             )
          ],
        ),
      ),
    );
  }
  
  Widget _buildStatItem(String label, String value) {
    return Column(
      children: [
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 14)),
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
      ]
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
          setState(() => _isRunning = false);
          _uploadRunData();
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
      
      const LocationSettings locationSettings = LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 5);
      Position? lastPos;
      _positionStream = Geolocator.getPositionStream(locationSettings: locationSettings).listen((Position? position) {
          if (position != null && lastPos != null) {
              double d = Geolocator.distanceBetween(lastPos!.latitude, lastPos!.longitude, position.latitude, position.longitude) / 1000.0;
              if (d > 0.002 && d < 0.1) { 
                  setState(() {
                      _distKm += d;
                      if (_distKm > 0) {
                          double paceVal = (_seconds / 60) / _distKm;
                          int pm = paceVal.toInt();
                          int ps = ((paceVal - pm) * 60).toInt();
                          _pace = "$pm'${ps.toString().padLeft(2,'0')}\"";
                      }
                      _gpsStatus = "GPS: ${position.accuracy.toInt()}m";
                  });
              }
          }
          if (position != null) lastPos = position;
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
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("✅ 기록 저장 완료!")));
      } catch (e) {
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("저장 오류: $e")));
      }
  }

  // --- 3. 플랜 페이지 ---
  Widget _buildPlanPage() {
    if (_plan.isEmpty) return const Center(child: Text("설정 탭에서 플랜을 생성하세요.", style: TextStyle(color: Colors.grey)));
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _plan.length,
      itemBuilder: (ctx, i) {
        var week = _plan[i];
        return Card(
          color: Colors.white10,
          margin: const EdgeInsets.only(bottom: 16),
          child: ExpansionTile(
            title: Text("${week['week']}주차 : ${week['focus']}", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
            children: (week['runs'] as List).map<Widget>((r) => ListTile(
               leading: CircleAvatar(backgroundColor: Colors.teal.withOpacity(0.3), child: Text(r['day'][0], style: const TextStyle(color: Colors.white))),
               title: Text(r['type'], style: const TextStyle(color: Colors.white)),
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
      },
    );
  }
}