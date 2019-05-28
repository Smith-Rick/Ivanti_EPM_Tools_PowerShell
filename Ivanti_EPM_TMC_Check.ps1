#Requires -RunAsAdministrator

<#
	.SYNOPSIS
		Kills the TMCsvc.exe process if suspect as causing a hang in file deployment.
	
	.DESCRIPTION
		Checks if Ivanti's EPM (LANDesk) Vulscan.exe or SDClient.exe process appears
		to be hung due to an issue with TMCsvc.exe and terminates the TMCsvc.exe
		process to work around the problem.
	
	.PARAMETER LogFileFolder
		Folder location for logs.
	
	.PARAMETER ProcessTTL
		Time to live in hours. If SDClient or Vulscan proccess are running longer than the threshold, assume there is a hang with the TMCsvc.exe service. It is not suggested to use a value lower than 4.
	
	.NOTES
		==================================================================================
		Created on:   	5/24/2019
		Created by:   	Rick Smith
		==================================================================================

		Validated on EPM Versions: 2018.x
		Problem: TMCsvc can sometimes have an issue when multicast is used. The Service appears to get into a loop causing vulscan.exe and\or sdclient.exe to appear hung for hours or days. A reboot of the system tends to mask the problem, but for systems that do not reboot frequently this can cause several days worth of deployment tasks to backup. In the console systems will appear to stay in the 'Active' state indefinetly.

		This script is designed to be run as a Windows Task Scheduler task on a reoccuring interval. It can be leveraged in other deployment methods.
		As with any powershell script, I would suggest that you sign the script for distribution. Below are some options on how to deploy\leverage the script.

		- Windows Task Scheduler Task set to run as local system.
		- EPM Managed Script deployment. Copy PS1 to local system and use managed script to execute. You cannot leverage the built in Windows PowerShell distribution method. This uses SDClient, which will not process if SDClient or Vulscan processes are hung. 
		- AppSense Envioronment Manager. 
		  - Use a dummy process (or some other process) to trigger the script using Environment Manager Policy, process started actions.
		  - Use a scheduled node in EM to setup a re-occuring task scheduler item (ref: https://www.youtube.com/watch?v=nT07mpCCL7A&feature=youtu.be&list=PLg6jGBN6NZrW5p_S-3PFN9pmh3x_VurbR)
		Version 1.0 - Updated 5/24/2019
		- Initial script posted for use.
		
		Exit Codes
		- 999 - Lacks administrative rights.

#>

param
(
	[string]$LogFileFolder = 'C:\Logs\Ivanti\TMCsvc',
	[int]$ProcessTTL = 6
)

#################################
## GLOBAL VARIABLES
#################################

$LogFileName = "Ivanti_EPM_HungProcess.log"

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
	
	if (-not (Test-Path $Path))
	{
		New-Item -Path $Path -ItemType Directory
	}
}

function RotateLogs
{
	#Lets make sure our log folder exists
	Ensure-FolderExists($LogFileFolder)
	
	$FullLogPath = $LogFileFolder + "/" + $LogFileName
	
	#Rotate the logs and keep 5 previous logs
	if (Test-Path $FullLogPath".5")
	{
		Remove-Item -Path $FullLogPath".5"
	}
	if (Test-Path $FullLogPath".4")
	{
		Rename-Item -Path $FullLogPath".4" -NewName $LogFileName".5"
	}
	if (Test-Path $FullLogPath".3")
	{
		Rename-Item -Path $FullLogPath".3" -NewName $LogFileName".4"
	}
	if (Test-Path $FullLogPath".2")
	{
		Rename-Item -Path $FullLogPath".2" -NewName $LogFileName".3"
	}
	if (Test-Path $FullLogPath".1")
	{
		Rename-Item -Path $FullLogPath".1" -NewName $LogFileName".2"
	}
	if (Test-Path $FullLogPath)
	{
		Rename-Item -Path $FullLogPath -NewName $LogFileName".1"
	}
	
	Write-LogIt -Message "Ivanti EPM TMC Health Check started." -Level INFO
	
}

