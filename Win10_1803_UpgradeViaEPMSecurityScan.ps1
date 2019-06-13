EXTERNAL APPLICATION
exe=powershell.exe
args=-executionpolicy bypass %filename%
filename=repair.ps1
timeout=10800

echo off
echo "Vulscan logs all standard output.  It looks for the special strings 'succeeded', and 'message'."
echo "If 'succeeded' is not found, then vulscan uses the return value to determine success (zero means succeeded)."
echo "the core name is %corename%"
echo "the local cache directory location: %sdmcache%"

<#
	.DESCRIPTION
		Utilized by to perform the Windows 10 1803 inplace upgrade as a custom definition using Ivanti Patch Management for EPM. 
    This is the install script, for detection logic, simply use  the registry key for Windows 10 version. This can also be 
    modified slightly to use as a Portal Management on demand job.     

	.NOTES
		Because we cannot follow the install post setup.exe rebooting the system, Vulscan can't report back if it succeeds. 
    It will report failures.

    Custom exit codes will fail if distributed as part of a package bundle. 
    EPM cant yet pass out the exit code through the package bundle.
		Exit Codes
		998 - This is NOT an elevated PowerShell session.
		997 - Could not download file - Error during download.
		996 - Could not download file - Not accessible.
		999 - Could not find setup.exe, possible mount error.
		995 - Something failed during execution of setup.exe.

#>

#################################
## Global Variables
#################################

#Logging
$LogFileName = "Win10 1803 Portal Task.log"
$LogFileFolder = "C:\Temp\Win10_1803\"

#Download folder
$DestinationFolder = "C:\temp\Win10_1803\"

#ISO Details
$IsoFileName = "Windows10x64Enterprise1803_tw7396-39297en.iso"
$IsoSourceFolder = "\\server\share\Win10\1803\ISO\"

#PostOOBE Script Source Folder
$PostOOBESourceFolder = '\\server\share\Win10\1803\PostOOBEScript\'

#PostOOBE associated install files. Do not download in the setupcomplete.ps1 itself, VPN users will not be online after the initial reboot.

#Post OOBE Install Files 
#Modifying the destination folder or file name will require modification to setupcomplete.ps1
#Will probably modify this to use robocoy, then modify the setupcomplete.ps1 to do a for each filename like "PostOOBEInstaller_XYZ.exe" do the install.
$InstallerFileName = "SomeApplication.exe"
$InstallerSrcFolder = "\\server\source\PostOOBEInstalls\"
$InstallerDstFolder = "C:\temp\"

#################################
#Do not change values in this section
$LogFile= $LogFileFolder + $LogFileName

#Windows expects these exact names.
$PostOOBEcmdFileName = "setupcomplete.cmd"
$PostOOBEps1FileName = "setupcomplete.ps1"
$PostOOBEcmdDestFullPath = $DestinationFolder + $PostOOBEcmdFileName

#SDMCache location to see if the files happen to be pre-cached
$EPM_SDMCachePath = "C:\Program Files (x86)\LANDesk\LDClient\sdmcache\"

$IsoSourceFullPath = $IsoSourceFolder + $IsoFileName
$IsoDestFullPath = $DestinationFolder + $IsoFileName

#Should be in this area. Wiping the file will cause AppSense to reimport at startup.
#IE Trusted sites appear to get wiped on an in place upgrade. Since we use AppSense to do a reg import if the file at this location
# does not exist, we need to wipe it during the upgrade. AppSense will then copy in the latest file and trigger the one time import.
$IETrustedReg = "C:\ProgramData\AppSense\Condition Checks\SecZones_HKLM.reg"

#################################

#################################
## FUNCTIONS
#################################
function Ensure-FolderExists
{
	param
	(
		[Parameter(Mandatory = $true)]
		[string]$Path
	)
	
	if(-not (Test-Path $Path))
	{
		New-Item -Path $Path -ItemType Directory		
	}
}

function Validate-Administrator
{
	
	$currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
	
	If ($currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator))
	{
		Write-LogIt $LogFile -Message "This is an elevated PowerShell session"
	}
	Else
	{
		$msg = "This is NOT an elevated PowerShell session. Script will exit."
		Write-LogIt $LogFile -Message $msg -Level FATAL
		Write-LogIt $LogFile -Message "EXIT 998" -Level FATAL
		Echo "succeeded=false"
		Echo "message=$msg"
		Exit 998
	}
}

