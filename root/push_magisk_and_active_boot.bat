@echo off
setlocal EnableExtensions

set "ROOT=%~dp0.."
for %%I in ("%ROOT%") do set "ROOT=%%~fI"
set "SERIAL=0123456789ABCDEF"
if not "%~1"=="" set "SERIAL=%~1"
set "ADB_SERIAL="
if not "%SERIAL%"=="" set "ADB_SERIAL=-s %SERIAL%"
set "ADB=adb"
set "APK=%ROOT%\root\Magisk-v30.7.apk"

echo Oilsky G88 Magisk staging.
echo Root:   %ROOT%
echo Serial: %SERIAL%
echo.
echo This only pushes files to /sdcard. It does not flash, patch, erase or reboot anything.
echo.

%ADB% %ADB_SERIAL% get-state 1>nul
if errorlevel 1 (
  echo ERROR: ADB device not available.
  if not "%SERIAL%"=="" echo Serial: %SERIAL%
  set "RC=1"
  goto fail
)

for /f "usebackq delims=" %%S in (`%ADB% %ADB_SERIAL% shell getprop ro.boot.slot_suffix`) do set "SLOT_SUFFIX=%%S"
if "%SLOT_SUFFIX%"=="" (
  echo ERROR: ro.boot.slot_suffix is empty.
  set "RC=1"
  goto fail
)

set "SLOT=%SLOT_SUFFIX:_=%"
set "BOOT=%ROOT%\dump\boot_%SLOT%.bin"

echo Active slot: %SLOT_SUFFIX%
echo Boot source: %BOOT%
echo APK source:  %APK%
echo.

if not exist "%APK%" (
  echo ERROR: Magisk APK not found: "%APK%"
  set "RC=1"
  goto fail
)

if not exist "%BOOT%" (
  echo ERROR: active stock boot not found: "%BOOT%"
  set "RC=1"
  goto fail
)

powershell -NoProfile -ExecutionPolicy Bypass -Command ^
  "$boot='%BOOT%';" ^
  "$i=Get-Item -LiteralPath $boot;" ^
  "if($i.Length -ne 33554432){Write-Host ('ERROR: unexpected boot size: {0}' -f $i.Length); exit 2};" ^
  "$b=[IO.File]::ReadAllBytes($boot);" ^
  "$magic=[Text.Encoding]::ASCII.GetString($b,0,8);" ^
  "if($magic -ne 'ANDROID!'){Write-Host ('ERROR: invalid boot magic: {0}' -f $magic); exit 3};" ^
  "Write-Host ('boot check: magic={0} size={1}' -f $magic,$i.Length)"
if errorlevel 1 (
  set "RC=%errorlevel%"
  goto fail
)

echo Pushing Magisk APK...
%ADB% %ADB_SERIAL% push "%APK%" /sdcard/Magisk-v30.7.apk
if errorlevel 1 (
  echo ERROR: failed to push Magisk APK.
  set "RC=1"
  goto fail
)

echo.
echo Pushing active stock boot as /sdcard/boot_stock.bin...
%ADB% %ADB_SERIAL% push "%BOOT%" /sdcard/boot_stock.bin
if errorlevel 1 (
  echo ERROR: failed to push active stock boot.
  set "RC=1"
  goto fail
)

echo.
echo Done. Files are staged on /sdcard:
echo   /sdcard/Magisk-v30.7.apk
echo   /sdcard/boot_stock.bin
pause
exit /b 0

:fail
echo.
echo Script stopped because of an error. No device partitions were written.
pause
exit /b %RC%
