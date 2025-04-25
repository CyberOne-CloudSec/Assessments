write-host "`nRUNNING SCRIPT - AZURE SECURE DEVOPS KIT" -f CYAN

# Define the target Az.Accounts version
$targetAzAccountsVersion = '1.7.1'

# Ensure 'Az' module (any submodule) is available and importable
function Ensure-AzModule {
    $azModules = Get-Module -ListAvailable -Name 'Az.*'
    if (-not $azModules) {
        Write-Host "[!] Az modules not found. Installing 'Az'..." -ForegroundColor Yellow
        Install-Module -Name 'Az' -Scope CurrentUser -AllowClobber -Force
    } else {
        Write-Host "[+] Az modules are already installed." -ForegroundColor Green
    }
}

# Ensure 'AzSK' module is available and importable
function Ensure-AzSKModule {
    $azModules = Get-Module -ListAvailable -Name 'AzSk'
    if (-not $azModules) {
        Write-Host "[!] AzSK modules not found - installing now..." -ForegroundColor Yellow
        Install-Module -Name 'AzSK' -Scope CurrentUser -AllowClobber -SkipPublisherCheck -Force -ErrorAction Stop
    } else {
        Write-Host "[+] AzSK modules are already installed." -ForegroundColor Green
    }

    try {
        Import-Module AzSK -ErrorAction Stop
        Write-Host "[+] AzSK module imported successfully." -ForegroundColor Green
    } catch {
        Write-Host "[!] Failed to import AzSK: $_" -ForegroundColor Red
    }
}

# Remove all Az.Accounts versions except target
function Enforce-AzAccountsVersion {
    Write-Host "[~] Checking for Az.Accounts versions..." -ForegroundColor Yellow
    Get-Module -Name 'Az.Accounts' -ListAvailable -ErrorAction SilentlyContinue |
    Where-Object { $_.Version -ne [version]$targetAzAccountsVersion } |
    ForEach-Object {
        Write-Host "[-] Uninstalling Az.Accounts version $($_.Version)..." -ForegroundColor Yellow
        Uninstall-Module -Name $_.Name -RequiredVersion $_.Version -Force -ErrorAction SilentlyContinue
    }

    $existingTarget = Get-Module -Name 'Az.Accounts' -ListAvailable |
                      Where-Object { $_.Version -eq [version]$targetAzAccountsVersion }

    if (-not $existingTarget) {
        Write-Host "[+] Installing Az.Accounts $targetAzAccountsVersion..." -ForegroundColor Yellow
        Install-Module -Name 'Az.Accounts' -RequiredVersion $targetAzAccountsVersion -Scope CurrentUser -Force -AllowClobber
    } else {
        Write-Host "[+] Az.Accounts $targetAzAccountsVersion already installed." -ForegroundColor Green
    }
}

# Execute logic
Ensure-AzModule
Ensure-AzSKModule
Enforce-AzAccountsVersion


# Connect to Az
$tenantId = $(Write-Host "Enter Tenant Id: " -ForegroundColor Yellow -NoNewLine; Read-Host)
$defaultSubId = $(Write-Host "Enter Default Subscription Id: " -ForegroundColor Yellow -NoNewLine; Read-Host)

Connect-AzAccount -TenantId $tenantId -Subscription $defaultSubId

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
Copy-Item -Path "$env:LOCALAPPDATA\Microsoft\AzSKLogs" -Destination $PSScriptRoot -Recurse -Force

# 2. Clear the original AzSK log folder
Remove-Item -Path "$env:LOCALAPPDATA\Microsoft\AzSKLogs\*" -Recurse -Force

# 3. Prune any scan folders that don't include a SecurityReport*.csv
$logsRoot = Join-Path $PSScriptRoot "\AzSKLogs"

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

ii $logsRoot

Write-Host "Press any key to exit..."
[void][System.Console]::ReadKey($true)
exit
