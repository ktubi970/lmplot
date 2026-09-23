@echo off
setlocal
pushd "%~dp0" || exit /b 1
set "RSCRIPT=C:\Program Files\R\R-4.6.0\bin\x64\Rscript.exe"
if not exist "%RSCRIPT%" (
  echo R 4.6.0 was not found at %RSCRIPT%.
  popd
  exit /b 1
)
rem Runtime only: bypass .Rprofile so a missing renv cannot bootstrap itself.
set "LMPLOT_LIBRARY=%CD%\renv\library\windows\R-4.6\x86_64-w64-mingw32"
"%RSCRIPT%" --vanilla -e "project_library <- Sys.getenv('LMPLOT_LIBRARY'); .libPaths(project_library, include.site=FALSE); if (!dir.exists(project_library) || !requireNamespace('renv', quietly=TRUE, lib.loc=project_library)) stop('Restore dependencies explicitly; see README.md.', call.=FALSE); if (!isTRUE(renv::status(project='.', library=.libPaths())$synchronized)) stop('Restore dependencies explicitly; see README.md.', call.=FALSE); shiny::runApp('.', launch.browser=TRUE)"
set "EXIT_CODE=%ERRORLEVEL%"
popd
endlocal & exit /b %EXIT_CODE%