function Write-LogIt
{
	[CmdletBinding()]
	param
	(
		[Parameter(Mandatory = $true)]
		[string]$LogFileLocation,
		
		[Parameter(Mandatory = $true)]
		[string]$Message,
		
		[Parameter(Mandatory = $false)]
		[ValidateSet("INFO", "WARN", "ERROR", "FATAL", "DEBUG")]
		[string]$Level = "INFO"
		

	)
	
	$TimeStamp = (Get-Date).ToString("yyyy/MM/dd HH:mm:ss")
	$Line = "$TimeStamp $Level $Message"
	
	
	try
	{
		
		Ensure-FolderExists $LogFileFolder
		Write-Host $Line
		Add-Content -Path $LogFileLocation -Value $Line -Force 
	}
	catch
	{
		Write-Host $TimeStamp "WARN Error writing to log file. Sending to Write-Host only."
		Write-Host $Line
	}
		
}
<#
	.DESCRIPTION
		Attempts to download the file. Will validate if file already exists locally, unless overwrite set to true.

	.OUTPUTS
		Returns string of destination path. This could change if the file is located in SDMCACHE folder instead of what was passed in.
#>
function Download-File
{
	param
	(
		
		[Parameter(Mandatory = $true)]
		[string]$FileName,
		[Parameter(Mandatory = $true)]
		[string]$SourceFolder,
		[Parameter(Mandatory = $true)]
		[string]$DestinationFolder,
		[bool]$OverwriteExisting
	)
	
	$src = $SourceFolder + $FileName
	$dst = $DestinationFolder + $FileName
	$sdmCache = $EPM_SDMCachePath + $FileName
			
	#Using the -Force switch to ensure directory is created if it doesnt already exist.
	
	Write-LogIt $LogFile "Attempting to download $FileName."
	Write-LogIt $LogFile "Overwrite Exiting file set to $OverwriteExisting."
	
	Ensure-FolderExists $DestinationFolder
		
	try
	{
		if (Test-Path $sdmCache)
		{
			
			#File found in SDMCache, use that instead.			
			Write-LogIt $LogFile "File found in $sdmCache using local cache instead of downloading."
			$dst = $sdmCache
			
		}
		elseif (Test-Path $dst)
		{
			#File is currently in local destination, checking if we are to force re-download to destination.
			Write-LogIt $LogFile "File exists in current $dst."
			
			if ($OverwriteExisting)
			{
				If (Test-Path $src)
				{
					Copy-Item $src $dst -Force
				}
				else
				{
					$msg = "Could not access network share to download."
					Write-LogIt $LogFile $msg -Level FATAL
					Write-LogIt $LogFile "EXIT 996." -Level FATAL
					Echo "succeeded=false"
					Echo "message=$msg"
					EXIT 996
					
				}
				
			}
			else
			{
				Write-LogIt $LogFile "No download required, using existing file."
			}
			
		}
		else
		{
			Write-LogIt $LogFile "File not found at $dst or $sdmCache."			
			Write-LogIt $LogFile "Attempting to download."
			
			If (Test-Path $src)
			{
				Copy-Item $src $dst -Force
			}
			else
			{
				$msg = "Could not access network share to download."
				Write-LogIt $LogFile $msg -Level FATAL
				Write-LogIt $LogFile "EXIT 996." -Level FATAL
				Echo "succeeded=false"
				Echo "message=$msg"
				EXIT 996
				
			}
			
			Write-LogIt $LogFile "Download completed, file is located at $dst."
			
		}
		
	}
	catch
	{
		$msg = "An error has occured while downloading $src."
		Write-LogIt $LogFile $msg -Level FATAL
		Write-LogIt $LogFile "Exiting install. EXIT 997" -Level FATAL
		Echo "succeeded=false"
		Echo "message=$msg"
		Exit 997
	}
	
	#Validate File actually exists.
	If (-not (Test-Path $dst))
	{
		$msg = "An error has occured while validating file exists at $dst."
		Write-LogIt $LogFile $msg -Level FATAL
		Write-LogIt $LogFile "Exiting install. EXIT 997" -Level FATAL
		Echo "succeeded=false"
		Echo "message=$msg"
		Exit 997
	}
	else
	{
		Write-LogIt $LogFile "File has been verified at: $dst"
	}
	
	#Return what the destination ended up being.	
	Write-LogIt $LogFile "Returning DST as: $dst" -Level DEBUG
	return $dst
}


