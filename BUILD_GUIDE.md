# SoloRunner Build & Deploy Guide

## Current Status (Environment)
- **Flet Version**: Downgraded to `0.21.2` for mobile compatibility.
- **Local Build**: Failed (Requires Flutter SDK & Android SDK).
- **Web Server**: Ready (`python main_single.py`).

## Deployment Options

### 1. Render (Dynamic Web App)
The project is configured for Render. It runs the Python server directly, so **no build step is needed**.
- **Config**: `render.yaml`
- **Command**: `python main_single.py`
- **Action**: Connect your GitHub repository to Render and deploy as a "Web Service".

### 2. GitHub Actions (Static Build / APK)
To generate an APK or Static Web Site, use GitHub Actions:
1. Push this code to GitHub.
2. Go to the "Actions" tab.
3. Select "Build and Deploy SoloRunner".
4. The APK will be built in the cloud.

## Local Testing
To test the app locally (mocking mobile View):
```bash
python main_single.py
```
*Note: This runs the server mode, which is how it works on Render.*
