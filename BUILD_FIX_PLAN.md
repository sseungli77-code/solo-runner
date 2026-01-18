# GitHub에 업로드할 파일 목록

## 우선순위 1: 빌드 실패를 막기 위한 최소 리소스 파일들

1. android/app/src/main/res/values/styles.xml - ✅ 로컬에 있음
2. android/app/src/main/res/drawable/launch_background.xml - 필요
3. android/app/src/main/res/values/colors.xml - 필요
4. android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png - 아이콘 (임시)

## 전략
- 웹 인터페이스를 통해 나머지 필수 파일들을 생성
- 아이콘은 placeholder 또는 기본 Flutter 아이콘 사용
