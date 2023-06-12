@echo off
setlocal

call C:\Users\drbuzz\Documents\_SRCS\Odin\odin run .\src -out:microui-odin.exe -subsystem:console -show-timings -define:GL_DEBUG=true

pause
