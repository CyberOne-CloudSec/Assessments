#Requires -Version 7.0
#Requires -RunAsAdministrator

param(
    [string[]]$ModulesToRun = @("Office365", "Exchange", "Teams", "Azure"),
    [switch]$IncludeSharePoint,
    [switch]$IncludeSecurityCompliance,
    [switch]$SkipModuleInstall,
    [string]$TenantId
)

$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"
$DebugPreference = "SilentlyContinue"
$VerbosePreference = "SilentlyContinue"
$InformationPreference = "SilentlyContinue"

Write-Host "`nRUNNING SCRIPT MICROSOFT LICENSE REVIEW" -ForegroundColor Cyan
Write-Host "PowerShell version: $($PSVersionTable.PSVersion)" -ForegroundColor DarkCyan

$userPrincipalName = $(Write-Host "Enter administrator user principal name: " -ForegroundColor Yellow -NoNewLine; Read-Host)
if ([string]::IsNullOrWhiteSpace($TenantId)) {
    $TenantId = $(Write-Host "Enter tenant ID or primary tenant domain: " -ForegroundColor Yellow -NoNewLine; Read-Host)
}

$m365OutPathReport = Join-Path $PSScriptRoot "Report"
if (-not (Test-Path -Path $m365OutPathReport)) { New-Item -Path $m365OutPathReport -ItemType Directory | Out-Null }

if ($IncludeSecurityCompliance -and ($ModulesToRun -notcontains "SecurityCompliance")) { $ModulesToRun += "SecurityCompliance" }
if ($IncludeSharePoint) {
    Write-Host "[!] SharePoint was requested, but this WAM disabled build intentionally skips SharePoint inspectors." -ForegroundColor Yellow
    Write-Host "[!] SPO PowerShell does not support the same reliable device authentication path as Graph, EXO, Teams, and Az." -ForegroundColor Yellow
}
$ModulesToRun = $ModulesToRun | Where-Object { $_ -ne "Sharepoint" -and $_ -ne "SharePoint" } | Select-Object -Unique

function Install-RequiredModules {
    if ($SkipModuleInstall) { return }

    $modules = @(
        'ExchangeOnlineManagement',
        'Microsoft.Graph.Authentication',
        'Microsoft.Graph.Users',
        'Microsoft.Graph.Groups',
        'Microsoft.Graph.Identity.DirectoryManagement',
        'Microsoft.Graph.Identity.SignIns',
        'Microsoft.Graph.DeviceManagement',
        'Microsoft.Graph.Applications',
        'Microsoft.Graph.Reports',
        'MicrosoftTeams',
        'PoShLog'
    )

    if ($ModulesToRun -contains "Azure") { $modules += @('Az.Accounts', 'Az.Resources') }

    foreach ($module in ($modules | Select-Object -Unique)) {
        $installed = Get-InstalledModule -Name $module -ErrorAction SilentlyContinue
        if (-not $installed) {
            Write-Host "Installing [$module]..." -ForegroundColor Yellow
            Install-Module -Name $module -Scope CurrentUser -AllowClobber -Force
        }
        else {
            Write-Host "[+] [$module] already installed." -ForegroundColor Green
        }
    }
}

function Assert-GraphConnected {
    Write-Host "Connecting to Microsoft Graph with device code..." -ForegroundColor Yellow
    Import-Module Microsoft.Graph.Authentication -Force -ErrorAction Stop

    $existing = Get-MgContext -ErrorAction SilentlyContinue
    if ($existing) {
        Write-Host "[+] Microsoft Graph already connected." -ForegroundColor Green
        return
    }

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
        "GroupMember.Read.All",
        "UserAuthenticationMethod.Read.All",
        "Organization.Read.All",
        "Domain.Read.All",
        "AccessReview.Read.All",
        "SecurityEvents.Read.All",
        "AuditLog.Read.All",
        "IdentityProvider.Read.All",
        "ThreatIndicators.Read.All",
        "MailboxSettings.Read"
    )

    if ([string]::IsNullOrWhiteSpace($TenantId)) {
        Connect-MgGraph -ContextScope Process -Scopes $scope -UseDeviceCode -NoWelcome -ErrorAction Stop | Out-Null
    }
    else {
        Connect-MgGraph -TenantId $TenantId -ContextScope Process -Scopes $scope -UseDeviceCode -NoWelcome -ErrorAction Stop | Out-Null
    }

    $context = Get-MgContext -ErrorAction Stop
    if (-not $context) { throw "Graph connection failed. No Microsoft Graph context exists." }
    Get-MgOrganization -ErrorAction Stop | Out-Null
    Write-Host "[+] Microsoft Graph connected." -ForegroundColor Green
}

