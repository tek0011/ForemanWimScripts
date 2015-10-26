param
(
	[string]$wimFile = $(throw "wimFile is mandatory"),
	[string]$updatesPath,
	[string[]]$features = @(),
	[string]$driversPath,
	[string]$destination = $(throw "destination is mandatory"),
	[bool]$isBoot = $false
)

$ScriptDirectory = Split-Path $MyInvocation.MyCommand.Path
. (Join-Path $ScriptDirectory Functions.ps1)
$rootwim = Split-Path -parent $ScriptDirectory

$working = Join-Path $rootwim "Working"
$bootInjectFolderName = "bootInject"
$sourcesFolderName = "sources"
$mountFolderName = "mnt"
$dismlog = "dism.log"
$bootcabs = @("WinPE-WMI", "WinPE-NetFX", "WinPE-Scripting", "WinPE-PowerShell", "WinPE-StorageWMI", "WinPE-DismCmdlets")

if ($isBoot)
{
	BuildBootWim $working $wimFile $driversPath $bootcabs
}
else
{
	BuildInstallWim $working $wimFile $updatesPath $features $driversPath	
}


CopySources $working $destination