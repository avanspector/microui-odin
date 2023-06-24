@echo off
setlocal

call .\odin\odin run .\src -o:size -out:microui-odin.exe -subsystem:console -show-timings -define:GL_DEBUG=true

pause
