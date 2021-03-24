param (
	[string]$version =  "14"
)
function Get-Instance([string]$version)
{
	$hostname = [System.NET.DNS]::GetHostByName($null).HostName
	$instance = (Get-WmiObject -namespace root\Microsoft\SqlServer\ReportServer  -class __Namespace -ComputerName $hostname | select Name).Name
	$namespaceAdminPath = "root\Microsoft\SqlServer\ReportServer\RS_SSRS\v$version"
	return Get-WmiObject -namespace $namespaceAdminPath -class MSReportServer_Instance -ComputerName $hostname 
}
function Get-ConfigSet([string]$version)
{
	$hostname = [System.NET.DNS]::GetHostByName($null).HostName
	$instance = (Get-WmiObject -namespace root\Microsoft\SqlServer\ReportServer  -class __Namespace -ComputerName $hostname | select Name).Name
	$namespaceAdminPath = "root\Microsoft\SqlServer\ReportServer\$instance\v$version\Admin"
	return Get-WmiObject -namespace $namespaceAdminPath -class MSReportServer_ConfigurationSetting -ComputerName $hostname 
}
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force
Install-Module -Name SqlServer -RequiredVersion 21.1.18235 -Force -AllowClobber

# Allow importing of sqlps module
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Force

# Retrieve the current configuration
$configset = Get-ConfigSet($version)

If (! $configset.IsInitialized)
{
	# Get the ReportServer and ReportServerTempDB creation script	
	$configset.GenerateDatabaseCreationScript("ReportServer", 1033, $false).Script | Out-File -FilePath ".\GenerateSSRSDb.sql"
	$configset.GenerateDatabaseRightsScript($configset.WindowsServiceIdentityConfigured, "ReportServer", $false, $true).Script | Out-File -FilePath ".\GenerateSSRSRights.sql" 

	# Run the ReportServer and ReportServerTempDB creation script
	Invoke-Sqlcmd -InputFile ".\GenerateSSRSDb.sql" -ServerInstance $hostname -Database master | Out-File -FilePath ".\GenerateSSRSDb.log"

	# Set permissions for the databases
	Invoke-Sqlcmd -InputFile ".\GenerateSSRSRights.sql" -ServerInstance $hostname -Database master | Out-File -FilePath ".\GenerateSSRSRights.log"
	
	# Set the database connection info
	$configset.SetDatabaseConnection("(local)", "ReportServer", 2, "", "")
	$configset.SetVirtualDirectory("ReportServerWebService", "ReportServer", 1033)
	$configset.ReserveURL("ReportServerWebService", "http://+:80", 1033)

	# For SSRS 2016-2017 only, older versions have a different name
	$configset.SetVirtualDirectory("ReportServerWebApp", "Reports", 1033)
	$configset.ReserveURL("ReportServerWebApp", "http://+:80", 1033)
	$configset.InitializeReportServer($configset.InstallationID)

	# Re-start services?
	$configset.SetServiceState($false, $false, $false)
	Restart-Service $configset.ServiceName
	$configset.SetServiceState($true, $true, $true)

	# Update the current configuration
	$configset = Get-ConfigSet($version)

	# Output to screen
	$configset.IsReportManagerEnabled
	$configset.IsInitialized
	$configset.IsWebServiceEnabled
	$configset.IsWindowsServiceEnabled
	$configset.ListReportServersInDatabase()
	$configset.ListReservedUrls();

	$inst = Get-Instance($version)

	$inst.GetReportServerUrls()
}