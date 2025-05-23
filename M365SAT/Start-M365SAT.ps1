write-host "`nRUNNING SCRIPT - MICROSOFT LICENSE REVIEW" -f CYAN

# Check if running as Administrator
if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "[!] Please run this script as Administrator." -ForegroundColor Red
    Write-Host "Press any key to exit..." -ForegroundColor Yellow
    [void][System.Console]::ReadKey($true)
    exit
}

$userPrincipalName = $(Write-Host "Enter Global Admin credentials: " -f yellow -NoNewLine; Read-Host)
$targetAzAccountsVersion = "2.19.0"

$m365OutPathReport = $PSScriptRoot + "\Report"
if (-not (Test-Path -Path $m365OutPathReport)) {New-Item -Path $m365OutPathReport -ItemType Directory | Out-Null}

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

Enforce-AzAccountsVersion

$modules = @(
    'ExchangeOnlineManagement',
    'Microsoft.Graph',
    'Microsoft.Graph.Beta',
    'Microsoft.Online.SharePoint.PowerShell',
    'MicrosoftTeams',
    'PoShLog'
)

foreach ($module in $modules) {
    $installed = Get-InstalledModule -Name $module -ErrorAction SilentlyContinue

    if (-not $installed) {
        Write-Host "Installing [$module]..." -ForegroundColor Yellow
        try {
            Install-Module -Name $module -Scope CurrentUser -AllowClobber -Force
            Write-Host "[+] [$module] installed." -ForegroundColor Green
        } catch {
            Write-Host "[!] Failed to install [$module]: $_" -ForegroundColor Red
        }
    } else {
        Write-Host "[+] [$module] already installed." -ForegroundColor Green
    }
}

# Connect Microsoft Graph
$scope = @(
    "Directory.Read.All", 
    "RoleManagement.Read.Directory", 
    "DeviceManagementServiceConfig.Read.All",
    "DeviceManagementConfiguration.Read.All", 
    "User.Read.All", 
    "Policy.Read.All",
    "DeviceManagementManagedDevices.Read.All", 
    "DeviceManagementApps.Read.All", 
    "Group.Read.All",
    "UserAuthenticationMethod.Read.All", 
    "GroupMember.Read.All", 
    "Organization.Read.All",
    "Domain.Read.All", 
    "AccessReview.Read.All", 
    "SecurityEvents.Read.All", 
    "AuditLog.Read.All"
    )

#Connect-MgGraph -ContextScope Process -Scope $scope

# Run M365SAT
.\M365SATTester.ps1 $m365OutPathReport $userPrincipalName

ii $m365OutPathReport
