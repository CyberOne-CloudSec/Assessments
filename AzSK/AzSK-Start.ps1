write-host "RUNNING SCRIPT - AZURE SECURE DEVOPS KIT`n" -f CYAN
write-host "CHECKING MODULES" -f yellow

# Suppress warnings
$originalWarningPreference = $WarningPreference
$WarningPreference = 'SilentlyContinue'
$ErrorActionPreference = 'SilentlyContinue'

# Define the module names
$modules = @('Az', 'AzSK')

# Function to ensure the Az module is imported or installed
function Ensure-AzModule {
    # Check if the Az module is imported
    if (-not (Get-Module -Name 'Az.*')) {
        # If not imported, check if it is installed
        if (-not (Get-Module -ListAvailable -Name 'Az.*')) {
            # Install the Az module if not found
            Write-Host "Az module is not installed. Installing now..." -ForegroundColor Yellow
            Install-Module -Name 'Az' -Scope CurrentUser -AllowClobber -Force
            Write-Host "[+] Az module installed." -ForegroundColor Green
        } else {
            Write-Host "Az module is installed but not imported. Importing now..." -ForegroundColor Yellow
        }
        # Import the Az module
        Import-Module -Name 'Az' -ErrorAction Stop
        Write-Host "[+] Az module imported successfully." -ForegroundColor Green
    } else {
        Write-Host "Az module is already imported." -ForegroundColor Green
    }
}

# Function to ensure AzSK is installed
function Ensure-AzSKModule {
    Write-Host "Installing AzSK module..." -ForegroundColor Yellow
    Install-Module -Name 'AzSK' -Scope CurrentUser -AllowClobber -SkipPublisherCheck -Force
    Write-Host "[+] AzSK module installed." -ForegroundColor Green
}

# Ensure Az module is installed and imported
Ensure-AzModule

# Ensure AzSK module is installed
Ensure-AzSKModule

# Restore original warning preference
$WarningPreference = $originalWarningPreference

#CREATE DIRECTORY FOLDERS
$documentsPath = Join-Path -Path $env:USERPROFILE -ChildPath "Documents"
$getDate = Get-Date -Format 'MM/dd/yyyy'
$date = $getDate -replace '/','.'
$clonePath = $documentsPath+'\BPA-'+$date+'\'
$azskPath = $clonePath+"AzSK"
$outPath = $clonePath+"M365-SAT"

#CONNECT TO TENANT AND AZURE AD
$tenantId = $(Write-Host "Enter Tenant Id: " -f yellow -NoNewLine; Read-Host)
Connect-AzAccount -TenantId $tenantId

#CAPTURE SUBSCRIPTIONS
write-host "CAPTURING SUBSCRIPTIONS & RESOURCE GROUPS" -f yellow
$subIds = Get-AzSubscription | Select-Object id

#SUBSCRIPTION SECURITY STATUS
write-host "RUN SUBSCRIPTION SECURITY STATUS" -f yellow
Foreach ($i in $subIds){
    $sub = $i.Id
    
    Set-AzContext -SubscriptionId $sub
    Get-AzSKSubscriptionSecurityStatus -SubscriptionId $sub

    $resourceGroups = Get-AzResourceGroup | Select-Object ResourceGroupName

    foreach ($j in $resourceGroups){
        $rg = $j.ResourceGroupName       
        
        Get-AzSKAzureServicesSecurityStatus `
            -SubscriptionId $sub `
            -ResourceGroupNames $rg
    }
}

Copy-Item -Path "$env:LOCALAPPDATA\Microsoft\AzSKLogs" -Destination $azskPath -Recurse

#CLOSE ALL EXPLORER WINDOWS
Stop-Process -Name explorer -Force

#CLEAN UP
Remove-Item -Path "$azskPath\AzSK-Start.ps1" -Force

$ErrorActionPreference= 'Continue'

ii $azskPath; ii $outPath; Exit
