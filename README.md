# Ivanti - EPM Tools (PowerShell)

## Summary
The files in this repository are a collection of powershell scripts to Ivanti EPM (LANDesk) designed to help EPM administrators. Most of the scripts are designed to be run on their own and are self contained. Check the instructions and details within each ps1 for more information.

**USE AT YOUR OWN RISK**

## Scripts and Uses

**- Ivanti_EPM_TMC_Check.ps1** - Intended to be used as a work around for when the TMCsvc service gets messed up, causing SDClient or Vulscan to hang during the multicast phase of a deployment and causing subsequent tasks to queue indefinetly. 

**- Win10_1803_UpgradeViaEPMSecurityScan.ps1** - Used for windows 10 in place upgrade with command line switches. 

**- Windows10_PreProvApp_Removal.ps1** - Sample script and method for removing pre-provisioned Windows 10 Store applications. 

**- setupcomplete.ps1** - Used with PostOOBE and a windows 10 in place upgrade. Simply create a setupcomplete.cmd file and copy it to the local device prior to the upgrade. The .CMD file needs one line:
"powershell.exe -ExecutionPolicy ByPass -file C:\temp\Win10_1803\setupcomplete.ps1 -WindowStyle Hidden"

**- Validate_LDISCNvroot.ps1** - Used as a DETECT ONLY custom security definition script. The script checks the ldiscn.vroot file and validates that the setting in the file is NOT the default LDCLIENTDIRECTORY value. Files in this state caused systems to have issues with downloading the LDAPPL3.ini from the core. Case was opened to determin root cause, however custom detection logic was required to identify broken systems. 

**- VDISeal.ps1** - Used to rename TMCsvc.exe and run provisioning template as part of the sealing automation. Execute this on the VDI desktop in maintenance mode. This will run the provisioning template where all sealing and shutdown activities exist. During the shutdown automation, TMCSvc.exe is renamed to avoid the CPU usage issues with the agent in the image when the VDI image goes live. 
