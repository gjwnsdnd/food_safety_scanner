@echo off
chcp 65001 > nul
setlocal enabledelayedexpansion

echo 🔄 백엔드 실행 중...
start "BACKEND_OCR" cmd /k ".\.venv\Scripts\python.exe -m uvicorn backend.main:app --reload --host 0.0.0.0 --port 8010"

timeout /t 3 /nobreak

echo 🔄 에뮬레이터 실행 중...
start "" "%ANDROID_HOME%\emulator\emulator.exe" -avd Medium_Phone

echo ⏳ 에뮬레이터 시작 대기 중... (30초)
timeout /t 30 /nobreak

echo 🔄 Flutter 앱 실행 중...
start "FLUTTER_APP" cmd /k "flutter run"

echo ✅ 모두 실행 완료!
timeout /t 5