function Assert-ExchangeConnected {
    if ($ModulesToRun -notcontains "Exchange") { return }
    Write-Host "Connecting to Exchange Online without WAM..." -ForegroundColor Yellow
    Import-Module ExchangeOnlineManagement -Force -ErrorAction Stop

    $existing = Get-ConnectionInformation -ErrorAction SilentlyContinue
    if ($existing) {
        Write-Host "[+] Exchange Online already connected." -ForegroundColor Green
        return
    }

    $cmd = Get-Command Connect-ExchangeOnline -ErrorAction Stop

    if ($cmd.Parameters.ContainsKey("Device")) {
        Write-Host "Using Exchange Online device authentication." -ForegroundColor Yellow
        Connect-ExchangeOnline -UserPrincipalName $userPrincipalName -Device -ShowBanner:$false -ErrorAction Stop | Out-Null
    }
    elseif ($cmd.Parameters.ContainsKey("DisableWAM")) {
        Write-Host "Using Exchange Online DisableWAM authentication." -ForegroundColor Yellow
        Connect-ExchangeOnline -UserPrincipalName $userPrincipalName -DisableWAM -ShowBanner:$false -ErrorAction Stop | Out-Null
    }
    else {
        throw "This ExchangeOnlineManagement module does not expose Device or DisableWAM. Run Get-Command Connect-ExchangeOnline -Syntax and validate the installed EXO module."
    }

    Get-ConnectionInformation -ErrorAction Stop | Out-Null
    Write-Host "[+] Exchange Online connected." -ForegroundColor Green
}

function Assert-TeamsConnected {
    if ($ModulesToRun -notcontains "Teams") { return }
    Write-Host "Connecting to Microsoft Teams with device authentication..." -ForegroundColor Yellow
    Import-Module MicrosoftTeams -Force -ErrorAction Stop
    Connect-MicrosoftTeams -UseDeviceAuthentication -ErrorAction Stop | Out-Null
    Write-Host "[+] Microsoft Teams connected." -ForegroundColor Green
}

function Assert-AzureConnected {
    if ($ModulesToRun -notcontains "Azure") { return }
    Write-Host "Checking Azure PowerShell connection..." -ForegroundColor Yellow
    Import-Module Az.Accounts -Force -ErrorAction Stop

    $existing = Get-AzContext -ErrorAction SilentlyContinue
    if ($existing -and $existing.Account) {
        Write-Host "[+] Azure already connected as $($existing.Account.Id)." -ForegroundColor Green
        return
    }

    Write-Host "Connecting to Azure PowerShell with device authentication..." -ForegroundColor Yellow
    if ([string]::IsNullOrWhiteSpace($TenantId)) {
        Connect-AzAccount -UseDeviceAuthentication -ErrorAction Stop | Out-Null
    }
    else {
        Connect-AzAccount -Tenant $TenantId -UseDeviceAuthentication -ErrorAction Stop | Out-Null
    }

    $context = Get-AzContext -ErrorAction Stop
    if (-not $context) { throw "Azure authentication failed. No Az context exists." }
    Get-AzTenant -ErrorAction Stop | Out-Null
    Write-Host "[+] Azure PowerShell connected as $($context.Account.Id)." -ForegroundColor Green
}

function Assert-SecurityComplianceConnected {
    if ($ModulesToRun -notcontains "SecurityCompliance") { return }
    Write-Host "Connecting to Security and Compliance PowerShell with WAM disabled..." -ForegroundColor Yellow
    Import-Module ExchangeOnlineManagement -Force -ErrorAction Stop
    $cmd = Get-Command Connect-IPPSSession -ErrorAction Stop
    if ($cmd.Parameters.ContainsKey("DisableWAM")) {
        Connect-IPPSSession -UserPrincipalName $userPrincipalName -DisableWAM -ErrorAction Stop | Out-Null
    }
    else {
        Connect-IPPSSession -UserPrincipalName $userPrincipalName -ErrorAction Stop | Out-Null
    }
    Write-Host "[+] Security and Compliance PowerShell connected." -ForegroundColor Green
}

Install-RequiredModules
Assert-GraphConnected
Assert-ExchangeConnected
Assert-TeamsConnected
Assert-AzureConnected
Assert-SecurityComplianceConnected

Write-Host "Running M365SAT with modules: $($ModulesToRun -join ', ')" -ForegroundColor Cyan
.\M365SATTester.ps1 -m365OutPathReport $m365OutPathReport -userPrincipalName $userPrincipalName -ModulesToRun $ModulesToRun

Invoke-Item $m365OutPathReport
