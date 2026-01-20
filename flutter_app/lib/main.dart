
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';

// Screens
import 'screens/setup_screen.dart';
import 'screens/run_screen.dart';
import 'screens/plan_screen.dart';
import 'services/plan_service.dart';

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
  final FlutterTts _tts = FlutterTts();

  // Data State
  Map<String, dynamic> _userData = {}; // height, weight, etc.
  List<Map<String, dynamic>> _plan = [];
  Map<String, dynamic> _trainingProgress = {
    'completedRuns': [], 'missedDays': 0, 'currentVDOT': 0.0, 'lastCalculatedVDOT': 0.0, 'weeklyCompletionRate': 0.0,
  };
  
  bool _isGenerating = false;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _initTTS();
    _loadData();
  }

  void _initTTS() async {
    await _tts.setLanguage("ko-KR");
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _userData = {
        'level': prefs.getString('level'),
        'height': prefs.getString('height'),
        'weight': prefs.getString('weight'),
        'weekly': prefs.getString('weekly'),
        'record': prefs.getString('record'),
        'useSelfGoal': prefs.getBool('useSelfGoal'),
        'goalDist': prefs.getString('goalDist'),
        'goalTime': prefs.getString('goalTime'),
      };

      String? jsonPlan = prefs.getString('training_plan');
      if (jsonPlan != null) {
        List<dynamic> decoded = jsonDecode(jsonPlan);
        _plan = decoded.cast<Map<String, dynamic>>();
      }
      String? jsonProgress = prefs.getString('training_progress');
      if (jsonProgress != null) _trainingProgress = jsonDecode(jsonProgress);
    });
  }

  Future<void> _saveData() async {
    final prefs = await SharedPreferences.getInstance();
    _userData.forEach((k, v) {
       if(v is String) prefs.setString(k, v);
       if(v is bool) prefs.setBool(k, v);
    });
    if (_plan.isNotEmpty) await prefs.setString('training_plan', jsonEncode(_plan));
    await prefs.setString('training_progress', jsonEncode(_trainingProgress));
  }

  // Logic: Plan Generation
  Future<void> _generatePlan(Map<String, dynamic> inputData) async {
    setState(() { _userData.addAll(inputData); _isGenerating = true; });
    
    // Server Call
    try {
      final reqBody = {
        'level': inputData['level'],
        'current_10k_record': double.tryParse(inputData['record']) ?? 60.0,
        'weekly_minutes': int.tryParse(inputData['weekly']) ?? 120,
        'height': double.tryParse(inputData['height']) ?? 175.0,
        'weight': double.tryParse(inputData['weight']) ?? 70.0,
      };
      
      final response = await http.post(
        Uri.parse('$_serverUrl/generate_plan'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(reqBody),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        setState(() {
          _plan = List<Map<String, dynamic>>.from(data['plan']);
          _isGenerating = false;
          _selectedIndex = 2; // Go to Plan
        });
        _pageController.animateToPage(2, duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
        _saveData();
        return;
      }
    } catch (e) { print("Server Error: $e"); }

    // Fallback Logic (Local)
    _generatePlanLocal(inputData);
  }

  // Fallback Logic (Local) with PlanService
  void _generatePlanLocal(Map<String, dynamic> inputData) {
    final PlanService planService = PlanService();
    final newPlan = planService.generatePlan(
      level: inputData['level'],
      heightCm: double.tryParse(inputData['height']) ?? 175.0,
      weightKg: double.tryParse(inputData['weight']) ?? 70.0,
      record10k: double.tryParse(inputData['record']) ?? 60.0,
      weeklyMinutes: int.tryParse(inputData['weekly']) ?? 120,
    );

    setState(() { _plan = newPlan; _isGenerating = false; _selectedIndex = 2; });
    _pageController.animateToPage(2, duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
    _saveData();
  }

  void _handleSelfGoal(Map<String, dynamic> inputData) {
      setState(() { _userData.addAll(inputData); _selectedIndex = 1; });
      _pageController.animateToPage(1, duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
      _saveData();
  }
  
  void _handleRunSave(Map<String, dynamic> runResult) {
     // Save run logic
     setState(() {
        if (_trainingProgress['completedRuns'] == null) _trainingProgress['completedRuns'] = [];
        (_trainingProgress['completedRuns'] as List).add(runResult);
     });
     _saveData();
     ScaffoldMessenger.of(context).showSnackBar(const SnackBar(backgroundColor: Color(0xFF00FFF0), content: Text("Run Saved Successfully!", style: TextStyle(color: Colors.black))));
  }

  @override
  Widget build(BuildContext context) {
    if (_userData.isEmpty) return const Scaffold(body: Center(child: CircularProgressIndicator())); // Loading

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
          physics: const NeverScrollableScrollPhysics(),
          onPageChanged: (index) => setState(() => _selectedIndex = index),
          children: [
            SetupScreen(
                initialData: _userData, 
                isGenerating: _isGenerating,
                onGeneratePlan: _generatePlan,
                onSetSelfGoal: _handleSelfGoal
            ),
            RunScreen(
                onSaveRun: _handleRunSave
            ),
            PlanScreen(
                plan: _plan, 
                progress: _trainingProgress,
                onRunSelect: (run) {
                    setState(() => _selectedIndex = 1);
                    _pageController.animateToPage(1, duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
                }
            ),
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
}