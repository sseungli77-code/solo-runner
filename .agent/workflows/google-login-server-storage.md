# Google Login + Server Storage Architecture

## 🏗️ 시스템 아키텍처

### Flow:
```
[사용자] → [Google Login] → [Supabase Auth] → [User Profile] → [앱 사용]
                                    ↓
                            [run_logs, plans, profiles]
                                    ↓
                            [멀티 디바이스 동기화]
```

---

## 📦 필요한 패키지

**pubspec.yaml:**
```yaml
dependencies:
  google_sign_in: ^6.1.5
  # 또는 Supabase Auth 사용 (이미 있음)
```

---

## 🔐 1. Supabase Auth 설정 (추천)

**장점:**
- 이미 Supabase 사용 중
- Google OAuth 내장
- 추가 설정 간단

**Supabase Dashboard 설정:**
1. Authentication → Providers → Google
2. Client ID, Secret 입력 (Google Cloud Console)
3. Redirect URL 설정

**코드:**
```dart
// 로그인
Future<void> _signInWithGoogle() async {
  try {
    final response = await Supabase.instance.client.auth.signInWithOAuth(
      Provider.google,
      redirectTo: 'io.supabase.solorunner://login-callback', // Deep link
    );
    
    if (response) {
      // 로그인 성공
      final user = Supabase.instance.client.auth.currentUser;
      setState(() {
        _userId = user!.id;
        _userEmail = user.email;
      });
    }
  } catch (e) {
    print('Login error: $e');
  }
}

// 로그아웃
Future<void> _signOut() async {
  await Supabase.instance.client.auth.signOut();
  setState(() {
    _userId = null;
    _userEmail = null;
  });
}

// 현재 사용자 확인
void _checkAuth() {
  final user = Supabase.instance.client.auth.currentUser;
  if (user != null) {
    setState(() {
      _userId = user.id;
      _userEmail = user.email;
    });
  }
}
```

---

## 🗄️ 2. 데이터베이스 구조 (Supabase)

### Tables:

**users (프로필)**
```sql
CREATE TABLE users (
  id UUID PRIMARY KEY REFERENCES auth.users(id),
  email TEXT NOT NULL,
  display_name TEXT,
  photo_url TEXT,
  level TEXT DEFAULT 'beginner',
  height REAL,
  weight REAL,
  weekly_min INTEGER,
  record_10km REAL,
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);

-- RLS (Row Level Security)
ALTER TABLE users ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own profile"
  ON users FOR SELECT
  USING (auth.uid() = id);

CREATE POLICY "Users can update own profile"
  ON users FOR UPDATE
  USING (auth.uid() = id);
```

**run_logs (러닝 기록)**
```sql
CREATE TABLE run_logs (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID REFERENCES users(id) NOT NULL,
  date TIMESTAMP NOT NULL,
  distance_km REAL NOT NULL,
  duration_sec INTEGER NOT NULL,
  pace TEXT NOT NULL,
  training_type TEXT,
  target_pace REAL,
  completed BOOLEAN DEFAULT true,
  created_at TIMESTAMP DEFAULT NOW()
);

-- Index for fast queries
CREATE INDEX idx_run_logs_user_date ON run_logs(user_id, date DESC);

-- RLS
ALTER TABLE run_logs ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own runs"
  ON run_logs FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own runs"
  ON run_logs FOR INSERT
  WITH CHECK (auth.uid() = user_id);
```

**training_plans (훈련 플랜)**
```sql
CREATE TABLE training_plans (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID REFERENCES users(id) NOT NULL,
  plan_data JSONB NOT NULL, -- 전체 플랜 JSON
  level TEXT NOT NULL,
  total_weeks INTEGER NOT NULL,
  current_week INTEGER DEFAULT 1,
  target_vdot REAL,
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);

-- RLS
ALTER TABLE training_plans ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can manage own plans"
  ON training_plans FOR ALL
  USING (auth.uid() = user_id);
```

---

## 📱 3. Flutter App 변경사항

### State 추가:
```dart
class _MainAppState extends State<MainApp> {
  String? _userId;
  String? _userEmail;
  String? _userName;
  bool _isLoggedIn = false;
  
  // ... 기존 코드
}
```

### initState 수정:
```dart
@override
void initState() {
  super.initState();
  
  // Auth 확인
  _checkAuth();
  
  // Auth 변경 리스너
  Supabase.instance.client.auth.onAuthStateChange.listen((data) {
    final user = data.session?.user;
    setState(() {
      _isLoggedIn = user != null;
      _userId = user?.id;
      _userEmail = user?.email;
    });
    
    if (user != null) {
      _loadUserProfile();
      _loadUserPlan();
    }
  });
  
  // ... 기존 코드
}
```

### 런닝 데이터 저장 수정:
```dart
Future<void> _uploadRunData() async {
  if (_userId == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('로그인이 필요합니다'))
    );
    return;
  }
  
  try {
    final data = {
      'user_id': _userId, // 실제 user_id 사용
      'date': DateTime.now().toIso8601String(),
      'distance_km': double.parse(_distKm.toStringAsFixed(2)),
      'duration_sec': _seconds,
      'pace': _pace,
      'training_type': _currentRun?['type'],
      'target_pace': _currentRun?['targetPace'],
    };
    await Supabase.instance.client.from('run_logs').insert(data);
    
    // ... 기존 로직
  } catch (e) {
    print("Upload error: $e");
  }
}
```

