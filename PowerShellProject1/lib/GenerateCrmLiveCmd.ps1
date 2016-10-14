#Create a global array to hold CRMLive Commands, which are executed after deploying the service, 
# to update CRM Live Database with the deployed service config information.
#Each resource would have an entry in this array as shown here - CrmLive MobileOfflineResource Create -ResourceName "offlinestorage" -ResourceType "StorageAccount" -ResourceConnectionString "XXXX" -DataCenterID "DC1" -SubscriptionId "hh" -Group "New"/"Default"

$global:CRMLiveCmds =  @()

#This function generates a file name from CRMLiveCommandsFilePath and current date-time suffix, which would later
#  be used to hold CRMLive commands for the azure resources created during script execution

function global:GenerateCommandsFile
{	
Param
(
	[Parameter(Mandatory=$true)][string] $CrmLiveCmdsFilePath
)
	$crmLiveCmdsFileInfo = New-Item $($($(GetFilePath $CrmLiveCmdsFilePath) + "_" + $(Get-Date).ToString("yyyy_MM_dd_hh_mm_ss")) + ".txt") -Type file -Force
	return $crmLiveCmdsFileInfo.FullName
}

# This function will generate a CRMLive as given below-
#CrmLive MobileOfflineResource Create -ResourceName "offlinestorage" -ResourceType "StorageAccount" -ResourceConnectionString "XXXX" -DataCenterID "DC1" -SubscriptionId "hh" -Group "New"/"Default" -GroupId "YYYY"

