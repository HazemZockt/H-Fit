@echo off
set "HFIT_PYTHON=%USERPROFILE%\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe"
if exist "%HFIT_PYTHON%" (
  "%HFIT_PYTHON%" "%~dp0companion\launch.py"
) else (
  py "%~dp0companion\launch.py"
)
pause
