@echo off
setlocal EnableExtensions

set "ROOT=%~dp0.."
for %%I in ("%ROOT%") do set "ROOT=%%~fI"
set "SERIAL=0123456789ABCDEF"
set "ADB=adb"
set "LIST=%ROOT%\creator\packages-default.txt"
set "AGGRESSIVE=%ROOT%\creator\packages-aggressive.txt"
set "KEEP=%ROOT%\creator\packages-keep.txt"
set "OUT=%ROOT%\creator\out"
set "GENERATED=%OUT%\packages.txt"

set "MODE=%~1"
if "%MODE%"=="" set "MODE=plan"

if /I "%MODE%"=="plan" goto start
if /I "%MODE%"=="apply" goto start
if /I "%MODE%"=="aggressive-plan" goto start
if /I "%MODE%"=="aggressive-apply" goto start
if /I "%MODE%"=="snapshot" goto snapshot
if /I "%MODE%"=="restore" goto restore

echo Usage:
echo   debloat_g88.bat plan
echo   debloat_g88.bat apply
echo   debloat_g88.bat aggressive-plan
echo   debloat_g88.bat aggressive-apply
echo   debloat_g88.bat snapshot
echo   debloat_g88.bat restore
echo.
echo Default mode is plan. Apply modes uninstall packages for user 0 only.
pause
exit /b 1

:start
if /I "%MODE%"=="aggressive-plan" set "LIST=%AGGRESSIVE%"
if /I "%MODE%"=="aggressive-apply" set "LIST=%AGGRESSIVE%"

if not exist "%LIST%" (
  echo ERROR: package list not found: "%LIST%"
  set "RC=1"
  goto fail
)
if not exist "%KEEP%" (
  echo ERROR: keep list not found: "%KEEP%"
  set "RC=1"
  goto fail
)

if not exist "%OUT%\" mkdir "%OUT%" 2>nul
if not exist "%OUT%\" (
  echo ERROR: failed to create output directory: "%OUT%"
  set "RC=1"
  goto fail
)

%ADB% -s %SERIAL% get-state 1>nul
if errorlevel 1 (
  echo ERROR: ADB device not available: %SERIAL%
  set "RC=1"
  goto fail
)

call :snapshot_no_pause
if errorlevel 1 goto fail

echo Oilsky G88 debloat.
echo Mode:   %MODE%
echo List:   %LIST%
echo Output: %OUT%
echo.
echo This uses pm uninstall --user 0. It does not touch partitions or system images.
echo.

if /I "%MODE%"=="plan" goto plan
if /I "%MODE%"=="aggressive-plan" goto plan
goto apply

:plan
break > "%GENERATED%"
echo Packages that would be removed if installed:
for /f "usebackq tokens=* delims=" %%P in ("%LIST%") do call :write_candidate "%%P"
echo.
echo Done. No packages were removed.
echo Generated:
echo   %GENERATED%
pause
exit /b 0

:apply
echo Removing packages for user 0...
for /f "usebackq tokens=* delims=" %%P in ("%LIST%") do call :remove_candidate "%%P"
echo.
echo Done. Reboot is recommended after reviewing the output above.
pause
exit /b 0

:restore
if not exist "%OUT%\" mkdir "%OUT%" 2>nul
%ADB% -s %SERIAL% get-state 1>nul
if errorlevel 1 (
  echo ERROR: ADB device not available: %SERIAL%
  set "RC=1"
  goto fail
)
echo Reinstalling packages from both debloat lists for user 0...
for /f "usebackq tokens=* delims=" %%P in ("%ROOT%\debloat\packages-default.txt") do call :restore_candidate "%%P"
for /f "usebackq tokens=* delims=" %%P in ("%ROOT%\debloat\packages-aggressive.txt") do call :restore_candidate "%%P"
echo.
echo Done. Reboot is recommended.
pause
exit /b 0

:snapshot
if not exist "%OUT%\" mkdir "%OUT%" 2>nul
call :snapshot_no_pause
if errorlevel 1 goto fail
echo Snapshot written to "%OUT%".
pause
exit /b 0

:snapshot_no_pause
%ADB% -s %SERIAL% shell pm list packages > "%OUT%\packages-all.txt"
if errorlevel 1 (
  echo ERROR: failed to snapshot package list.
  set "RC=1"
  exit /b 1
)
%ADB% -s %SERIAL% shell pm list packages -s > "%OUT%\packages-system.txt"
%ADB% -s %SERIAL% shell pm list packages -3 > "%OUT%\packages-third-party.txt"
exit /b 0

:print_candidate
set "PKG=%~1"
if "%PKG%"=="" exit /b 0
echo %PKG% | findstr /b "#" >nul
if not errorlevel 1 exit /b 0
findstr /x /c:"package:%PKG%" "%OUT%\packages-all.txt" >nul
if errorlevel 1 exit /b 0
findstr /x /c:"%PKG%" "%KEEP%" >nul
if not errorlevel 1 exit /b 0
echo   %PKG%
exit /b 0

:write_candidate
set "PKG=%~1"
if "%PKG%"=="" exit /b 0
echo %PKG% | findstr /b "#" >nul
if not errorlevel 1 exit /b 0
findstr /x /c:"package:%PKG%" "%OUT%\packages-all.txt" >nul
if errorlevel 1 exit /b 0
findstr /x /c:"%PKG%" "%KEEP%" >nul
if not errorlevel 1 exit /b 0
echo   %PKG%
echo %PKG%>>"%GENERATED%"
exit /b 0

:remove_candidate
set "PKG=%~1"
if "%PKG%"=="" exit /b 0
echo %PKG% | findstr /b "#" >nul
if not errorlevel 1 exit /b 0
findstr /x /c:"package:%PKG%" "%OUT%\packages-all.txt" >nul
if errorlevel 1 (
  echo SKIP not installed: %PKG%
  exit /b 0
)
findstr /x /c:"%PKG%" "%KEEP%" >nul
if not errorlevel 1 (
  echo KEEP protected: %PKG%
  exit /b 0
)
echo uninstall --user 0 %PKG%
%ADB% -s %SERIAL% shell pm uninstall --user 0 %PKG%
exit /b 0

:restore_candidate
set "PKG=%~1"
if "%PKG%"=="" exit /b 0
echo %PKG% | findstr /b "#" >nul
if not errorlevel 1 exit /b 0
echo install-existing --user 0 %PKG%
%ADB% -s %SERIAL% shell cmd package install-existing --user 0 %PKG%
exit /b 0

:fail
echo.
echo Script stopped because of an error. No partition or firmware image was modified.
pause
exit /b %RC%
