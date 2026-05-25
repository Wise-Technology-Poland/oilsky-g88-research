@echo off
setlocal EnableExtensions

set "SERIAL=0123456789ABCDEF"
if not "%~1"=="" set "SERIAL=%~1"
set "ADB=adb"
set "ADB_SERIAL="
if not "%SERIAL%"=="" set "ADB_SERIAL=-s %SERIAL%"
set "TRIES=90"

echo Oilsky G88 boot-critical package restore.
echo Serial: %SERIAL%
echo.
echo This uses cmd package install-existing --user 0.
echo It does not flash or modify partitions.
echo.

for /l %%I in (1,1,%TRIES%) do (
  echo Waiting for package service, try %%I/%TRIES%...
  %ADB% %ADB_SERIAL% wait-for-device
  %ADB% %ADB_SERIAL% shell cmd package install-existing --user 0 com.bs.setupwizard >nul 2>nul
  if not errorlevel 1 goto restore_all
  timeout /t 2 /nobreak >nul
)

echo ERROR: package service did not become available.
set "RC=1"
goto fail

:restore_all
echo Package service is available. Restoring critical packages...
for %%P in (
com.android.wallpaperpicker
com.google.android.inputmethod.latin
com.android.systemui
com.android.launcher3
) do (
  echo install-existing %%P
  %ADB% %ADB_SERIAL% shell cmd package install-existing --user 0 %%P
)

echo.
echo Rebooting after restore...
REM %ADB% %ADB_SERIAL% reboot
pause
exit /b 0

:fail
echo.
echo Restore failed. If ADB never reaches package service, use recovery/BROM path.
pause
exit /b %RC%
