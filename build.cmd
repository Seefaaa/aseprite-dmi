@echo off
cd %~dp0

python --version 1>nul 2>nul
IF %ERRORLEVEL% EQU 0 (
	python tools\build.py %*
	exit /b %ERRORLEVEL%
)

SET EXTENSION_NAME=aseprite-dmi
SET TARGET=debug
SET SKIP=0

IF "%~1"=="--release" (
	SET TARGET=release
)

IF "%~1"=="--ci" (
	SET TARGET=%~2\release
	SET SKIP=1
)

IF %SKIP% EQU 0 (
	rustc --version 1>nul
	IF %ERRORLEVEL% NEQ 0 (
		echo "Rust is not installed."
		exit /b 1
	)
	cd lib
	IF %TARGET%==debug (
		cargo build
	) ELSE (
		cargo build --release
	)
	cd ..
	IF %ERRORLEVEL% NEQ 0 (
		echo "lib build failed. Please check for errors."
		exit /b 1
	)
)

IF NOT EXIST lib\target\%TARGET%\lib.exe (
	echo "lib.exe was not built. Please check for errors."
	exit /b 1
)

IF EXIST dist (
	rmdir /S /Q dist
)

mkdir dist
mkdir dist\unzipped

copy package.json dist\unzipped
copy LICENSE dist\unzipped

copy lib\target\%TARGET%\lib.exe dist\unzipped

xcopy /E scripts\ dist\unzipped\scripts\

powershell Compress-Archive -Path "dist\unzipped\*" -DestinationPath "dist\%EXTENSION_NAME%.zip" -Force

IF EXIST dist\%EXTENSION_NAME%.aseprite-extension (
	del dist\%EXTENSION_NAME%.aseprite-extension
)

copy dist\%EXTENSION_NAME%.zip dist\%EXTENSION_NAME%.aseprite-extension
