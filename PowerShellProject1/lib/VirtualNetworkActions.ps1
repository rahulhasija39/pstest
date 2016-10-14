
#Delete a virtual network if it exists. If it has a cloud service associated with it, first delete the cloud service and then the Virtual Network
function global:DeleteVirtualNetworkNode
{
Param
(
	[parameter(Mandatory=$true)][string] $virtualNetworkName,
	[parameter(Mandatory=$true)][string] $ServiceName
)
	$configPath = getConfigPath

	New-Item $configPath -type file -force -value '<?xml version="1.0" encoding="utf-8"?><NetworkConfiguration xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns="http://schemas.microsoft.com/ServiceHosting/2011/07/NetworkConfiguration"><VirtualNetworkConfiguration><Dns/><VirtualNetworkSites></VirtualNetworkSites></VirtualNetworkConfiguration></NetworkConfiguration>'

	write-host "Absolute path for SubscriptionVirtualNetworkConfig $configPath"
	Get-AzureVNetConfig -ExportToFile 	$configPath
	$subscriptionVirtualNetworkConfig = LoadVirtualNetworkConfig -ConfigFilePath $configPath

	$sites = $subscriptionVirtualNetworkConfig.DocumentElement.VirtualNetworkConfiguration.VirtualNetworkSites
	#If there is an existing cloud service, which is using the vnet with the same name, first delete Cloud service and then the Vnet.
	if($sites -ne $null)
	{
		foreach ($node in $sites.ChildNodes)
		{
			if($node.name -eq $virtualNetworkName )
			{
				Write-Host "Found a network with same name $($node.name)."
				$azureService = Get-AzureService | Where-Object {$_.ServiceName -eq $ServiceName}
				if ($azureService -ne $null)
				{
					Remove-AzureService -ServiceName $ServiceName -Force
				}
				$sites.RemoveChild($node)
				$subscriptionVirtualNetworkConfig.save($configPath)
				break
			}
		}
	}
}

#Create a virtual network in a re-entrant way

function global:CreateVirtualNetwork
{
Param
(
	[parameter(Mandatory=$true)][string] $VirtualNetworkFilePath,
	[parameter(Mandatory=$true)][string] $VirtualNetworkName,
	[parameter(Mandatory=$true)][string] $ServiceName,
	[parameter(Mandatory=$true)][string] $AzureDeploymentLocation,
	[parameter(Mandatory=$true)][string] $DeploymentType,
	[parameter(Mandatory=$true)][string] $ScaleUnit
)

	$virtualNetworkConfig = LoadVirtualNetworkConfig -ConfigFilePath $VirtualNetworkFilePath
	$virtualNetworkConfig.NetworkConfiguration.VirtualNetworkConfiguration.VirtualNetworkSites.VirtualNetworkSite.Attributes["name"].Value = $VirtualNetworkName
	$virtualNetworkConfig.NetworkConfiguration.VirtualNetworkConfiguration.VirtualNetworkSites.VirtualNetworkSite.Attributes["Location"].Value = $AzureDeploymentLocation
	DeleteVirtualNetworkNode $VirtualNetworkName $ServiceName
	$configPath = getConfigPath
	$subscriptionVirtualNetworkConfig = LoadVirtualNetworkConfig -ConfigFilePath $configPath

	$newnode = $subscriptionVirtualNetworkConfig.ImportNode($virtualNetworkConfig.NetworkConfiguration.VirtualNetworkConfiguration.VirtualNetworkSites.VirtualNetworkSite, $true)
	$configurationNodes = $subscriptionVirtualNetworkConfig.DocumentElement.VirtualNetworkConfiguration.ChildNodes
	foreach ($node in $configurationNodes)
	{
		if($node.name -eq "VirtualNetworkSites" )
		{
			$node.AppendChild($newnode)
		}
	}
	$subscriptionVirtualNetworkConfig.save($configPath)
	Set-AzureVNetConfig -ConfigurationPath $configPath
	AddServiceVirtualNetwork $virtualNetworkConfig
	Remove-Item $configPath
}

function global:getConfigPath
{
	$configPathObj = resolve-path .\Config
	$configPath = $configPathObj.Path + "\SubscriptionVirtualNetworkConfig.xml"
	return $configPath
}

function global:DeleteVirtualNetwork
{
Param
(
	[parameter(Mandatory=$true)][string] $virtualNetworkName,
	[parameter(Mandatory=$true)][string] $ServiceName
)
	$configPath = getConfigPath
	DeleteVirtualNetworkNode $virtualNetworkName $ServiceName
	Set-AzureVNetConfig -ConfigurationPath $configPath
	Remove-Item $configPath
}