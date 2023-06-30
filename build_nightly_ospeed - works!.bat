@echo off
setlocal

call C:\_SRCS\Odin\odin run .\src -out:microui-odin.exe -o:speed -vet -strict-style -show-timings -define:GL_DEBUG=true -subsystem:console 

pause
