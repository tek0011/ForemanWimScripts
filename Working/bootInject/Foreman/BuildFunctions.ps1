##############################################################################
#.SYNOPSIS
# Validates that at least one disk is available
##############################################################################
function ValidateDisks()
{
	$diskCount = @(Get-Disk).Count
	
	if ($diskCount -lt 1)
	{
		throw ("No disks found, missing driver or wrong OS set for VM?")
	}
}

##############################################################################
#.SYNOPSIS
# Validates that at least one NIC is available
##############################################################################
function ValidateNetworks()
{
	$nicCount = @(Get-WmiObject win32_networkadapterconfiguration).Count
	
	if ($nicCount -lt 1)
	{
		throw ("No NIC's found, missing driver or wrong VM network adapter set?")
	}
}

##############################################################################
#.SYNOPSIS
# Waits for network to start, will make 20 attempts before throwing
##############################################################################
function BlockForNetwork()
{
	$tries = 0
	do 
	{  		
		Write-Progress -Activity "Waiting for network to start" -Status "Attempt $tries of 20"
		$tries++
  		sleep 10
		ping -n 1 10.125.80.2 | Out-Null
	} 
	until(($LASTEXITCODE -eq 0) -or ($tries -gt 20)) #Test-NetConnection not available with PE
	
	Write-Progress -Activity "Waiting for network to start" -Completed
	
	if ($tries -gt 20)
	{
		throw ("Network was not available after 20 tries.")
	}
}

##############################################################################
#.SYNOPSIS
# Ensures parent folders of a file exist
#
#.PARAMETER filePath
# The path to file to create parent folders for
##############################################################################
function EnsureFileDirectoryExists($filePath)
{
	$dirPath = [IO.Path]::GetDirectoryName($filePath)
	EnsureDirectoryExists $dirPath
}

##############################################################################
#.SYNOPSIS
# Ensures a folder and its parent folders exist
#
#.PARAMETER dirPath
# The path to the folder to create
##############################################################################
function EnsureDirectoryExists($dirPath)
{	
	New-Item -Path $dirPath -ItemType directory -ErrorAction SilentlyContinue | Out-Null
}

##############################################################################
#.SYNOPSIS
# Downloads a file and saves it to the specified location
#
#.PARAMETER source
# The http path for the file to download
#
#.PARAMETER destination
# The destination path
##############################################################################
function DownloadFile($source, $destination)
{
	EnsureFileDirectoryExists $destination
	
	try 
	{
		Write-Progress -Activity "Downloading $source"
        (New-Object System.Net.WebClient).DownloadFile($source, $destination)
    } 
    catch [System.Net.WebException] 
	{
        $errorCode = $_.Exception.Response.StatusCode
		
		throw ("Error $errorCode encountered when downloading $source")
    }
	finally
	{
		Write-Progress -Activity "Downloading $source" -Completed
	}
}

##############################################################################
#.SYNOPSIS
# Returns a list of the current machines mac addresses
##############################################################################
function BuildMacList()
{
	return (Get-WmiObject win32_networkadapterconfiguration | ? {![string]::IsNullOrEmpty($_.MacAddress)} | % {$_.MacAddress})
}

##############################################################################
#.SYNOPSIS
# Joins a list in to a comma seperated string
##############################################################################
function JoinList($list)
{
	return ($list -join ",")
}

##############################################################################
#.SYNOPSIS
# Returns a URL for an unattend file in foreman
#
#.PARAMETER foreman
# The IP or FQDN of the foreman instance
#
#.PARAMETER type
# The type of script to get from foreman
##############################################################################
function BuildForemanUnattendUrl($foreman, $type)
{
	$macslist = BuildMacList
	$macstring = JoinList $macslist
	return [string]::Format("http://{0}/unattended/{1}?maclist={2}", $foreman, $type, $macstring)
}

##############################################################################
#.SYNOPSIS
# Downloads a foreman unattend file to a FS location
#
#.PARAMETER foreman
# The IP or FQDN of the foreman instance
#
#.PARAMETER type
# The type of script to get from foreman
#
#.PARAMETER destination
# The destination to create the file
##############################################################################
function DownloadForemanUnattendFile($foreman, $type, $destination)
{
	$foremanurl = BuildForemanUnattendUrl $foreman $type
	DownloadFile $foremanurl $destination
}

##############################################################################
#.SYNOPSIS
# Mounts a windows share to a drive
#
#.PARAMETER letter
# The drive letter for the mount
#
#.PARAMETER path
# The windows share to mount
##############################################################################
function MountDrive($letter, $path)
{
	#Drop trailing \
	$path = $path.TrimEnd("\")
	
	try
	{
		New-PSDrive –Name $letter –PSProvider FileSystem –Root $path
	}
	catch [System.IO.IOException]
	{
		throw ("Error mounting $path to $letter")
	}
}

##############################################################################
#.SYNOPSIS
# Converts a HTTP path to a FS path
#
#.PARAMETER root
# The root path to prefix
#
#.PARAMETER path
# The URI to convert
##############################################################################
function HttpPathToFSPath($root, $path)
{
	Join-Path $root ([Uri]$path).AbsolutePath
}

function SetInterfaceWithMac($mac, $ip, $cidr, $gateway, $domain, $dns)
{
	$interface = Get-NetAdapter | ? {$_.MacAddress.ToLower().Replace("-",":") -eq $mac.ToLower()} | Select -First 1
		
	if ($interface -ne $null)
	{			
        Remove-NetIPAddress -InterfaceAlias $interface.Name -Confirm:$false
		Set-DnsClient -InterfaceAlias $interface.Name -ConnectionSpecificSuffix $domain
		New-NetIPAddress -InterfaceAlias $interface.Name -AddressFamily IPv4 -IPAddress $ip -PrefixLength $cidr -DefaultGateway $gateway
		Set-DnsClientServerAddress -InterfaceAlias $interface.Name -ServerAddresses $dns
	}
	else
	{
		Write-Warning "Mac address $mac not found"
	}
}