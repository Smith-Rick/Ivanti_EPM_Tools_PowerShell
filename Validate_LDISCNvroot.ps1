EXTERNAL APPLICATION
exe=powershell.exe
args=-executionpolicy bypass %filename%
filename=detect.ps1

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



