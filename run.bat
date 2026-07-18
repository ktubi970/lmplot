@echo off
set RSCRIPT="C:\Program Files\R\R-4.6.0\bin\x64\Rscript.exe"
echo Checking dependencies...
%RSCRIPT% -e "req <- c('shiny', 'plotly', 'shinythemes', 'bslib', 'DT', 'ggplot2', 'lme4'); ins <- req[!(req %%in%% installed.packages()[,'Package'])]; if(length(ins)) install.packages(ins, repos='https://cloud.r-project.org')"
echo Starting Shiny App...
%RSCRIPT% -e "shiny::runApp('app.R', launch.browser = TRUE)"
pause
