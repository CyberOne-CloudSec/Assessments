write-host "`nRUNNING SCRIPT - MICROSOFT LICENSE REVIEW" -f CYAN

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

# Pull license data from Graph
$licenses = Invoke-MgGraphRequest -Uri "beta/subscribedSkus" -OutputType PSObject | 
    Select-Object -ExpandProperty value | 
    Where-Object { $_.CapabilityStatus -eq 'Enabled' -and  ($_.PrepaidUnits.enabled -lt 9998) }

# Build raw license allocation report
$licenseOverview = @()
foreach ($license in $licenses) {
    $skuPartNumber = $license.skuPartNumber
    $total = [int]$license.PrepaidUnits.Enabled
    $used  = [int]$license.ConsumedUnits
    $unused = $total - $used

    $licenseOverview += [PSCustomObject]@{
        "SKU Part Number" = $skuPartNumber
        "Total"      = $total
        "Assigned"   = $used
        "Unused"     = $unused
    }
}

# Export to CSV
$csvFile = "$PSScriptRoot\License_Review.csv"
$licenseOverview | Export-Csv -Path $csvFile -NoTypeInformation

# Disconnect
Disconnect-MgGraph

ii $PSScriptRoot

Write-Host "Press any key to exit..."
[void][System.Console]::ReadKey($true)
exit
