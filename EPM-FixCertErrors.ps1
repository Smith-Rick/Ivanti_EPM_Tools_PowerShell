<#	
	.NOTES
	===========================================================================
	 Created on:   	4/21/2020 10:47 AM
	 Created by:   	Smith-Rick
	 Filename:     	EPM-FixCertErrors.ps1
	===========================================================================
	.DESCRIPTION
		Attempts to automate the broken communications due to cert errors as 
			described here:
			https://tinyurl.com/EPMSOAP503

#>
#Requires -RunAsAdministrator

# As described in the KB, keep the .0 file you need and the broker.conf.xml. You can append additional files if required.
$toKeep = "0000000.0", "broker.conf.xml"

# If you installed to a non-default location (or need to also support 32-bit) update the paths.
$BrokerFolderPath = "C:\Program Files (x86)\LANDesk\Shared Files\cbaroot\broker"
$CertFolderPath = "C:\Program Files (x86)\LANDesk\Shared Files\cbaroot\certs"

# Remove all files except those specified in the $toKeep above.
Get-ChildItem $BrokerFolderPath -Recurse | Where-Object { !$_.PSIsContainer } | Where-Object { $toKeep -notcontains $_.Name } | remove-item
Get-ChildItem $CertFolderPath -Recurse | Where-Object { !$_.PSIsContainer } | Where-Object { $toKeep -notcontains $_.Name } | remove-item

# Run Broker Config
Start-Process -FilePath "C:\Program Files (x86)\LANDesk\LDClient\BrokerConfig.exe" -ArgumentList "/r"
