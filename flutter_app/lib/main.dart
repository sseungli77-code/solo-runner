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
  Map<String, dynamic>? _currentRun;
  
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
          NavigationDestination(icon: Icon(Icons.settings), label: 'Setup'),
          NavigationDestination(icon: Icon(Icons.directions_run), label: 'Run'),
          NavigationDestination(icon: Icon(Icons.calendar_month), label: 'Plan'),
        ],
      ),
    );
  }

  // --- 1. SETUP PAGE ---
  Widget _buildSetupPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 20),
          const Text("SOLO RUNNER", 
            style: TextStyle(fontSize: 40, fontWeight: FontWeight.bold, color: Colors.white),
            textAlign: TextAlign.center,
          ),
          const Text("Native Flutter Edition", 
            style: TextStyle(color: Colors.white70), 
            textAlign: TextAlign.center
          ),
          const SizedBox(height: 40),
          Row(children: [
            Expanded(child: _buildInput("Height (cm)", _heightController)),
            const SizedBox(width: 10),
            Expanded(child: _buildInput("Weight (kg)", _weightController)),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: _buildInput("Weekly Vol (min)", _weeklyController)),
            const SizedBox(width: 10),
            Expanded(child: _buildInput("10km Rec (min)", _recordController)),
          ]),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(10)),
            child: Column(children: [
              RadioListTile(value: "beginner", groupValue: _level, onChanged: (v){setState(()=>_level=v.toString());}, title: const Text("Beginner (12w)")),
              RadioListTile(value: "intermediate", groupValue: _level, onChanged: (v){setState(()=>_level=v.toString());}, title: const Text("Intermediate (24w)")),
              RadioListTile(value: "advanced", groupValue: _level, onChanged: (v){setState(()=>_level=v.toString());}, title: const Text("Advanced (48w)")),
            ]),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _isGenerating ? null : _generatePlan,
            style: ElevatedButton.styleFrom(padding: const EdgeInsets.all(20)),
            child: Text(_isGenerating ? "Generating..." : "Generate AI Plan"),
          )
        ],
      ),
    );
  }

  Widget _buildInput(String label, TextEditingController ctrl) {
    return TextField(
      controller: ctrl,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(labelText: label, border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))),
    );
  }

  void _generatePlan() async {
    setState(() => _isGenerating = true);
    await Future.delayed(const Duration(seconds: 1)); // Simulating AI
    
    // Simple Logic Port
    double w = double.tryParse(_weightController.text) ?? 70;
    double h = (double.tryParse(_heightController.text) ?? 175) / 100;
    double bmi = w / (h*h);
    
    List<Map<String, dynamic>> newPlan = [];
    for(int i=1; i<=12; i++) {
        newPlan.add({
          "week": i,
          "focus": i < 5 ? "Base Building" : "Strength",
          "runs": [
             {"day": "Tue", "type": "Easy", "dist": 3 + (i*0.5)},
             {"day": "Thu", "type": "Interval", "dist": 4},
             {"day": "Sat", "type": "LSD", "dist": 5 + i},
          ]
        });
    }

    setState(() {
      _plan = newPlan;
      _isGenerating = false;
      _selectedIndex = 2; // Go to Plan
    });
    
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Plan Generated!")));
  }

  // --- 2. RUN PAGE (With GPS) ---
  bool _isRunning = false;
  String _gpsStatus = "Waiting for GPS...";
  double _distKm = 0.0;
  String _pace = "-'--\"";
  Timer? _timer;
  int _seconds = 0;
  StreamSubscription<Position>? _positionStream;

  Widget _buildRunPage() {
    String timeStr = "${(_seconds~/60).toString().padLeft(2,'0')}:${(_seconds%60).toString().padLeft(2,'0')}";
    
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
           Text(_isRunning ? "RUNNING" : "READY", style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.tealAccent)),
           const SizedBox(height: 10),
           Text(timeStr, style: const TextStyle(fontSize: 80, fontFamily: 'monospace', fontWeight: FontWeight.bold)),
           const SizedBox(height: 20),
           Text("Dist: ${_distKm.toStringAsFixed(2)} km", style: const TextStyle(fontSize: 24)),
           Text("Pace: $_pace /km", style: const TextStyle(fontSize: 20, color: Colors.grey)),
           const SizedBox(height: 10),
           Text(_gpsStatus, style: const TextStyle(fontSize: 12, color: Colors.grey)),
           const SizedBox(height: 40),
           IconButton(
             icon: Icon(_isRunning ? Icons.pause_circle_filled : Icons.play_circle_filled),
             iconSize: 100,
             color: _isRunning ? Colors.red : Colors.teal,
             onPressed: _toggleRun,
           )
        ],
      ),
    );
  }

  void _toggleRun() async {
    if (_isRunning) {
      // Stop
      _timer?.cancel();
      _positionStream?.cancel();
      setState(() => _isRunning = false);
    } else {
      // Start
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return;
      }
      
      setState(() {
        _isRunning = true;
        _seconds = 0;
        _distKm = 0;
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
                  if (d > 0.002) { // Filter jitter
                      setState(() {
                          _distKm += d;
                          // Calc pace
                          double paceVal = (_seconds / 60) / _distKm;
                          int pm = paceVal.toInt();
                          int ps = ((paceVal - pm) * 60).toInt();
                          _pace = "$pm'${ps.toString().padLeft(2,'0')}\"";
                          _gpsStatus = "GPS Active: Acc ${position.accuracy.toInt()}m";
                      });
                  }
              }
              lastPos = position;
          }
      });
    }
  }

  // --- 3. PLAN PAGE ---
  Widget _buildPlanPage() {
    if (_plan.isEmpty) {
        return const Center(child: Text("No Plan Generated Yet. Go to Setup."));
    }
    return ListView.builder(
      itemCount: _plan.length,
      itemBuilder: (ctx, i) {
        var week = _plan[i];
        return Card(
          margin: const EdgeInsets.all(10),
          child: ExpansionTile(
            title: Text("Week ${week['week']} - ${week['focus']}"),
            children: (week['runs'] as List).map<Widget>((r) => ListTile(
               leading: CircleAvatar(child: Text(r['day'][0])),
               title: Text(r['type']),
               trailing: Text("${r['dist']} km"),
               onTap: () {
                 // Select run logic
                 setState(() => _selectedIndex = 1); // Go to Run to simulate verify
               },
            )).toList(),
          ),
        );
      },
    );
  }
}