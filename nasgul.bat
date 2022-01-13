@echo off
Mode con cols=70 lines=31
title %~nx0
setlocal enableextensions enabledelayedexpansion
chcp 1252 >nul
color 0F

if "%COMPUTERNAME%"=="PC06" (set "cible=%ProgramData%") else (set "cible=%ProgramData%\RemoteNasgulAssistance")

: ----------------------------------------------------
: on teste la présence des fichiers requis
: ----------------------------------------------------

if not exist "%windir%\System32\plink.exe" (exit /b 1)
if not exist "%windir%\System32\curl.exe" (exit /b 1)
if not exist "%cible%\pastebin.asc" (exit /b 1)
if not exist "%~dp0vnc2_rsa.ppk" (exit /b 1)

certutil -? >nul || exit /b 1

echo. & 0out E ">>> Présence des commandes externes : \b" F " OK\n"

call :arret "Module_MAJ.exe"

: ----------------------------------------------------
: on quitte le script en cas de doublon
: ----------------------------------------------------

set process=0
for /f "delims=" %%A in ('tasklist ^| find /i "%~n0.exe"') do set /a process+=1
if %process% GTR 1 (exit /b 1)

: ----------------------------------------------------
: on extrait les identifiants Pastebin
: ----------------------------------------------------

certutil -decode "%cible%\pastebin.asc" "%cible%\pastebin.txt" >nul
for /f "eol=# tokens=1,2 delims=[] " %%A in ('type "%cible%\pastebin.txt"') do set "dev_key=%%~A" & set "user_key=%%~B"

if not defined dev_key (exit /b 1)
if not defined user_key (exit /b 1)

set pastebin=--max-time 30 --tlsv1.2 -s -d "api_dev_key=%dev_key%" -d "api_user_key=%user_key%"
del /f /q "%cible%\pastebin*.txt"

echo. & 0out E ">>> Extraction des identifiants : \b" F " OK\n"

: ----------------------------------------------------
: on initialise les variables
: ----------------------------------------------------

set "api=https://pastebin.com/api/api_post.php"
set "portail=dingdong.murky-lane.top"
set "tentative=0"

echo. & 0out E ">>> Initialisation des variables : \b" F " OK\n"

: ----------------------------------------------------
: on crée une empreinte numérique
: ----------------------------------------------------

:empreinte
(wmic path Win32_NetworkAdapter where "AdapterTypeID='0'" get name,MacAddress,Manufacturer
wmic os list brief
wmic baseboard get product,manufacturer,version,serialnumber
wmic bios get BIOSVersion,Manufacturer,Name) >"%tmp%\parallax.txt"

for /f "delims=" %%A in ('certutil -hashfile "%tmp%\parallax.txt" SHA1 ^| findstr /v ":"') do set "fingerprint=%%A"
set "fingerprint=!fingerprint: =!"
set "position=0"

: ----------------------------------------------------
: on vérifie la validité de l'empreinte
: ----------------------------------------------------

:validation
if not "!fingerprint:~%position%,1!"=="" (set /a position+=1 & goto :validation)
if %position% NEQ 40 (goto :empreinte)
echo.!fingerprint! | findstr /R "[0-9]" >nul || goto :empreinte

echo. & 0out E ">>> Création de l'empreinte numérique : \b" F " OK\n"

: ----------------------------------------------------
: on définit un port aléatoire
: ----------------------------------------------------

:debut
set /a port=20000 + %RANDOM% %% 1000

set /a tentative+=1
if !tentative! GTR 15 (set delai=1740) else (set delai=20)
if !tentative! GTR 17 (set delai=3540)
if !tentative! GTR 25 (set delai=7140)
if !tentative! GTR 32 (exit /b 1)

: ----------------------------------------------------
: on teste la connexion au serveur
: ----------------------------------------------------

:test
set conn=0
timeout /t !delai! /nobreak
curl --max-time 30 -k -i -s "https://%portail%" | find "HTTP" | findstr "200 301 302 401" >nul && set conn=1
if !conn! NEQ 1 (goto :test)

echo. & 0out E ">>> Disponibilité du serveur : \b" F " OK\n"

call :arret "Module_MAJ.exe"

: ----------------------------------------------------
: on vérifie si le serveur VNC est actif
: ----------------------------------------------------

