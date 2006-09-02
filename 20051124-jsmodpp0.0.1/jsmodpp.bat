@IF "%1" NEQ "" (
	@perl "-I%~dp0\" "%~dp0jsmodpp.pl" "%1"
) ELSE (
	@echo Usage: jsmodpp JS-FILE
)