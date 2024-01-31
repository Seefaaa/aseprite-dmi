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
		rmdir /S /Q .dist
		exit /b
	)
)

IF NOT EXIST lib\target\%TARGET%\lib.exe (
	echo "lib.exe was not built. Please check for errors."
	rmdir /S /Q .dist
	exit /b
)

IF EXIST .dist (
	rmdir /S /Q .dist
)
mkdir .dist

copy package.json .dist
copy LICENSE .dist

copy lib\target\%TARGET%\lib.exe .dist

xcopy /E scripts\ .dist\scripts\

IF EXIST dist (
	rmdir /S /Q dist
)
mkdir dist

powershell Compress-Archive -Path ".dist\*" -DestinationPath "dist\%EXTENSION_NAME%.zip" -Force

rmdir /S /Q .dist

cd dist
IF EXIST %EXTENSION_NAME%.aseprite-extension (
	del %EXTENSION_NAME%.aseprite-extension
)
copy %EXTENSION_NAME%.zip %EXTENSION_NAME%.aseprite-extension
cd ..
