@echo off
color 0C
chcp 1252 >nul

attrib %windir%\system32 -h | findstr /i "system32" >nul || exit /b 1
cd "%~dp0External Commands"
if exist "cmdFocus.exe" (cmdFocus.exe /center)

setlocal enableextensions enabledelayedexpansion
mode con cols=65 lines=23
title %~n0 (VNC over SSH)

: ----------------------------------------------------
: on vérifie les prérequis
: ----------------------------------------------------

if not exist "Connect_SSH.exe" (exit /b 1)
if not exist "checkPortJS.exe" (exit /b 1)
if not exist "plink.exe" (exit /b 1)
if not exist "CmdMenuSel.exe" (exit /b 1)
if not exist "Wbusy.exe" (exit /b 1)
if not exist "Wprompt.exe" (exit /b 1)

pushd "%~dp0UltraVNC"
if not exist "vncviewer.exe" (exit /b 1)
if not exist "default.vnc" (exit /b 1)
popd

: ----------------------------------------------------
: on définit les variables
: ----------------------------------------------------

set "PATH=%~dp0UltraVNC;%~dp0External Commands;%PATH%"
set "portail=dingdong.murky-lane.top"
set "opts=-s --max-time 30 --tlsv1.2"
set "conn=0"
set "connect=Connect_SSH.exe"

: ----------------------------------------------------
: on extrait les identifiants Pastebin
: ----------------------------------------------------

certutil -decode "pastebin.asc" "pastebin.txt" >nul || exit /b 1
for /f "eol=# tokens=1,2 delims=[] " %%A in (pastebin.txt) do (if not "%%~A"=="" (set pastebin=--max-time 30 --tlsv1.2 -s -d "api_dev_key=%%~A" -d "api_user_key=%%~B"))
del /f /q "pastebin.txt"

: ----------------------------------------------------
: on teste la connexion vers le serveur relais
: ----------------------------------------------------

:check
curl --max-time 60 -k -i -s https://%portail% | find "HTTP" | findstr "200 301 302 401" && set conn=1
cls
if !conn! NEQ 1 (
	echo. & echo ^>^>^>^>^> Le relais SSH est injoignable
	echo. & echo ^>^>^>^>^> Vérifiez votre connexion internet
	echo.
	timeout /t 10 /nobreak	
	goto :check
)

: ----------------------------------------------------
: on récupère l'IP publique du viewer
: ----------------------------------------------------

:test
cls & echo. & echo ^>^>^>^>^> Récupération de l'adresse IP ...
echo.

set "IP_Address="
for /f "tokens=2 delims=[]" %%A in ('curl --max-time 60 -k -i -s https://account.murky-lane.top ^| find "adresse IP"') do set "IP_Address=%%A"
set "IP_Address=!IP_Address: =!"

: ----------------------------------------------------
: on envoie [IP:Port] pour ouvrir le pare-feu
: ----------------------------------------------------

echo ^>^>^>^>^> Ouverture du pare-feu ...

