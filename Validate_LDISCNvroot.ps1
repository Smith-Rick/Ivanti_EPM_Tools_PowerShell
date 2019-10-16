EXTERNAL APPLICATION
exe=powershell.exe
args=-executionpolicy bypass %filename%
filename=detect.ps1

<#	
	.NOTES
	===========================================================================
	 Created on:   	10/16/2019 09:54 AM
	 Created by:   	Smith-Rick
	 Filename:     	Validate_LDISCNvroot.ps1
	===========================================================================
	.DESCRIPTION
		Validates that the ldiscn.vroot file has a value other than 'LDCLIENTDIRECTORY'.

		Validation need is a result of identifying systems that had an XML file 
		with a bogus result even with a clean install. 
#>

echo off
$path = 'C:\Program Files (x86)\LANDesk\Shared Files\cbaroot\ldiscn.vroot'

[xml]$XmlDocument = Get-Content -Path $path
$value = $XmlDocument.application.file.location

if ($value -eq 'LDCLIENTDIRECTORY')
{	
	echo "detected=true"
	echo "reason=Value is not correct."
	echo "expected=$path"
	echo "found=$value"
}
else
{	
	echo "detected=false"
	echo "reason=Value does not appear corrupt"
	echo "expected=$path"
	echo "found=$value"
}



