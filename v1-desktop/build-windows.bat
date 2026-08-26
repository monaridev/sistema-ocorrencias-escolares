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
  --collect-data googleapiclient ^
  --hidden-import pywhatkit ^
  "ocorrenciaescolar.py"

if errorlevel 1 exit /b %errorlevel%

set "PORTABLE_DIR=%CD%\dist\SistemaOcorrencias"
for %%F in (.env credentials.json token.json) do (
  if exist "%%F" copy /Y "%%F" "%PORTABLE_DIR%\%%F" >nul
)

echo Pacote portatil criado em: %PORTABLE_DIR%
