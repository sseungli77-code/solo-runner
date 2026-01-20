# SoloRunner 모듈화 가이드

**목표:** main.dart (1480 lines) → 여러 작은 파일로 분리

---

## 🎯 Step-by-Step 모듈화 계획

### Phase 1: 폴더 구조 생성

**VSCode에서 폴더 생성:**
```
flutter_app/lib/
├── main.dart (새로 작성, ~100 lines)
├── screens/
│   ├── setup_screen.dart
│   ├── run_screen.dart
│   └── plan_screen.dart
├── widgets/
│   └── (나중에)
└── services/
    └── (나중에)
```

**터미널 명령어:**
```bash
cd flutter_app/lib
mkdir screens
mkdir widgets
mkdir services
```

---

## 📝 Phase 2: Setup Screen 분리

### Step 1: 파일 생성

**파일:** `flutter_app/lib/screens/setup_screen.dart`

**내용:**
```dart
import 'package:flutter/material.dart';

class SetupScreen extends StatefulWidget {
  final Function(Map<String, dynamic>) onSetupComplete;
  
  const SetupScreen({Key? key, required this.onSetupComplete}) : super(key: key);

  @override
  _SetupScreenState createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  // State variables
  String _level = 'beginner';
  bool _isSelfGoal = false;
  
  // Controllers
  final TextEditingController _heightController = TextEditingController(text: '175');
  final TextEditingController _weightController = TextEditingController(text: '70');
  final TextEditingController _weeklyController = TextEditingController(text: '120');
  final TextEditingController _recordController = TextEditingController(text: '60');
  final TextEditingController _goalDistController = TextEditingController(text: '5');
  final TextEditingController _goalTimeController = TextEditingController(text: '30');

  @override
  void dispose() {
    _heightController.dispose();
    _weightController.dispose();
    _weeklyController.dispose();
    _recordController.dispose();
    _goalDistController.dispose();
    _goalTimeController.dispose();
    super.dispose();
  }

  void _completeSetup() {
    widget.onSetupComplete({
      'level': _level,
      'isSelfGoal': _isSelfGoal,
      'height': _heightController.text,
      'weight': _weightController.text,
      'weekly': _weeklyController.text,
      'record': _recordController.text,
      'goalDist': _goalDistController.text,
      'goalTime': _goalTimeController.text,
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Setup'),
        backgroundColor: Colors.black,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF1A2A3A), Color(0xFF0F0F1E)],
          ),
        ),
        child: Center(
          child: Text(
            'Setup Screen (To be implemented)',
            style: TextStyle(color: Colors.white, fontSize: 24),
          ),
        ),
      ),
    );
  }
}
```

### Step 2: main.dart에서 import

**main.dart 상단에 추가:**
```dart
import 'screens/setup_screen.dart';
```

### Step 3: 테스트 & 커밋

```bash
git add lib/screens/setup_screen.dart lib/main.dart
git commit -m "refactor: Add SetupScreen skeleton"
git push origin main
```

**빌드 확인 후 다음 단계 진행!**

---

## 📝 Phase 3: Run Screen 분리

### Step 1: 파일 생성

**파일:** `flutter_app/lib/screens/run_screen.dart`

```dart
import 'package:flutter/material.dart';

class RunScreen extends StatefulWidget {
  const RunScreen({Key? key}) : super(key: key);

  @override
  _RunScreenState createState() => _RunScreenState();
}

class _RunScreenState extends State<RunScreen> {
  int _seconds = 0;
  double _distKm = 0.0;
  String _pace = "0'00\"";
  bool _isRunning = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF1A2A3A), Color(0xFF0F0F1E)],
          ),
        ),
        child: Center(
          child: Text(
            'Run Screen (To be implemented)',
            style: TextStyle(color: Colors.white, fontSize: 24),
          ),
        ),
      ),
    );
  }
}
```

---

## 📝 Phase 4: Plan Screen 분리

**파일:** `flutter_app/lib/screens/plan_screen.dart`

