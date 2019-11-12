#requires -Version 5
#Requires -RunAsAdministrator

<#	
	.NOTES
	===========================================================================
	 Created on:   	12/31/2018 12:53 PM
	 Created by:   	Smith-Rick 	
	===========================================================================
	.DESCRIPTION
		Automate the execution of an LANDesk\EPM provisioning template for the device for full provisioning process.
#>


#Template details for the task
$templateName = '_VDI - RUN MaintMode PROD Seal Condensed'
$deliveryMethod = 'Always listed for installation'

#Prompt for the creds early on
$mycreds = Get-Credential
$coreServerName = Get-ItemPropertyValue 'HKLM:\SOFTWARE\WOW6432Node\Intel\LANDesk\LDWM' 'CoreServer'

#Force DNS Registration due to possible DNS issues outside of our processes.
Write-Host "Forcing DNS Re-registration"
Register-DnsClient

#Execute AppSense Computer Process Stop Node items. On physical these are done as a task scheduler 30 mminutes after comptuer startup. This has to run as system, so PSEXEC is used.
Write-Host "Executing AppSense EM Policy Computer Process Stopped Node Items"

#Check if PSEXEC is local.
$psExecPath = "C:\Provisioning\PsExec.exe"
If (-not (test-path $psExecPath))
{
	New-PSDrive -Name X -PSProvider FileSystem -Root \\<PUT UNC HERE>\landeskpackages -Credential $mycreds
	Copy-Item "\\<PUT UNC HERE>\Microsoft\Sysinternals\PsExec.exe" $psExecPath
	
}

#Check and enable the Ivanti Targeted Multicast Service (This section requires the run as administrator call out at the top)
Write-Host "Enabling and starting the LANDesk Targeted Multicast Service"
$Computer = $env:computername
get-service -displayname "LANDesk Targeted Multicast" | ? { $_.Status -eq 'Stopped' } | % {
	
	#Rename the file back to its original name
	Rename-Item -Path "C:\Program Files (x86)\LANDesk\LDClient\tmcsvc_DISABLED.exe" -NewName "tmcsvc.exe"
	
	$_ | start-service
	sleep 5
	$result = if (($_ | get-service).Status -eq "Running")
	{
		Write-Host "LANDesk Targeted Multicast service was Enabled."
	}
	else
	{
		Write-Host "LANDesk Targeted Multicast could not be started or failed to start."
	}
}

#Run Inventory Scan in case the device is missing from the core inventory.
Write-Host "Running Inventory Scan"
$p = Start-Process 'C:\Program Files (x86)\LANDesk\LDClient\LDISCN32.EXE' -ArgumentList "/V /F /SYNC" -wait
$p.HasExited

#Schedule provisioning task and assign the device to it.
Write-Host "Running Provisioning Template."
$taskName = 'Provisioning Task'
$Computer = $env:COMPUTERNAME
$Date = Get-Date
$ScheduleTask = $templateName + " " + $Computer + " " + $Date

$mbsdk = New-WebServiceProxy -uri http://$coreServerName/MBSDKService/MsgSDK.asmx?WSDL -Credential $mycreds
$connected = $mbsdk.ResolveScopeRights()
$templates = $mbsdk.GetProvisioningTemplates()

$templateID = ($templates.ProvisioningTemplates | where-object { $_.Name -eq $templateName }).id
$taskID = $($mbsdk.CreateProvisioningTask($ScheduleTask, $templateID, $deliveryMethod, $false)).TaskID
$rc = $mbsdk.AddDeviceToScheduledTask($taskID, $env:COMPUTERNAME)
$rc = $mbsdk.StartTaskNow($taskID, "All")


