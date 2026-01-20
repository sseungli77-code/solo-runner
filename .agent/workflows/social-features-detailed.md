# SoloRunner 소셜 기능 디테일 설계

## 🌐 소셜 기능 전체 구조

### 목표:
- 사용자 간 동기부여 및 경쟁
- 커뮤니티 형성
- 앱 바이럴 성장
- 장기 사용자 유지

---

## 1️⃣ 친구 시스템

### 친구 추가/관리
```dart
// 친구 추가 방법
- QR 코드 스캔
- 이메일/유저네임 검색
- 연락처 동기화
- 같이 뛴 사람 추천 (GPS 기반)
```

**UI 구성:**
```
Friends Tab
├─ 친구 목록
│  ├─ 프로필 사진
│  ├─ 이름
│  ├─ 최근 런닝 (3시간 전)
│  └─ 이번 주 거리 (25.3 km)
│
├─ 친구 요청 (알림 배지)
│  ├─ 수락/거절 버튼
│  └─ 요청한 날짜
│
└─ 친구 추가 버튼
   ├─ QR 코드 스캔
   ├─ 검색
   └─ 연락처 동기화
```

**데이터베이스 스키마:**
```sql
CREATE TABLE friendships (
  id UUID PRIMARY KEY,
  user_id UUID REFERENCES users(id),
  friend_id UUID REFERENCES users(id),
  status TEXT DEFAULT 'pending', -- pending/accepted/blocked
  created_at TIMESTAMP DEFAULT NOW(),
  UNIQUE(user_id, friend_id)
);

-- 친구의 런닝 피드 조회
CREATE VIEW friend_runs AS
SELECT 
  r.*, 
  u.display_name,
  u.photo_url,
  f.user_id as viewer_id
FROM run_logs r
JOIN users u ON r.user_id = u.id
JOIN friendships f ON (f.friend_id = r.user_id AND f.status = 'accepted')
WHERE r.date > NOW() - INTERVAL '7 days'
ORDER BY r.date DESC;
```

---

## 2️⃣ 피드 (Feed)

### 홈 피드 화면
```
📱 Feed Screen
┌─────────────────────────────┐
│ 🏃 친구들의 최근 런닝        │
├─────────────────────────────┤
│ [프사] 김철수               │
│ • 7.2 km 달렸습니다         │
│ • 5'30" /km · 40분          │
│ • "오늘 날씨 최고! 🌞"      │
│ ❤️ 15   💬 3   🏆           │
├─────────────────────────────┤
│ [프사] 이영희               │
│ • 주간 목표 달성! 🎉        │
│ • 이번 주: 32.5 km          │
│ ⭐⭐⭐ 3주 연속!            │
│ ❤️ 28   💬 5   👏           │
└─────────────────────────────┘
```

**피드 아이템 종류:**
1. **런닝 완료**
   - 거리, 페이스, 시간
   - 짧은 코멘트
   - 지도 경로 (선택)
   
2. **마일스톤**
   - 100km 달성
   - 10번째 런닝
   - 개인 최고 기록
   
3. **플랜 완료**
   - 주차 완료
   - 전체 플랜 완료
   
4. **배지 획득**
   - 특정 목표 달성 배지

**상호작용:**
```dart
// 좋아요
- 하트 버튼
- 친구의 런닝에 응원

// 댓글
- 짧은 응원 메시지
- 이모지 리액션

// 공유
- 내 런닝을 친구에게 공유
- SNS 공유 (Instagram, Twitter 등)
```

---

## 3️⃣ 리더보드 (순위표)

### 글로벌 & 친구 리더보드
```
🏆 Leaderboard
┌─────────────────────────────┐
│ [전체] [친구] [지역]        │
├─────────────────────────────┤
│ 이번 주 거리 순위            │
│                             │
│ 🥇 1위 김철수    52.3 km   │
│ 🥈 2위 이영희    48.7 km   │
│ 🥉 3위 박민수    45.2 km   │
│ ─────────────────────────   │
│ 12위 나      ⬆️ 32.5 km    │
│                             │
│ [이번 주] [이번 달] [전체]  │
└─────────────────────────────┘
```

**순위 카테고리:**
1. **거리 순위**
   - 주간 총 거리
   - 월간 총 거리
   - 전체 총 거리

2. **페이스 순위**
   - 평균 페이스
   - 5km 최고 기록
   - 10km 최고 기록

3. **일관성 순위**
   - 연속 런닝 일수
   - 주간 플랜 달성률

4. **VDOT 순위**
   - 현재 VDOT
   - VDOT 개선률

