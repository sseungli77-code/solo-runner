# 🛡️ Development Rules for AI Assistant (Antigravity)

이 파일은 AI 에이전트가 코드를 수정할 때 반드시 따라야 할 절대적인 규칙을 정의합니다.
사용자의 명시적인 허락 없이 이 규칙을 무시해서는 안 됩니다.

## 1. 🚫 NO FULL REWRITE (전체 덮어쓰기 금지)
- **절대 금지:** `write_to_file` 도구를 사용하여 기존 파일(`main.dart` 등)을 통째로 덮어쓰는 행위.
- **필수 준수:** 기존 코드를 수정할 때는 반드시 `replace_file_content`를 사용하여 **변경할 부분만** 정교하게 수정해야 한다.
- **예외:** 새로 파일을 생성할 때만 `write_to_file` 사용 가능.

## 2. 🧱 MODULARITY FIRST (모듈화 우선)
- **Structure:** `lib/features/<feature_name>/` 폴더에 `ui`, `logic`, `data`로 나누어 관리한다.
- **Example:** `lib/features/run/ui/run_screen.dart`
- **Common:** 공통 위젯이나 테마는 `lib/core/`에 둔다.

## 3. 💾 PRESERVE LEGACY (기존 기능 보존)
- 코드를 리팩토링하거나 UI를 바꿀 때, **기존에 잘 작동하던 핵심 기능(GPS, 데이터 저장, 셀프 목표 등)**을 삭제하거나 누락시켜서는 안 된다.
- 기능을 변경할 땐 "기존 로직이 유지되는가?"를 먼저 자문한다.

## 4. 🛑 ASK BEFORE ACTION (실행 전 보고)
- 대규모 수정(리팩토링, 구조 변경) 전에는 반드시 계획을 사용자에게 브리핑하고 승인을 받는다.
- "내가 알아서 다 고쳤어!" 식의 통보는 금지한다.

## 5. 🏷️ ERROR ISOLATION (에러 격리)
- 빌드 에러가 발생하면 전체를 뒤집지 말고, 에러가 발생한 **해당 모듈(파일)**만 집중적으로 수정한다.
- "잘 모르겠으니 초기화" 전략은 최후의 수단으로만 사용한다.
