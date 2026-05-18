#Requires -Version 7.0
#Requires -RunAsAdministrator

param(
    [Parameter(Mandatory = $true)]
    [string]$m365OutPathReport,
    [Parameter(Mandatory = $true)]
    [string]$userPrincipalName,
    [string[]]$ModulesToRun = @("Office365", "Exchange", "Teams", "Azure")
)

function ExecuteM365SAT {
    Import-Module .\M365SAT.psd1 -Force

    Get-M365SATReport `
        -OutPath $m365OutPathReport `
        -Username $userPrincipalName `
        -reportType "HTML" `
        -AllowLogging "Warning" `
        -Modules $ModulesToRun `
        -BenchmarkVersion LATEST `
        -LicenseMode All `
        -LicenseLevel All `
        -EnvironmentType M365 `
        -SkipChecks `
        -SkipLogin

    Remove-Module M365SAT -Force -ErrorAction SilentlyContinue
}

$IsAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $IsAdmin) {
    throw "Run this script as Administrator."
}

ExecuteM365SAT
