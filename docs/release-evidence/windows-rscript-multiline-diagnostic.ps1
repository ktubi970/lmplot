$ErrorActionPreference = 'Stop'
$env:LC_ALL = 'C'
$env:LC_CTYPE = 'C'
$env:LANG = 'C'
$PSNativeCommandArgumentPassing = 'Windows'
$PSNativeCommandUseErrorActionPreference = $false

$taskRRoot = 'C:/Program Files/R/R-4.6.0'
$taskBinaries = [ordered]@{
  dispatcher = Join-Path $taskRRoot 'bin/Rscript.exe'
  x64 = Join-Path $taskRRoot 'bin/x64/Rscript.exe'
}
$taskLines = @(
  'stopifnot(getRversion() == "4.6.0")'
  'cat("SECOND_LINE_REACHED\n")'
  'stop("THIRD_LINE_STOP")'
)

[pscustomobject]@{
  PowerShell = $PSVersionTable.PSVersion.ToString()
  OS = $PSVersionTable.OS
  NativeArgumentMode = $PSNativeCommandArgumentPassing
  RRoot = $taskRRoot
  Lines = $taskLines
} | ConvertTo-Json -Compress

foreach ($taskBinary in $taskBinaries.GetEnumerator()) {
  foreach ($taskSeparator in @('LF', 'CRLF')) {
    $taskCode = $taskLines -join $(if ($taskSeparator -eq 'LF') { "`n" } else { "`r`n" })
    $taskOutput = & $taskBinary.Value --vanilla -e $taskCode 2>&1
    $taskExit = $LASTEXITCODE
    [pscustomobject]@{
      invocation = 'inline -e'
      binary = $taskBinary.Key
      separator = $taskSeparator
      output = @($taskOutput | ForEach-Object { $_.ToString() })
      exit = $taskExit
    } | ConvertTo-Json -Compress
  }
}

# Prove that executing the same code from a file reaches the later assertion.
$taskFixture = Join-Path $PSScriptRoot 'windows-rscript-multiline-diagnostic.tmp.R'
try {
  foreach ($taskBinary in $taskBinaries.GetEnumerator()) {
    foreach ($taskSeparator in @('LF', 'CRLF')) {
      $taskCode = $taskLines -join $(if ($taskSeparator -eq 'LF') { "`n" } else { "`r`n" })
      [System.IO.File]::WriteAllText($taskFixture, $taskCode, [System.Text.UTF8Encoding]::new($false))
      $taskOutput = & $taskBinary.Value --vanilla $taskFixture 2>&1
      $taskExit = $LASTEXITCODE
      [pscustomobject]@{
        invocation = 'file'
        binary = $taskBinary.Key
        separator = $taskSeparator
        output = @($taskOutput | ForEach-Object { $_.ToString() })
        exit = $taskExit
      } | ConvertTo-Json -Compress
    }
  }
} finally {
  if (Test-Path -LiteralPath $taskFixture) { Remove-Item -LiteralPath $taskFixture }
}
exit 0
