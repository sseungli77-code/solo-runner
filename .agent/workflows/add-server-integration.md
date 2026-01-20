# 서버 연동 추가 가이드

## 🎯 목표:
- 서버 API로 플랜 생성
- 체중/키 반영
- 오프라인 시 로컬 폴백

---

## 📝 수정 단계:

### Step 1: Imports 추가 (1-11라인)

**현재:**
```dart
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'dart:async';
import 'dart:math';
import 'dart:io';

const String _geminiKey = 'AIzaSyBtEtujomeYnJUc5ZlEi7CteLmapaEZ4MY';
```

**수정 후:**
```dart
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'dart:async';
import 'dart:math';
import 'dart:io';
import 'package:http/http.dart' as http;  // ← 추가
import 'dart:convert';  // ← 추가

const String _geminiKey = 'AIzaSyBtEtujomeYnJUc5ZlEi7CteLmapaEZ4MY';
const String _serverUrl = 'https://solo-runner-api.onrender.com';  // ← 추가
```

---

### Step 2: _generatePlan 함수 교체 (530-580라인)

**VSCode에서:**
1. 530라인으로 이동
2. 530-580라인 전체 선택 (Shift+Down)
3. 삭제
4. `.temp_generatePlan.dart` 내용 복사-붙여넣기

---

## ✅ 체크리스트:

- [ ] Step 1 완료 (imports)
- [ ] Step 2 완료 (_generatePlan)
- [ ] 저장 (Ctrl+S)
- [ ] VSCode 문법 에러 확인
- [ ] 커밋
- [ ] 푸시
- [ ] 빌드 확인

---

## 🎯 기대 효과:

**성공 시:**
- ✅ 체중 70kg → 플랜 변경
- ✅ 키 175cm → BMI 반영
- ✅ 주간 훈련량 반영
- ✅ ACSM 알고리즘 사용

**서버 실패 시:**
- ✅ 자동으로 로컬 알고리즘
- ✅ 앱 정상 작동
- ✅ 사용자는 눈치 못 챔

---

## 🔧 테스트:

**앱에서:**
1. Setup 화면
2. 체중 50kg 입력 → 플랜 생성
3. 체중 90kg 입력 → 플랜 생성
4. 플랜 비교 → 다르면 성공!

**로그 확인:**
```
📡 Calling server API...
✅ Server response success
```
또는
```
❌ Server error...
🔄 Falling back to local algorithm
```

---

**준비되면 수정 시작하세요!** 🚀
