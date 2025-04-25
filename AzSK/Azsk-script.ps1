param ($tenantId,$azskOutPath,$assessmentPath)

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
        # Import the Az module with name checking disabled
        Import-Module -Name 'Az' -DisableNameChecking -ErrorAction Stop
        Write-Host "[+] Az module imported successfully." -ForegroundColor Green
    } else {
        Write-Host "[+] Az module is already imported." -ForegroundColor Green
    }
}

# Function to ensure AzSK is installed
function Ensure-AzSKModule {
    Write-Host "Checking if AzSK module is installed..." -ForegroundColor Yellow
    
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
}

# Ensure Az module is installed and imported
Ensure-AzModule

# Ensure AzSK module is installed
Ensure-AzSKModule


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