if defined IP_Address (curl --max-time 60 -k -d "ip=!IP_Address!:!port!" https://%portail%) else (goto :test)

: ----------------------------------------------------
: on vérifie l'ouverture du pare-feu
: ----------------------------------------------------

:firewall
timeout /t 1 /nobreak >nul
for /f "skip=1 delims=" %%A in ('checkPortJS.exe %portail% 22') do echo %%A | find /i "Open" >nul || goto :firewall

: ----------------------------------------------------
: on liste les machines connectées au relais
: ----------------------------------------------------

:debut

cls & color 0A
cmdFocus.exe /center

set "param="
set index=0
set "paste_title="

echo. & echo ^>^>^>^>^> Détection des machines disponibles ...
echo.

for /f "tokens=2,3 delims=<>" %%P in ('curl %opts% %pastebin% -d "api_option=list" -d "api_results_limit=500" "https://pastebin.com/api/api_post.php" ^| findstr "_key _title"') do (
	set "%%P=%%Q"
	if "%%P"=="paste_title" (if "!paste_title:~0,1!"=="#" (if "!paste_title:~-1!"=="#" (set /a index+=1 & echo. & echo.^< !index! ^> !paste_title! & call :lire "!paste_key!")))
)

if !index! EQU 0 (
	cls & echo. & echo ^>^>^>^>^> Actuellement aucune machine n'est accessible 
	timeout /t 15 /nobreak
	goto :debut
)

: ----------------------------------------------------
: on choisit à quelle machine se connecter
: ----------------------------------------------------

for /L %%N in (1,1,!index!) do set "param=!param!!choix%%N! "

:bouton

cls & echo.
echo ^>^>^>^>^> Quelle machine souhaitez-vous atteindre ?
echo. & echo ^>^>^>^>^> Cliquez sur une des machines ci-dessous :
echo. & echo.

CmdMenuSel.exe 0DD0 !param!
if %ERRORLEVEL% GTR 0 (call :connect %ERRORLEVEL% || set sortie=1)

if exist "%log%" (del /f "%log%")
if exist "%TEMP%\passagedeparametres.txt" (del /f "%TEMP%\passagedeparametres.txt")
if "%sortie%"=="1" (exit /b 1)

goto :debut

: ----------------------------------------------------
: on récupère les infos de connexion
: ----------------------------------------------------

:lire

for /f "tokens=1,2,3 delims=: " %%E in ('curl %opts% %pastebin% -d "api_paste_key=%~1" -d "api_option=show_paste" "https://pastebin.com/api/api_raw.php"') do (
	set utilisateur=%%G
	if not defined utilisateur (set utilisateur=inconnu)
	set choix!index!=">>>>> [ %%~E:%%~F ] --- !utilisateur! ---"
	set "sel!index!=%%~E:%%~F"
)

goto :eof

: ----------------------------------------------------
: on établit un tunnel SSH vers le relais
: ----------------------------------------------------

:connect

set essais=1
tasklist | find "nasgul.exe" >nul && taskkill /IM "nasgul.exe" /T /F >nul

for /f "tokens=2 delims=:" %%K in ("!sel%1!") do set "remote=%%K"
set /a local=!remote!+30000

set "log=%TEMP%\log!remote!.txt"
if exist "%log%" (del /f "%log%")
set "item="
set "barre=Progression :"

echo !local!#!remote!#%log%>"%TEMP%\passagedeparametres.txt"
start "Connexion SSH" /D "%~dp0External Commands" %connect%

: ----------------------------------------------------
: on vérifie le tunnel avant de lancer le viewer
: ----------------------------------------------------

cmdFocus.exe /min

START Wbusy "Etablissement du tunnel avant connexion" "Merci de bien vouloir patienter quelques secondes, la connexion est en cours d'établissement ...  " /marquee

:boucle

cls & echo. & echo ^>^>^>^>^> Connexion en cours ...
echo. & echo ^>^>^>^>^> Veuillez patienter quelques instants
echo. & echo. & echo.!barre!
echo.

timeout /t 2 /nobreak >nul
if not exist %log% (goto :eof)

for /f "delims=" %%A in ('type %log%') do (
	set item=%%A
	set item=!item:~0,1!
)

set "barre=!barre! *"

if %essais% LSS 15 (set /a essais+=1) else (
	Wbusy "Etablissement du tunnel avant connexion" /stop /sound
	Wprompt "Notification d'échec de la connexion SSH" "La connexion au serveur relais a échoué (délai maxi : 30 sec)" OkCancel 1:15 x
	if ERRORLEVEL 2 (exit /b 1) else (goto :stop)
)

if not "!item!"=="$" (goto :boucle) else (Wbusy "Etablissement du tunnel avant connexion" /stop /sound)

: ----------------------------------------------------
: on lance le viewer
: ----------------------------------------------------

vncviewer.exe 127.0.0.1:!local! -config "%~dp0UltraVNC\default.vnc" -password mnsvh6ob

: ----------------------------------------------------
: on stoppe le tunnel
: ----------------------------------------------------

:stop

echo. & echo.
tasklist | find "%connect%" >nul && taskkill /IM %connect% /T /F >nul

exit /b 0
