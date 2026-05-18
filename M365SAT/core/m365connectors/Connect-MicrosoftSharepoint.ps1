function Connect-M365SATSharePointInteractive($tenantname) {
	try {
		Write-Host "Connecting to Microsoft SharePoint Online PowerShell..."
		Write-Host "SharePoint Online PowerShell does not support the same device code flow used by Graph, Exchange, Teams, and Az. If interactive browser auth is blocked, SharePoint inspectors must be excluded or converted to Graph or PnP PowerShell."
		Connect-SPOService -Url "https://$tenantname-admin.sharepoint.com" -ErrorAction Stop
		Get-SPOTenant -ErrorAction Stop | Out-Null
		Write-Host "Connected to Microsoft SharePoint Online PowerShell." -ForegroundColor DarkYellow -BackgroundColor Black
		return $true
	}
	catch {
		Write-Error "Failed to connect to Microsoft SharePoint Online PowerShell. $($_.Exception.Message)"
		return $false
	}
}

function Invoke-MicrosoftSharepointCredentials($tenantname, $Credential) { return Connect-M365SATSharePointInteractive $tenantname }
function Invoke-MicrosoftSharepointUsername($tenantname) { return Connect-M365SATSharePointInteractive $tenantname }
function Invoke-MicrosoftSharepointLite($tenantname) { return Connect-M365SATSharePointInteractive $tenantname }
