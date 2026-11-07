@echo off
rem Win10Lab guest-side graceful shutdown fallback. Not a startup task or service.
"%SystemRoot%\System32\shutdown.exe" /s /t 0
exit /b %errorlevel%
