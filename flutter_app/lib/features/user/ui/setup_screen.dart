
import 'package:flutter/material.dart';

class SetupScreen extends StatefulWidget {
  final Map<String, dynamic> initialData;
  final Function(Map<String, dynamic>) onGeneratePlan;
  final Function(Map<String, dynamic>) onSetSelfGoal;
  final bool isGenerating;

  const SetupScreen({
    super.key, 
    required this.initialData,
    required this.onGeneratePlan,
    required this.onSetSelfGoal,
    required this.isGenerating,
  });

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  late TextEditingController _heightController;
  late TextEditingController _weightController;
  late TextEditingController _weeklyController;
  late TextEditingController _recordController;
  
  // Self Goal
  late TextEditingController _goalDistanceController;
  late TextEditingController _goalTimeController;
  
  String _level = "beginner";
  bool _useSelfGoal = false;

  @override
  void initState() {
    super.initState();
    _heightController = TextEditingController(text: widget.initialData['height'] ?? "175");
    _weightController = TextEditingController(text: widget.initialData['weight'] ?? "70");
    _weeklyController = TextEditingController(text: widget.initialData['weekly'] ?? "120");
    _recordController = TextEditingController(text: widget.initialData['record'] ?? "60");
    _goalDistanceController = TextEditingController(text: widget.initialData['goalDist'] ?? "5");
    _goalTimeController = TextEditingController(text: widget.initialData['goalTime'] ?? "30");
    _level = widget.initialData['level'] ?? "beginner";
    _useSelfGoal = widget.initialData['useSelfGoal'] ?? false;
  }
  
  @override
  Widget build(BuildContext context) {
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
          
          // Self Target Toggle
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
            onPressed: widget.isGenerating ? null : _handleAction,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00FFF0),
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(vertical: 18),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
              shadowColor: const Color(0xFF00FFF0).withOpacity(0.5),
              elevation: 10,
            ),
            child: widget.isGenerating 
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2))
              : Text(_useSelfGoal ? "START CUSTOM RUN" : "GENERATE AI PLAN", style: const TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.5, fontSize: 16)),
          )
        ],
      ),
    );
  }
  
  void _handleAction() {
    final data = {
        'level': _level,
        'height': _heightController.text,
        'weight': _weightController.text,
        'weekly': _weeklyController.text,
        'record': _recordController.text,
        'useSelfGoal': _useSelfGoal,
        'goalDist': _goalDistanceController.text,
        'goalTime': _goalTimeController.text,
    };

    if (_useSelfGoal) {
        widget.onSetSelfGoal(data);
    } else {
        widget.onGeneratePlan(data);
    }
  }

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
}
