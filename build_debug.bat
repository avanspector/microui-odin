@echo off
setlocal

call C:\_SRCS\Odin\odin run .\src -out:mu-odin.exe -debug -vet -strict-style -show-timings -subsystem:console 

pause
