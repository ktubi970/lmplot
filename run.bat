@echo off
setlocal
pushd "%~dp0" || exit /b 1
set "RSCRIPT=C:\Program Files\R\R-4.6.0\bin\x64\Rscript.exe"
if not exist "%RSCRIPT%" (
  echo R 4.6.0 was not found at %RSCRIPT%.
  popd
  exit /b 1
)
"%RSCRIPT%" -e "if (!requireNamespace('renv', quietly=TRUE)) install.packages('renv', repos='https://cloud.r-project.org'); renv::restore(prompt=FALSE); shiny::runApp('.', launch.browser=TRUE)"
set "EXIT_CODE=%ERRORLEVEL%"
popd
endlocal & exit /b %EXIT_CODE%
