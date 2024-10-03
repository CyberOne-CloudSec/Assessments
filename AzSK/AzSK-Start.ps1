#CHECK IF MODULES EXISTS
$Modules = @('Az','AzSK')

foreach($m in $Modules){
	if($m -eq 'Az'){
		$name = 'Az*'
		$module = Get-Module -ListAvailable | where-Object {$_.Name -like $name} | select name
			
		if($module.name -ne $null){
			write-host "Module already installed: $m" -Foreground green
			Import-Module -Name $m
		}
		else{
			write-host "Installing module: $m" -Foreground yellow
			Install-Module -Name $m -Scope CurrentUser -Force -AllowClobber
		}
	}
	else{
		$module = Get-Module -Name $m -ListAvailable | select name
			
		if($module.name -ne $null){
			write-host "Module already installed: $m" -Foreground green
			Import-Module -Name $m
		}
		else{
			write-host "Installing module: $m" -Foreground yellow
			Install-Module $m -SkipPublisherCheck -Scope CurrentUser -AllowClobber -Force
		}
	}
}

#CONNECT TO TENANT AND AZURE AD
Connect-AzAccount

#CAPTURE SUBSCRIPTIONS
write-host "CAPTURE SUBSCRIPTIONS" -f yellow

#CREATE DIRECTORY FOLDERS
$path = 'C:\BPA'
$getDate = Get-Date -Format 'MM/dd/yyyy'
$date = $getDate -replace '/','.'
$mainPath = $path+'-'+$date+'\'
$azskPath = $mainPath+"AzSK"

# List files in the Documents folder
Get-AzSubscription | Export-Csv -Path "$azskPath\subscriptions.csv" -NoTypeInformation
$Subs = Import-Csv -Path "$azskPath\subscriptions.csv"

# CAPTURE RESOURCE GROUPS
Write-Host "CAPTURE RESOURCE GROUPS" -ForegroundColor Yellow
Get-AzResourceGroup | Select-Object ResourceGroupName | Export-Csv -Path "$azskPath\resourcegroups.csv" -NoTypeInformation
$ResourceGroups = Import-Csv -Path "$azskPath\resourcegroups.csv"

#SUBSCRIPTION SECURITY STATUS
write-host "RUN SUBSCRIPTION SECURITY STATUS" -f yellow
Foreach ($i in $Subs){
    $Sub = $i.Id
    Get-AzSKSubscriptionSecurityStatus -SubscriptionId $Sub
}

#SERVICES SECURITY STATUS PER RESOURCE GROUPS
foreach ($j in $ResourceGroups){
    $Groups = $j.ResourceGroupName
    Get-AzSKAzureServicesSecurityStatus `
        -SubscriptionId $Sub `
        -ResourceGroupNames $Groups
}

#CLEANUP FILES
$subscriptionsFile = Join-Path -Path $env:USERPROFILE -ChildPath "Documents\subscriptions.csv"
$resourceGroupsFile = Join-Path -Path $env:USERPROFILE -ChildPath "Documents\resourcegroups.csv"

if (Test-Path -Path $subscriptionsFile) {
    Remove-Item -Path $subscriptionsFile -Force
}

if (Test-Path -Path $resourceGroupsFile) {
    Remove-Item -Path $resourceGroupsFile -Force
}

#CLOSE ALL EXPLORER WINDOWS
Stop-Process -Name explorer -Force

#OPEN FOLDER PATH FOR ASKLOGS
Start-Process "$env:LOCALAPPDATA\Microsoft\AzSKLogs"

#Copy-Item -Path "$env:LOCALAPPDATA\Microsoft\AzSKLogs" -Destination $azskPath -Recurse
