# Solo Runner - 적응형 알고리즘 업데이트 요약

## 🎯 추가된 주요 기능

### 1. 셀프 목표 설정 (Self Goal Setting)
**위치**: 설정 페이지 메인 화면
- 목표 거리(km)와 목표 시간(분) 입력 필드 추가
- 자동 목표 페이스 계산 및 실시간 표시
- 목표 기반 VDOT 계산으로 맞춤형 플랜 생성

**구현**:
```dart
// 컨트롤러
final TextEditingController _goalDistanceController = TextEditingController(text: "10");
final TextEditingController _goalTimeController = TextEditingController(text: "60");

// UI - 셀프 목표 설정 섹션
Container(
  decoration: BoxDecoration(
    color: Colors.teal.withOpacity(0.15),
    borderRadius: BorderRadius.circular(10),
  ),
  child: Column(
    children: [
      Icon(Icons.flag) + "🎯 셀프 목표 설정",
      Row([
        "목표거리 (km)",
        "목표시간 (분)",
      ]),
      "목표 페이스: X'XX\" /km" // 자동 계산
    ]
  )
)
```

---

### 2. Jack Daniels VDOT 기반 과학적 훈련 계산

**알고리즘 기반**: Jack Daniels' Running Formula
- VO2max 추정 및 훈련 강도 계산
- VDOT 공식 구현

**구현 함수**:
```dart
double _calculateVDOT(double distanceKm, double timeMin) {
  // VO2max 계산
  double velocity = (distanceKm * 1000) / (timeMin * 60); // m/s
  double percent02Max = 0.8 + 0.1894393 * exp(-0.012778 * timeMin) 
                        + 0.2989558 * exp(-0.1932605 * timeMin);
  double vo2 = -4.60 + 0.182258 * velocity + 0.000104 * velocity * velocity;
  return vo2 / percent02Max;
}
```

**훈련 타입별 페이스 계산**:
- **Easy Pace**: 65 / VDOT (편안한 유산소 페이스)
- **Tempo Pace**: 55 / VDOT (젖산 역치 훈련)
- **Interval Pace**: 48 / VDOT (최대 산소 섭취량 훈련)

---

### 3. 적응형 플랜 자동 조정 (Adaptive Algorithm)

#### 3.1 러닝 완료 후 자동 VDOT 재계산
```dart
Future<void> _adjustTrainingPlan(double distKm, double timeMin) async {
  // 1. 현재 러닝 기반 VDOT 계산
  double newVDOT = _calculateVDOT(distKm, timeMin);
  double oldVDOT = _trainingProgress['currentVDOT'];
  
  // 2. VDOT 변화율 확인
  double vdotChange = ((newVDOT - oldVDOT) / oldVDOT) * 100;
  
  // 3. 조건별 플랜 조정
  if (vdotChange > 5.0 && completedCount >= 3) {
    // 페이스 개선 → 난이도 상향
    await _regeneratePlanWithNewVDOT(newVDOT);
  } 
  else if (vdotChange < -10.0 || missedDays > 5) {
    // 페이스 저하 또는 누락 많음 → 난이도 하향
    await _regeneratePlanWithNewVDOT(newVDOT * 0.95);
  }
  else {
    // 이동평균으로 부드럽게 업데이트
    currentVDOT = (oldVDOT * 0.8) + (newVDOT * 0.2);
  }
}
```

#### 3.2 조정 조건
| 조건 | VDOT 변화 | 누락 일수 | 동작 |
|------|-----------|-----------|------|
| 실력 향상 | +5% 이상 | 3회 이상 완료 | 플랜 난이도 상향 ⬆️ |
| 실력 저하 | -10% 이상 | - | 플랜 난이도 하향 ⬇️ |
| 훈련 누락 | - | 5일 이상 | 플랜 난이도 하향 ⬇️ |
| 정상 범위 | -10% ~ +5% | 5일 미만 | 이동평균 업데이트 |

#### 3.3 피드백 메시지
- ✅ 향상: "🎉 실력이 향상되었습니다! 플랜이 자동 조정되었습니다."
- ⚠️ 조정: "⚠️ 컨디션에 맞춰 플랜이 재조정되었습니다. 무리하지 마세요!"

---

### 4. 주기화 (Periodization) 적용

**3주 증가 + 1주 회복 사이클**:
```dart
double _calculateWeekIntensity(int week, int totalWeeks) {
  int cycle = (week - 1) % 4;
  double baseIntensity = 0.6 + (week / totalWeeks) * 0.3;
  
  if (cycle == 3) return baseIntensity * 0.7; // 회복 주
  return baseIntensity + (cycle * 0.1); // 점진적 증가
}
```

**주차별 포커스**:
- 0-30%: 기초 체력 및 유연성
- 30-60%: 지구력 향상
- 60-85%: 스피드 및 템포
- 85-100%: 목표 달성 및 테이퍼링

---

### 5. 훈련 누락 감지 시스템

