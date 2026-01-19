## Critical Features Implementation Plan

### 1️⃣ 데이터 지속성 (Data Persistence)

**추가할 Import:**
```dart
import 'package:shared_preferences/shared_preferences.dart';
```

**추가할 함수들:**

```dart
// 📦 플랜 저장
Future<void> _savePlan() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString('plan', json.encode(_plan));
  print("✅ Plan saved");
}

// 📦 플랜 불러오기
Future<void> _loadPlan() async {
  final prefs = await SharedPreferences.getInstance();
  final planJson = prefs.getString('plan');
  if (planJson != null) {
    setState(() {
      _plan = List<Map<String, dynamic>>.from(json.decode(planJson));
    });
    print("✅ Plan loaded: ${_plan.length} weeks");
  }
}

// 📦 프로필 저장
Future<void> _saveProfile() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString('height', _heightController.text);
  await prefs.setString('weight', _weightController.text);
  await prefs.setString('weekly', _weeklyController.text);
  await prefs.setString('record', _recordController.text);
  await prefs.setString('level', _level);
  print("✅ Profile saved");
}

// 📦 프로필 불러오기
Future<void> _loadProfile() async {
  final prefs = await SharedPreferences.getInstance();
  setState(() {
    _heightController.text = prefs.getString('height') ?? '175';
    _weightController.text = prefs.getString('weight') ?? '70';
    _weeklyController.text = prefs.getString('weekly') ?? '120';
    _recordController.text = prefs.getString('record') ?? '60';
    _level = prefs.getString('level') ?? 'beginner';
  });
  print("✅ Profile loaded");
}
```

**initState 수정:**
```dart
@override
void initState() {
  super.initState();
  _pageController = PageController(initialPage: _selectedIndex);
  _initTTS();
  
  // Gemini 모델 초기화
  _geminiModel = GenerativeModel(model: 'gemini-pro', apiKey: _geminiKey);
  
  // 📦 데이터 불러오기
  _loadProfile();
  _loadPlan();
  
  // 앱 시작 시 누락된 훈련 확인
  Future.delayed(const Duration(seconds: 2), () {
    if (_plan.isNotEmpty) {
      _checkMissedTraining();
    }
  });
}
```

**_generatePlan 수정 (플랜 생성 후 저장):**
```dart
// 기존 setState 후에 추가:
_savePlan();
```

**_uploadRunData 수정 (런닝 완료 후 저장):**
```dart
// 플랜 업데이트 후에 추가:
_savePlan();
```

---

### 2️⃣ 플랜 완료 로직

**추가할 함수들:**

```dart
// 📅 주간 완료 확인
bool _isWeekCompleted(Map<String, dynamic> week) {
  List runs = week['runs'] ?? [];
  if (runs.isEmpty) return false;
  
  int completed = runs.where((r) => r['completed'] == true).length;
  return completed == runs.length;
}

// 📅 다음 주로 이동
void _moveToNextWeek() {
  if (_plan.isEmpty) return;
  
  var currentWeek = _plan.first;
  if (_isWeekCompleted(currentWeek)) {
    setState(() {
      currentWeek['completed'] = true;
      // 다음 주를 맨 위로
      _plan.removeAt(0);
      _plan.add(currentWeek); // 완료된 주는 뒤로
      
      _savePlan();
    });
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('🎉 ${currentWeek['week']}주차 완료! 다음 주차로 이동합니다'),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 3),
      ),
    );
  }
}

// 📅 전체 플랜 완료 확인
void _checkPlanCompletion() {
  if (_plan.isEmpty) return;
  
  bool allCompleted = _plan.every((week) => _isWeekCompleted(week));
  
  if (allCompleted) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Color(0xFF1A2A3A),
        title: Row(
          children: [
            Icon(Icons.celebration, color: Color(0xFF00FFF0), size: 30),
            SizedBox(width: 12),
            Text('🎉 플랜 완료!', style: TextStyle(color: Colors.white)),
          ],
        ),
        content: Text(
          '축하합니다! 전체 훈련 플랜을 완료했습니다.\n\n새로운 목표를 설정하시겠어요?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('나중에', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _resetPlan();
              _selectedIndex = 0; // Setup 페이지로
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Color(0xFF00FFF0),
              foregroundColor: Color(0xFF0F0F1E),
            ),
            child: Text('새 플랜 생성', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}

// 🔄 플랜 리셋
Future<void> _resetPlan() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.remove('plan');
  
  setState(() {
    _plan = [];
    _currentRun = null;
  });
  
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('플랜이 초기화되었습니다'), backgroundColor: Colors.orange),
  );
}
```

**_uploadRunData 수정 (주간 완료 체크 추가):**
```dart
// 플랜 업데이트 후에 추가:
_moveToNextWeek();
_checkPlanCompletion();
```

---

### 3️⃣ GPS 정확도 개선

**GPS 신호 약할 때 처리:**
```dart
void _checkGPSAccuracy(Position position) {
  if (position.accuracy > 20) { // 20m 이상 오차
    setState(() {
      _gpsStatus = "⚠️ GPS 신호 약함";
    });
  } else if (position.accuracy > 10) {
    setState(() {
      _gpsStatus = "📶 GPS 보통";
    });
  } else {
    setState(() {
      _gpsStatus = "✅ GPS 양호";
    });
  }
}
```

**배터리 최적화:**
```dart
// GPS 설정 개선
LocationSettings locationSettings;
if (Platform.isAndroid) {
  locationSettings = AndroidSettings(
    accuracy: LocationAccuracy.high, // bestForNavigation에서 high로 변경
    distanceFilter: 5, // 2m에서 5m로 변경 (배터리 절약)
    forceLocationManager: true,
    intervalDuration: const Duration(milliseconds: 2000), // 1초에서 2초로
  );
} else if (Platform.isIOS) {
  locationSettings = AppleSettings(
    accuracy: LocationAccuracy.high, // bestForNavigation에서 high로 변경
    distanceFilter: 5,
    pauseLocationUpdatesAutomatically: true, // 배터리 절약
    activityType: ActivityType.fitness,
  );
} else {
  locationSettings = LocationSettings(
    accuracy: LocationAccuracy.high,
    distanceFilter: 5,
  );
}
```

**GPS 끊김 처리:**
```dart
// 위치 스트림 구독 시 에러 처리 추가
_positionStream = Geolocator.getPositionStream(
  locationSettings: locationSettings
).listen(
  (Position position) {
    // 기존 로직
  },
  onError: (e) {
    print("GPS Error: $e");
    setState(() {
      _gpsStatus = "❌ GPS 오류";
    });
  },
  cancelOnError: false, // 에러 발생 시에도 계속 수신
);
```

---

## 🎯 구현 방법

이 코드들을 main.dart에 추가해야 합니다. 파일이 크고 인코딩 문제가 있어서, 다음 방법 중 선택하세요:

1. **새 파일로 다시 작성** (안전, 시간 오래 걸림)
2. **PowerShell로 수동 추가** (빠름, 실수 가능)
3. **작은 단위로 나눠서 추가** (안전하지만 여러 단계)

어떤 방법으로 진행할까요?
