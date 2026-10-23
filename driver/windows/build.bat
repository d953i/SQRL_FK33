@echo off
rem Build sqrlfk.sys (KMDF) and sqrl_fk_mcap.exe with the Enterprise WDK (EWDK), then test-sign the driver package
rem into .\package. EWDK is the root of the mounted EWDK ISO (for example G:); without it, the first drive with an
rem EWDK is used. "build.bat analyze" also runs the compiler's static analysis with the driver rules.
setlocal
set "SRC=%~dp0"
set "OUT=%~dp0package"
set "ANALYZE="
if /i "%~1"=="analyze" set "ANALYZE=-p:Analyze=true"
if "%EWDK%"=="" for %%d in (D E F G H I J K L M N O P Q R S T U V W X Y Z) do if not defined EWDK if exist "%%d:\BuildEnv\SetupBuildEnv.cmd" set "EWDK=%%d:"
if not exist "%EWDK%\BuildEnv\SetupBuildEnv.cmd" (
    echo Enterprise WDK not found: mount the EWDK ISO, or set EWDK to its root folder.
    exit /b 1
)
rem Windows PowerShell with its own module path (PowerShell 7 passes its path to child processes); no Visual
rem Studio telemetry step, which cannot load its DLL from the ISO.
set "PSModulePath="
set "VSCMD_SKIP_SENDTELEMETRY=1"
call "%EWDK%\BuildEnv\SetupBuildEnv.cmd" amd64 >nul
@echo off
set "INF2CAT=%WindowsSdkDir%bin\%Version_Number%\x86\Inf2Cat.exe"
set "INFVERIF=%WindowsSdkDir%Tools\%Version_Number%\x64\infverif.exe"
rem The EWDK environment has no user-mode SDK paths (vsdevcmd -winsdk=none); sqrl_fk_mcap.exe needs them.
set "INCLUDE=%INCLUDE%;%WindowsSdkDir%Include\%Version_Number%\ucrt;%WindowsSdkDir%Include\%Version_Number%\um;%WindowsSdkDir%Include\%Version_Number%\shared"
set "LIB=%LIB%;%WindowsSdkDir%Lib\%Version_Number%\ucrt\x64;%WindowsSdkDir%Lib\%Version_Number%\um\x64"

msbuild "%SRC%sqrlfk.vcxproj" -nologo -v:minimal -t:Rebuild -p:Configuration=Release -p:Platform=x64 %ANALYZE%
if errorlevel 1 exit /b 1

if not exist "%OUT%" mkdir "%OUT%"
del /q "%OUT%\*" 2>nul
copy /y "%SRC%build\Release\sqrlfk\sqrlfk.sys" "%OUT%\" >nul
copy /y "%SRC%build\Release\sqrlfk\sqrlfk.inf" "%OUT%\" >nul
copy /y "%SRC%build\Release\sqrlfk.pdb" "%OUT%\" >nul
copy /y "%SRC%install.ps1" "%OUT%\" >nul
copy /y "%SRC%install.bat" "%OUT%\" >nul

cl -nologo -O2 -W4 -WX -D_CRT_SECURE_NO_WARNINGS -Fo"%SRC%build\obj\\" -Fe"%OUT%\sqrl_fk_mcap.exe" "%SRC%sqrl_fk_mcap.c"
if errorlevel 1 exit /b 1

rem Test signature on the driver and on the catalog that inf2cat makes for the package.
set "THUMB="
for /f "usebackq delims=" %%t in (`powershell -NoProfile -ExecutionPolicy Bypass -File "%SRC%testcert.ps1" -Package "%OUT%"`) do set "THUMB=%%t"
if not defined THUMB (
    echo No test certificate.
    exit /b 1
)
signtool sign -q -fd sha256 -sha1 %THUMB% -s My "%OUT%\sqrlfk.sys"
if errorlevel 1 exit /b 1
"%INF2CAT%" /driver:"%OUT%" /os:10_X64 /uselocaltime >"%SRC%build\inf2cat.log"
if errorlevel 1 (
    type "%SRC%build\inf2cat.log"
    exit /b 1
)
signtool sign -q -fd sha256 -sha1 %THUMB% -s My "%OUT%\sqrlfk.cat"
if errorlevel 1 exit /b 1
"%INFVERIF%" /w "%OUT%\sqrlfk.inf"
if errorlevel 1 exit /b 1
echo Driver package: %OUT% (test-signed with certificate %THUMB%)
