function Get-M365SATExchangeOrgName {
    try {
        $domain = Get-AcceptedDomain -ErrorAction Stop | Where-Object { ($_.Default -eq $true) -and ($_.DomainName -like "*.onmicrosoft.com") -and ($_.DomainName -notlike "*mail.onmicrosoft.com") } | Select-Object -First 1
        if ($domain) { return (($domain.DomainName -split '.onmicrosoft.com')[0]) }
        $domain = Get-AcceptedDomain -ErrorAction Stop | Where-Object { ($_.DomainName -like "*.onmicrosoft.com") -and ($_.DomainName -notlike "*mail.onmicrosoft.com") } | Select-Object -First 1
        if ($domain) { return (($domain.DomainName -split '.onmicrosoft.com')[0]) }
        return $null
    }
    catch { return $null }
}

function Connect-M365SATExchangeNoWam {
    param([string]$Username)
    try {
        Write-Host "Checking Microsoft Exchange Online connection..."
        Import-Module ExchangeOnlineManagement -Force -ErrorAction Stop

        $existing = Get-ConnectionInformation -ErrorAction SilentlyContinue
        if ($existing) {
            Write-Host "Already connected to Microsoft Exchange Online." -ForegroundColor DarkYellow -BackgroundColor Black
            $existingOrg = Get-M365SATExchangeOrgName
            if ($existingOrg) { return $existingOrg }
            return $true
        }

        $cmd = Get-Command Connect-ExchangeOnline -ErrorAction Stop
        if (-not $cmd.Parameters.ContainsKey("DisableWAM")) {
            throw "Connect-ExchangeOnline does not expose DisableWAM in the loaded module."
        }

        Write-Host "Connecting to Microsoft Exchange Online with WAM disabled..."
        if ([string]::IsNullOrWhiteSpace($Username)) {
            Connect-ExchangeOnline -DisableWAM -ShowBanner:$false -ErrorAction Stop | Out-Null
        }
        else {
            Connect-ExchangeOnline -UserPrincipalName $Username -DisableWAM -ShowBanner:$false -ErrorAction Stop | Out-Null
        }

        if ((Get-ConnectionInformation -ErrorAction SilentlyContinue) -ne $null) {
            Write-Host "Connected to Microsoft Exchange Online." -ForegroundColor DarkYellow -BackgroundColor Black
            $OrgName = Get-M365SATExchangeOrgName
            if ([string]::IsNullOrWhiteSpace($OrgName)) { return $true }
            return $OrgName
        }
        throw "Exchange connection was not created."
    }
    catch {
        Write-Error "Failed to connect to Microsoft Exchange Online. $($_.Exception.Message)"
        return $false
    }
}

function Invoke-MicrosoftExchangeCredentials($Credential) { return Connect-M365SATExchangeNoWam }
function Invoke-MicrosoftExchangeUsername($Username) { return Connect-M365SATExchangeNoWam -Username $Username }
function Invoke-MicrosoftExchangeLite { return Connect-M365SATExchangeNoWam }