for /f "tokens=2 delims=," %%A in ('tasklist /FI "IMAGENAME eq tvnserver.exe" /FO CSV ^| find /i "Services"') do set "pid=%%~A"
if not defined pid (exit /b 1)

for /f "tokens=3 delims=: " %%A in ('netstat -a -p TCP -o ^| findstr /e "%pid%"') do set "listening=%%~A"
if not defined listening (exit /b 1)

echo. & 0out E ">>> Présence de TightVNC Server : \b" F " OK\n"

: ----------------------------------------------------
: on récupère l'IP publique du client
: ----------------------------------------------------

set "IP_Address="
for /f "tokens=2 delims=[]" %%A in ('curl --max-time 30 -k -i -s "https://account.murky-lane.top" ^| find "adresse IP"') do set "IP_Address=%%A"
if defined IP_Address (set "IP_Address=!IP_Address: =!") else (goto :test)

echo. & 0out E ">>> Récupération de l'adresse IP publique : \b" F " OK\n"

: ----------------------------------------------------
: on envoie [IP:port] pour ouvrir le pare-feu
: ----------------------------------------------------

set check=0
curl --max-time 30 -k -d "ip=!IP_Address!:%port%:%dev_key%:%user_key%" "https://%portail%" >nul && set check=1
if !check! NEQ 1 (goto :test)

echo. & 0out E ">>> Demande d'ouverture du pare-feu : \b" F " OK\n"
pause
: ----------------------------------------------------
: on vérifie l'ouverture du pare-feu
: ----------------------------------------------------

if not exist "%windir%\System32\checkPortJS.exe" (
	timeout /t 20 /nobreak
	goto :notification
)

:verification
timeout /t 1 /nobreak
for /f "skip=1 delims=" %%A in ('checkPortJS.exe %portail% 22') do echo %%A | find /i "Open" >nul || goto :verification

: ----------------------------------------------------
: on notifie le démarrage de la machine via SMS
: ----------------------------------------------------

:notification
call :arret "Module_MAJ.exe"

echo %USERNAME% | findstr /L "%COMPUTERNAME%" && set "profil=SYSTEM" || set "profil=%USERNAME%"
rem curl --max-time 30 --tlsv1.2 "https://smsapi.free-mobile.fr/sendmsg?user=&pass=&msg=%COMPUTERNAME% de %profil% ; %port%"

echo. & 0out E ">>> Notification par SMS : \b" F " OK\n"

: ----------------------------------------------------
: on supprime l'ancien pastebin si besoin
: ----------------------------------------------------

for /f "tokens=2,3 delims=<>" %%P in ('curl %pastebin% -d "api_option=list" -d "api_results_limit=500" "%api%" ^| findstr "_key _title"') do (
    set "%%P=%%Q"
    if "%%P"=="paste_title" (if "%%Q"=="#!fingerprint!#" (
                    echo.
                    curl %pastebin% -d "api_paste_key=!paste_key!" -d "api_option=delete" "%api%" >nul
                    set "paste_title="
                    0out E ">>> Suppression du Pastebin obsolète : \b" F " OK\n"
                )
    )
)

: ----------------------------------------------------
: on crée un pastebin avec l'ip et le port
: ----------------------------------------------------

if "%COMPUTERNAME%"=="PC06" (set "listening=3389")

curl %pastebin% -d "api_paste_name=#!fingerprint!#" -d "api_paste_private=2" -d "api_paste_expire_date=1W" -d "api_option=paste" -d "api_paste_code=!IP_Address!:%port%:%profil%:!listening!" "%api%" >nul

echo. & 0out E ">>> Création du nouveau Pastebin : \b" F " OK\n"

: ----------------------------------------------------
: on établit un tunnel inversé
: ----------------------------------------------------

echo. & 0out E ">>> Etablissement du tunnel inverse : \b" F " en cours ...\n"
echo.

plink.exe -ssh -P 22 -l vnc -i "%~dp0vnc2_rsa.ppk" -R %port%:localhost:!listening! -X -2 -4 -C -hostkey 8d:f8:ea:d0:11:86:33:dc:7a:a4:b0:0b:71:36:4c:ec -noagent -batch -N %portail%

echo. & 0out E ">>> Problème avec le tunnel : \b" F " relance du processus\n"

goto :debut

: ----------------------------------------------------
: on stoppe le module de mise à jour
: ----------------------------------------------------

:arret

tasklist | find /i "%~1" >nul && (taskkill /IM %1 /T /F >nul)

goto :eof