#################################
## MAIN
#################################

Validate-Administrator

#Grab PostOOBE Files - Forcing overwrite in case these get modified. 
$PostOOBEcmdDestFullPath = Download-File $PostOOBEcmdFileName $PostOOBESourceFolder $DestinationFolder -OverwriteExisting $true
Download-File $PostOOBEps1FileName $PostOOBESourceFolder $DestinationFolder -OverwriteExisting $true

#Grab PostOOBE Install Files and Cache it for the PostOOBE setup.
Download-File $InstallerFileName $InstallerSrcFolder $InstallerDstFolder

#Download Windows 10 ISO
$IsoDestFullPath = Download-File $IsoFileName $IsoSourceFolder $DestinationFolder

#Begine Windows 10 In Place Upgrade
Write-LogIt $LogFile "Removing any previous mounted attempt. From $IsoDestFullPath"

#Perform Dismount in case of previous failed install attempt still has it mounted.
try
{
	Dismount-DiskImage -ImagePath $IsoDestFullPath
}
catch
{
	Write-Host $LogFile "No existing Image to dismount. Or dismount might have failed. Continuing Install."
}

#Try to mount the ISO
Try
{
	$vol = Mount-DiskImage -ImagePath $IsoDestFullPath -PassThru | Get-DiskImage | Get-Volume
	$installer = $vol.DriveLetter + ":\setup.exe"
	
	If (-not (test-path $installer))
	{
		$msg = "Could not find installer. ISO may not be mounting. Exiting with a fail."
		Write-LogIt $LogFile $msg -Level FATAL
		Write-LogIt $LogFile "EXIT 999" -Level FATAL
		Echo "succeeded=false"
		Echo "message=$msg"
		EXIT 999
	}
	else
	{
		Write-LogIt $LogFile "Installer found at $installer"
	}
	
}
catch
{
	$msg = "Could not mount the installer."
	Write-LogIt $LogFile $msg -Level FATAL
	Write-LogIt $LogFile "EXIT 999" -Level FATAL
	Echo "succeeded=false"
	Echo "message=$msg"
	EXIT 999
	
}

#ISO Mounted, so lets get going.

Write-LogIt $LogFile "Removing IE Trusted sites registry key so AppSense re-syncs post OS upgrade."
If (test-path $IETrustedReg)
{
	Remove-Item -Path $IETrustedReg
	Write-LogIt $LogFile "$IETrustedReg has been removed"
}

#Set Arguments to be used as part of the upgrade. ADD /quiet if needing to be quiet.
#This includes the parameters required for McAfee Hardrive Encryption to allow the in place upgrade. 
$parameters = '/Auto upgrade /Quiet /DynamicUpdate disable /MigrateDrivers all /ShowOOBE none /telemetry disable /Compat IgnoreWarning /ReflectDrivers "C:\Program Files\McAfee\Endpoint Encryption\OSUpgrade" /copylogs "c:\Temp\Win10_1803upgrade_ErrorLogs" /PostOOBE "' + $PostOOBEcmdDestFullPath + '"'

Write-LogIt $LogFile "Running Setup.exe with the following arguments: $parameters"

try
{
	#For Security scan, we dont use -WAIT or Unmount. Mainly because we only deploy this 1 patch without others. And vulscan.exe would sit there forever. This mimics what Ivanti used to do.
	#Start -filepath $installer -Argumentlist $parameters
  #For portal job, we currently use -wait. Mainly so the portal doesnt tell the end user its all done. 
	Start-Process $installer -ArgumentList $parameters -Wait
	
	#wait up to 2 hours.
	#Wait-Process -Name "Setup.exe" -Timeout  7200
	
	Write-LogIt $LogFile "Windows 10 Setup completed. If upgrade failed, re-validate pre-requisite software is isntalled. Ex. McAffee is up to date."
	
	
}
catch
{
	Dismount-DiskImage -ImagePath $IsoDestFullPath
	$msg = "Something failed during execution of setup.exe."
	Write-LogIt $LogFile $msg -Level FATAL
	Echo "succeeded=false"
	Echo "message=$msg"
	EXIT 995
}

#Send messaging back to Vulscan.
Write-Output "succeeded=true"
Write-Output "message=Please reboot the machine to finish the upgrade. If failed check log file."

Exit 0
