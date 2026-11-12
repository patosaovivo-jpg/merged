@echo off
setlocal
cd /d "%~dp0"
set "GODOT=C:\Godot\Godot_v4.7.2-stable_win64.exe"
set "GODOTC=C:\Godot\Godot_v4.7.2-stable_win64_console.exe"
if not exist "%GODOT%" (echo Godot nao encontrado em C:\Godot & pause & exit /b 1)
echo [1/2] Importando assets...
"%GODOTC%" --headless --path . --import > "%~dp0godot_import.txt" 2>&1
echo [2/2] Abrindo o lab...
start "" "%GODOT%" --path .
exit /b 0
