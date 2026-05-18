function Connect-M365SATTeamsDeviceCode {
	try {
		Write-Host "Connecting to Microsoft Teams PowerShell using device code..."
		$Team = Connect-MicrosoftTeams -UseDeviceAuthentication -ErrorAction Stop
		if ($Team) {
			Write-Host "Connected to Microsoft Teams PowerShell." -ForegroundColor DarkYellow -BackgroundColor Black
			return $true
		}
		throw "Teams connection was not created."
	}
	catch {
		Write-Error "Failed to connect to Microsoft Teams PowerShell. $($_.Exception.Message)"
		return $false
	}
}

function Invoke-MicrosoftTeamsCredentials($Credential) { return Connect-M365SATTeamsDeviceCode }
function Invoke-MicrosoftTeamsUsername($Username) { return Connect-M365SATTeamsDeviceCode }
function Invoke-MicrosoftTeamsLite { return Connect-M365SATTeamsDeviceCode }
