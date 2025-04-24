param ($tenantId,$azskOutPath,$assessmentPath)

write-host "RUNNING SCRIPT - AZURE SECURE DEVOPS KIT`n" -f CYAN

# Define the module names
$modules = @('AzSK')
    
# Check if AzSK is already installed
$azskModule = Get-Module -ListAvailable -Name 'AzSK'

if (-not $azskModule) {
    Write-Host "AzSK module not found. Attempting to install..." -ForegroundColor Yellow

    # Install the AzSK module and suppress warnings
    try {
        Install-Module -Name 'AzSK' -Scope CurrentUser -AllowClobber -SkipPublisherCheck -Force -ErrorAction Stop
        Write-Host "[+] AzSK module installed successfully." -ForegroundColor Green
    } catch {
        Write-Host "[!] Error installing AzSK module: $_" -ForegroundColor Red
    }
} else {
    Write-Host "[+] AzSK module is already installed." -ForegroundColor Green
}

Connect-AzAccount -TenantId $tenantId

# Capture all subscriptions
$subIds = Get-AzSubscription | Select-Object -ExpandProperty Id

# Subscription Security Status
Write-Host "Running Subscription Security Status..." -ForegroundColor Yellow
foreach ($sub in $subIds) {
    Set-AzContext -SubscriptionId $sub
    Get-AzSKSubscriptionSecurityStatus -SubscriptionId $sub -DoNotOpenOutputFolder

    $resourceGroups = Get-AzResourceGroup | Select-Object -ExpandProperty ResourceGroupName
    foreach ($rg in $resourceGroups) {
        Get-AzSKAzureServicesSecurityStatus -SubscriptionId $sub -ResourceGroupNames $rg -DoNotOpenOutputFolder
    }
}

# 1. Copy AzSK logs from local user profile
Copy-Item -Path "$env:LOCALAPPDATA\Microsoft\AzSKLogs" -Destination $azskOutPath -Recurse -Force

# 2. Clear the original AzSK log folder
Remove-Item -Path "$env:LOCALAPPDATA\Microsoft\AzSKLogs\*" -Recurse -Force

# 3. Prune any scan folders that don't include a SecurityReport*.csv
$logsRoot = Join-Path $assessmentPath "AzSK\AzSKLogs"

Get-ChildItem -Path $logsRoot -Directory | ForEach-Object {
    $subscriptionPath = $_.FullName

    Get-ChildItem -Path $subscriptionPath -Directory | ForEach-Object {
        $scanFolder = $_.FullName
        $csvExists = Get-ChildItem -Path $scanFolder -Recurse -Filter "SecurityReport*.csv" -ErrorAction SilentlyContinue

        if (-not $csvExists) {
            Write-Host "Removing folder: $scanFolder"
            Remove-Item -Path $scanFolder -Recurse -Force
        }
    }
}
