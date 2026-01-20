
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
import 'package:permission_handler/permission_handler.dart';

// [API Key & URL]
const String _geminiKey = 'AIzaSyBtEtujomeYnJUc5ZlEi7CteLmapaEZ4MY'; 
const String _serverUrl = 'https://solo-runner-api.onrender.com';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // 네이버 맵 초기화
  await NaverMapSdk.instance.initialize(
    clientId: '35sazlmvtf',
    onAuthFailed: (ex) => print("********* 네이버 맵 인증 실패: $ex *********"),
  );
  
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
  
  String _level = "beginner";
  bool _useSelfGoal = false;
  
  // State
  List<Map<String, dynamic>> _plan = [];
  bool _isGenerating = false;
  Map<String, dynamic>? _currentRun;
  
  // Adaptive Data
  Map<String, dynamic> _trainingProgress = {
    'completedRuns': [],
    'missedDays': 0,
    'currentVDOT': 0.0,
    'lastCalculatedVDOT': 0.0,
    'weeklyCompletionRate': 0.0,
  };

  // AI & Voice
  late GenerativeModel _geminiModel;
  final FlutterTts _tts = FlutterTts();
  bool _isVoiceOn = true;
  
  // Running State
  bool _isRunning = false;
  String _gpsStatus = "GPS 대기 중...";
  double _distKm = 0.0;
  String _pace = "-'--\"";
  Timer? _timer;
  int _seconds = 0;
  StreamSubscription<Position>? _positionStream;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _initTTS();
    _initPermissions();
    _geminiModel = GenerativeModel(model: 'gemini-pro', apiKey: _geminiKey);
    _loadData();
  }
  
  Future<void> _initPermissions() async {
    await [Permission.location, Permission.microphone].request();
  }

  void _initTTS() async {
    await _tts.setLanguage("ko-KR");
    await _tts.setPitch(0.9);
    await _tts.setSpeechRate(0.5);
  }
  
  // --- Data Persistence ---
  Future<void> _saveData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('level', _level);
    await prefs.setString('height', _heightController.text);
    await prefs.setString('weight', _weightController.text);
    await prefs.setString('weekly', _weeklyController.text);
    await prefs.setString('record', _recordController.text);
    await prefs.setBool('useSelfGoal', _useSelfGoal);
    
    if (_plan.isNotEmpty) {
      await prefs.setString('training_plan', jsonEncode(_plan));
    }
    await prefs.setString('training_progress', jsonEncode(_trainingProgress));
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _level = prefs.getString('level') ?? 'beginner';
      _heightController.text = prefs.getString('height') ?? '175';
      _weightController.text = prefs.getString('weight') ?? '70';
      _weeklyController.text = prefs.getString('weekly') ?? '120';
      _recordController.text = prefs.getString('record') ?? '60';
      _useSelfGoal = prefs.getBool('useSelfGoal') ?? false;
      
      String? jsonPlan = prefs.getString('training_plan');
      if (jsonPlan != null) {
        List<dynamic> decoded = jsonDecode(jsonPlan);
        _plan = decoded.cast<Map<String, dynamic>>();
      }
      
      String? jsonProgress = prefs.getString('training_progress');
      if (jsonProgress != null) {
        _trainingProgress = jsonDecode(jsonProgress);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F1E),
      appBar: AppBar(
        title: const Text('SOLO RUNNER', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 2)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: PageView(
        controller: _pageController,
        onPageChanged: (index) => setState(() => _selectedIndex = index),
        children: [
          _buildSetupPage(),
          _buildRunPage(), // Naver Map UI
          _buildPlanPage(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) {
          setState(() => _selectedIndex = index);
          _pageController.animateToPage(index, duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
        },
        backgroundColor: const Color(0xFF1A1A2E),
        selectedItemColor: const Color(0xFF00FFF0),
        unselectedItemColor: Colors.white24,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'Setup'),
          BottomNavigationBarItem(icon: Icon(Icons.directions_run), label: 'Run'),
          BottomNavigationBarItem(icon: Icon(Icons.calendar_today), label: 'Plan'),
        ],
      ),
    );
  }

  // --- 1. Setup Page ---
  Widget _buildSetupPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildTextField("신장 (cm)", _heightController),
          const SizedBox(height: 10),
          _buildTextField("체중 (kg)", _weightController),
          const SizedBox(height: 10),
          _buildTextField("현재 10km 기록 (분)", _recordController),
          const SizedBox(height: 10),
          _buildTextField("주간 훈련 가능 시간 (분)", _weeklyController),
          const SizedBox(height: 20),
          
          DropdownButtonFormField<String>(
            value: _level,
            dropdownColor: const Color(0xFF1A1A2E),
            items: ['beginner', 'intermediate', 'advanced'].map((l) => DropdownMenuItem(value: l, child: Text(l.toUpperCase(), style: const TextStyle(color: Colors.white)))).toList(),
            onChanged: (v) => setState(() => _level = v!),
            decoration: const InputDecoration(labelText: 'Fitness Level', labelStyle: TextStyle(color: Colors.white70)),
          ),
          
          const SizedBox(height: 30),
          ElevatedButton(
            onPressed: _isGenerating ? null : _generatePlan,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00FFF0),
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(vertical: 15),
            ),
            child: _isGenerating 
              ? const CircularProgressIndicator()
              : const Text("A.I. PLAN GENERATE", style: TextStyle(fontWeight: FontWeight.bold)),
          )
        ],
      ),
    );
  }
  
  Widget _buildTextField(String label, TextEditingController controller) {
    return TextField(
      controller: controller,
      style: const TextStyle(color: Colors.white),
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white54),
        enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
        focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Color(0xFF00FFF0))),
      ),
    );
  }

  // --- Plan Logic ---
  Future<void> _generatePlan() async {
    setState(() => _isGenerating = true);
    
    // Server First logic
    try {
      final userData = {
        'level': _level,
        'current_10k_record': double.parse(_recordController.text),
        'weekly_minutes': int.parse(_weeklyController.text),
        'height': double.parse(_heightController.text),
        'weight': double.parse(_weightController.text),
      };
      
      final response = await http.post(
        Uri.parse('$_serverUrl/generate_plan'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(userData),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        setState(() {
          _plan = List<Map<String, dynamic>>.from(data['plan']);
          _isGenerating = false;
          _selectedIndex = 2; // Move to Plan tab
        });
        _saveData();
        return;
      }
    } catch (e) {
      print("Server Error, falling back to local: $e");
    }

    // Local Fallback Logic (Updated with BMI Adjustment)
    _generatePlanLocal();
  }
  
  void _generatePlanLocal() {
    double record10k = double.tryParse(_recordController.text) ?? 60.0;
    double targetVDOT = _calculateVDOT(record10k);
    
    double h = double.tryParse(_heightController.text) ?? 175;
    double w = double.tryParse(_weightController.text) ?? 70;
    double userHeightM = h / 100.0;
    double bmi = w / (userHeightM * userHeightM);
    
    // BMI Adjustment (Local)
    double adjustedVDOT = targetVDOT;
    double volMod = 1.0;
    
    if (bmi >= 30) {
      adjustedVDOT -= 3.0; // Slower
      volMod = 0.5; // Less volume
    } else if (bmi >= 25) {
      adjustedVDOT -= 1.0; // Slightly slower
      volMod = 0.7;
    }

    List<Map<String, dynamic>> newPlan = [];
    int totalWeeks = _level == 'beginner' ? 12 : 24;
    
    for (int i = 1; i <= totalWeeks; i++) {
        double easyPace = _getPaceFromVDOT(adjustedVDOT, 'easy');
        List<Map<String, dynamic>> runs = [
           {'day': 'Mon', 'type': 'Rest', 'dist': 0, 'desc': 'Rest Day', 'completed': false},
           {'day': 'Tue', 'type': 'Easy', 'dist': 3.0 * volMod, 'desc': 'Easy Run', 'completed': false},
           {'day': 'Thu', 'type': 'Easy', 'dist': 3.0 * volMod, 'desc': 'Easy Run', 'completed': false},
           {'day': 'Sat', 'type': 'Long', 'dist': 5.0 * volMod, 'desc': 'LSD Run', 'completed': false},
        ];
        
        newPlan.add({
          'week': i,
          'focus': 'Foundation',
          'runs': runs,
        });
    }
    
    setState(() {
      _plan = newPlan;
      _isGenerating = false;
      _selectedIndex = 2;
    });
    _saveData();
  }

  double _calculateVDOT(double min10k) {
    if (min10k <= 0) return 30.0;
    return 85.0 - (min10k * 0.8);
  }
  
  double _getPaceFromVDOT(double vdot, String type) {
    double basePace = (85.0 - vdot) / 0.8;
    if (type == 'easy') return basePace * 1.2;
    return basePace;
  }

  // --- 2. Run Page (Naver Map) ---
  Widget _buildRunPage() {
    String timeStr = "${(_seconds~/60).toString().padLeft(2,'0')}:${(_seconds%60).toString().padLeft(2,'0')}";
    
    return Stack(
      children: [
        NaverMap(
          options: const NaverMapViewOptions(
            locationButtonEnable: true,
            indoorEnable: true,
            consumeSymbolTapEvents: false,
            mapType: NMapType.basic,
            nightModeEnable: true,
          ),
          onMapReady: (controller) {
             print("Maps Ready");
          },
        ),
        
        Positioned(
          top: 0, left: 0, right: 0, height: 150,
          child: Container(decoration: BoxDecoration(gradient: LinearGradient(colors: [Colors.black.withOpacity(0.8), Colors.transparent], begin: Alignment.topCenter, end: Alignment.bottomCenter))),
        ),
        
        Positioned(
          top: 60, left: 0, right: 0,
          child: Column(
            children: [
              Text(_isRunning ? "RUNNING" : "READY", style: TextStyle(color: Color(0xFF00FFF0), fontWeight: FontWeight.bold, letterSpacing: 2)),
              Text(timeStr, style: TextStyle(fontSize: 60, fontWeight: FontWeight.w900, color: Colors.white, fontFamily: 'monospace')),
            ]
          )
        ),
        
        Positioned(
          bottom: 30, left: 20, right: 20,
          child: Container(
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
               color: Color(0xFF0F0F1E).withOpacity(0.9),
               borderRadius: BorderRadius.circular(20),
               border: Border.all(color: Colors.white12)
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildStat("Distance", "${_distKm.toStringAsFixed(2)}", "km"),
                    _buildStat("Pace", _pace, "/km"),
                  ],
                ),
                SizedBox(height: 20),
                GestureDetector(
                  onTap: _toggleRun,
                  child: Container(
                    width: 70, height: 70,
                    decoration: BoxDecoration(shape: BoxShape.circle, color: _isRunning ? Color(0xFFFF3366) : Color(0xFF00FFF0)),
                    child: Icon(_isRunning ? Icons.pause : Icons.play_arrow, color: Colors.black, size: 35),
                  ),
                )
              ]
            )
          )
        )
      ],
    );
  }
  
  Widget _buildStat(String label, String value, String unit) {
    return Column(children: [
      Text(label, style: TextStyle(color: Colors.white54, fontSize: 12)),
      Text(value, style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold))
    ]);
  }
  
  void _toggleRun() {
    if (_isRunning) {
        _timer?.cancel();
        _positionStream?.cancel();
        setState(() => _isRunning = false);
        _uploadRunData();
    } else {
        setState(() {
            _isRunning = true; 
            _seconds = 0; 
            _distKm = 0.0;
        });
        _timer = Timer.periodic(Duration(seconds: 1), (t) {
            setState(() => _seconds++);
        });
        
        // Mock GPS
        _timer = Timer.periodic(Duration(seconds: 2), (t) {
             if(_isRunning) {
               setState(() {
                   _distKm += 0.01;
                   _pace = "6'30\"";
               });
             }
        });
    }
  }
  
  void _uploadRunData() {
      _saveData();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Run Saved!")));
  }

  // --- 3. Plan Page ---
  Widget _buildPlanPage() {
    if (_plan.isEmpty) return Center(child: Text("Please generate a plan first", style: TextStyle(color: Colors.white30)));
    
    return ListView.builder(
      padding: EdgeInsets.all(16),
      itemCount: _plan.length,
      itemBuilder: (ctx, idx) {
        final week = _plan[idx];
        return Card(
          color: Colors.white10,
          child: ExpansionTile(
            title: Text("Week ${week['week']}", style: TextStyle(color: Colors.white)),
            children: (week['runs'] as List).map<Widget>((r) => ListTile(
                title: Text(r['type'], style: TextStyle(color: Colors.white)),
                subtitle: Text(r['desc'], style: TextStyle(color: Colors.white70)),
                trailing: Text("${r['dist']}km", style: TextStyle(color: Color(0xFF00FFF0))),
                onTap: () {
                     setState(() {
                         _currentRun = r;
                         _selectedIndex = 1;
                     });
                     ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Target set!")));
                },
            )).toList()
          ),
        );
      },
    );
  }
}