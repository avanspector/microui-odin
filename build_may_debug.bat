@echo off
setlocal

call .\odin\odin run .\src -debug -out:microui-odin.exe -subsystem:console -show-timings -define:GL_DEBUG=true

pause
