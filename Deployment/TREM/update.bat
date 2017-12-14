@echo off
setlocal EnableDelayedExpansion
set jenkinsLocal=192.168.1.15
set jenkinsExt=80.12.89.158
set versionFile=last
set tremApplication=TREM

ping -n 1 %jenkinsLocal%
IF %ERRORLEVEL% NEQ 0 (
	ping -n 1 %jenkinsExt%
	IF %ERRORLEVEL% NEQ 0 (
		GOTO PROCESS
	) else (
		GOTO EXT
	)
)

:LOCAL
set ip=%jenkinsLocal%
GOTO MAIN

:EXT
set ip=%jenkinsExt%:1515

:MAIN
set url=http://%ip%/delivery/trem/
set urlVersion=%url%versions/

IF "%~1"=="" GOTO DOWNLOADLAST
set lastVersion=%1
GOTO DOWNLOADVERSION

:DOWNLOADLAST
curl -O -s %urlVersion%%versionFile%
for /f "delims=" %%i in (%versionFile%) do (
	set lastVersion=%%i
)

:DOWNLOADVERSION
echo Downloading !lastVersion!
curl -O -s %urlVersion%!lastVersion!
GOTO PROCESS

:PROCESS
for /f "delims=" %%x in (%versionFile%) do set versionToInstall=%%x
echo Installing !versionToInstall!

rem stopping web and services
for /f "tokens=1,2* delims=_" %%i in ('dir /b /a:d') do (
	if %%i EQU %tremApplication% (
	
		set tremfolder=%%i_%%j
		call !tremfolder!\DeploymentScripts\manageServices.bat stop
		IF !ERRORLEVEL! NEQ 0 (
			echo Failed to stop all services
			GOTO ERROR
		)
		
		call !tremfolder!\DeploymentScripts\manageWebSites.bat stop
		IF !ERRORLEVEL! NEQ 0 (
			echo Failed to stop web services
			GOTO ERROR
		)
	)
)

for /f "tokens=1,2* delims=_" %%i in (!versionToInstall!) do (

	set packageFile=%%i_%%j
	set packageFileMd5=!packageFile!.md5
	set fileWithoutExtension=!packageFile:~0,-4!
	set appli=%%i

	rem version already installed
	IF NOT EXIST !fileWithoutExtension! (
		
		rem download zip if not present
		IF NOT EXIST !packageFile! (
			
			echo Downloading !packageFile!
			set packageUrl=%url%!packageFile!
			curl -O -s !packageUrl!
			IF !ERRORLEVEL! NEQ 0 (
				echo Failed to download !packageUrl!
				GOTO ERROR
			)
			
			set packageChecksumUrl=%url%!packageFileMd5!
			curl -O -s !packageChecksumUrl!
			IF !ERRORLEVEL! NEQ 0 (
				echo Failed to download !packageChecksumUrl!
				GOTO ERROR
			)
		)	
	
		echo checking checksum of archive !packageFileMd5!
		call fciv -v -md5 -xml !packageFileMd5!
		IF !ERRORLEVEL! NEQ 0 (
			echo Integrity check failed on !packageFile! package, download it again
			GOTO ERROR
		)
	
		rem uninstalling previous version
		for /f "tokens=1,2* delims=_" %%i in ('dir /b /a:d') do (
			if %%i EQU !appli! (
			
				set previousversion=%%i_%%j
				echo uninstalling !previousversion!
				
				call !previousversion!\uninstall.bat				
				IF !ERRORLEVEL! NEQ 0 (
					echo Failed to uninstall !previousversion!
					GOTO ERROR
				)
					
				rmdir /Q /S !previousversion!
				IF !ERRORLEVEL! NEQ 0 (
					echo Failed to remove !previousversion!
					GOTO ERROR
				)
				
				echo !previousversion! uninstalled successfuly
			)
		)
		
		7z -y -bd x !packageFile! -o!fileWithoutExtension!
		set error=!ERRORLEVEL!
		IF !error! EQU 255 (
			echo User cancel extraction of !packageFile!
			GOTO ERROR
		)
		
		IF !error! EQU 8 (
			echo Not enough memory to extract !packageFile!
			GOTO ERROR
		)
		
		IF !error! EQU 2 (
			echo Fatal error extracting !packageFile!
			GOTO ERROR
		)
		
		REM INSTALLING NEW ONE
		echo Installing !fileWithoutExtension!
		call !fileWithoutExtension!\install.bat
		IF !ERRORLEVEL! NEQ 0 (
			echo failed to install !fileWithoutExtension!
			GOTO error
		)
		
		echo !fileWithoutExtension! installed successfully
	) else (
		echo skipped: !fileWithoutExtension! already installed 
	)
)

rem stopping web and services
for /f "tokens=1,2* delims=_" %%i in ('dir /b /a:d') do (
	if %%i EQU %tremApplication% (
		set tremfolder=%%i_%%j
		
		call !tremfolder!\DeploymentScripts\manageServices.bat start
		IF %ERRORLEVEL% NEQ 0 (
			echo Failed to start all services
			GOTO ERROR
		) else (
			echo All services successfully started
		)
		
		call !tremfolder!\DeploymentScripts\manageWebSites.bat start
		IF %ERRORLEVEL% NEQ 0 (
			echo Failed to start web services
			GOTO ERROR
		) else (
			echo All web sites successfully started
		)
		
		echo !lastVersion!>!tremfolder!\WebApplication\version
		IF %ERRORLEVEL% NEQ 0 (
			echo Failed to update web version file
			GOTO ERROR
		) else (
			echo Web version file updated to !lastVersion!
		)
	)
)

echo !versionToInstall! installed successfully

GOTO EXIT

:ERROR
echo ERROR: at least one error happened
exit /B 1

:EXIT