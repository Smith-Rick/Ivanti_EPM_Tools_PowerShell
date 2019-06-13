####################################################
## Post Windows 10 Upgrade Script
## For further configuration and installations after a Windows 10
## upgrade.
####################################################

##################
## Global Parameters
##################
$logFile = "C:\temp\Win10PostUpgradeScript.log"
$backgroundPIDList = New-Object System.Collections.ArrayList # used for collecting packages run in the background so they can be evaluated later


##################
## Functions
##################

Function getDateTime {
	$theDate = get-date -format  "MM-dd-yy HH:mm:ss"
	return "[$theDate]"
}

Function logIt($text) {
	Add-Content $logFile "$(getDateTime) $text"
}

Function runPackage() {
	param(
		[string]$FilePath, # full path to the executable you wish to run
		[string]$Params, # parameters to be passed to the executable
		[switch]$Wait # use -Wait to prevent the script from continuing until your process has completed
	)
	
	logIt "runPackage Started"
	
	If (!(Test-Path $FilePath))
	{
		logIt "File $FilePath not found!"
		return -1
	}
	
	$app = ""
	If ($Wait) {
		If ($Params) {
			$app = Start-Process -FilePath $FilePath -ArgumentList $Params -Passthru
			logIt "$($app.Name) started with PID $($app.Id)"
			$app | Wait-Process
			logIt "Process ID $($app.Id) exited with code $($app.ExitCode)"
		} else {
			$app = Start-Process -FilePath $FilePath -Passthru
			logIt "$($app.Name) started with PID $($app.Id)"
			$app | Wait-Process
			logIt "Process ID $($app.Id) exited with code $($app.ExitCode)"
		}
	} else {
		If ($Params) {
			$app = Start-Process -FilePath $FilePath -ArgumentList $Params -Passthru
			$backgroundPIDList.Add($app) | out-null
			logIt "$($app.ProcessName) with ID $($app.Id) was started"
		} else {
			$app = Start-Process -FilePath $FilePath -Passthru
			$backgroundPIDList.Add($app) | out-null
			logIt "$($app.ProcessName) with ID $($app.Id) was started"
		}
	}
	
}


##################
## Main Execution
##################

Set-Content $logFile "Windows 10 Post Upgrade Script started"

# Install Some Applciations
# No detection possible to check if necessary, but it must be run
write-host "Running the Touchworks package"
runPackage -FilePath "C:\Temp\SomeAppInstall.exe" -Params "/silent" -Wait
Start-Sleep -s 1
#Remove the cached files.
If (Test-Path "C:\Temp\SomeAppInstall.exe") {
	Remove-Item "C:\Temp\SomeAppInstall.exe"
}


#Run LANDesk Items - Do not wait for these to finish as part of the setupcomplete.
#Update Invnetory Record.
Write-Host "Running Inventory Scan"
runPackage -FilePath "C:\Program Files (x86)\LANDesk\LDClient\LDISCN32.EXE"

#Run Patches, this will patch us to the latest cumulative update we have set to autofix. 
Write-Host "Running Security Scan"
runPackage -FilePath "C:\Program Files (x86)\LANDesk\LDClient\vulscan.exe"


##################
## Cleanup
##################

ForEach ($proc in $backgroundPIDList) {
	# build loop to wait and/or kill procs later
	logIt "Checking for status of background processes"
	If ($proc.HasExited) {
		logIt "$($proc.ProcessName) with ID $($proc.Id) exited with code $($proc.ExitCode)"
	} else {
		logIt "Process ID $($proc.Id) is still running"
	}
}

logIt "Windows 10 Post Upgrade Script finished"
