param (
	[string]$version =  "14"
)
./InstallSSRS.ps1 -version $version
./ConfigureSSRS.ps1 -version $version
