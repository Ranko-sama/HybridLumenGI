@echo off
start "HybridLumenGI" /D "%~dp0" "%~dp0HybridLumenGITest.exe" -force-d3d12 -screen-fullscreen 0 -screen-width 640 -screen-height 360 -logFile "%~dp0local-release.log"
