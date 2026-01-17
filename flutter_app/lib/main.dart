import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:async';
import 'dart:math';

void main() {
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
        fontFamily: 'Roboto', // 한글 폰트 적용 고려 (시스템 폰트 사용)
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
  
  // 데이터 컨트롤러 (기본값 제거 또는 한국인 표준 체형으로 설정)
  final TextEditingController _heightController = TextEditingController(text: "175");
  final TextEditingController _weightController = TextEditingController(text: "70");
  final TextEditingController _weeklyController = TextEditingController(text: "120");
  final TextEditingController _recordController = TextEditingController(text: "60");
  String _level = "beginner";
  
  // 상태 변수
  List<Map<String, dynamic>> _plan = [];
  bool _isGenerating = false;
  Map<String, dynamic>? _currentRun;
  
  // 네비게이션
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

  // --- 1. 설정 페이지 (한글화) ---
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
          const Text("나만의 AI 러닝 코치", 
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
            Expanded(child: _buildInput("주간 목표 시간 (분)", _weeklyController)),
            const SizedBox(width: 10),
            Expanded(child: _buildInput("10km 기록 (분)", _recordController)),
          ]),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(10)),
            child: Column(children: [
              RadioListTile(value: "beginner", groupValue: _level, onChanged: (v){setState(()=>_level=v.toString());}, 
                  title: const Text("입문자 (12주 완성)", style: TextStyle(color: Colors.white))),
              RadioListTile(value: "intermediate", groupValue: _level, onChanged: (v){setState(()=>_level=v.toString());}, 
                  title: const Text("중급자 (24주 하프)", style: TextStyle(color: Colors.white))),
              RadioListTile(value: "advanced", groupValue: _level, onChanged: (v){setState(()=>_level=v.toString());}, 
                  title: const Text("상급자 (48주 풀코스)", style: TextStyle(color: Colors.white))),
            ]),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _isGenerating ? null : _generatePlan,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.all(20),
              backgroundColor: Colors.teal,
              foregroundColor: Colors.white,
            ),
            child: Text(_isGenerating ? "AI가 분석 중입니다..." : "AI 맞춤형 플랜 생성"),
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
      decoration: InputDecoration(
        labelText: label, 
        labelStyle: const TextStyle(color: Colors.white70),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        enabledBorder: OutlineInputBorder(borderSide: const BorderSide(color: Colors.white24), borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  // --- 핵심 로직 이식 (Dart version of routine_generator.py) ---
  void _generatePlan() async {
    setState(() => _isGenerating = true);
    
    // UI 반응성을 위해 약간의 지연
    await Future.delayed(const Duration(milliseconds: 800)); 
    
    // 1. 사용자 데이터 파싱
    double weight = double.tryParse(_weightController.text) ?? 70;
    double height = (double.tryParse(_heightController.text) ?? 175) / 100;
    double record10k = double.tryParse(_recordController.text) ?? 60;
    
    // BMI 계산
    double bmi = weight / (height * height);
    
    // 2. 알고리즘 로직 적용 (Python 코드 이식)
    List<Map<String, dynamic>> newPlan = [];
    int totalWeeks = _level == "beginner" ? 12 : (_level == "intermediate" ? 24 : 48);
    
    for(int week=1; week<=totalWeeks; week++) {
        String focus = "기초 다지기";
        List<Map<String, dynamic>> runs = [];
        
        if (_level == "beginner") {
          // 초보자 알고리즘
          if (week <= 4) focus = "기초 체력";
          else if (week <= 8) focus = "거리 늘리기";
          else focus = "페이스 향상";

          if (bmi > 25) {
             // 과체중: 걷기 비중 높음
             runs = [
               {"day": "화", "type": "빠르게 걷기", "dist": 3.0, "desc": "부상 방지를 위한 걷기"},
               {"day": "목", "type": "가벼운 조깅", "dist": 2.0 + (week*0.2), "desc": "아주 천천히 뛰세요"},
               {"day": "토", "type": "LSD (장거리 걷기)", "dist": 4.0 + (week*0.5), "desc": "오래 걷기"},
             ];
          } else {
             // 일반: 런-워크
             runs = [
               {"day": "화", "type": "조깅", "dist": 3.0 + (week*0.3), "desc": "편안한 호흡 유지"},
               {"day": "목", "type": "인터벌", "dist": 3.0, "desc": "1분 뛰고 1분 걷기 반복"},
               {"day": "토", "type": "장거리 조깅", "dist": 5.0 + (week*0.5), "desc": "지구력 훈련"},
             ];
          }
        } else {
          // 유경험자 (VDOT 개념 약식 적용)
          // 10km 기록(분)이 낮을수록 고수
          bool isElite = record10k < 45;
          focus = isElite ? "기록 단축" : "완주 목표";
          
          runs = [
             {"day": "화", "type": "조깅", "dist": 5.0 + (week*0.5), "desc": "회복 러닝"},
             {"day": "수", "type": isElite ? "트랙 인터벌" : "템포런", "dist": 6.0, "desc": "심박수 높이기"},
             {"day": "금", "type": "조깅", "dist": 5.0, "desc": "자세 집중"},
             {"day": "일", "type": "LSD", "dist": 10.0 + week, "desc": "장거리 지속주"},
          ];
        }

        newPlan.add({
          "week": week,
          "focus": focus,
          "runs": runs
        });
    }

    setState(() {
      _plan = newPlan;
      _isGenerating = false;
      _selectedIndex = 2; // 플랜 탭으로 이동
    });
    
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("AI 맞춤형 플랜이 생성되었습니다!")));
  }

  // --- 2. 러닝 페이지 (GPS 연동) ---
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
         gradient: LinearGradient(
           begin: Alignment.topCenter, end: Alignment.bottomCenter,
           colors: [Color(0xFF263238), Color(0xFF000000)]
         )
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
             Text(_isRunning ? "RUNNING" : "READY", style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.tealAccent, letterSpacing: 2)),
             const SizedBox(height: 20),
             
             // 타이머 원형 디자인
             Container(
               width: 200, height: 200,
               decoration: BoxDecoration(
                 shape: BoxShape.circle,
                 border: Border.all(color: _isRunning ? Colors.tealAccent : Colors.grey, width: 4),
                 boxShadow: [BoxShadow(color: _isRunning ? Colors.teal.withOpacity(0.5) : Colors.transparent, blurRadius: 20)]
               ),
               alignment: Alignment.center,
               child: Text(timeStr, style: const TextStyle(fontSize: 50, fontFamily: 'monospace', fontWeight: FontWeight.bold, color: Colors.white)),
             ),
             
             const SizedBox(height: 30),
             Row(
               mainAxisAlignment: MainAxisAlignment.spaceEvenly,
               children: [
                 _buildStatItem("거리", "${_distKm.toStringAsFixed(2)} km"),
                 _buildStatItem("페이스", "$_pace /km"),
               ],
             ),
             const SizedBox(height: 20),
             Text(_gpsStatus, style: const TextStyle(fontSize: 12, color: Colors.grey)),
             const SizedBox(height: 40),
             
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
      // 멈춤
      _timer?.cancel();
      _positionStream?.cancel();
      setState(() => _isRunning = false);
    } else {
      // 시작
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
             ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("GPS 권한이 필요합니다.")));
             return;
        }
      }
      
      setState(() {
        _isRunning = true;
        _seconds = 0;
        _distKm = 0.0;
        _gpsStatus = "GPS 수신 중...";
      });
      
      _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        setState(() => _seconds++);
      });
      
      const LocationSettings locationSettings = LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5,
      );
      
      Position? lastPos;
      _positionStream = Geolocator.getPositionStream(locationSettings: locationSettings).listen((Position? position) {
          if (position != null) {
              if (lastPos != null) {
                  double d = Geolocator.distanceBetween(lastPos!.latitude, lastPos!.longitude, position.latitude, position.longitude) / 1000.0;
                  // GPS 튐 방지 (너무 빠른 이동은 무시)
                  if (d > 0.002 && d < 0.1) { 
                      setState(() {
                          _distKm += d;
                          // 페이스 계산
                          if (_distKm > 0) {
                              double paceVal = (_seconds / 60) / _distKm;
                              int pm = paceVal.toInt();
                              int ps = ((paceVal - pm) * 60).toInt();
                              _pace = "$pm'${ps.toString().padLeft(2,'0')}\"";
                          }
                          _gpsStatus = "GPS 작동 중 (정확도: ${position.accuracy.toInt()}m)";
                      });
                  }
              }
              lastPos = position;
          }
      });
    }
  }

  // --- 3. 플랜 페이지 (한글화) ---
  Widget _buildPlanPage() {
    if (_plan.isEmpty) {
        return const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.calendar_today, size: 60, color: Colors.grey),
              SizedBox(height: 20),
              Text("생성된 플랜이 없습니다.\n[설정] 탭에서 플랜을 생성해주세요.", textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
            ],
          )
        );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _plan.length,
      itemBuilder: (ctx, i) {
        var week = _plan[i];
        return Card(
          color: Colors.white10,
          margin: const EdgeInsets.only(bottom: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: ExpansionTile(
            title: Text("${week['week']}주차 : ${week['focus']}", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
            textColor: Colors.tealAccent,
            iconColor: Colors.tealAccent,
            children: (week['runs'] as List).map<Widget>((r) => ListTile(
               leading: CircleAvatar(
                 backgroundColor: Colors.teal.withOpacity(0.3),
                 child: Text(r['day'][0], style: const TextStyle(color: Colors.white)),
               ),
               title: Text(r['type'], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
               subtitle: Text(r['desc'], style: const TextStyle(color: Colors.white70, fontSize: 12)),
               trailing: Container(
                 padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                 decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(20)),
                 child: Text("${r['dist']} km", style: const TextStyle(color: Colors.tealAccent)),
               ),
               onTap: () {
                 // 훈련 선택 시 러닝 탭으로 이동하고 목표 설정
                 ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("${r['day']}요일 훈련을 시작합니다: ${r['type']}")));
                 setState(() => _selectedIndex = 1); 
               },
            )).toList(),
          ),
        );
      },
    );
  }
}