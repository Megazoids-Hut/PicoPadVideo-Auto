@echo off
setlocal enabledelayedexpansion

:: Store arguments
set INPUT=%~1
set START_TIME=%~2
set DURATION=%~3

:: Check for input file
if not defined INPUT goto USAGE
if "%INPUT%"=="" goto USAGE

:: ---------------------------------------------------------------
:: Check dependencies
:: ---------------------------------------------------------------
echo [CHECK] Testing ffmpeg...
ffmpeg -version >nul 2>nul
if errorlevel 1 (
    echo [FAIL] ffmpeg not found. Place ffmpeg.exe in this folder or add to PATH.
    pause
    exit /b 1
)
echo [OK] ffmpeg found

if not exist "PicoPadVideo.exe" (
    echo [FAIL] PicoPadVideo.exe not found in current folder.
    pause
    exit /b 1
)
echo [OK] PicoPadVideo.exe found

if not exist "%INPUT%" (
    echo [FAIL] Input file "%INPUT%" not found.
    dir *.mp4 *.avi *.mov *.mkv 2>nul
    pause
    exit /b 1
)
echo [OK] Input: %INPUT%

:: ---------------------------------------------------------------
:: Clean up old files and prepare working directories
:: ---------------------------------------------------------------
set PALETTE=palette.png
set BMPDIR=BMP
set OUTFILE=VIDEO.VID

:: Remove old intermediate files to avoid stale data between runs
del "%PALETTE%" 2>nul
del "SOUND.wav" 2>nul
del "%OUTFILE%" 2>nul
del "PicoPadOutput.txt" 2>nul

:: Reset BMP directory
if exist "%BMPDIR%" (
    rmdir /s /q "%BMPDIR%"
)
mkdir "%BMPDIR%"
if not exist "%BMPDIR%" (
    echo [FAIL] Cannot create BMP directory
    pause
    exit /b 1
)
echo [OK] Working directory cleaned

:: ffmpeg options: hide startup banner and suppress warnings (e.g. "Late SEI is not implemented")
set FFMPEG_OPTS=-hide_banner -loglevel error -stats

:: Target display aspect ratio (width/height). Use 4/3 for the 320x240 PicoPad screen.
set CROP_RATIO=4/3
set CROP_RATIO_INV=3/4

:: Audio volume multiplier (1.0 = original, 1.25 = 25%% louder)
set VOLUME=1.25

:: Build trim parameters
set TRIM=
if defined START_TIME set TRIM=-ss %START_TIME%
if defined DURATION set TRIM=%TRIM% -t %DURATION%

echo.
echo ============================================================
echo   PicoPad Video Converter
echo   Input: %INPUT%
echo ============================================================
echo.

:: ---------------------------------------------------------------
echo [STEP 1/4] Generating optimized 256-color palette...
:: ---------------------------------------------------------------
ffmpeg %FFMPEG_OPTS% %TRIM% -i "%INPUT%" -vf "framerate=fps=10,crop='min(iw\,ih*%CROP_RATIO%)':'min(ih\,iw*%CROP_RATIO_INV%)',scale=160:240:flags=lanczos,palettegen=max_colors=256:stats_mode=full" -y "%PALETTE%"
if not exist "%PALETTE%" (
    echo [FAIL] Palette generation failed
    pause
    exit /b 1
)
echo [OK] Palette saved

:: ---------------------------------------------------------------
echo [STEP 2/4] Exporting paletted BMP frames...
:: ---------------------------------------------------------------
ffmpeg %FFMPEG_OPTS% %TRIM% -i "%INPUT%" -i "%PALETTE%" -filter_complex "[0:v]framerate=fps=10,crop='min(iw\,ih*%CROP_RATIO%)':'min(ih\,iw*%CROP_RATIO_INV%)',scale=160:240:flags=lanczos[v];[v][1:v]paletteuse=dither=sierra2_4a" -r 10 -start_number 0 "%BMPDIR%\%%06d.bmp"
dir /b "%BMPDIR%\*.bmp" >nul 2>nul
if errorlevel 1 (
    echo [FAIL] BMP export failed - no BMP files created
    pause
    exit /b 1
)
echo [OK] BMP frames exported

