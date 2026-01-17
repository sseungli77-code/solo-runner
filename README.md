# Solo Runner AI (Flutter Edition)

**Solo Runner**는 사용자의 신체 정보와 러닝 레벨을 분석하여 맞춤형 훈련 플랜을 제공하고, 러닝 중 실시간으로 **AI 보이스 코칭**을 제공하는 스마트 러닝 앱입니다.

## 🚀 주요 기능

### 1. AI 맞춤형 플랜 (Smart Plan)
- 사용자의 키, 체중(BMI), 10km 기록, 주간 목표 시간을 분석합니다.
- 입문(12주), 중급(24주), 상급(48주) 레벨에 맞춰 과학적인 훈련 스케줄을 자동으로 생성합니다.
- 서버 없이 앱 내부 로직으로 즉시 생성됩니다.

### 2. 실시간 AI 보이스 코칭 (Live Coaching)
- **Gemini AI**가 탑재되어 있습니다.
- 러닝 중 1분마다 현재 페이스와 거리를 분석하여, 상황에 맞는 격려와 조언을 음성(TTS)으로 들려줍니다.
- 예: *"페이스가 너무 빠릅니다. 호흡을 조절하며 천천히 달리세요."*

### 3. 클라우드 기록 동기화 (Cloud Sync)
- **Supabase**와 연동되어 있습니다.
- 러닝이 종료되면 날짜, 거리, 시간, 페이스 정보가 클라우드 DB(`run_logs`)에 자동 저장됩니다.
- 관리자(또는 다른 기기)에서 통합 데이터를 확인할 수 있습니다.

---

## 🛠️ 개발 환경 및 설정 (Setup)

이 프로젝트는 **Flutter**로 개발되었습니다.

### 필수 API Keys 설정
`lib/main.dart` 파일 상단에 있는 키 값을 본인의 키로 교체해야 합니다.

```dart
// lib/main.dart

// 1. Gemini API Key (AI 코칭용)
const String _geminiKey = 'YOUR_GEMINI_API_KEY';

// 2. Supabase 설정 (데이터 저장용)
await Supabase.initialize(
  url: 'YOUR_SUPABASE_URL',
  anonKey: 'YOUR_SUPABASE_ANON_KEY',
);
```

### 필요한 라이브러리 (Dependencies)
- `flutter_tts`: 음성 출력 (TTS)
- `google_generative_ai`: Gemini AI 연동
- `supabase_flutter`: 데이터베이스 연동
- `geolocator`: GPS 위치 추적

---

## 📱 빌드 및 설치 (Build)

### Android APK 빌드
터미널에서 다음 명령어를 실행하면 `build/app/outputs/flutter-apk/app-release.apk`가 생성됩니다.

```bash
flutter build apk --release
```

### GitHub Actions (자동 빌드)
이 저장소에는 CI/CD가 설정되어 있습니다. 코드를 Push하면 자동으로 APK가 빌드되어 **Actions** 탭의 Artifacts에서 다운로드할 수 있습니다.

---

## 📂 프로젝트 구조

- `flutter_app/lib/main.dart`: 앱의 모든 로직(UI, AI, GPS, DB)이 포함된 메인 파일
- `flutter_app/pubspec.yaml`: 라이브러리 설정 파일
- `flutter_app/android`: 안드로이드 네이티브 설정 (권한, 아이콘 등)

---

Developed by **Solo Runner Team**