function global:GenerateAndAddCrmLiveCmdToList
{
Param(
		[Parameter(Mandatory=$true)][String] $ResourceName,
		[Parameter(Mandatory=$true)][String] $ResourceType,
		[Parameter(Mandatory=$true)][String] $ResourceConnStr,
		[Parameter(Mandatory=$true)][String] $DataCenterID,
		[Parameter(Mandatory=$true)][String] $SubscriptionId,
		[Parameter(Mandatory=$false)][String] $Purpose
	)

	$CRMLiveCmd +="Crmlive MobileOfflineResource Create `"-ResourceName:$ResourceName`" `"-ResourceType:$ResourceType`" `"-ResourceConnectionString:$ResourceConnStr`" `"-DataCenterID:$DataCenterID`" `"-SubscriptionId:$SubscriptionId`""
	if($Purpose)
	{
		$CRMLiveCmd +=" `"-Purpose:$Purpose`""
	}
	$global:CRMLiveCmds += $CRMLiveCmd
}

<# 
This function will generate set of CrmLive commands which on excecution will add the information of all azure resources, that are created during the deployment, to Crm GEO Database.
.DESCRIPTION 
	It reads the Array - $CRMLiveCmds and generates CRMLive commands for each entry in the format given below-
	#CrmLive MobileOfflineResource Create -ResourceName "offlinestorage" -ResourceType "StorageAccount" -ResourceConnectionString "XXXX" -DataCenterID "DC1" -SubscriptionId "hh" -Group:"New"/"Default" -GroupId:"YYYY"
.OUTPUTS 
	Generates CRMLive commands for azure resource data creation in CRM GEO config database
#>

function global:GenerateScriptToUpdateCrm
{
Param
(
	[Parameter(Mandatory=$true)][string] $CRMLiveCommandsFilePath,
	[Parameter(Mandatory=$false)][string] $DataCenterID,
	[Parameter(Mandatory=$false)][string] $DeploymentType,
	[Parameter(Mandatory=$false)][string] $GroupId,
	[Parameter(Mandatory=$false)][string] $ActiveSecretVersion,
	[Parameter(Mandatory=$false)][string] $ScaleUnit,
	[Parameter(Mandatory=$false)][string] $Reason
)
	$firstResource = $true
	if($DeploymentType)
	{
		Add-Content $CRMLiveCommandsFilePath "`r`n`# Crmlive commands for DataCenterID: $DataCenterID `n `r`n"
	}
	if($Reason)
	{
		Add-Content $CRMLiveCommandsFilePath "`r`n`# Crmlive commands for $Reason `n `r`n"
	}
	foreach($resourceCommand in $global:CRMLiveCmds)
	{
		if($DeploymentType)
		{
			$resourceCommand += " `"-DeploymentType:$DeploymentType`""
		}
		if($GroupId)
		{
			$resourceCommand += " `"-GroupId:$GroupId`""
		}
		if($ActiveSecretVersion)
		{
			$resourceCommand += " `"-ActiveSecretVersion:$ActiveSecretVersion`""
		}
		if($ScaleUnit)
		{
			$resourceCommand += " `"-ScaleUnit:$ScaleUnit`"`n`r`n"
		}
	
		Add-Content $CRMLiveCommandsFilePath "$resourceCommand"

	}
}

# This function will generate a CRMLive as given below-
#CrmLive AzureResource create <Parameters>

function global:GenerateAndAddAzureResourceCreateCrmLiveCmdToList
{
Param(
		[Parameter(Mandatory=$true)][String] $ResourceName,
		[Parameter(Mandatory=$true)][String] $ResourceType,
		[Parameter(Mandatory=$true)][String] $SubscriptionId,
		[Parameter(Mandatory=$false)][String] $ResourceGroupName,
		[Parameter(Mandatory=$false)][String] $ResourceConnectionString,
		[Parameter(Mandatory=$false)][String] $Purpose,
		[Parameter(Mandatory=$false)][String] $TimeToLive,
		[Parameter(Mandatory=$false)][String] $ResourceId
	)

	$CRMLiveCmd +="Crmlive AzureResource Create `"-ResourceName:$ResourceName`" `"-ResourceType:$ResourceType`" `"-SubscriptionId:$SubscriptionId`""

	if($ResourceGroupName)
	{
		$CRMLiveCmd +=" `"-ResourceGroupName:$ResourceGroupName`""
	}

	if($ResourceConnStr)
	{
		$CRMLiveCmd +=" `"-ResourceConnectionString:$ResourceConnStr`""
	}

	if($Purpose)
	{
		$CRMLiveCmd +=" `"-Purpose:$Purpose`""
	}

	if($TimeToLive)
	{
		$CRMLiveCmd +=" `"-TimeToLive:$TimeToLive`""
	}

	if($ResourceId)
	{
		$CRMLiveCmd +=" `"-ResourceId:$ResourceId`""
	}

	$global:CRMLiveCmds += $CRMLiveCmd
}


# This function will generate a CRMLive as given below-
# CrmLive AzureResourceGroupResources create "-GroupId:8A4C1574-56CF-431E-83ED-687203B2F93D" "-ResourceId:84fa6e96-4864-473f-82e9-5622bd5c70b6"

function global:GenerateAndAddAzureResourceGroupResourcesCreateCrmLiveCmdToList
{
Param(
		[Parameter(Mandatory=$true)][String] $GroupId,
		[Parameter(Mandatory=$true)][String] $ResourceId
	)

	$CRMLiveCmd +="Crmlive AzureResourceGroupResources Create `"-GroupId:$GroupId`" `"-ResourceId:$ResourceId`"`n`r`n"

	Add-Content $CRMLiveCommandsFilePath "$CRMLiveCmd"
}

# This function will generate a CRMLive for DNS as given below-
# CrmLive domain addspecial "-Name:mobile" "-nstarget:ns1-03.azure-dns.com"

function global:GenerateCrmLiveToAddDNSRecords
{
Param(
		[Parameter(Mandatory=$true)][String] $Name,
		[Parameter(Mandatory=$true)][String] $nstarget
	)

	$CRMLiveCmd +="Crmlive domain addspecial `"-Name:$Name`" `"-nstarget:$nstarget`"`n`r`n"

	Add-Content $CRMLiveCommandsFilePath "$CRMLiveCmd"
}


# This function will generate a CRMLive to refresh DNS as given below-
# CrmLive domain refresh -special 

function global:GenerateCrmLiveToRefreshDNS
{

	$CRMLiveCmd +="Crmlive domain refresh -special"

	Add-Content $CRMLiveCommandsFilePath "$CRMLiveCmd"
}