**데이터베이스:**
```sql
CREATE TABLE leaderboards (
  id UUID PRIMARY KEY,
  period TEXT, -- 'weekly', 'monthly', 'all_time'
  category TEXT, -- 'distance', 'pace', 'consistency'
  user_id UUID REFERENCES users(id),
  value REAL,
  rank INTEGER,
  week_start DATE,
  updated_at TIMESTAMP DEFAULT NOW()
);

-- 매주 월요일 자동 계산
CREATE OR REPLACE FUNCTION calculate_weekly_leaderboard()
RETURNS VOID AS $$
BEGIN
  -- 주간 거리 순위
  INSERT INTO leaderboards (period, category, user_id, value, rank, week_start)
  SELECT 
    'weekly',
    'distance',
    user_id,
    SUM(distance_km) as total_distance,
    RANK() OVER (ORDER BY SUM(distance_km) DESC),
    DATE_TRUNC('week', NOW())
  FROM run_logs
  WHERE date >= DATE_TRUNC('week', NOW())
  GROUP BY user_id;
END;
$$ LANGUAGE plpgsql;
```

---

## 4️⃣ 챌린지 시스템

### 챌린지 종류

**1. 개인 챌린지**
```
🎯 이번 주 100km 달리기
├─ 진행률: 32.5 km / 100 km (33%)
├─ 남은 시간: 4일
├─ 보상: 🏅 100km 배지
└─ 참여자: 1,234명
```

**2. 친구 챌린지**
```
🤝 김철수와 대결
├─ 이번 주 누가 더 많이?
├─ 나: 32.5 km  vs  철수: 28.3 km
├─ 내가 4.2 km 앞서고 있어요! 💪
└─ 남은 시간: 2일 15시간
```

**3. 그룹 챌린지**
```
👥 한강러너스 팀 챌린지
├─ 목표: 팀 총 1,000 km
├─ 진행: 687 km / 1,000 km (68%)
├─ 내 기여: 32.5 km (4.7%)
├─ 팀원: 23명
└─ 1등 팀: 서울런너스 (892 km)
```

**4. 시즌 챌린지**
```
🌸 봄맞이 챌린지 (3월)
├─ 매일 달리기 (21일 연속)
├─ 현재: 14일 연속 ⭐⭐
├─ 보상: 
│  ├─ 7일: 브론즈 배지
│  ├─ 14일: 실버 배지
│  ├─ 21일: 골드 배지 + 특별 테마
└─ 실패하면 처음부터!
```

**데이터베이스:**
```sql
CREATE TABLE challenges (
  id UUID PRIMARY KEY,
  type TEXT, -- 'personal', 'friend', 'group', 'season'
  title TEXT NOT NULL,
  description TEXT,
  goal_type TEXT, -- 'distance', 'count', 'streak'
  goal_value REAL,
  start_date TIMESTAMP,
  end_date TIMESTAMP,
  reward_badge_id UUID,
  created_by UUID REFERENCES users(id)
);

CREATE TABLE challenge_participants (
  id UUID PRIMARY KEY,
  challenge_id UUID REFERENCES challenges(id),
  user_id UUID REFERENCES users(id),
  current_value REAL DEFAULT 0,
  completed BOOLEAN DEFAULT false,
  joined_at TIMESTAMP DEFAULT NOW()
);
```

---

## 5️⃣ 배지 & 업적 시스템

### 배지 카테고리

**거리 배지**
```
🏃 달린 거리
├─ 🥉 10km   - 첫 걸음
├─ 🥈 100km  - 초보 러너
├─ 🥇 500km  - 중급 러너
├─ 💎 1000km - 베테랑
└─ 👑 5000km - 레전드
```

**일관성 배지**
```
📅 연속 런닝
├─ 🔥 7일 연속
├─ 🔥🔥 30일 연속
└─ 🔥🔥🔥 100일 연속
```

**속도 배지**
```
⚡ 페이스 마스터
├─ 6'00" /km 달성
├─ 5'30" /km 달성
├─ 5'00" /km 달성
└─ 4'30" /km 달성
```

**특별 배지**
```
🌟 특별 달성
├─ 🌅 새벽 러너 (5시 이전)
├─ 🌙 야간 러너 (10시 이후)
├─ ☔ 비 속의 러너
├─ 🎂 생일 런닝
└─ 🎄 크리스마스 런닝
```

