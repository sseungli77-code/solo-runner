# SoloRunner APK Build Guide

## Prerequisites
To build the APK, you need to install **Flutter** and the **Android SDK** on your computer.
Since these tools are currently missing, the automatic build failed.

## How to Build (Once Flutter is Installed)

1. **Install Flutter**: [Download Link](https://docs.flutter.dev/get-started/install/windows)
2. **Open Terminal** in this folder.
3. **Run Command**:
   ```bash
   flet build apk
   ```
4. The APK file will appear in the `build/apk` folder.

## Alternative: Cloud Build
If you cannot install Flutter, you can upload this code to GitHub and use "GitHub Actions" to build the APK automatically in the cloud.
