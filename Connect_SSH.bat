@echo off
setlocal enableextensions enabledelayedexpansion
ver | find "10.0." >nul && chcp 65001 >nul || chcp 28591 >nul
title %~nx0
color 0F

if not exist "%TEMP%\passagedeparametres.txt" (exit /b 1)

for /f "tokens=1,2,* delims=#" %%A in ('type "%TEMP%\passagedeparametres.txt"') do (

	set local=%%A
	set remote=%%B
	set log=%%C

)

plink.exe -ssh -P 22 -l vnc -i vnc2_rsa.ppk -L !local!:localhost:!remote! -X -2 -4 -C -noagent -batch dingdong.murky-lane.top >> !log!