:: Count BMP files for info
set BMPCOUNT=0
for /f %%f in ('dir /b "%BMPDIR%\*.bmp" 2^>nul') do set /a BMPCOUNT+=1
echo [INFO] %BMPCOUNT% BMP files in %BMPDIR%\

:: ---------------------------------------------------------------
echo [STEP 3/4] Exporting audio...
:: ---------------------------------------------------------------
ffmpeg %FFMPEG_OPTS% %TRIM% -i "%INPUT%" -af "volume=%VOLUME%" -ar 22050 -ac 1 -sample_fmt u8 -acodec pcm_u8 -y SOUND.wav
if not exist "SOUND.wav" (
    echo [FAIL] Audio export failed
    pause
    exit /b 1
)
echo [OK] Audio exported

:: ---------------------------------------------------------------
echo [STEP 4/4] Converting to PicoPad format...
:: ---------------------------------------------------------------
PicoPadVideo.exe > PicoPadOutput.txt 2>&1
type PicoPadOutput.txt

:: Check output file has content
if not exist "%OUTFILE%" (
    echo [FAIL] PicoPadVideo conversion failed - no output file created
    pause
    exit /b 1
)

for %%F in ("%OUTFILE%") do set OUTSIZE=%%~zF
if "%OUTSIZE%"=="0" (
    echo [FAIL] VIDEO.VID is empty ^(0 bytes^)
    echo.
    echo === Diagnostic Info ===
    echo First 5 BMP files in %BMPDIR%\:
    dir /b "%BMPDIR%\*.bmp" 2>nul | findstr /n "." | findstr /b "[12345]:"
    echo.
    echo First BMP file header check ^(first 4 bytes should be BM^):
    certutil -encodehex "%BMPDIR%\000000.bmp" /d 2>nul | findstr /b "0000"
    if errorlevel 1 (
        echo Cannot read BMP header - file may not exist or wrong format
        echo.
        echo Files in BMP directory:
        dir "%BMPDIR%"
    )
    echo.
    echo === PicoPadVideo Output ===
    type PicoPadOutput.txt
    echo.
    echo Possible issues:
    echo 1. You may need to recompile PicoPadVideo.exe from the modified source
    echo 2. BMP files may have wrong format ^(expected: 8-bit paletted 160x240^)
    echo 3. BMP file naming may not match ^(expected: 000000.bmp, 000001.bmp, ...^)
    pause
    exit /b 1
)

echo.
echo ============================================================
echo   SUCCESS! Output file: %OUTFILE% ^(%OUTSIZE% bytes^)
echo ============================================================
echo.

:: ---------------------------------------------------------------
:: Post-conversion cleanup
echo [CLEANUP] Removing intermediate files...
if exist "%BMPDIR%" (
    rmdir /s /q "%BMPDIR%"
    echo [OK] Removed %BMPDIR% directory
)
if exist "SOUND.wav" (
    del "SOUND.wav"
    echo [OK] Removed SOUND.wav
)
if exist "PicoPadOutput.txt" (
    del "PicoPadOutput.txt"
    echo [OK] Removed PicoPadOutput.txt
)
if exist "%PALETTE%" (
    del "%PALETTE%"
    echo [OK] Removed %PALETTE%
)
echo [OK] Cleanup complete

echo.
echo Done.
pause
exit /b 0

:USAGE
echo ============================================================
echo   PicoPad Video Converter - Simplified ffmpeg Workflow
echo ============================================================
echo.
echo Usage: %~nx0 input_video [start_time] [duration]
echo.
echo   input_video   - Source video file
echo   start_time    - Optional start time (e.g. 00:01:30 or 90)
echo   duration      - Optional duration (e.g. 30 or 00:00:30)
echo.
pause
exit /b 1
