@echo off
cls
cd /d %0\..
TITLE "Air Monkey Package"
setlocal
::call .\build.bat

.\tools\msxsl.exe application.xml version.xsl>.\tools\v
set /p v=<.\tools\v
del .\tools\v
echo "v = %v%"

echo Packaging MyAirApp_%v%.air 
adt -package -storetype pkcs12 -keystore cert.p12 -storepass LetItAllOut MyAirApp_%v%.air application.xml _site 
endlocal
pause