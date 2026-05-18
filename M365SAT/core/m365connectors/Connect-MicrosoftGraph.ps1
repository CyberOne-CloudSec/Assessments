function Get-M365SATGraphScopes {
    return @(
        "AuditLog.Read.All",
        "Policy.Read.All",
        "Directory.Read.All",
        "IdentityProvider.Read.All",
        "Organization.Read.All",
        "SecurityEvents.Read.All",
        "ThreatIndicators.Read.All",
        "User.Read.All",
        "UserAuthenticationMethod.Read.All",
        "MailboxSettings.Read",
        "Group.Read.All",
        "GroupMember.Read.All",
        "RoleManagement.Read.Directory",
        "DeviceManagementManagedDevices.Read.All",
        "DeviceManagementApps.Read.All",
        "DeviceManagementServiceConfig.Read.All",
        "DeviceManagementConfiguration.Read.All",
        "AccessReview.Read.All",
        "Domain.Read.All"
    )
}

function Get-M365SATOrgNameFromGraph {
    try {
        $org = Get-MgOrganization -ErrorAction Stop
        $domain = $org.VerifiedDomains | Where-Object { ($_.Name -like "*.onmicrosoft.com") -and ($_.Name -notlike "*mail.onmicrosoft.com") } | Select-Object -First 1
        if ($domain) { return (($domain.Name -split '.onmicrosoft.com')[0]) }
        return $null
    }
    catch { return $null }
}

function Get-M365SATGraphTokenFromAzureCli {
    $tenant = $script:M365SATTenantId
    if ([string]::IsNullOrWhiteSpace($tenant)) { $tenant = $env:M365SAT_TENANT_ID }
    if ([string]::IsNullOrWhiteSpace($tenant)) { return $null }
    if (-not (Get-Command az -ErrorAction SilentlyContinue)) { return $null }

    try {
        $token = az account get-access-token --tenant $tenant --resource-type ms-graph --query accessToken -o tsv 2>$null
        if ([string]::IsNullOrWhiteSpace($token)) {
            $token = az account get-access-token --tenant $tenant --resource "https://graph.microsoft.com/" --query accessToken -o tsv 2>$null
        }
        if ([string]::IsNullOrWhiteSpace($token)) { return $null }
        return $token
    }
    catch { return $null }
}

function Connect-M365SATGraphWithToken {
    param([Parameter(Mandatory = $true)][string]$AccessToken)
    try {
        $secureToken = ConvertTo-SecureString $AccessToken -AsPlainText -Force
        Connect-MgGraph -AccessToken $secureToken -NoWelcome -ErrorAction Stop | Out-Null
    }
    catch {
        Connect-MgGraph -AccessToken $AccessToken -NoWelcome -ErrorAction Stop | Out-Null
    }
}

function Connect-M365SATGraphDeviceCode {
    Write-Host "Connecting to Microsoft Graph PowerShell..."
    $existing = Get-MgContext -ErrorAction SilentlyContinue
    if ($existing) {
        Write-Host "Already connected to Microsoft Graph PowerShell." -ForegroundColor DarkYellow -BackgroundColor Black
        $existingOrg = Get-M365SATOrgNameFromGraph
        if ($existingOrg) { return $existingOrg }
    }

    try {
        $token = Get-M365SATGraphTokenFromAzureCli
        if ($token) {
            Connect-M365SATGraphWithToken -AccessToken $token
        }
        else {
            $scope = Get-M365SATGraphScopes
            Connect-MgGraph -ContextScope Process -Scopes $scope -UseDeviceCode -NoWelcome -ErrorAction Stop | Out-Null
        }

        if ((Get-MgContext -ErrorAction SilentlyContinue) -ne $null) {
            Write-Host "Connected to Microsoft Graph PowerShell." -ForegroundColor DarkYellow -BackgroundColor Black
            $OrgName = Get-M365SATOrgNameFromGraph
            if ([string]::IsNullOrWhiteSpace($OrgName)) { throw "Graph connected, but organization name could not be detected." }
            return $OrgName
        }
        throw "Graph context was not created."
    }
    catch {
        Write-Error "Failed to connect to Microsoft Graph PowerShell. $($_.Exception.Message)"
        throw
    }
}

function Invoke-MicrosoftGraphCredentials($Credentials) { return Connect-M365SATGraphDeviceCode }
function Invoke-MicrosoftGraphUsername { return Connect-M365SATGraphDeviceCode }
function Invoke-MicrosoftGraphLite { return Connect-M365SATGraphDeviceCode }
