@echo off
setlocal EnableDelayedExpansion
set jenkinsLocal=192.168.1.15
set jenkinsExt=80.12.89.158
set downloadFile=update.bat
set version=v1.0.0

ping -n 1 %jenkinsLocal%
IF %ERRORLEVEL% NEQ 0 GOTO EXT ELSE GOTO LOCAL

:LOCAL
set ip=%jenkinsLocal%
GOTO MAIN

:EXT
set ip=%jenkinsExt%:1515
GOTO MAIN

:MAIN
set url=http://%ip%/delivery/sas/
set updateFileUrl=!url!%downloadFile%
echo downloading !updateFileUrl!
cd C:\SAS
curl -O -s !updateFileUrl!
IF %ERRORLEVEL% NEQ 0 (
  echo Failed to download !updateFileUrl!
  GOTO ERROR
)

IF "%~1"=="" GOTO INSTALLLAST
set version=%1

:INSTALLVERSION
call %downloadFile% -v %version%
IF %ERRORLEVEL% NEQ 0 (
  echo Failed to update environment
  GOTO ERROR
)

:INSTALLLAST
call %downloadFile% %version%
IF %ERRORLEVEL% NEQ 0 (
  echo Failed to update environment
  GOTO ERROR
)

:ERROR


:EXIT
pause