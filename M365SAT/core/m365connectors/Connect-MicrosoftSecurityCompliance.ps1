function Connect-M365SATSecurityComplianceDeviceCode {
	try {
		Write-Host "Connecting to Microsoft Security and Compliance using device code..."
		Connect-IPPSSession -Device -ShowBanner:$false -ErrorAction Stop | Out-Null
		Get-PolicyConfig -ErrorAction Stop | Out-Null
		Write-Host "Connected to Microsoft Security and Compliance." -ForegroundColor DarkYellow -BackgroundColor Black
		return $true
	}
	catch {
		Write-Error "Failed to connect to Microsoft Security and Compliance. $($_.Exception.Message)"
		return $false
	}
}

function Invoke-MicrosoftSecurityComplianceCredentials($Credential) { return Connect-M365SATSecurityComplianceDeviceCode }
function Invoke-MicrosoftSecurityComplianceUsername($Username) { return Connect-M365SATSecurityComplianceDeviceCode }
function Invoke-MicrosoftSecurityComplianceLite { return Connect-M365SATSecurityComplianceDeviceCode }