**UI 예시:**
```
프로필 > 배지 컬렉션
┌─────────────────────────────┐
│ 획득한 배지 (15/50)         │
├─────────────────────────────┤
│ 🥇 🥈 🥉 💎 🔥 ⚡          │
│ 🌅 ☔ 🎂 👑 🏆 💪          │
│                             │
│ 잠김: 🔒 🔒 🔒 ...          │
└─────────────────────────────┘
```

---

## 6️⃣ 그룹 & 클럽

### 러닝 클럽 생성
```
🏃‍♂️ 한강러너스
├─ 멤버: 45명
├─ 주간 목표: 300 km (달성!)
├─ 멤버 랭킹:
│  ├─ 1위 김철수 (32 km)
│  ├─ 2위 이영희 (28 km)
│  └─ ...
│
├─ 클럽 피드
│  ├─ 공지사항
│  ├─ 멤버 런닝 기록
│  └─ 이벤트 공유
│
└─ 클럽 챌린지
   ├─ 이번 주 총 거리 경쟁
   └─ vs 서울런너스
```

**그룹 런닝 이벤트:**
```
📅 이번 주 그룹 런닝
├─ 일시: 토요일 오전 7시
├─ 장소: 한강공원 뚝섬
├─ 거리: 10km
├─ 참가자: 12명 신청
└─ [참가하기] [공유하기]
```

---

## 7️⃣ 알림 시스템

### 소셜 알림
```
📬 알림
├─ 🎉 김철수님이 10km 달렸어요! 응원해주세요
├─ 💬 이영희님이 내 런닝에 댓글을 남겼어요
├─ ❤️ 박민수님이 내 기록에 좋아요를 눌렀어요
├─ 🏆 주간 리더보드 3위 달성!
├─ 🏃 친구 요청: 최영수님이 친구 신청을 보냈어요
└─ 🎯 챌린지 종료 임박: "100km 달리기" 2일 남음
```

---

## 8️⃣ 데이터 공유

### 런닝 기록 공유
```
[공유하기] 버튼
├─ 앱 내 피드에 공유
├─ 친구에게 직접 공유
├─ Instagram Stories
├─ Twitter
├─ Facebook
└─ 이미지로 저장
   └─ 예쁜 카드 디자인
      ├─ 거리, 시간, 페이스
      ├─ 지도 경로
      ├─ SoloRunner 로고
      └─ 개인 메시지
```

---

## 🎯 구현 우선순위

### Phase 1: 기본 소셜 (2주)
1. ✅ 친구 추가/관리
2. ✅ 친구 피드 (런닝 기록 보기)
3. ✅ 좋아요/댓글

### Phase 2: 경쟁 요소 (2주)
1. ✅ 친구 리더보드
2. ✅ 개인 챌린지
3. ✅ 기본 배지

### Phase 3: 커뮤니티 (2주)
1. ✅ 그룹/클럽 기능
2. ✅ 그룹 챌린지
3. ✅ 시즌 챌린지

### Phase 4: 고급 기능 (2주)
1. ✅ SNS 공유
2. ✅ 알림 시스템
3. ✅ 고급 배지/업적

---

## 💡 핵심 성공 요소

**1. 동기부여**
- 친구와 비교 → 더 뛰고 싶어짐
- 리더보드 → 경쟁심 유발
- 배지/업적 → 수집 욕구

**2. 바이럴**
- 친구 초대 인센티브
- SNS 공유 시 예쁜 이미지
- 챌린지 초대

**3. 커뮤니티**
- 같은 목표를 가진 사람들
- 서로 응원하는 문화
- 그룹 이벤트

**4. 장기 유지**
- 매일 확인하고 싶은 피드
- 끊기면 아까운 연속 기록
- 친구들과의 약속 (챌린지)

---

## 🚀 번외: 독특한 기능 아이디어

**1. Ghost Running** 👻
- 과거의 나와 경주
- 친구의 기록과 실시간 비교
- "지금 3분 전 김철수보다 200m 앞섭니다!"

**2. Virtual Partner** 🤖
- AI가 내 수준에 맞춰서 페이스 설정
- 실시간으로 "더 빠르게!" "천천히!" 코칭
- 친구처럼 응원해주는 AI

**3. 런닝 스토리** 📖
- 매일의 런닝을 기록
- 자동으로 연간 스토리북 생성
- "2026년, 총 1,234km 달렸습니다"

**4. 음성 메시지** 🎤
- 런닝 중 친구에게 음성 응원 보내기
- 골인 시점에 자동 재생
- "철수야 파이팅!"

---

이 정도 소셜 기능이면 **Nike Run Club, Strava 수준**입니다!

어떤 기능이 가장 매력적인가요? 🤔
