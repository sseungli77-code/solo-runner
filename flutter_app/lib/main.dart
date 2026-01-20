
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
// import 'package:flutter_naver_map/flutter_naver_map.dart'; 
import 'package:permission_handler/permission_handler.dart';

const String _geminiKey = 'AIzaSyBtEtujomeYnJUc5ZlEi7CteLmapaEZ4MY'; 
const String _serverUrl = 'https://solo-runner-api.onrender.com';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
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
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF090910), 
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF00FFF0), 
          secondary: Color(0xFFFF0055), 
          surface: Color(0xFF1E1E2C),
          background: Color(0xFF090910),
        ),
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
  
  // Controllers
  final TextEditingController _heightController = TextEditingController(text: "175");
  final TextEditingController _weightController = TextEditingController(text: "70");
  final TextEditingController _weeklyController = TextEditingController(text: "120");
  final TextEditingController _recordController = TextEditingController(text: "60");
  
  // Self Goal Controllers (Restored)
  final TextEditingController _goalDistanceController = TextEditingController(text: "5");
  final TextEditingController _goalTimeController = TextEditingController(text: "30");
  
  String _level = "beginner";
  bool _useSelfGoal = false; // Toggle state
  
  List<Map<String, dynamic>> _plan = [];
  bool _isGenerating = false;
  Map<String, dynamic>? _currentRun;
  
  Map<String, dynamic> _trainingProgress = {
    'completedRuns': [], 'missedDays': 0, 'currentVDOT': 0.0, 'lastCalculatedVDOT': 0.0, 'weeklyCompletionRate': 0.0,
  };

  late GenerativeModel _geminiModel;
  final FlutterTts _tts = FlutterTts();
  bool _isVoiceOn = true;
  
  // Running State (Real GPS Logic)
  bool _isRunning = false;
  double _distKm = 0.0;
  String _pace = "-'--\"";
  Timer? _timer;
  int _seconds = 0;
  StreamSubscription<Position>? _positionStream;
  Position? _lastPosition; // For distance calc

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
    await _tts.setPitch(1.0);
    await _tts.setSpeechRate(0.5);
  }
  
  Future<void> _saveData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('level', _level);
    await prefs.setString('height', _heightController.text);
    await prefs.setString('weight', _weightController.text);
    await prefs.setString('weekly', _weeklyController.text);
    await prefs.setString('record', _recordController.text);
    await prefs.setBool('useSelfGoal', _useSelfGoal);
    // Goals
    await prefs.setString('goalDist', _goalDistanceController.text);
    await prefs.setString('goalTime', _goalTimeController.text);

    if (_plan.isNotEmpty) await prefs.setString('training_plan', jsonEncode(_plan));
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
      _goalDistanceController.text = prefs.getString('goalDist') ?? "5";
      _goalTimeController.text = prefs.getString('goalTime') ?? "30";
      
      String? jsonPlan = prefs.getString('training_plan');
      if (jsonPlan != null) {
        List<dynamic> decoded = jsonDecode(jsonPlan);
        _plan = decoded.cast<Map<String, dynamic>>();
      }
      String? jsonProgress = prefs.getString('training_progress');
      if (jsonProgress != null) _trainingProgress = jsonDecode(jsonProgress);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter, end: Alignment.bottomCenter,
            colors: [Color(0xFF0F0F1E), Color(0xFF1A1A2E)],
          )
        ),
        child: PageView(
          controller: _pageController,
          onPageChanged: (index) => setState(() => _selectedIndex = index),
          physics: const NeverScrollableScrollPhysics(),
          children: [
            _buildSetupPage(),
            _buildRunPage(), 
            _buildPlanPage(),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: Colors.white.withOpacity(0.1), width: 0.5)),
          color: const Color(0xFF0F0F1E).withOpacity(0.95),
        ),
        child: BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: (index) {
            setState(() => _selectedIndex = index);
            _pageController.animateToPage(index, duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
          },
          backgroundColor: Colors.transparent,
          elevation: 0,
          selectedItemColor: const Color(0xFF00FFF0),
          unselectedItemColor: Colors.white38,
          selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          type: BottomNavigationBarType.fixed,
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.tune), label: 'SETUP'),
            BottomNavigationBarItem(icon: Icon(Icons.directions_run), label: 'RUN'),
            BottomNavigationBarItem(icon: Icon(Icons.calendar_month), label: 'PLAN'),
          ],
        ),
      ),
    );
  }

  // --- 1. SETUP PAGE (Restored Self Goal) ---
  Widget _buildSetupPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 60),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text("PROFILE", style: TextStyle(color: Color(0xFF00FFF0), fontSize: 14, letterSpacing: 2, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          const Text("LET'S GET\nSTARTED", style: TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.w900, height: 1.1)),
          const SizedBox(height: 40),
          
          _buildNeonInput("Height (cm)", _heightController),
          const SizedBox(height: 16),
          _buildNeonInput("Weight (kg)", _weightController),
          const SizedBox(height: 16),
          _buildNeonInput("Current 10k Record (min)", _recordController),
          const SizedBox(height: 16),
          _buildNeonInput("Weekly Available Time (min)", _weeklyController),
          const SizedBox(height: 30),
          
          // Fitness Level
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white24)),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _level, dropdownColor: const Color(0xFF1E1E2C), icon: const Icon(Icons.arrow_drop_down, color: Color(0xFF00FFF0)),
                items: ['beginner', 'intermediate', 'advanced'].map((l) => DropdownMenuItem(value: l, child: Text(l.toUpperCase(), style: const TextStyle(color: Colors.white, fontFamily: 'monospace')))).toList(),
                onChanged: (v) => setState(() => _level = v!),
              ),
            ),
          ),
          
          const SizedBox(height: 30),
          
          // --- Self Target Toggle (Restored) ---
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(16), border: Border.all(color: _useSelfGoal ? const Color(0xFF00FFF0) : Colors.white10)),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("Set Custom Goal", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    Switch(
                      value: _useSelfGoal, 
                      onChanged: (v) => setState(() => _useSelfGoal = v),
                      activeColor: const Color(0xFF00FFF0),
                      activeTrackColor: const Color(0xFF00FFF0).withOpacity(0.3),
                    )
                  ],
                ),
                if (_useSelfGoal) ...[
                  const SizedBox(height: 16),
                  _buildNeonInput("Target Distance (km)", _goalDistanceController),
                  const SizedBox(height: 10),
                  _buildNeonInput("Target Time (min)", _goalTimeController),
                ]
              ],
            ),
          ),
          
          const SizedBox(height: 30),
          ElevatedButton(
            onPressed: _isGenerating ? null : (_useSelfGoal ? _setSelfGoal : _generatePlan),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00FFF0),
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(vertical: 18),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
              shadowColor: const Color(0xFF00FFF0).withOpacity(0.5),
              elevation: 10,
            ),
            child: _isGenerating 
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2))
              : Text(_useSelfGoal ? "START CUSTOM RUN" : "GENERATE AI PLAN", style: const TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.5, fontSize: 16)),
          )
        ],
      ),
    );
  }
  
  void _setSelfGoal() {
     setState(() {
       _currentRun = {
         'type': 'Custom Run',
         'dist': double.tryParse(_goalDistanceController.text) ?? 5.0,
         'desc': 'Target: ${_goalTimeController.text} min',
         'completed': false
       };
       _selectedIndex = 1; // Move to Run
     });
     _saveData();
     ScaffoldMessenger.of(context).showSnackBar(const SnackBar(backgroundColor: Color(0xFF00FFF0), content: Text("Custom Goal Set!", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black))));
  }

  // --- Run Page & REAL GPS Logic ---
  Widget _buildRunPage() {
    String timeStr = "${(_seconds~/60).toString().padLeft(2,'0')}:${(_seconds%60).toString().padLeft(2,'0')}";
    
    return Stack(
      children: [
        // Map Placeholder 
        Container(
          decoration: const BoxDecoration(
            color: Color(0xFF0F0F1E),
            image: DecorationImage(image: NetworkImage("https://upload.wikimedia.org/wikipedia/commons/e/ec/World_map_blank_without_borders.png"), opacity: 0.1, fit: BoxFit.cover)
          ),
          child: const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.map, size: 40, color: Colors.white12), SizedBox(height: 10), Text("Map View Disabled", style: TextStyle(color: Colors.white24))])),
        ),
        
        Positioned.fill(child: Container(decoration: BoxDecoration(gradient: LinearGradient(colors: [Colors.black.withOpacity(0.7), Colors.transparent, Colors.black.withOpacity(0.8)], begin: Alignment.topCenter, end: Alignment.bottomCenter, stops: const [0.0, 0.4, 0.8])))),
        
        // Top Info
        Positioned(
          top: 60, left: 0, right: 0,
          child: Column(children: [
              Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), decoration: BoxDecoration(color: _isRunning ? const Color(0xFFFF0055) : const Color(0xFF00FFF0), borderRadius: BorderRadius.circular(20)), child: Text(_isRunning ? "RUNNING" : "READY", style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 1.2))),
              const SizedBox(height: 20),
              Text(timeStr, style: const TextStyle(fontSize: 80, fontWeight: FontWeight.normal, color: Colors.white, fontFamily: 'monospace', letterSpacing: -2)),
              const Text("DURATION", style: TextStyle(color: Colors.white30, fontSize: 12, letterSpacing: 2)),
          ])
        ),
        
        // Bottom Stats
        Positioned(
          bottom: 40, left: 24, right: 24,
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(color: const Color(0xFF1E1E2C).withOpacity(0.8), borderRadius: BorderRadius.circular(30), border: Border.all(color: Colors.white.withOpacity(0.1)), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 20, spreadRadius: 5)]),
            child: Column(children: [
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    _buildNeonStatItem("DISTANCE", "${_distKm.toStringAsFixed(2)}", "km"),
                    Container(width: 1, height: 40, color: Colors.white24),
                    _buildNeonStatItem("AVG PACE", _pace, "/km"),
                ]),
                const SizedBox(height: 30),
                GestureDetector(onTap: _toggleRun, child: Container(width: 72, height: 72, decoration: BoxDecoration(shape: BoxShape.circle, color: _isRunning ? const Color(0xFFFF0055) : const Color(0xFF00FFF0), boxShadow: [BoxShadow(color: (_isRunning ? const Color(0xFFFF0055) : const Color(0xFF00FFF0)).withOpacity(0.4), blurRadius: 15, spreadRadius: 2)]), child: Icon(_isRunning ? Icons.pause : Icons.play_arrow, color: Colors.black, size: 36))),
            ])
          )
        )
      ],
    );
  }
  
  // REAL GPS Logic (Cleaned up)
  void _toggleRun() async {
    if (_isRunning) {
        // STOP
        _timer?.cancel();
        _positionStream?.cancel();
        setState(() => _isRunning = false);
        _saveData();
    } else {
        // START
        LocationPermission permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) {
          permission = await Geolocator.requestPermission();
          if (permission == LocationPermission.denied) return;
        }

        setState(() { _isRunning = true; _seconds = 0; _distKm = 0.0; _lastPosition = null; });
        
        // Timer for duration only (No Mock Distance!)
        _timer = Timer.periodic(const Duration(seconds: 1), (t) { 
           if (mounted) setState(() => _seconds++); 
        });

        // Real GPS Stream
        const LocationSettings locationSettings = LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 5);
        _positionStream = Geolocator.getPositionStream(locationSettings: locationSettings).listen((Position position) {
            if (_lastPosition != null) {
               double distMeters = Geolocator.distanceBetween(_lastPosition!.latitude, _lastPosition!.longitude, position.latitude, position.longitude);
               // Filter weird jumps (e.g. > 50m in 1 sec)
               if (distMeters > 0 && distMeters < 100) {
                 setState(() {
                   _distKm += distMeters / 1000.0;
                   if (_distKm > 0) {
                      double totalMinutes = _seconds / 60.0;
                      double paceVal = totalMinutes / _distKm;
                      int pMin = paceVal.floor();
                      int pSec = ((paceVal - pMin) * 60).round();
                      _pace = "$pMin'${pSec.toString().padLeft(2,'0')}\"";
                   }
                 });
               }
            }
            _lastPosition = position;
        });
    }
  }

  // Common UI & Logic
  Widget _buildNeonInput(String label, TextEditingController controller) {
    return TextField(
      controller: controller,
      style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white54),
        filled: true, fillColor: Colors.white.withOpacity(0.05),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.white.withOpacity(0.1))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF00FFF0))),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      ),
    );
  }
  
  Widget _buildNeonStatItem(String label, String value, String unit) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(color: Colors.white38, fontSize: 10, letterSpacing: 1.5, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
             Text(value, style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold, fontFamily: 'monospace')),
             const SizedBox(width: 4),
             Text(unit, style: const TextStyle(color: Color(0xFF00FFF0), fontSize: 12, fontWeight: FontWeight.bold)),
        ])
    ]);
  }
  
  // Plan Page & Logic
  Widget _buildPlanPage() {
    if (_plan.isEmpty) return const Center(child: Text("Generate a Plan first", style: TextStyle(color: Colors.white24)));
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 60, 20, 100),
      itemCount: _plan.length,
      itemBuilder: (ctx, idx) {
        final week = _plan[idx];
        return Card(color: Colors.white10, child: ExpansionTile(
          title: Text("Week ${week['week']}", style: const TextStyle(color: Colors.white)),
          children: (week['runs'] as List).map<Widget>((r) => ListTile(
            title: Text(r['type'], style: const TextStyle(color: Colors.white)),
            trailing: Text("${r['dist']}km", style: const TextStyle(color: Color(0xFF00FFF0))),
            onTap: () { setState(() => _currentRun = r); _selectedIndex = 1; },
          )).toList()
        ));
      }
    );
  }

  Future<void> _generatePlan() async {
    setState(() => _isGenerating = true);
    // Server & Local Fallback (BMI Logic Included)
    _generatePlanLocal(); // For stability, just calling local directly or server if needed
  }
  
  void _generatePlanLocal() {
    // ... (Same BMI Logic from before) ...
    double h = double.tryParse(_heightController.text) ?? 175;
    double w = double.tryParse(_weightController.text) ?? 70;
    double bmi = w / ((h/100)*(h/100));
    double volMod = 1.0;
    if (bmi >= 25) volMod = 0.8; // Example logic

    List<Map<String, dynamic>> newPlan = [];
    for (int i = 1; i <= 12; i++) {
        newPlan.add({'week': i, 'focus': 'Foundations', 'runs': [
           {'day': 'Tue', 'type': 'Easy', 'dist': 3.0 * volMod, 'completed': false},
           {'day': 'Thu', 'type': 'Tempo', 'dist': 4.0 * volMod, 'completed': false},
           {'day': 'Sat', 'type': 'Long', 'dist': 6.0 * volMod, 'completed': false},
        ]});
    }
    setState(() { _plan = newPlan; _isGenerating = false; _selectedIndex = 2; });
    _saveData();
  }
}