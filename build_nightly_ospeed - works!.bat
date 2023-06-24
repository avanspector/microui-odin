@echo off
setlocal

call C:\_SRCS\Odin\odin run .\src -o:speed -out:microui-odin.exe -subsystem:console -show-timings -define:GL_DEBUG=true

pause
