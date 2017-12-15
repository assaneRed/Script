@echo off
setlocal EnableDelayedExpansion
set jenkinsLocal=192.168.1.15
set jenkinsExt=80.12.89.158
set versionFile=last
set sasApplication=SAS

IF "%~1"=="" GOTO WRONGPARAM

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
set url=http://%ip%/delivery/sas/
set urlVersion=%url%versions/

IF "%~1"=="-v" (
	IF "%~2"=="" GOTO WRONGPARAM
	set lastVersion=%2
	GOTO DOWNLOADSPECIFICVERSION
) else (
	set solutionVersion=%1
	echo Downloading !solutionVersion!
	curl -O -s %urlVersion%!solutionVersion!
	for /f "delims=" %%i in (!solutionVersion!) do (
		set lastVersion=%%i
		GOTO DOWNLOADSPECIFICVERSION
	)
)

:DOWNLOADSPECIFICVERSION
echo Downloading !lastVersion!
curl -O -s %urlVersion%!lastVersion!
GOTO PROCESS

:PROCESS
for /f "delims=" %%x in (%versionFile%) do set versionToInstall=%%x
echo Installing !versionToInstall!

rem stopping web and services
for /f "tokens=1,2* delims=_" %%i in ('dir /b /a:d') do (
	if %%i EQU %sasApplication% (
	
		set appFolder=%%i_%%j
		call !appFolder!\DeploymentScripts\manageServices.bat stop
		IF !ERRORLEVEL! NEQ 0 (
			echo Failed to stop all services
			GOTO ERROR
		)
		
		call !appFolder!\DeploymentScripts\manageWebSites.bat stop
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
	if %%i EQU %sasApplication% (
		set appFolder=%%i_%%j
		
		call !appFolder!\DeploymentScripts\manageServices.bat start
		IF !ERRORLEVEL! NEQ 0 (
			echo Failed to start all services
			GOTO ERROR
		) else (
			echo All services successfully started
		)
		
		call !appFolder!\DeploymentScripts\manageWebSites.bat start
		IF !ERRORLEVEL! NEQ 0 (
			echo Failed to start web services
			GOTO ERROR
		) else (
			echo All web sites successfully started
		)
		
		echo !lastVersion!>!appFolder!\WebApplication\version
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

:WRONGPARAM
echo Incorrect number of parameter: version should be given as parameter
echo use -v vX.Y.Z.R to update to specific version
echo use vX.Y.Z to install last revision of vX.Y.Z version
exit /B 2

:ERROR
echo Error: at least one error happened
exit /B 1

:EXIT