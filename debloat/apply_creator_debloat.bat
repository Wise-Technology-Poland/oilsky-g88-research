@echo off
setlocal EnableExtensions

set "ROOT=%~dp0.."
for %%I in ("%ROOT%") do set "ROOT=%%~fI"
set "SERIAL=0123456789ABCDEF"
if not "%~1"=="" set "SERIAL=%~1"
set "ADB=adb"
set "LIST=%ROOT%\debloat\packages.txt"
set "OPTIONAL_MARKET_LIST=%ROOT%\debloat\packages-optional-google-market.txt"
set "OUT=%ROOT%\debloat\out"
set "LAUNCHER_APK=%ROOT%\debloat\fr.neamar.kiss_222.apk"
set "LAUNCHER_PKG=fr.neamar.kiss"
set "REMOVE_MARKET=0"
if /I "%~1"=="remove-market" (
  set "SERIAL=0123456789ABCDEF"
  set "REMOVE_MARKET=1"
)
if /I "%~2"=="remove-market" set "REMOVE_MARKET=1"
if /I "%~1"=="remove-market" if not "%~2"=="" set "SERIAL=%~2"
set "ADB_SERIAL="
if not "%SERIAL%"=="" set "ADB_SERIAL=-s %SERIAL%"

if not exist "%LIST%" (
  echo ERROR: package list not found: "%LIST%"
  echo Put the package list at: "%LIST%"
  set "RC=1"
  goto fail
)

if not exist "%OUT%\" mkdir "%OUT%" 2>nul
if not exist "%OUT%\" (
  echo ERROR: failed to create output directory: "%OUT%"
  set "RC=1"
  goto fail
)

%ADB% %ADB_SERIAL% get-state 1>nul
if errorlevel 1 (
  echo ERROR: ADB device not available.
  if not "%SERIAL%"=="" echo Serial: %SERIAL%
  set "RC=1"
  goto fail
)

if exist "%LAUNCHER_APK%" (
  echo Installing fallback launcher before debloat: "%LAUNCHER_APK%"
  %ADB% %ADB_SERIAL% install -r "%LAUNCHER_APK%"
  if errorlevel 1 (
    echo ERROR: failed to install fallback launcher.
    set "RC=1"
    goto fail
  )

  %ADB% %ADB_SERIAL% shell pm list packages %LAUNCHER_PKG% | findstr /x /c:"package:%LAUNCHER_PKG%" >nul
  if errorlevel 1 (
    echo ERROR: fallback launcher package is not visible after install: %LAUNCHER_PKG%
    set "RC=1"
    goto fail
  )
) else (
  echo WARNING: fallback launcher APK not found: "%LAUNCHER_APK%"
  echo WARNING: continuing without installing a launcher.
)

echo Snapshotting packages before debloat...
%ADB% %ADB_SERIAL% shell pm list packages > "%OUT%\packages-before.txt"
if errorlevel 1 (
  echo ERROR: failed to snapshot package list.
  set "RC=1"
  goto fail
)

echo Oilsky G88 debloat apply.
echo Serial: %SERIAL%
echo List:   %LIST%
echo Output: %OUT%
echo Launcher APK: %LAUNCHER_APK%
echo Remove Google Market: %REMOVE_MARKET%
echo.
echo This removes packages for user 0 using pm uninstall --user 0.
echo It does not modify partitions, firmware images, boot, vendor_boot or userdata.
echo.

for /f "usebackq tokens=* delims=" %%P in ("%LIST%") do call :remove_candidate "%%P"
if "%REMOVE_MARKET%"=="1" (
  if exist "%OPTIONAL_MARKET_LIST%" (
    for /f "usebackq tokens=* delims=" %%P in ("%OPTIONAL_MARKET_LIST%") do call :remove_candidate "%%P"
  ) else (
    echo WARNING: optional Google Market list not found: "%OPTIONAL_MARKET_LIST%"
  )
)

echo.
echo Snapshotting packages after debloat...
%ADB% %ADB_SERIAL% shell pm list packages > "%OUT%\packages-after.txt"

echo.
echo Done. Reboot is recommended after reviewing the output above.
pause
exit /b 0

:remove_candidate
set "PKG=%~1"
if "%PKG%"=="" exit /b 0
echo %PKG% | findstr /b "#" >nul
if not errorlevel 1 exit /b 0

findstr /x /c:"package:%PKG%" "%OUT%\packages-before.txt" >nul
if errorlevel 1 (
  echo SKIP not installed: %PKG%
  exit /b 0
)

echo uninstall --user 0 %PKG%
%ADB% %ADB_SERIAL% shell pm uninstall --user 0 %PKG%
exit /b 0

:fail
echo.
echo Script stopped because of an error. No partition or firmware image was modified.
pause
exit /b %RC%
