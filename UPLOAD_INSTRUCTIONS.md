# GitHub 파일 업로드 가이드

## 문제 상황
Flutter Android 빌드에 필요한 리소스 파일들이 GitHub에 없어서 빌드가 실패하고 있습니다.

## 해결 방법
다음 4개의 파일을 GitHub 웹 UI를 통해 생성해야 합니다.

---

## 📁 파일 1: styles.xml

**경로:** `flutter_app/android/app/src/main/res/values/styles.xml`

**GitHub에서 생성 방법:**
1. https://github.com/stanqpl7-code/solorunner 접속
2. `flutter_app` → `android` → `app` → `src` → `main` → `res` → `values` 폴더로 이동
3. 우측 상단 **"Add file"** → **"Create new file"** 클릭
4. 파일명에 `styles.xml` 입력
5. 아래 내용 복사/붙여넣기:

```xml
<?xml version="1.0" encoding="utf-8"?>
<resources>
    <style name="LaunchTheme" parent="@android:style/Theme.Light.NoTitleBar">
        <item name="android:windowBackground">@drawable/launch_background</item>
    </style>
    <style name="NormalTheme" parent="@android:style/Theme.Light.NoTitleBar">
        <item name="android:windowBackground">?android:colorBackground</item>
    </style>
</resources>
```

6. 커밋 메시지: `Add styles.xml for Android theme`
7. **"Commit new file"** 클릭

---

## 📁 파일 2: colors.xml

**경로:** `flutter_app/android/app/src/main/res/values/colors.xml`

**GitHub에서 생성 방법:**
1. 같은 `values/` 폴더에서 **"Add file"** → **"Create new file"**
2. 파일명에 `colors.xml` 입력
3. 아래 내용 복사/붙여넣기:

```xml
<?xml version="1.0" encoding="utf-8"?>
<resources>
    <color name="ic_launcher_background">#009688</color>
</resources>
```

4. 커밋 메시지: `Add colors.xml for launcher colors`
5. **"Commit new file"** 클릭

---

## 📁 파일 3: launch_background.xml

**경로:** `flutter_app/android/app/src/main/res/drawable/launch_background.xml`

**GitHub에서 생성 방법:**
1. `flutter_app/android/app/src/main/res/` 위치에서
2. **"Add file"** → **"Create new file"**
3. 파일명에 **`drawable/launch_background.xml`** 입력 (drawable 폴더가 자동 생성됩니다)
4. 아래 내용 복사/붙여넣기:

```xml
<?xml version="1.0" encoding="utf-8"?>
<layer-list xmlns:android="http://schemas.android.com/apk/res/android">
    <item android:drawable="@android:color/white" />
</layer-list>
```

5. 커밋 메시지: `Add launch_background.xml for splash screen`
6. **"Commit new file"** 클릭

---

## 📁 파일 4: ic_launcher.xml

**경로:** `flutter_app/android/app/src/main/res/mipmap-anydpi-v26/ic_launcher.xml`

**GitHub에서 생성 방법:**
1. `flutter_app/android/app/src/main/res/` 위치에서
2. **"Add file"** → **"Create new file"**
3. 파일명에 **`mipmap-anydpi-v26/ic_launcher.xml`** 입력
4. 아래 내용 복사/붙여넣기:

```xml
<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@color/ic_launcher_background"/>
    <foreground android:drawable="@mipmap/ic_launcher_foreground"/>
</adaptive-icon>
```

5. 커밋 메시지: `Add ic_launcher.xml for adaptive icon`
6. **"Commit new file"** 클릭

---

## ✅ 완료 후 확인

모든 파일을 업로드한 후:

1. **Actions** 탭으로 이동
2. **"Build Flutter APK"** 워크플로우가 자동으로 실행되는지 확인
3. 또는 수동으로 **"Run workflow"** 버튼 클릭하여 실행

빌드가 성공하면 초록색 체크마크가 표시됩니다! ✅

---

## 💡 팁

- GitHub 웹 UI에서 여러 폴더를 한번에 만들려면 파일명에 `/`를 사용하세요
  - 예: `drawable/launch_background.xml` → drawable 폴더가 자동 생성됨
- 각 파일 생성 후 바로 다음 파일로 진행하면 됩니다
- 커밋 메시지는 변경해도 괜찮습니다