```dart
void _checkMissedTrainings() {
  DateTime now = DateTime.now();
  var thisWeek = _plan.first;
  
  for (var run in thisWeek['runs']) {
    if (run['completed'] != true) {
      int targetWeekday = _getDayOfWeek(run['day']);
      
      // 현재 요일보다 과거라면 누락
      if (now.weekday > targetWeekday) {
        missedCount++;
      }
    }
  }
  
  _trainingProgress['missedDays'] += missedCount;
}
```

---

### 6. 진행 상황 시각화

#### 6.1 플랜 페이지 상단 진행률 표시
```
┌─────────────────────────────────┐
│ 주간 완료율          2/3        │
│ ████████████░░░░░  66%         │
│                                 │
│ 📈 현재 VDOT: 45.2             │
│ ⚠️  누락: 0일                   │
└─────────────────────────────────┘
```

#### 6.2 완료된 훈련 체크마크
- 완료: ✅ 녹색 체크 아이콘
- 미완료: 요일 아바타 (화, 목, 토)

#### 6.3 AI 시스템 설명 섹션
```
🤖 적응형 AI 트레이닝 시스템
• Jack Daniels VDOT 알고리즘 기반
• 훈련 누락 시 자동 난이도 조정
• 페이스 개선 감지하여 플랜 상향
• 실시간 체력 지수 추적 및 조정
```

---

## 📊 데이터 구조 변경

### 훈련 진행 상황 추적
```dart
Map<String, dynamic> _trainingProgress = {
  'completedRuns': [],        // 완료된 러닝 기록
  'missedDays': 0,            // 누락된 훈련 일수
  'currentVDOT': 0.0,         // 현재 VDOT
  'lastCalculatedVDOT': 0.0,  // 마지막 계산 VDOT
  'weeklyCompletionRate': 0.0,// 주간 완료율
};
```

### 플랜 구조 강화
```dart
{
  "week": 1,
  "focus": "기초 체력 및 유연성",
  "intensity": 0.65,
  "targetVDOT": 45.2,
  "completed": false,
  "runs": [
    {
      "day": "화",
      "type": "이지런",
      "dist": 3.5,
      "targetPace": 6.5,
      "desc": "편안한 페이스로 (6'30\")",
      "completed": false,
    },
    // ...
  ]
}
```

---

## 🔧 주요 수정 파일

1. **lib/main.dart**
   - 셀프 목표 설정 UI 추가
   - VDOT 계산 함수 구현
   - 적응형 알고리즘 로직 추가
   - 플랜 재생성 함수 구현
   - 주간 완료율 표시 추가
   - 훈련 누락 감지 시스템

2. **README.md**
   - 새로운 기능 설명 추가
   - 적응형 알고리즘 문서화

---

## 🎯 사용자 시나리오

### 시나리오 1: 신규 사용자
1. 앱 열기 → 설정 탭
2. 목표 입력: 10km를 60분에
3. 입문자 선택
4. "AI 플랜 생성" 클릭
5. 결과: "🎯 목표 기반 플랜 생성 완료! (VDOT: 42.5)"
6. 12주 플랜 자동 생성 (VDOT 기반 페이스 적용)

### 시나리오 2: 실력 향상
1. 3회 연속 훈련 완료
2. 페이스가 목표보다 10% 빠름 → VDOT 5% 향상
3. 자동 메시지: "🎉 실력이 향상되었습니다! 플랜이 자동 조정되었습니다. (VDOT: 47.3)"
4. 남은 주차의 목표 페이스 자동 상향

### 시나리오 3: 훈련 누락
1. 6일간 훈련 안 함
2. 앱 열면 자동 감지
3. 다음 훈련 완료 시 난이도 자동 하향
4. 메시지: "⚠️ 컨디션에 맞춰 플랜이 재조정되었습니다. 무리하지 마세요!"

---

## 📚 참고 문헌

- **Jack Daniels' Running Formula** (3rd Edition)
  - VDOT 계산식
  - 훈련 강도별 페이스 권장치
  - 피리어다이제이션 원칙

- **Adaptive Training Systems**
  - 이동평균 기반 점진적 조정
  - 과훈련 방지 알고리즘

---

## ✅ 테스트 체크리스트

- [ ] 셀프 목표 입력 시 페이스 자동 계산
- [ ] VDOT 기반 플랜 생성 (12/24/48주)
- [ ] 러닝 완료 후 VDOT 재계산
- [ ] 5% 이상 향상 시 플랜 상향
- [ ] 10% 이상 저하 시 플랜 하향
- [ ] 5일 이상 누락 시 플랜 조정
- [ ] 주간 완료율 표시
- [ ] 완료된 훈련 체크마크 표시
- [ ] 피리어다이제이션 사이클 적용

---

## 🚀 다음 단계 권장사항

1. **로컬 데이터 저장**: SharedPreferences로 훈련 진행 상황 저장
2. **주간 전환 자동화**: 3개 훈련 완료 시 다음 주로 자동 전환
3. **통계 차트**: 주간 VDOT 변화 그래프
4. **목표 달성 알림**: 목표 페이스 도달 시 축하 메시지
5. **커스텀 훈련**: 사용자가 직접 훈련 추가/수정 가능
