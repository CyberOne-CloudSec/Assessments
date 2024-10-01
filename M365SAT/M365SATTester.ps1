#Requires -Version 5.1
#Requires -RunAsAdministrator

param ($outPath,$userPrincipalName)

function ExecuteM365SAT
{
	Import-Module .\M365SAT.psd1

	Get-M365SATReport `
		-OutPath $outPath `
		-Username $userPrincipalName `
		-reportType "HTML" `
		-AllowLogging "Warning" `
		-Modules All `
		-BenchmarkVersion LATEST `
		-LicenseMode All `
		-LicenseLevel All `
		-EnvironmentType M365
  		#-EnvironmentType AZURE,M365
  
	Remove-Module M365SAT -Force
}


function CheckAdminPrivBeta
{
	# Check if script is running as Adminstrator and if not use RunAs
	Write-Host "[...] Checking if the script is running as Administrator"
	$IsAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
	if (-not $IsAdmin)
	{
		Write-Warning "[!] Program needs Administrator Rights! Trying to Elevate to Admin..."
		Start-Process powershell -Verb runas -ArgumentList "-NoExit -c cd '$pwd'; .\M365SATTester.ps1"
	}
	else
	{
		Write-Host "[+] The script is running as Administrator..." -ForegroundColor Green
		ExecuteM365SAT
	}
}
CheckAdminPrivBeta
