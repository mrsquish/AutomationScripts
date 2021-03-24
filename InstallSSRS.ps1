param (
	[string]$version = "14"
)
if ($version -eq "14") {	
	$DownloadUrl = "https://download.microsoft.com/download/E/6/4/E6477A2A-9B58-40F7-8AD6-62BB8491EA78/SQLServerReportingServices.exe"
} elseif ($version -eq "15") {
	$DownloadUrl = "https://download.microsoft.com/download/1/a/a/1aaa9177-3578-4931-b8f3-373b24f63342/SQLServerReportingServices.exe"
} else {
	throw "Invalid Version. Script only supports '14' and '15'"
}
$sqlServerInstallPath = "C:\SQLServerFull\x64\DefaultSetup.ini"
$workingDir = "c:\temp\SQLServerReportingServices"
$InstallPath = (Join-Path $workingDir "SQLServerReportingServices.exe")
mkdir $workingDir
cd $workingDir
$WebClient = New-Object System.Net.WebClient
$WebClient.DownloadFile($DownloadUrl, $InstallPath)
$sqlServerPid = (Get-Content $sqlServerInstallPath | Select -Skip 2 | ForEach-Object -Process { $_.Replace("\","\\") } | ConvertFrom-StringData).PID.Replace("`"","")
& $InstallPath /passive /IAcceptLicenseTerms /PID=$sqlServerPid /log (Join-Path $workingDir "SSRSInstall.log")

