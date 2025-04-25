$userPrincipalName = $(Write-Host "Enter Global Admin credentials: " -f yellow -NoNewLine; Read-Host)

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
            Install-Module -Name $module -Scope CurrentUser -AllowClobber -Force -ErrorAction Stop
            Write-Host "[+] [$module] installed." -ForegroundColor Green
        } catch {
            Write-Host "[!] Failed to install [$module]: $_" -ForegroundColor Red
        }
    } else {
        Write-Host "[+] [$module] already installed." -ForegroundColor Green
    }
}

# Run M365SAT
.\M365SATTester.ps1 $m365OutPath $userPrincipalName
