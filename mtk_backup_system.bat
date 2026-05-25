@echo off
setlocal EnableExtensions

set "ROOT=%~dp0"
set "ROOT=%ROOT:~0,-1%"
set "MTK=%ROOT%\mtkclient\mtk.bat"
set "OUT=%ROOT%\dump"
set "PL=%ROOT%\preloader\g88_preloader_exploited_from_brom.bin"
set "SKIP=userdata"

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

echo Oilsky G88 full readback without userdata.
echo Root:      %ROOT%
echo mtkclient: %MTK%
echo Output:    %OUT%
echo Preloader: %PL%
echo Skip:      %SKIP%
echo.
echo This reads all GPT partitions except userdata into dump.
echo This script does not flash, erase, format or unlock anything.
echo.
echo Connect powered-off device in BROM/preloader mode when mtkclient waits for the port.
echo.

call "%MTK%" rl "%OUT%" --skip %SKIP% --preloader "%PL%"
set "RC=%errorlevel%"
if not "%RC%"=="0" (
  echo.
  echo ERROR: mtkclient full readback failed with exit code %RC%.
  echo Verification was skipped because the readback did not complete.
  echo Check the USB mode/button sequence, preloader path and mtkclient output above.
  goto fail
)

:verify
echo.
echo Verifying full dump sizes and hashes...
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
  "$d='%OUT%';" ^
  "$expected=[ordered]@{" ^
  "  'boot_para.bin'=1048576; 'para.bin'=524288; 'expdb.bin'=20971520; 'frp.bin'=1048576;" ^
  "  'nvcfg.bin'=33554432; 'nvdata.bin'=67108864; 'md_udc.bin'=23699456; 'metadata.bin'=33554432;" ^
  "  'protect1.bin'=8388608; 'protect2.bin'=11395072; 'seccfg.bin'=8388608; 'sec1.bin'=2097152;" ^
  "  'proinfo.bin'=3145728; 'nvram.bin'=67108864; 'logo.bin'=11534336;" ^
  "  'md1img_a.bin'=104857600; 'spmfw_a.bin'=1048576; 'scp_a.bin'=1048576; 'sspm_a.bin'=1048576;" ^
  "  'gz_a.bin'=16777216; 'lk_a.bin'=1048576; 'boot_a.bin'=33554432; 'vendor_boot_a.bin'=67108864;" ^
  "  'dtbo_a.bin'=8388608; 'tee_a.bin'=5242880; 'vbmeta_a.bin'=8388608; 'vbmeta_system_a.bin'=8388608;" ^
  "  'vbmeta_vendor_a.bin'=11534336; 'md1img_b.bin'=104857600; 'spmfw_b.bin'=1048576; 'scp_b.bin'=1048576;" ^
  "  'sspm_b.bin'=1048576; 'gz_b.bin'=16777216; 'lk_b.bin'=1048576; 'boot_b.bin'=33554432;" ^
  "  'vendor_boot_b.bin'=67108864; 'dtbo_b.bin'=8388608; 'tee_b.bin'=8388608; 'super.bin'=4976541696;" ^
  "  'vbmeta_b.bin'=8388608; 'vbmeta_system_b.bin'=8388608; 'vbmeta_vendor_b.bin'=14680064;" ^
  "  'otp.bin'=45088768; 'flashinfo.bin'=16777216" ^
  "};" ^
  "$rows=foreach($name in $expected.Keys){$p=Join-Path $d $name; if(Test-Path -LiteralPath $p){$i=Get-Item -LiteralPath $p; [pscustomobject]@{Name=$name;Length=$i.Length;Expected=$expected[$name];OK=($i.Length -eq $expected[$name])}}else{[pscustomobject]@{Name=$name;Length=0;Expected=$expected[$name];OK=$false}}};" ^
  "$bad=@($rows|Where-Object{-not $_.OK}); $rows|Format-Table -AutoSize;" ^
  "$boot=Join-Path $d 'boot_a.bin'; if(Test-Path -LiteralPath $boot){$b=[IO.File]::ReadAllBytes($boot); $magic=[Text.Encoding]::ASCII.GetString($b,0,8); $ver=[BitConverter]::ToUInt32($b,40); $page=[BitConverter]::ToUInt32($b,36); Write-Host ('boot_a: magic={0} header_version={1} page_size={2}' -f $magic,$ver,$page); if($magic -ne 'ANDROID!'){Write-Host 'ERROR: boot_a has invalid Android boot magic'; exit 3}};" ^
  "if($bad.Count){Write-Host 'ERROR: missing files or size mismatch in full dump'; exit 2};" ^
  "Get-ChildItem -LiteralPath $d -File | Where-Object {$_.Name -ne 'SHA256SUMS.txt'} | Sort-Object Name | Get-FileHash -Algorithm SHA256 | Tee-Object -FilePath (Join-Path $d 'SHA256SUMS.txt')"

if errorlevel 1 (
  set "RC=%errorlevel%"
  echo.
  echo ERROR: verification failed with exit code %errorlevel%.
  goto fail
)

echo.
echo Done. Full readback without userdata and verification completed successfully.
pause
exit /b 0

:fail
echo.
echo Script stopped because of an error. No flash/write/erase command was run.
pause
exit /b %RC%
