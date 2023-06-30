@echo off
setlocal

call C:\_SRCS\Odin\odin run .\src -out:mu-odin.exe -o:speed -vet -strict-style -show-timings -subsystem:console -define:RDR_GL=directx11

pause
