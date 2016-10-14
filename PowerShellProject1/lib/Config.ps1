#Global variable to hold the data from config XML's GlobalConfig tag

$global:GlobalConfigs = @{};

#Global variable to hold the current directory from where scripts are executed from
$global:CurrentDirectory=""

#This function reads Config XML from the input ConfigXML provided

function global:LoadConfig
{
	Param
	(
		[Parameter(Mandatory=$true)][string] $ConfigFilePath
	)

	$ConfigFilePath = $ConfigFilePath.Trim("`"")
	$configFileInfo = get-item $ConfigFilePath
	$global:CurrentDirectory =  $configFileInfo.DirectoryName | Split-Path -parent
	[xml]$configXml = Get-Content $ConfigFilePath
	if (!$configXml)
	{
		Write-Error "Failed to load XML config"
		return $null
	}

	$config = XmlToHashTable($configXml.Config)
	if (-not $config)
	{
		return $null
	}

	Write-Output "Loaded Configuration: $($config.Name)"

	return $config
}

#This function reads the VirtualNetwork configuration from the input VirtualNetworkConfig.netcfg provided

function global:LoadVirtualNetworkConfig
{
	Param
	(
		[Parameter(Mandatory=$true)][string] $ConfigFilePath
	)

	$ConfigFilePath = $ConfigFilePath.Trim("`"")
	$configFileInfo = get-item $ConfigFilePath
	[xml]$configXml = Get-Content $ConfigFilePath
	Write-Host $configXml
	if (!$configXml)
	{
		Write-Error "Failed to load virtual network configuration"
		return $null
	}

	# We are loading the VirtualNetworkConfig.netcfg file

	Write-Host "Loaded Virtual Network Configuration: $($configXml)"

	return $configXml
}

#This function reads MonitoringConfig XML from the input $MonitoringConfigFilePath provided. This file is actually the output of SetupMds.ps1 script

function global:LoadMonitoringConfig
{
	Param
	(
		[Parameter(Mandatory=$true)][string] $MonitoringConfigFilePath
	)

	$MonitoringConfigFilePath = $MonitoringConfigFilePath.Trim("`"")
	[xml]$configXml = Get-Content $MonitoringConfigFilePath
	if (!$configXml)
	{
		Write-Error "Failed to load Monitoring XML config"
		return $null
	}

	$config = XmlToHashTable($configXml.Settings)
	if (-not $config)
	{
		return $null
	}

	Write-Output "Loadeded Monitoring Configuration"

	return $config
}

#This function converts Config XML to Hash list format

function XmlToHashTable
{
	Param
	(
		[Parameter(Mandatory=$true)] $xml
	)
	$ht = @{}
	foreach($node in $xml.ChildNodes)
	{
		if ($node.HasChildNodes -and ($node.ChildNodes | where {$_.NodeType -ne "Text"}))
		{
			if ($node.Attributes["Type"] -and ($node.Attributes["Type"].Value -eq "List"))
			{
				$list = @()
				foreach($childNode in $node.ChildNodes)
				{
					$list += XmlToHashTable($childNode);
				}
				$ht[$node.LocalName] = $list
			}
			else
			{
				$ht[$node.LocalName] = XmlToHashTable($node);
			}
		}
		else
		{
			if ($node.LocalName -eq "ConfigSnippet")
			{
				$keyMapAttribute = $node.Attributes["KeyMap"];
				$keyMap = @{};
				if ($keyMapAttribute)
				{
					$keyMapPairs = $keyMapAttribute.Value.Split(";");
					foreach($pair in $keyMapPairs)
					{
						$keyMapPair = $pair.Split(":");
						if($keyMapPair.Length -eq 2)
						{
							$keyMap[$keyMapPair[0]] = $keyMapPair[1];
						}
					}
				}

				$filePath = GetFilePath($node.InnerText.Trim())
				[xml]$confgXml = Get-Content $filePath
				$configHashTable = XmlToHashTable($confgXml)
				#Merge config
				foreach ($ck in $($configHashTable.keys))
				{
					$key = $ck;
					if($keyMap.ContainsKey($ck))
					{
						$key = $keyMap[$ck];
					}

					$ht[$key] = $configHashTable[$ck];
				}
			}
			else
			{
				$value = $node.InnerText.Trim();
				if ($value.StartsWith("$"))
				{
					$globalConfigKey = $value.TrimStart("$");
					if (-not $global:GlobalConfigs.ContainsKey($globalConfigKey))
					{
						Write-Error "The expected global key $globalConfigKey not defined"
					}
					$value = $global:GlobalConfigs[$globalConfigKey];
				}

				if ($xml.LocalName -eq "GlobalConfigs")
				{
					$global:GlobalConfigs[$node.LocalName] = $value;
				}
				
				$ht[$node.LocalName] = $value;
			}
		}
	}
	return $ht
}

#This function returns full path for the file passed in

function global:GetFilePath
{
	Param
	(
		[Parameter(Mandatory=$true)][string] $filePath,
		[Parameter(Mandatory=$false)][string] $currDir
	)
	
	if ($([System.IO.Path]::IsPathRooted($filePath)) -ieq $False)
	{
		if ($currDir -and ($([System.IO.Path]::IsPathRooted($currDir)) -ieq $true))
		{
			return $currDir + "\" + $filePath
		}else
		{
			return $global:CurrentDirectory + "\" + $filePath
		}
	}
	else
	{
		return $filePath
	}
}


#This function add an entry to hashtable -'$global:DeploymentConfigs' with ($configName,$value) in Name-Value pair

function global:AddServiceConfiguration
{
	Param
	(
		[Parameter(Mandatory=$true)][string] $configName,
		[Parameter(Mandatory=$true)][string] [AllowEmptyString()] $value
	)
	$global:DeploymentConfigs[$configName] = $value
}

#This function add an entry to hashtable -'$global:DeploymentCertificates' with ($configName,$value) in Name-Value pair

function global:AddServiceCertificate
{
	Param
	(
		[Parameter(Mandatory=$true)][string] $certName,
		[Parameter(Mandatory=$true)][string] $thumbprint
	)
	foreach($serviceCert in $global:DeploymentCertificates)
	{
		if ($serviceCert["Name"] -eq $certName)
		{
			$serviceCert["Thumbprint"] = $thumbprint
			return
		}
	}

	$htConfigKVP = @{}
	$htConfigKVP["Name"] = $certName
	$htConfigKVP["Thumbprint"] = $thumbprint
	$global:DeploymentCertificates += $htConfigKVP
}

#This function adds the virtual network settings to the the hashtable '$global:VirtualNetworkConfiguration'

function global:AddServiceVirtualNetwork
{
	Param
	(
		[Parameter(Mandatory=$true)][xml] $virtualNetworkConfig
	)

	$virtualNetworkSite = $virtualNetworkConfig.NetworkConfiguration.VirtualNetworkConfiguration.VirtualNetworkSites.VirtualNetworkSite

	$global:VirtualNetworkConfiguration["virtualNetworkName"] = $virtualNetworkSite.name

	$subnet = $virtualNetworkSite.Subnets.Subnet
	$global:VirtualNetworkConfiguration["subnetName"] = $subnet.name
}

#This function adds the virtual network static IP Address to the hastable '$global:VirtualNetworkConfiguration'

function global:AddVirtualNetworkStaticIPAddress
{
	Param
	(
		[Parameter(Mandatory=$true)][string] $staticVirtualNetworkIPAddress
	)

	$global:VirtualNetworkConfiguration["staticVirtualNetworkIPAddress"] = $staticVirtualNetworkIPAddress
}

#This function gets corresponding vaule from hashtable -'$global:DeploymentConfigs' for the passed in $configName 

function global:GetServiceConfiguration
{
	Param
	(
		[Parameter(Mandatory=$true)][string] $configName
	)
	if ($global:DeploymentConfigs.ContainsKey($configName))
	{
		return $global:DeploymentConfigs[$configName]
	}

	return ""
}

#This function loops through $PreDeploymentActions list and find the path for the given blob name
#The expected $PreDeploymentActions structure is as given below-
<#
<PreDeploymentActions Type="List">
	<PreDeploymentAction>
		<FilePath>.\AzurePackage\ProvisioningCloudService.cspkg</FilePath>
		<BlobName>provisioningblob</BlobName>
		<ContainerName>provisioningcontainer</ContainerName>
	</PreDeploymentAction>
	<PreDeploymentAction>
		<FilePath>.\AzurePackage\ProvisioningConfiguration.Cloud.cscfg</FilePath>
		<BlobName>provisioningconfigblob</BlobName>
		<ContainerName>provisioningcontainer</ContainerName>
	</PreDeploymentAction>
</PreDeploymentActions>
#>

function global:GetFilePathfromBlob
{
	Param
	(
		[Parameter(Mandatory=$true)] $PreDeploymentActions,
		[Parameter(Mandatory=$true)][string] $blobName
	)
	foreach($PreDeploymentAction in $PreDeploymentActions)
	{
		if ($PreDeploymentAction.BlobName -eq $blobName)
		{
			return $PreDeploymentAction.FilePath
		}
	}

	return ""
}

# This function reads given cloud config file (.cscfg), fills the placeholders (usually connection strings for azure resources created 
#  and creates a new config file and its name is same as cloud config file name suffixed by current data-time.

function global:ApplyServiceConfigOverrides
{
	Param
	(
		[Parameter(Mandatory=$true)][string] $ConfigLocalFilePath,
		[Parameter(Mandatory=$false)][string] $OverrideFilePath
	)
	Write-Host "Opening CsCfg service config XML file $ConfigLocalFilePath"
	$cscfg = [xml](get-content (GetFilePath($ConfigLocalFilePath)))
	
	foreach($role in $cscfg.ServiceConfiguration.Role)
	{
		$roleName = $role.Attributes["name"].Value
		
		# Set regular configs
		foreach($roleSetting in $role.ConfigurationSettings.Setting)
		{
			if ($global:DeploymentConfigs.ContainsKey($roleSetting.Attributes["name"].Value))
			{
				$roleSetting.Attributes["value"].Value = $global:DeploymentConfigs[$roleSetting.Attributes["name"].Value]
			}
		}

		# Set the certificates
		foreach ($certConfig in $role.Certificates.Certificate)
		{
			$certData =  $global:DeploymentCertificates | where { $_.Name -eq $certConfig.Attributes["name"].Value }
			if ($certData)
			{
				$certConfig.Attributes["thumbprint"].Value = $certData.Thumbprint
			}
		}

		if ($global:VirtualNetworkConfiguration -and $global:VirtualNetworkConfiguration["staticVirtualNetworkIPAddress"])
		{
			$norsyncAdminEndpointXmlElement = $role.ConfigurationSettings.Setting | where { $_.Attributes["name"].Value -eq "NorsyncAdminEndpoint" }
			if($norsyncAdminEndpointXmlElement)
			{
				$norsyncAdminEndpointValue = $norsyncAdminEndpointXmlElement.Attributes["value"].Value
				$norsyncAdminEndpointValue = $norsyncAdminEndpointValue -replace "\[staticVirtualNetworkIPAddress\]", $global:VirtualNetworkConfiguration["staticVirtualNetworkIPAddress"]
				$norsyncAdminEndpointXmlElement.Attributes["value"].Value = $norsyncAdminEndpointValue
			}
		}
	}

	$networkConfiguration = $cscfg.ServiceConfiguration.NetworkConfiguration

	# Apply virtual network overrides only for the data sync cscfg file
	if ($networkConfiguration -and $global:VirtualNetworkConfiguration) {
		$networkConfiguration.VirtualNetworkSite.name = $global:VirtualNetworkConfiguration["virtualNetworkName"]

		foreach ($instanceAddress in $networkConfiguration.AddressAssignments.InstanceAddress)
		{
			$instanceAddress.Subnets.Subnet.name = $global:VirtualNetworkConfiguration["subnetName"]
		}

		$networkConfiguration.LoadBalancers.LoadBalancer.FrontendIPConfiguration.subnet = $global:VirtualNetworkConfiguration["subnetName"]

		$networkConfiguration.LoadBalancers.LoadBalancer.FrontendIPConfiguration.staticVirtualNetworkIPAddress = $global:VirtualNetworkConfiguration["staticVirtualNetworkIPAddress"]
	}

	$configFileInfo = get-item (GetFilePath($configLocalFilePath))
	$currentDateTime = Get-Date;

	if($OverrideFilePath){
		$overideCscfgName =  $OverrideFilePath 
	}else
	{
		$overideCscfgName = $configFileInfo.DirectoryName + "\\DeploymentConfigs\\" + $configFileInfo.Name + "_" + "Override_" + $currentDateTime.ToString("yyyy_MM_dd_hh_mm_ss") + ".cscfg"
	}
	$overrideConfigFileInfo = New-Item ($overideCscfgName) -Type file -Force
	$cscfg.Save($($overrideConfigFileInfo.FullName))
	
	Write-Host "Created Service config override: $($overrideConfigFileInfo.FullName)"
	$OverrideConfigurationFile = $overrideConfigFileInfo.FullName
	return $OverrideConfigurationFile
}

# This function reads given diagnostics config file and fills the placeholders (usually diagnostics storage account)

function global:ApplyDiagnsoticsConfigOverrides
{
	Param
	(
		[Parameter(Mandatory=$true)][string] $DiagnsoticsConfigLocalFilePath,
		[Parameter(Mandatory=$true)][string] $DiagnsoticsStorageAccountName
	)
	Write-Host "Opening Diagnostics config file - $DiagnsoticsConfigLocalFilePath"
	$diagnosticConfig = [xml](get-content (GetFilePath($DiagnsoticsConfigLocalFilePath)))
	#We are interested with <PublicConfig><StorageAccount>
	$diagnosticConfig.PublicConfig.StorageAccount = $DiagnsoticsStorageAccountName
	
	
	$diagnsoticConfigFileInfo = get-item (GetFilePath($DiagnsoticsConfigLocalFilePath))
	$currentDateTime = Get-Date;
	$overrideConfigFileInfo = New-Item ($diagnsoticConfigFileInfo.DirectoryName + "\\DeploymentConfigs\\" + $diagnsoticConfigFileInfo.Name + "_Override_" + $currentDateTime.ToString("yyyy_MM_dd_hh_mm_ss") + ".xml") -Type file -Force

	$diagnosticConfig.Save($overrideConfigFileInfo.FullName)

	Write-Host "Created Diagnsostics config override: $($overrideConfigFileInfo.FullName)"
	$OverrideConfigurationFile = $overrideConfigFileInfo.FullName
	return $OverrideConfigurationFile
}
