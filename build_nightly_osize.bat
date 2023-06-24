@echo off
setlocal

call C:\_SRCS\Odin\odin run .\src -o:size -out:microui-odin.exe -subsystem:console -show-timings -define:GL_DEBUG=true

pause
