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
      if (_isSelfGoal) {
        double goalDist = double.parse(_goalDistanceController.text);
        double goalTime = double.parse(_goalTimeController.text);
        targetVDOT = _calculateVDOT(goalDist, goalTime);
      } else {
        targetVDOT = _calculateVDOT(10, userData['record_10k']);
      }
      userData['target_vdot'] = targetVDOT;
    } catch (e) {
      targetVDOT = 45.0; // 기본값
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
    
    // ⚠️ 로컬 알고리즘 폴백
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
        "runs": _generateWeekRuns(i, totalWeeks, intensity, easyPace, tempoPace, intervalPace),
      });
    }

    setState(() {
      _plan = newPlan;
      _isGenerating = false;
      _selectedIndex = 2;
    });
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('🎯 로컬 플랜 생성 완료! (VDOT: ${targetVDOT.toStringAsFixed(1)})'),
        backgroundColor: Colors.orange,
      ),
    );
  }
  
  // Helper: 영어 요일 → 한글
  String _translateDay(String day) {
    const days = {
      'Mon': '월', 'Tue': '화', 'Wed': '수', 'Thu': '목',
      'Fri': '금', 'Sat': '토', 'Sun': '일'
    };
    return days[day] ?? day;
  }
