<#	

	.DESCRIPTION
		Used to remove Windows 10 pre-provisioned apps (bloat).

	.LINK
		#Reference: https://support.microsoft.com/en-us/kb/2769827

	.NOTES
		Simply add or remove (or comment out) applications from the list. 
#>


#Start Logging to file
$ErrorActionPreference = "SilentlyContinue"
Stop-Transcript | out-null
$ErrorActionPreference = "Continue"

$OutputFileLocation = "C:\Temp\Win10_PreProvApps_Removal.log"
Start-Transcript -path $OutputFileLocation -append

$AppsList =
"Microsoft.MSPaint",
"Microsoft.DesktopAppInstaller",
"Microsoft.Microsoft3DViewer",
"Microsoft.Wallet",
"Microsoft.XboxGameOverlay",
"Microsoft.XboxSpeechToTextOverlay",
"Microsoft.Office.Onenote",
"Microsoft.OneConnect",
"Microsoft.BingFinance",
"Microsoft.BingNews",
"Microsoft.BingWeather",
"Microsoft.XboxApp",
"Microsoft.SkypeApp",
"Microsoft.MicrosoftSolitaireCollection",
"Microsoft.BingSports",
"Microsoft.ZuneMusic",
"Microsoft.ZuneVideo",
#"Microsoft.Windows.Photos",
"Microsoft.People",
"Microsoft.MicrosoftOfficeHub",
"Microsoft.WindowsMaps",
"Microsoft.Windowscommunicationsapps",
"Microsoft.Getstarted",
"Microsoft.3DBuilder",
"Microsoft.Office.Sway",
"Microsoft.Windows.FeaturesOnDemand.InsiderHub",
"Microsoft.XboxGameCallableUI",
"Microsoft.WindowsPhone",
"Microsoft.WindowsCamera",
"Microsoft.WindowsAlarms",
"Microsoft.Messaging",
"Microsoft.CommsPhone",
"Microsoft.Feedback",
"Microsoft.WindowsFeedbackHub",
"Microsoft.XboxIdentityProvider",
#"Microsoft.MicrosoftStickyNotes",
"Microsoft.StorePurchaseApp",
"Microsoft.WindowsSoundRecorder",
"*.Twitter",
"*.CandyCrushSaga"

#Imports
Import-Module Appx
Import-Module Dism


ForEach ($App in $AppsList)
{
	$PackageFullName = (Get-AppxPackage $App).PackageFullName
	$ProPackageFullName = (Get-AppxProvisionedPackage -online | where { $_.Displayname -eq $App }).PackageName
	write-host $PackageFullName
	Write-Host $ProPackageFullName
	if ($PackageFullName)
	{
		Write-Host "Removing Package: $App"
		remove-AppxPackage -package $PackageFullName
	}
	else
	{
		Write-Host "Unable to find package: $App"
	}
	if ($ProPackageFullName)
	{
		Write-Host "Removing Provisioned Package: $ProPackageFullName"
		Remove-AppxProvisionedPackage -online -packagename $ProPackageFullName
	}
	else
	{
		Write-Host "Unable to find provisioned package: $App"
	}
	
}

Stop-Transcript

exit 0
