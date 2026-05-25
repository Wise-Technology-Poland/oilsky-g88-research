@echo off
setlocal EnableExtensions

set "ROOT=%~dp0"
set "ROOT=%ROOT:~0,-1%"
set "MTK=%ROOT%\mtkclient\mtk.bat"
set "OUT=%ROOT%\dump\userdata"
set "PL=%ROOT%\preloader\g88_preloader_exploited_from_brom.bin"

if not exist "%MTK%" (
  echo ERROR: mtkclient not found: "%MTK%"
  set "RC=1"
  goto fail
)

if not exist "%PL%" (
  echo ERROR: preloader not found: "%PL%"
  set "RC=1"
  goto fail
)

set "VERIFY_ONLY=0"
if /I "%~1"=="verify" set "VERIFY_ONLY=1"
if /I "%~1"=="/verify" set "VERIFY_ONLY=1"

if not exist "%OUT%\" mkdir "%OUT%" 2>nul
if not exist "%OUT%\" (
  echo ERROR: failed to create output directory: "%OUT%"
  set "RC=1"
  goto fail
)

if "%VERIFY_ONLY%"=="1" goto verify

echo Oilsky G88 userdata/state readback.
echo Root:      %ROOT%
echo mtkclient: %MTK%
echo Output:    %OUT%
echo Preloader: %PL%
echo.
echo This reads userdata plus data-recovery related state partitions.
echo It does not flash, erase, format, unlock or write anything to the device.
echo.
echo WARNING: userdata.bin is expected to be about 24 GB.
echo For encrypted Android 12/FBE data, userdata should be kept with metadata
echo and the device-specific NV/protect/sec partitions from this backup.
echo Restore is intended only for the same physical device and matching state.
echo.
echo Connect powered-off device in BROM/preloader mode when mtkclient waits for the port.
echo.

call :read_part userdata
if errorlevel 1 goto fail_readback
call :read_part metadata
if errorlevel 1 goto fail_readback
call :read_part nvdata
if errorlevel 1 goto fail_readback
call :read_part nvcfg
if errorlevel 1 goto fail_readback
call :read_part nvram
if errorlevel 1 goto fail_readback
call :read_part protect1
if errorlevel 1 goto fail_readback
call :read_part protect2
if errorlevel 1 goto fail_readback
call :read_part proinfo
if errorlevel 1 goto fail_readback
call :read_part sec1
if errorlevel 1 goto fail_readback
call :read_part seccfg
if errorlevel 1 goto fail_readback
call :read_part frp
if errorlevel 1 goto fail_readback

:verify
echo.
echo Verifying userdata/state dump sizes and hashes...
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
  "$d='%OUT%';" ^
  "$expected=[ordered]@{" ^
  "  'userdata.bin'=25393332224; 'metadata.bin'=33554432; 'nvdata.bin'=67108864; 'nvcfg.bin'=33554432;" ^
  "  'nvram.bin'=67108864; 'protect1.bin'=8388608; 'protect2.bin'=11395072; 'proinfo.bin'=3145728;" ^
  "  'sec1.bin'=2097152; 'seccfg.bin'=8388608; 'frp.bin'=1048576" ^
  "};" ^
  "$rows=foreach($name in $expected.Keys){$p=Join-Path $d $name; if(Test-Path -LiteralPath $p){$i=Get-Item -LiteralPath $p; [pscustomobject]@{Name=$name;Length=$i.Length;Expected=$expected[$name];OK=($i.Length -eq $expected[$name])}}else{[pscustomobject]@{Name=$name;Length=0;Expected=$expected[$name];OK=$false}}};" ^
  "$bad=@($rows|Where-Object{-not $_.OK}); $rows|Format-Table -AutoSize;" ^
  "if($bad.Count){Write-Host 'ERROR: missing files or size mismatch in userdata/state dump'; exit 2};" ^
  "Get-ChildItem -LiteralPath $d -File | Where-Object {$_.Name -ne 'SHA256SUMS.txt'} | Sort-Object Name | Get-FileHash -Algorithm SHA256 | Tee-Object -FilePath (Join-Path $d 'SHA256SUMS.txt')"

if errorlevel 1 (
  set "RC=%errorlevel%"
  echo.
  echo ERROR: verification failed with exit code %errorlevel%.
  goto fail
)

echo.
echo Done. Userdata/state backup command and verification completed successfully.
pause
exit /b 0

:read_part
set "PART=%~1"
echo.
echo Reading %PART%...
call "%MTK%" r "%PART%" "%OUT%\%PART%.bin" --preloader "%PL%"
set "RC=%errorlevel%"
if not "%RC%"=="0" (
  echo.
  echo ERROR: mtkclient readback failed for %PART% with exit code %RC%.
  exit /b %RC%
)
exit /b 0

:fail_readback
echo.
echo Verification was skipped because the readback did not complete.
echo Check the USB mode/button sequence, preloader path and mtkclient output above.
goto fail

:fail
echo.
echo Script stopped because of an error. No flash/write/erase command was run.
pause
exit /b %RC%
