# Run command : # Run command : .\RollbackMobileOfflineResource.ps1 "CreatedResourceFile_2015_11_04_01_40_20.txt"
param
(
	[parameter(Mandatory=$true)][string] $ResourcesFile = $null
)

$ErrorActionPreference = "Stop"

# Make sure that it is in AzureServiceManagement mode initially to make Service cmdlets workable
Switch-AzureMode AzureServiceManagement
if(-not (Get-Module Azure))
{
	Write-Error "This script needs to be run in Azure PowerShell"
}

. .\Lib\Config.ps1

### Start of the script to remove the resources given in input text file

$global:CurrentDirectory = Convert-Path .
$ResourcesCmdList = Get-Content $(GetFilePath $ResourcesFile)

# Read each command from the file and execute 
foreach($resourceOneCmd in $ResourcesCmdList)
{
	if(-not $resourceOneCmd -or $resourceOneCmd.StartsWith('#')){
		continue
	}
	else
	{
		Invoke-Expression $resourceOneCmd
	}
}

 
