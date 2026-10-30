@echo off
start "HybridLumenGI Unified Sample" /D "%~dp0" "%~dp0HybridLumenGIPlayer.exe" -force-d3d12 -screen-fullscreen 0 -screen-width 960 -screen-height 540 -logFile "%~dp0..\LocalRelease94.log"
