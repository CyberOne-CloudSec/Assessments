#RUN SCRIPT ON POWERSHELL 5.1

#$downloadsPath = Join-Path -Path $env:USERPROFILE -ChildPath "Downloads"; Start-Process "C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe" -ArgumentList "-ExecutionPolicy Bypass -File `"$downloadsPath\start.ps1`"" -Verb RunAs

#INSTALL GIT WINGET
$ErrorActionPreference = 'SilentlyContinue'
$downloadsPath = Join-Path -Path $env:USERPROFILE -ChildPath "Downloads"
$gitInstalled = git --version

if($gitInstalled -eq $null){
    write-host "Installing Git" -Foreground yellow
    winget install --id Git.Git -e --source winget

    $command = "Set-Location `"$downloadsPath`"; & `".\start.ps1`""
    Start-Process powershell.exe -ArgumentList '-NoProfile', '-NoExit', '-Command', $command -Verb RunAs; Exit
}

write-host "RUNNING SCRIPT - M365SAT`n" -f CYAN
$userPrincipalName = $(Write-Host "Enter User Name: " -f yellow -NoNewLine; Read-Host)
$tenantId = $(Write-Host "Enter Tenant Id: " -f yellow -NoNewLine; Read-Host)
$defaultSubId = $(Write-Host "Enter Default Subscription Id: " -f yellow -NoNewLine; Read-Host)
Update-AzConfig -DefaultSubscriptionForLogin $defaultSubId

#CREATE DIRECTORY FOLDERS
$documentsPath = Join-Path -Path $env:USERPROFILE -ChildPath "Documents"
$getDate = Get-Date -Format 'MM/dd/yyyy'
$date = $getDate -replace '/','.'
$clonePath = $documentsPath+'\BPA-'+$date+'\'
$azskPath = $clonePath+"AzSK"
$m365satPath = $clonePath+"M365SAT"
$outPath = $clonePath+"M365-SAT"


if (Test-Path -Path $clonePath) {
    Remove-Item $clonePath -Recurse -Force
    New-Item $clonePath -Type Directory
    git clone https://github.com/CyberOne-CloudSec/Assessments $clonePath
}
else {
    New-Item $clonePath -Type Directory
    git clone https://github.com/CyberOne-CloudSec/Assessments $clonePath
}

#UNBLOCK FILES
$files = Get-ChildItem $pathDate -Recurse -File

foreach ($file in $files) {
    Unblock-File -Path $file.FullName -Confirm:$false
}

#RUN M365SAT
Set-Location $m365Path
#.\M365SATTester.ps1 $outPath $userPrincipalName $services

#CLEAN UP
Remove-Item -Path $m365Path -Recurse -Force
Remove-Item -Path "$clonePath\start.ps1" -Force

$ErrorActionPreference = 'Continue'

#SECURE DEVOPS KIT (AZSK)

$command = "Set-Location `"$azskPath`"; & `".\AzSK-Start.ps1`" -TenantId `"$tenantId`" -DefaultSubId `"$defaultSubId`" -ClonePath `"$clonePath`"" 

Start-Process powershell.exe -ArgumentList '-NoProfile', '-NoExit', '-Command', $command -Verb RunAs; Exit
