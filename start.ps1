#RUN SCRIPT ON POWERSHELL 5.1

$userPrincipalName = $(Write-Host "Enter User Name: " -f yellow -NoNewLine; Read-Host)
#$tenant = $(Write-Host "Enter Tenant Id: " -f yellow -NoNewLine; Read-Host)
$fullDomain = ($userPrincipalName -split "@")[1]
$domain = ($fullDomain -split ".c")[0]

#CREATE DIRECTORY FOLDERS
$path = 'C:\BPA'
$getDate = Get-Date -Format 'MM/dd/yyyy'
$date = $getDate -replace '/','.'
$mainPath = $path+'-'+$date+'\'
$gitHubPath = 'GitHubRepo'
$orgName = $domain.ToUpper()

$clonePath = $mainPath+$gitHubPath
$outPath = $mainPath+$orgName+'\Report\'

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
Set-Location "$clonePath\M365SAT\"
.\M365SATTester.ps1 $outPath $userPrincipalName $services