$invocationPath = Split-Path -Path $MyInvocation.MyCommand.Path -Parent

# CHANGE ME
$wsusRoot = "C:\ProgramData\chocolatey\lib\wsus-offline-update\tools\wsusoffline"
$destinationPath = "Z:\sources\Microsoft\Windows"
# CHANGE ME

. (Join-Path $invocationPath "Functions.ps1")

$sourceWimsPath = (Join-Path $invocationPath "SourceWims")
$scriptPath = (Join-Path $invocationPath "Scripts")
$driversPath = (Join-Path $invocationPath "Drivers")
$wsusUpdates = (Join-Path $wsusRoot "client\w{0}-x64\glb")

function GetWimArguments([string]$windowsVersion)
{
	$args = @()
	$args += '-wimFile "' + (Join-Path (Join-Path $sourceWimsPath $windowsVersion) "install.wim") + '"'
	$args += '-destination "' + (Join-Path $destinationPath $windowsVersion) + '"'
	$args += '-updatesPath "' + [string]::Format($wsusUpdates, $windowsVersion.Replace('.', '')) + '"'
	$args += '-driversPath "' + (Join-Path $driversPath $windowsVersion) + '"'
	
	return (" " + [String]::Join(" ", $args))
}

function GetBootWimArguments()
{
    $windowsVersion = "boot"
	$args = @()
	$args += '-wimFile "' + (Join-Path (Join-Path $sourceWimsPath $windowsVersion) "boot.wim") + '"'
	$args += '-destination "' + (Join-Path $destinationPath $windowsVersion) + '"'
	$args += '-driversPath "' + (Join-Path $driversPath $windowsVersion) + '"'
	$args += '-isBoot 1'
	
	return (" " + [String]::Join(" ", $args))
}

function CheckUpdates([string]$windowsVersion)
{
	$process = Start-Process -FilePath (Join-Path $wsusRoot "cmd\DownloadUpdates.cmd") -ArgumentList @([string]::Format("w{0}-x64 glb", $windowsVersion.Replace('.', '')), "/verify") -Wait -PassThru;
	$exitCode = $process.ExitCode
	if ($exitCode -ne 0)
	{
		throw "Error downloading updates for Windows ${windowsVersion}, exit code was ${exitCode}"
	}
}