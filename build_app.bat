@echo off
title Stylora App Builder
color 0B
echo ===================================================
echo             Stylora App Builder Script
echo ===================================================
echo.
echo What do you want to build? (ماذا تريد أن تبني؟)
echo 1. Android (APK) - لجميع هواتف أندرويد
echo 2. iPhone (iOS) - لأجهزة الآيفون
echo.
set /p choice="Enter your choice (1 or 2): "

if "%choice%"=="1" goto build_android
if "%choice%"=="2" goto build_ios
echo [ERROR] Invalid choice! اختيار غير صحيح!
pause
exit /b 1

:build_ios
color 0C
echo.
echo ================================================================================
echo [تنبيه هام جداً]
echo لا يمكن بناء تطبيق الآيفون (iOS) من جهاز يعمل بنظام ويندوز!
echo شركة آبل تفرض استخدام جهاز ماك (macOS) لعمل نسخة الآيفون.
echo لكي تبني التطبيق للآيفون، يجب عليك فتح المشروع على جهاز ماك واستخدام برنامج Xcode.
echo ================================================================================
echo.
pause
exit /b 0

:build_android
color 0B
echo.
:: Check if pubspec.yaml exists
if not exist pubspec.yaml (
    color 0C
    echo [ERROR] pubspec.yaml not found! Make sure you run this script from the project root.
    pause
    exit /b 1
)

:: Extract name and version from pubspec.yaml using PowerShell
for /f "usebackq tokens=*" %%i in (`powershell -Command "(Get-Content pubspec.yaml | Select-String '^name:').Line.Split(':')[1].Trim()"`) do (
    set APP_NAME=%%i
)
for /f "usebackq tokens=*" %%i in (`powershell -Command "(Get-Content pubspec.yaml | Select-String '^version:').Line.Split(':')[1].Trim()"`) do (
    set APP_VERSION=%%i
)

:: Replace '+' with '_' for safer filename compatibility
set SAFE_VERSION=%APP_VERSION%
set SAFE_VERSION=%SAFE_VERSION:+=_%

echo [INFO] App Name   : %APP_NAME%
echo [INFO] App Version: %APP_VERSION%
echo [INFO] APK Name   : %APP_NAME%_v%SAFE_VERSION%.apk
echo ---------------------------------------------------
echo [INFO] Running 'flutter build apk --release'...
echo.

:: Build the APK
call flutter build apk --release

if %ERRORLEVEL% neq 0 (
    color 0C
    echo.
    echo [ERROR] Flutter build failed! Please check the errors above.
    pause
    exit /b %ERRORLEVEL%
)

:: Source path for the APK
set SRC_APK=build\app\outputs\flutter-apk\app-release.apk

:: Check if the output APK exists
if not exist "%SRC_APK%" (
    color 0C
    echo.
    echo [ERROR] Built APK was not found at %SRC_APK%.
    pause
    exit /b 1
)

:: Target directory
set TARGET_DIR=builds
if not exist "%TARGET_DIR%" (
    mkdir "%TARGET_DIR%"
)

:: Destination path
set DEST_APK=%TARGET_DIR%\%APP_NAME%_v%SAFE_VERSION%.apk

echo.
echo [INFO] Copying built APK to target directory...
copy "%SRC_APK%" "%DEST_APK%" > nul

if %ERRORLEVEL% neq 0 (
    color 0C
    echo [ERROR] Failed to copy APK to %DEST_APK%
    pause
    exit /b %ERRORLEVEL%
)

color 0A
echo ===================================================
echo [SUCCESS] APK built and renamed successfully!
echo [SUCCESS] Saved to: %DEST_APK%
echo ===================================================
echo.
echo Opening the builds directory...
explorer.exe "%TARGET_DIR%"
pause
