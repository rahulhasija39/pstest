function global:GenerateAcisConfig
(
	[Parameter(Mandatory=$true)] $acisConfigFullPath,
	[Parameter(Mandatory=$true)] $deployment,
	[Parameter(Mandatory=$true)] $compositeParamsOverrideFullPath,
	[Parameter(Mandatory=$true)] $provisioningParamsOverrideFullPath,
	[Parameter(Mandatory=$true)] $datasyncParamsOverrideFullPath,
	[Parameter(Mandatory=$true)] $vNetParamsOverrideFullPath,
	[Parameter(Mandatory=$true)] $AzureSubscriptionId
)
{
	# create objects with the parameters after converting the files to individual object
	$compositeParams = (Get-Content -Raw -Path $compositeParamsOverrideFullPath) | ConvertFrom-Json | %{$_.parameters}
	$dataSyncParams = (Get-Content -Raw -Path $datasyncParamsOverrideFullPath) | ConvertFrom-Json | %{$_.parameters}
	$provisioningParams = (Get-Content -Raw -Path $provisioningParamsOverrideFullPath) | ConvertFrom-Json | %{$_.parameters}
	$vNetParams = (Get-Content -Raw -Path $vNetParamsOverrideFullPath) | ConvertFrom-Json | %{$_.parameters}

	# Set the commonly parameters values to local variables
	$scaleUnit = $deployment.ParameterOverrides.scaleUnit;
	$deploymentType = $deployment.ParameterOverrides.DeploymentType;
	$activeSecretVersion = $deployment.ParameterOverrides.ActiveSecretVersion;
	$dataCenterID = $deployment.DataCenterId;
	$geoIdentifier = $deployment.ParameterOverrides.geoIdentifier;
	$dnsZoneSubscriptionId = $deployment.ParameterOverrides.DnsZoneSubscriptionId;
	$provisioningType = $deployment.ParameterOverrides.ProvisioningType;
	$subscriptionId = $AzureSubscriptionId;
	$groupId = [System.Guid]::NewGuid();

	# Intializing an Hash Table and set the default node with "AcisConfig"
	$AcisConfigDeployment = @{};
	$AcisConfigDeployment["AcisConfigDeployment"] = @{};

	# Add the AzureResourceGroup node
	$AzureResourceGroupElement = @{};
	$AzureResourceGroupElement["Name"] = $deployment.ResourceGroupPrefix + $geoIdentifier + $scaleUnit;
	$AzureResourceGroupElement["DeploymentType"] = $deploymentType;
	$AzureResourceGroupElement["ProvisioningType"] = $provisioningType;
	$AzureResourceGroupElement["GroupId"] = $groupId;	
	$AcisConfigDeployment["AzureResourceGroup"] = $AzureResourceGroupElement;

	# Prepare the keyvault Url
	$keyValtUrl = "https://"+ $compositeParams.KeyvaultPrefix.value + $geoIdentifier + $scaleUnit + ".vault.azure.net:443/secrets/"

	# Define the nodes that need to be created.
	$AcisConfigElements = "AzureDns", "AzureADApplication", "ProvisiongCloudService", "DataSyncCloudService", "ProvisioningServiceBusNameSpace", "StorageAccount", "ProvisioningServiceBusQueue", "DataSyncServiceBusNameSpace", "DataSyncServiceBusQueue", "AzureSqlserver",
						  "AzureSqlDatabase", "DiagnosticStorageAccount", "VirtualNetwork", "KeyVault", "AzureResourceGroupResources";
	$ResourceRootElement = @{};
		
	# Process Each elements in AcisConfigElements
	foreach ($AcisConfigElement in $AcisConfigElements)
	{
		$ResourceElement = @{};
		
		# If Element is not equal to AzureADApplication and AzureDns 
		# then set all the common properties applicable to the different Resources .
		if ($AcisConfigElement -ne "AzureADApplication"-And $AcisConfigElement -ne "AzureDns" -And $AcisConfigElement -ne "AzureResourceGroupResources")
		{
			# Setting common properties values.
			$ResourceElement["ScaleUnit"] = $scaleUnit;
			$ResourceElement["DeploymentType"] = $deploymentType;
			$ResourceElement["ActiveSecretVersion"] = $activeSecretVersion;
			$ResourceElement["GroupId"] = $groupId;
			$ResourceElement["SubscriptionId"] = $subscriptionId;
			$ResourceElement["DataCenterID"] = $dataCenterID;
			$ResourceElement["ProvisioningType"] = $provisioningType;
	
			Switch ($AcisConfigElement)
			{
				"ProvisiongCloudService"
				{
					$ResourceElement["ResourceName"] = $provisioningParams.serviceDomainNamePrefix.value+$geoIdentifier+$scaleUnit;
					$ResourceElement["ResourceType"] = "CloudService";
					$ResourceElement["Purpose"] = "MobileOfflineProvisioning";
					$ResourceElement["ResourceConnectionString"] = $ResourceElement["ResourceName"]+".cloudapp.net"
				}
				"DataSyncCloudService"
				{
					$ResourceElement["ResourceName"] = $dataSyncParams.serviceDomainNamePrefix.value+$geoIdentifier+$scaleUnit;
					$ResourceElement["ResourceType"] = "CloudService";
					$ResourceElement["Purpose"] = "MobileOfflineDataSync";
					$ResourceElement["ResourceConnectionString"] = $ResourceElement["ResourceName"]+".cloudapp.net"
				}
				"ProvisioningServiceBusNameSpace"
				{
					$ResourceElement["ResourceName"] = $compositeParams.provisioningServiceBusNamespacePrefix.value+$geoIdentifier+$scaleUnit;
					$ResourceElement["ResourceType"] = "ServiceBusNamespace";
					$ResourceElement["Purpose"] = "MobileOfflineProvisioning";
					$ResourceElement["ResourceConnectionString"] = $keyValtUrl+$compositeParams.provisioningServiceBusNamespaceSecretName.value
				}
				"DataSyncServiceBusNameSpace"
				{
					$ResourceElement["ResourceName"] = $compositeParams.dataSyncServiceBusNamespacePrefix.value+$geoIdentifier+$scaleUnit;
					$ResourceElement["ResourceType"] = "ServiceBusNamespace";
					$ResourceElement["Purpose"] = "MobileOfflineDataSync";
					$ResourceElement["ResourceConnectionString"] = $keyValtUrl+$compositeParams.dataSyncServiceBusNamespaceSecretName.value
				}
				"ProvisioningServiceBusQueue"
				{
					$ResourceElement["ResourceName"] = $compositeParams.provisioningServiceBusQueuePrefix.value+$geoIdentifier+$scaleUnit;
					$ResourceElement["ResourceType"] = "ServiceBusQueue";
					$ResourceElement["Purpose"] = "MobileOfflineProvisioning";
					$ResourceElement["ResourceConnectionString"] = $keyValtUrl+$compositeParams.provisioningServiceBusQueueSecretName.value
				}
				"DataSyncServiceBusQueue"
				{
					$ResourceElement["ResourceName"] = $compositeParams.dataSyncServiceBusQueuePrefix.value+$geoIdentifier+$scaleUnit;
					$ResourceElement["ResourceType"] = "ServiceBusQueue";
					$ResourceElement["Purpose"] = "MobileOfflineDataSync";
					$ResourceElement["ResourceConnectionString"] = $keyValtUrl+$compositeParams.dataSyncServiceBusQueueSecretName.value
				}
				"StorageAccount"
				{
					$ResourceElement["ResourceName"] = $compositeParams.storageAccountPrefix.value+$geoIdentifier+$scaleUnit;
					$ResourceElement["ResourceType"] = "StorageAccount";
					$ResourceElement["Purpose"] = "Invalid";
					$ResourceElement["ResourceConnectionString"] = $keyValtUrl+$compositeParams.storageAccountSecretName.value;
				}
				"AzureSqlserver"
				{
					$ResourceElement["ResourceName"] = $compositeParams.azureSqlserverNamePrefix.value+$geoIdentifier+$scaleUnit;
					$ResourceElement["ResourceType"] = "AzureSqlServer";
					$ResourceElement["Purpose"] = "Invalid";
					$ResourceElement["ResourceConnectionString"] = $keyValtUrl+$compositeParams.sqlServerSecretName.value;
				}
				"AzureSqlDatabase"
				{
					$ResourceElement["ResourceName"] = $compositeParams.azureSqlDatabasePrefix.value+$geoIdentifier+$scaleUnit;
					$ResourceElement["ResourceType"] = "AzureSqlDatabase";
					$ResourceElement["Purpose"] = "Invalid";
					$ResourceElement["ResourceConnectionString"] = $keyValtUrl+$compositeParams.sqlDatabaseSecretName.value;
				}
				"DiagnosticStorageAccount"
				{
					$ResourceElement["ResourceName"] = $compositeParams.diagnosticsStorageAccountPrefix.value+$geoIdentifier+$scaleUnit;
					$ResourceElement["ResourceType"] = "StorageAccount";
					$ResourceElement["Purpose"] = "Invalid";
					$ResourceElement["ResourceConnectionString"] = $keyValtUrl+$compositeParams.diagnosticsStorageSecretName.value;
				}
				"VirtualNetwork"
				{
					$ResourceElement["ResourceName"] = $vNetParams.vnetNamePrefix.value+$geoIdentifier+$scaleUnit;
					$ResourceElement["ResourceType"] = "VirtualNetwork";
					$ResourceElement["Purpose"] = "Invalid";
					$ResourceElement["ResourceConnectionString"] = "VirtualNetwork";
				}
				"KeyVault"
				{
					$ResourceElement["ResourceName"] = $compositeParams.KeyvaultPrefix.value+$geoIdentifier+$scaleUnit;
					$ResourceElement["ResourceType"] = "SecureVault";
					$ResourceElement["Purpose"] = "Invalid";
					$ResourceElement["ResourceConnectionString"] = $keyValtUrl;
				}
			}
		}
		Elseif ($AcisConfigElement -eq "AzureADApplication")
		{
			$ResourceElement["SubscriptionId"] = $dnsZoneSubscriptionId
			$ResourceElement["ResourceName"] = $deployment.ParameterOverrides.MobileOfflineAzureAppName;
			$ResourceElement["ResourceType"] = "AzureADApplication";
			$ResourceElement["ResourceId"] = $deployment.ParameterOverrides.MobileOfflineAzureAppId;
		}
		Elseif ($AcisConfigElement -eq "AzureDns")
		{
			$ResourceElement["SubscriptionId"] = $dnsZoneSubscriptionId;
			$ResourceElement["ResourceName"] = $deployment.ParameterOverrides.AzureResourceName
			$ResourceElement["ResourceType"] = "AzureDns";
			$ResourceElement["TimeToLive"] = $deployment.ParameterOverrides.DnsRecordTimeToLive
			$ResourceElement["ResourceGroupName"] = $deployment.ParameterOverrides.AzureResourceGroupName
		}
		Elseif ($AcisConfigElement -eq "AzureResourceGroupResources")
		{
			$ResourceElement["GroupId"] = $groupId;
			$ResourceElement["ResourceId"] = $deployment.ParameterOverrides.AzureDnsResourceId
		}

		$ResourceRootElement[$AcisConfigElement] = $ResourceElement
	}

	#Update the root hash table for the generation of the json.
	$AcisConfigDeployment["AcisConfigDeployment"] = $ResourceRootElement;
	
	#Generate the Acis config json file
	$AcisConfigDeployment | ConvertTo-Json -depth 64 | Set-Content -path $acisConfigFullPath

	Write-Host "Generated file for Acis config: $acisConfigFullPath"
}