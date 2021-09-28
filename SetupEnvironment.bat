@echo off
:: setup following environment variables to point to correct location of external libraries

SET DPF=%PROGRAMFILES(X86)%
if "%DPF%"=="" (
	SET DPF="%PROGRAMFILES%"
)

IF EXIST "%DPF%\Embarcadero\Studio\22.0\bin\rsvars.bat" (
  ECHO Found Delphi 11.0 Alexandria
  CALL "%DPF%\Embarcadero\Studio\22.0\bin\rsvars.bat"
) ELSE (
	IF EXIST "%DPF%\Embarcadero\Studio\21.0\bin\rsvars.bat" (
	  ECHO Found Delphi 10.4 Sydney
	  CALL "%DPF%\Embarcadero\Studio\21.0\bin\rsvars.bat"
	) ELSE (
		IF EXIST "%DPF%\Embarcadero\Studio\20.0\bin\rsvars.bat" (
		  ECHO Found Delphi 10.3 Rio
		  CALL "%DPF%\Embarcadero\Studio\20.0\bin\rsvars.bat"
		) ELSE (
			ECHO Unsupported Compiler Please use DX 10.3 or newer.
			Exit /B 1
		)
	)
)
