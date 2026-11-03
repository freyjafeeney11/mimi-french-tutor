@echo off
setlocal enabledelayedexpansion

:: Optional: Set window title and text color (Light Blue)
title Mimi AI Launcher
color 0B

echo =========================================
echo      Mimi AI French Teacher Launcher
echo =========================================
echo.

:: Ensure working directory is the folder where this batch file lives
cd /d "%~dp0"

:: ----------------------------------------------------
:: Configuration Variables (Easier to maintain)
:: ----------------------------------------------------
set "GODOT_PATH=C:\Users\Freyja\Desktop\Godot.exe"
set "FRONTEND_PATH=%~dp0frontend\mimi"
set "BACKEND_DIR=%~dp0backend"

:: Model used by Ollama AND by server.py (it reads OLLAMA_MODEL).
:: To try another model, change only this line (e.g. qwen2.5:7b).
set "MODEL=gemma3:4b"
set "OLLAMA_MODEL=%MODEL%"

:: ----------------------------------------------------
:: Step 1: Check and Setup Python Backend
:: ----------------------------------------------------
echo [1/4] Checking Python Virtual Environment...

if not exist "%BACKEND_DIR%\venv\Scripts\activate.bat" (
    echo [!] Virtual environment not found. Creating venv in backend folder...
    cd /d "%BACKEND_DIR%"

    python -m venv venv
    if errorlevel 1 (
        echo [X] Failed to create virtual environment. Ensure Python is installed and added to PATH.
        pause
        exit /b 1
    )
    cd /d "%~dp0"
) else (
    echo [+] Virtual environment found.
)

echo [*] Verifying dependencies...
call "%BACKEND_DIR%\venv\Scripts\activate.bat"

:: Install/update dependencies every time the launcher runs
if exist "%BACKEND_DIR%\requirements.txt" (
    pip install -q -r "%BACKEND_DIR%\requirements.txt"
) else if exist "requirements.txt" (
    pip install -q -r requirements.txt
) else (
    echo [!] Warning: requirements.txt not found!
    echo [!] Please create one in your backend folder with 'fastapi', 'uvicorn' and 'httpx' in it.
)

if errorlevel 1 (
    echo [X] Failed to install dependencies.
    pause
    exit /b 1
)
echo [+] Environment setup complete!

:: ----------------------------------------------------
:: Step 2: Start Ollama and make sure the model is available
:: ----------------------------------------------------
echo.
echo [2/4] Starting Ollama (%MODEL%)...
:: If the Ollama tray app is already running, this just exits harmlessly.
start "Ollama AI" /min cmd /c "ollama serve"

echo [*] Waiting 3 seconds for Ollama to start...
timeout /t 3 /nobreak >nul

:: Download the model the first time (several GB, so this can take a while)
ollama list | findstr /i /c:"%MODEL%" >nul
if errorlevel 1 (
    echo [!] Model %MODEL% not found locally. Downloading it now...
    ollama pull %MODEL%
    if errorlevel 1 (
        echo [X] Failed to download %MODEL%. Is Ollama running and are you online?
        pause
        exit /b 1
    )
) else (
    echo [+] Model %MODEL% found.
)

:: Pre-load the model into memory so the first message isn't slow
start "Ollama Model Pre-load" /min cmd /c "ollama run %MODEL% """

:: ----------------------------------------------------
:: Step 3: Start Python Backend
:: ----------------------------------------------------
echo [3/4] Starting Python Backend...
:: OLLAMA_MODEL is inherited by the new window, so server.py uses the same model.
start "Mimi Backend" /min cmd /k "cd /d "%BACKEND_DIR%" && call venv\Scripts\activate.bat && python -m uvicorn server:app --reload"

echo [*] Waiting 5 seconds for backend to initialize...
timeout /t 5 /nobreak >nul

:: ----------------------------------------------------
:: Step 4: Launch Godot Frontend
:: ----------------------------------------------------
echo [4/4] Launching Godot Frontend...
if exist "%GODOT_PATH%" (
    start "Mimi Frontend" "%GODOT_PATH%" --path "%FRONTEND_PATH%"
) else (
    echo [X] Error: Godot executable not found at %GODOT_PATH%
    echo Please update the GODOT_PATH variable at the top of this script.
    pause
    exit /b 1
)

echo.
echo =========================================
echo [+] All systems launched! You can close this window.
echo =========================================
timeout /t 3 >nul