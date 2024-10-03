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
Get-AzSubscription | Export-Csv -Path '$env:USERPROFILE\Documents\subscriptions.csv'
$Subs = Import-Csv -Path '$env:USERPROFILE\Documents\subscriptions.csv'

#CAPTURE RESROUCE GROUPS
write-host "CAPTURE RESOURCE GROUPS" -f yellow
Get-AzResourceGroup | select ResourceGroupName | Export-Csv -Path '$env:USERPROFILE\Documents\resourcegroups.csv'
$ResourceGroups = Import-Csv -Path '$env:USERPROFILE\Documents\resourcegroups.csv'

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

Exit

#Copy-Item -Path "$env:LOCALAPPDATA\Microsoft\AzSKLogs" -Destination $azskPath -Recurse
