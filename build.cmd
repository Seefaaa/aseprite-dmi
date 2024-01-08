@echo off
SET EXTENSION_NAME=dmi-editor
SET TARGET=debug
SET SKIP=0

IF "%~1"=="--release" (
	SET TARGET=release
)

IF "%~1"=="--skip" (
	SET SKIP=1
)

IF NOT %SKIP% NEQ 0 (
	rustc --version
	IF %ERRORLEVEL% NEQ 0 (
		echo "Rust is not installed."
		exit /b
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
		rmdir /S /Q .build
		exit /b
	)
)

IF NOT EXIST lib\target\%TARGET%\lib.exe (
	echo "lib.exe was not built. Please check for errors."
	rmdir /S /Q .build
	exit /b
)

IF EXIST .build (
	rmdir /S /Q .build
)
mkdir .build

copy package.json .build
copy LICENSE .build

copy lib\target\%TARGET%\lib.exe .build

xcopy /E scripts\ .build\scripts\

IF EXIST build (
	rmdir /S /Q build
)
mkdir build

powershell Compress-Archive -Path ".build\*" -DestinationPath "build\%EXTENSION_NAME%.zip" -Force

rmdir /S /Q .build

cd build
IF EXIST %EXTENSION_NAME%.aseprite-extension (
	del %EXTENSION_NAME%.aseprite-extension
)
copy %EXTENSION_NAME%.zip %EXTENSION_NAME%.aseprite-extension
cd ..