```dart
import 'package:flutter/material.dart';

class PlanScreen extends StatefulWidget {
  const PlanScreen({Key? key}) : super(key: key);

  @override
  _PlanScreenState createState() => _PlanScreenState();
}

class _PlanScreenState extends State<PlanScreen> {
  List<Map<String, dynamic>> _plan = [];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF1A2A3A), Color(0xFF0F0F1E)],
          ),
        ),
        child: Center(
          child: Text(
            'Plan Screen (To be implemented)',
            style: TextStyle(color: Colors.white, fontSize: 24),
          ),
        ),
      ),
    );
  }
}
```

---

## 📝 Phase 5: main.dart 간소화

**새로운 main.dart (100 lines):**

```dart
import 'package:flutter/material.dart';
import 'screens/setup_screen.dart';
import 'screens/run_screen.dart';
import 'screens/plan_screen.dart';

void main() {
  runApp(const SoloRunnerApp());
}

class SoloRunnerApp extends StatelessWidget {
  const SoloRunnerApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SOLO RUNNER',
      theme: ThemeData.dark(),
      home: const MainApp(),
    );
  }
}

class MainApp extends StatefulWidget {
  const MainApp({Key? key}) : super(key: key);

  @override
  _MainAppState createState() => _MainAppState();
}

class _MainAppState extends State<MainApp> {
  int _selectedIndex = 0;
  bool _setupComplete = false;

  void _onSetupComplete(Map<String, dynamic> data) {
    setState(() {
      _setupComplete = true;
      // Save setup data
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_setupComplete) {
      return SetupScreen(onSetupComplete: _onSetupComplete);
    }

    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: const [
          SetupScreen(onSetupComplete: null), // Temp
          RunScreen(),
          PlanScreen(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
        backgroundColor: Colors.black,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.tune), label: 'Setup'),
          BottomNavigationBarItem(icon: Icon(Icons.directions_run), label: 'Run'),
          BottomNavigationBarItem(icon: Icon(Icons.calendar_today), label: 'Plan'),
        ],
      ),
    );
  }
}
```

---

## ⚠️ 중요 주의사항

### **절대 하지 말 것:**
- ❌ PowerShell로 파일 수정
- ❌ 한 번에 모든 파일 변경
- ❌ 테스트 없이 커밋

### **반드시 할 것:**
- ✅ VSCode에서 파일 생성
- ✅ 한 화면씩 분리
- ✅ 각 단계마다 빌드 테스트
- ✅ 작은 커밋

---

## 🎯 실제 구현 순서

### **이번 세션 (2-3시간):**

1. ✅ **폴더 생성** (5분)
   ```bash
   mkdir lib/screens lib/widgets lib/services
   ```

2. ✅ **SetupScreen Skeleton** (30분)
   - 파일 생성
   - 기본 구조만
   - Import 추가
   - 빌드 테스트 ← **중요!**

3. ✅ **RunScreen Skeleton** (30분)
   - 파일 생성
   - 기본 구조만
   - 빌드 테스트

4. ✅ **PlanScreen Skeleton** (30분)
   - 파일 생성
   - 기본 구조만
   - 빌드 테스트

5. ✅ **main.dart 간소화** (30분)
   - screens import
   - IndexedStack 사용
   - 빌드 테스트

### **다음 세션:**
6. SetupScreen 실제 UI 이동
7. RunScreen 실제 UI 이동
8. PlanScreen 실제 UI 이동

---

## 📊 Progress Tracking

- [ ] 폴더 생성
- [ ] SetupScreen skeleton
- [ ] RunScreen skeleton
- [ ] PlanScreen skeleton
- [ ] main.dart 간소화
- [ ] Build #86 성공
- [ ] SetupScreen full UI
- [ ] RunScreen full UI
- [ ] PlanScreen full UI
- [ ] 모듈화 완료

---

**지금 시작할까요?** 🚀

첫 단계: VSCode에서 폴더 생성부터!