### 프로필 저장/불러오기:
```dart
// 서버에 프로필 저장
Future<void> _saveUserProfile() async {
  if (_userId == null) return;
  
  final data = {
    'id': _userId,
    'email': _userEmail,
    'level': _level,
    'height': double.parse(_heightController.text),
    'weight': double.parse(_weightController.text),
    'weekly_min': int.parse(_weeklyController.text),
    'record_10km': double.parse(_recordController.text),
    'updated_at': DateTime.now().toIso8601String(),
  };
  
  await Supabase.instance.client
    .from('users')
    .upsert(data);
}

// 서버에서 프로필 불러오기
Future<void> _loadUserProfile() async {
  if (_userId == null) return;
  
  final response = await Supabase.instance.client
    .from('users')
    .select()
    .eq('id', _userId)
    .single();
  
  if (response != null) {
    setState(() {
      _heightController.text = (response['height'] ?? 175).toString();
      _weightController.text = (response['weight'] ?? 70).toString();
      _weeklyController.text = (response['weekly_min'] ?? 120).toString();
      _recordController.text = (response['record_10km'] ?? 60).toString();
      _level = response['level'] ?? 'beginner';
    });
  }
}
```

---

## 🎨 4. 로그인 UI

### 간단한 로그인 화면:
```dart
Widget _buildLoginPage() {
  return Container(
    decoration: BoxDecoration(
      gradient: LinearGradient(
        colors: [Color(0xFF1A2A3A), Color(0xFF0F0F1E)],
      ),
    ),
    child: Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // 로고
          ShaderMask(
            shaderCallback: (bounds) => LinearGradient(
              colors: [Color(0xFF00FFF0), Color(0xFF00D9FF), Color(0xFF0099FF)],
            ).createShader(bounds),
            child: Text(
              'SOLO RUNNER',
              style: TextStyle(
                fontSize: 48,
                fontWeight: FontWeight.w900,
                color: Colors.white,
              ),
            ),
          ),
          SizedBox(height: 60),
          
          // Google 로그인 버튼
          ElevatedButton.icon(
            onPressed: _signInWithGoogle,
            icon: Icon(Icons.login),
            label: Text('Google로 시작하기'),
            style: ElevatedButton.styleFrom(
              padding: EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              backgroundColor: Color(0xFF00FFF0),
              foregroundColor: Color(0xFF0F0F1E),
            ),
          ),
        ],
      ),
    ),
  );
}
```

### 메인 위젯 수정:
```dart
@override
Widget build(BuildContext context) {
  // 로그인 안 했으면 로그인 화면
  if (!_isLoggedIn) {
    return MaterialApp(
      home: Scaffold(
        body: _buildLoginPage(),
      ),
    );
  }
  
  // 기존 앱 UI
  return MaterialApp(
    home: Scaffold(
      // ... 기존 코드
    ),
  );
}
```

---

## 🔄 5. 플랜 동기화

```dart
// 플랜 서버에 저장
Future<void> _savePlanToServer() async {
  if (_userId == null) return;
  
  final planData = {
    'user_id': _userId,
    'plan_data': json.encode(_plan),
    'level': _level,
    'total_weeks': _plan.length,
    'current_week': 1,
    'target_vdot': _trainingProgress['currentVDOT'],
    'updated_at': DateTime.now().toIso8601String(),
  };
  
  await Supabase.instance.client
    .from('training_plans')
    .upsert(planData);
}

// 플랜 서버에서 불러오기
Future<void> _loadPlanFromServer() async {
  if (_userId == null) return;
  
  final response = await Supabase.instance.client
    .from('training_plans')
    .select()
    .eq('user_id', _userId)
    .order('created_at', ascending: false)
    .limit(1)
    .single();
  
  if (response != null) {
    setState(() {
      _plan = List<Map<String, dynamic>>.from(
        json.decode(response['plan_data'])
      );
    });
  }
}
```

---

## 📊 6. 히스토리 조회

```dart
// 지난 7일 기록 조회
Future<List<Map<String, dynamic>>> _getRecentRuns() async {
  if (_userId == null) return [];
  
  final sevenDaysAgo = DateTime.now().subtract(Duration(days: 7));
  
  final response = await Supabase.instance.client
    .from('run_logs')
    .select()
    .eq('user_id', _userId)
    .gte('date', sevenDaysAgo.toIso8601String())
    .order('date', ascending: false);
  
  return List<Map<String, dynamic>>.from(response);
}

// 통계
Future<Map<String, dynamic>> _getUserStats() async {
  if (_userId == null) return {};
  
  final response = await Supabase.instance.client
    .rpc('get_user_stats', params: {'uid': _userId});
  
  return response;
}
```

---

## 🎯 구현 우선순위

**Phase 1: 기본 로그인**
1. Supabase Auth + Google 설정
2. 로그인 화면 추가
3. user_id 기반 데이터 저장

**Phase 2: 데이터 동기화**
1. 프로필 서버 저장/불러오기
2. 플랜 서버 저장/불러오기
3. 런닝 로그 동기화

**Phase 3: 히스토리 UI**
1. 과거 런닝 목록
2. 통계 (총 거리, 평균 페이스 등)
3. 차트/그래프

---

APK 빌드 완료 후에 이 기능을 추가할까요? 🚀
