write-host "`nRUNNING SCRIPT - MICROSOFT LICENSE REVIEW" -f CYAN

# Check if running as Administrator
if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "[!] Please run this script as Administrator." -ForegroundColor Red
    Write-Host "Press any key to exit..." -ForegroundColor Yellow
    [void][System.Console]::ReadKey($true)
    exit
}

# Ensure Required Microsoft Graph Modules Are Installed & Imported
$modules = @(
    "Microsoft.Graph.Authentication",
    "Microsoft.Graph.Beta.Users",
    "Microsoft.Graph.Identity.DirectoryManagement"
)

foreach ($module in $modules) {
    if (Get-Module -ListAvailable -Name $module) {
        if (-not (Get-Module -Name $module)) {
            try {
                Import-Module $module -ErrorAction Stop
                Write-Host "Imported module: $module" -ForegroundColor Green
            } catch {
                Write-Warning "Failed to import module: $module. Error: $_"
            }
        } else {
            Write-Host "Module already imported: $module" -ForegroundColor Gray
        }
    } else {
        try {
            Install-Module -Name $module -Scope CurrentUser -AllowClobber -Force -ErrorAction Stop
            Import-Module $module -ErrorAction Stop
            Write-Host "Installed and imported module: $module" -ForegroundColor Green
        } catch {
            Write-Warning "Failed to install or import module: $module. Error: $_"
        }
    }
}

# Check Microsoft Graph connection
$state = Get-MgContext

# Define required permissions
$requiredPerms = @(
    "User.Read.All",
    "AuditLog.Read.All",
    "Organization.Read.All",
    "Directory.Read.All"
)

# Check connection status and permissions
$hasAllPerms = $false
if ($state) {
    $missingPerms = @()
    foreach ($perm in $requiredPerms) {
        if ($state.Scopes -notcontains $perm) {
            $missingPerms += $perm
        }
    }

    if ($missingPerms.Count -eq 0) {
        $hasAllPerms = $true
        Write-Host "Connected to Microsoft Graph with all required permissions" -ForegroundColor Green
    } else {
        Write-Host "Missing required permissions: $($missingPerms -join ', ')" -ForegroundColor Yellow
        Write-Host "Reconnecting with all required permissions..." -ForegroundColor Yellow
    }
} else {
    Write-Host "Not connected to Microsoft Graph. Connecting now..." -ForegroundColor Yellow
}

# Connect if needed
if (-not $hasAllPerms) {
    try {
        Connect-MgGraph -Scopes $requiredPerms -ErrorAction Stop -NoWelcome
        Write-Host "Successfully connected to Microsoft Graph" -ForegroundColor Green
    } catch {
        Write-Error "Failed to connect to Microsoft Graph: $_"
        exit
    }
}

# Define path to the CSV in the same folder as the script
$csvPath = Join-Path -Path $PSScriptRoot -ChildPath 'Product names and service plan identifiers for licensing.csv'
$productList = Import-Csv -Path $csvPath

# Build a mapping: GUID → Product_Display_Name
$guidMap = @{}
foreach ($item in $productList) {
    $guid = $item.GUID
    if ($guid) {
        $guidMap[$guid] = $item.Product_Display_Name
    }
}

# Pull license data from Microsoft Graph
$licenses = Invoke-MgGraphRequest -Uri "https://graph.microsoft.com/beta/subscribedSkus" -OutputType PSObject |
    Select-Object -ExpandProperty value |
    Where-Object { $_.CapabilityStatus -eq 'Enabled' -and $_.PrepaidUnits.Enabled -lt 9998 }

# Build report
$licenseOverview = @()
foreach ($license in $licenses) {
    $skuId = $license.skuId
    $skuName = $license.skuPartNumber
    $productName = $null

    # Try matching skuId to GUID → Product_Display_Name
    if ($guidMap.ContainsKey($skuId)) {
        $productName = $guidMap[$skuId]
    }
    else {
        $productName = $skuName # fallback
    }

    $total  = [int]$license.PrepaidUnits.Enabled
    $used   = [int]$license.ConsumedUnits
    $unused = $total - $used

    $licenseOverview += [PSCustomObject]@{
        "Product Name"  = $productName
        "Total"         = $total
        "Assigned"      = $used
        "Unused"        = $unused
    }
}

# Export to CSV
$csvFile = "$PSScriptRoot\License_Review.csv"
$licenseOverview | Export-Csv -Path $csvFile -NoTypeInformation

# Disconnect
Disconnect-MgGraph

ii $PSScriptRoot
