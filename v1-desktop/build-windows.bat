@echo off
setlocal

cd /d "%~dp0"

python -m PyInstaller ^
  --noconfirm ^
  --clean ^
  --onedir ^
  --windowed ^
  --name SistemaOcorrencias ^
  --icon "escolaicone.ico" ^
  --collect-all customtkinter ^
  --collect-all pywhatkit ^
  --hidden-import pywhatkit ^
  "ocorrenciaescolar.py"

if errorlevel 1 exit /b %errorlevel%

set "PORTABLE_DIR=%CD%\dist\SistemaOcorrencias"
if exist ".env" copy /Y ".env" "%PORTABLE_DIR%\.env" >nul

echo Pacote portatil criado em: %PORTABLE_DIR%