function Validate-Administrator
{
	
	$currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
	
	If ($currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator))
	{
		#Write-LogIt $LogFile -Message "This is an elevated PowerShell session"
	}
	Else
	{
		$msg = "This is NOT an elevated PowerShell session. Script will exit."
		Write-LogIt -Message $msg -Level FATAL
		Exit 999
	}
	
}

function Write-LogIt
{
	[CmdletBinding()]
	param
	(
		[Parameter(Mandatory = $true)]
		[string]$Message,
		[Parameter(Mandatory = $false)]
		[ValidateSet("INFO", "WARN", "ERROR", "FATAL", "DEBUG")]
		[string]$Level = "INFO"
		
		
	)
	
	$LogFileLocation = $LogFileFolder + "\" + $LogFileName
	$TimeStamp = (Get-Date).ToString("yyyy/MM/dd HH:mm:ss")
	$Line = "$TimeStamp $Level $Message"
	
	try
	{		
		Write-Host $Line
		Add-Content -Path $LogFileLocation -Value $Line -Force
	}
	catch
	{
		#Write error to console output but do not exit the script. 
		Write-Host $TimeStamp "WARN Error writing to log file. Sending to Write-Host only."
		Write-Host $Line
	}
	
}

function CheckProcessRunTime
{
	[CmdletBinding()]
	param
	(
		[Parameter(Mandatory = $true)]
		[System.Diagnostics.Process]$Process
		
	)
	
	try
	{
		$Id = $Process.Id
		$Name = $Process.Name
		$StartTime = $Process.StartTime
		#Pull additional data from WMI
		$WMIProcessDetails = Get-WmiObject -Class Win32_Process | ? { $_.ProcessId -eq "$Id" }
		
		Write-LogIt -Message "Process ID: $Id"
		Write-LogIt -Message "Name: $Name"
		Write-LogIt -Message "Command Line: $Commandline"
		
		$CreationDateTime = $WMIProcessDetails.ConvertToDateTime($WMIProcessDetails.CreationDate).ToString('yyyy-MM-dd hh:mm:ss tt')
		$pDateTime = [datetime]::ParseExact($CreationDateTime, 'yyyy-MM-dd hh:mm:ss tt', $null)
		
		$DateTimeNow = (Get-Date)
		$DateCompare = $DateTimeNow - $pDateTime
		$ProcessUpTime = [String]::Format('{0:00} Days, {1:00} Hours, {2:00} Minutes', $DateCompare.Days, $DateCompare.Hours, $DateCompare.Minutes)
		
		Write-LogIt -Message "Start Time: $CreationDateTime"
		Write-LogIt -Message "Run Time: $ProcessUpTime"
		
		$TotalHours = ($DateCompare.Days * 12) + $DateCompare.Hours
		
		IF ($TotalHours -ge $ProcessTTL)
		{
			
			Write-LogIt -Message "Process has been running too long. Attempting to terminate TMCSVC process."
			KillTmcSvc
			
		}
		else
		{			
			Write-LogIt -Message "Process Uptime OK"
		}
	}
	catch
	{
		Write-LogIt -Message "$_.Exception.Message" -Level ERROR
	}
	
	
}

function KillTmcSvc
{
	Get-Process -Name tmcsvc -ErrorAction SilentlyContinue | ForEach-Object {
		
		try
		{
			Write-LogIt -Message "Attempting to Kill TMCSvc.exe"
			$_.Terminate()
			Write-LogIt -Message "TMCSvc.exe terminated. Multicast should no longer be hung."
			
		}
		catch
		{
			Write-LogIt -Message "Error Fix Your Code. Could not kill TMCsvc." -Level ERROR
			Write-LogIt -Message "$_.Exception.Message" -Level ERROR
			
		}
		
	}
}

#################################
## MAIN
#################################

Validate-Administrator

RotateLogs

Get-Process -Name sdclient, vulscan -ErrorAction SilentlyContinue | ForEach-Object{
	
	CheckProcessRunTime($_)
	
}

Write-LogIt -Message "Check completed. Exit 0."

Exit 0
