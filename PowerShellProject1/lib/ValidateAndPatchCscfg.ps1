$OptionalParametersList = @("EnvironmentType","OAuth.MicrosoftTenantName", "Auth.Basic.UserName","Auth.Basic.UserPassword", "AppDynamics-DeploymentScope")

# This function converts passed in JSON formatted PSObject to a Hashtable, intialises DeploymentConfigs hashtable

function ConvertJsonToHashtable
{
	param (
		[Parameter(ValueFromPipeline)] $InputObject
	)

	process
	{
		if ($null -ne $InputObject -and $InputObject -is [psobject])
		{
			foreach ($property in $InputObject.PSObject.Properties)
			{
				# Error handling for $property.Name and  $property.Value.value
				if (($($property.Name) -notin $OptionalParametersList) -and (-not $property.Value) )
				{
					Write-Error "No value provided for - $($property.Name) in ConfigOverrides Section." 
				}elseif( $($property.Name) -in $GUIDParamList )
				{
					ValidateGuid $($property.Name) $property.Value
				}elseif($property.Name -ieq "ActiveSecretVersion" -and $property.Name -in ("Primary","Secondary"))
				{
					Write-Error "$property.Name- '$property.Value' is not an expected value. Valid types : 'Primary','Secondary'"
				}elseif($property.Name -ieq "ConfigurationStoreType" -and $property.Name -in ("Remote","Local"))
				{
					Write-Error "$property.Name- '$property.Value' is not an expected value. Valid types : 'Remote','Local'"
				}
				
				AddServiceConfiguration $property.Name $property.Value
			}
		}
	}
}

# This function reads MonitoringConfig XML from the input $MonitoringConfigFilePath provided. This file is actually the output of SetupMds.ps1 script

function  LoadMonitoringConfigXML
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

	foreach($node in $configXml.Settings.ChildNodes)
	{
		AddServiceConfiguration $node.LocalName $node.InnerText.Trim()
	}
	
	Write-Output "Loadeded Monitoring Configuration"
}

function ValidateCscfgParams
{
	# Validate EnvironmentType if Sync Connector Auth Protocal is 'S2S' 
	$EnvironmentType = ''
	$SyncConnectionAuthenticationProtocol = $(GetServiceConfiguration "SyncConnectionAuthenticationProtocol")
	if ( $SyncConnectionAuthenticationProtocol -ieq "S2S")
	{
		$EnvironmentType = $(GetServiceConfiguration  "EnvironmentType")
		$EnvTypeList = "PROD","PPE","FairFax","Gallatin","Nova"
		if ($EnvTypeList -inotcontains $EnvironmentType)
		{
			Write-Error "EnvironmentType- '$EnvironmentType' is not an expected value. Valid types : $EnvTypeList"
		}

		AddServiceConfiguration ("EnvironmentType") $EnvironmentType
		
		# Determine OAuthMicrosoftTenantName based on environment type
		$OAuthMicrosoftTenantName = ''
		switch ($EnvironmentType)
		{
			"PROD" { $OAuthMicrosoftTenantName = "microsoftservices.onmicrosoft.com" }
			"PPE" { $OAuthMicrosoftTenantName = "microsoftservices.ccsctp.net" }
			"FairFax" { $OAuthMicrosoftTenantName = "microsoftservices.onmicrosoft.com" }
			"Gallatin" { $OAuthMicrosoftTenantName = "microsoftservices.partner.onmschina.cn" }
		}
		AddServiceConfiguration ("OAuth.MicrosoftTenantName") $OAuthMicrosoftTenantName
	}

	# If SyncConnectionAuthenticationProtocol is Basic Check for AuthBasicUserName and AuthBasicPassword
	if ($SyncConnectionAuthenticationProtocol -ieq "Basic")
	{
		if (!$(GetServiceConfiguration  "Auth.Basic.UserName"))
		{
			Write-Error "When SyncConnectionAuthenticationProtocol is Basic provide the -Auth.Basic.UserName as input parameter"
		}
		if (!$(GetServiceConfiguration  "Auth.Basic.UserPassword"))
		{
			Write-Error "When SyncConnectionAuthenticationProtocol is Basic provide the -Auth.Basic.UserPassword as input parameter" 
		}
	}
}

function LoadCertData(
[Parameter(Mandatory=$true)] $overriddenCertData
)
{
	if ($null -ne $overriddenCertData -and $overriddenCertData -is [psobject])
		{
			foreach ($cert in $overriddenCertData.PSObject.Properties)
		{
			# Error handling for $property.Name and  $property.Value
			if ($cert.Value.Thumbprint )
			{
				AddServiceCertificate $cert.Name $cert.Value.Thumbprint
				#Special handling for <Setting name="KeyVault.Auth.CertThumbprint">
				if($cert.Name -ieq "KeyVaultAuthcertificate")
				{
					AddServiceConfiguration "KeyVault.Auth.CertThumbprint" $cert.Value.Thumbprint
				}
			}
		}
	}
}

function LoadVNetData(
[Parameter(Mandatory=$true)] $vNetParamsOverrideFullPath
)
{
	$parametersVNet = Get-Content -Raw -Path $vNetParamsOverrideFullPath | ConvertFrom-Json
	$parametersVNetParamsSection = $parametersVNet.Parameters
	$global:VirtualNetworkConfiguration["virtualNetworkName"] = "$($parametersVNetParamsSection.vnetNamePrefix.value)"+ "$($parametersVNetParamsSection.geoIdentifier.value)"+"$($parametersVNetParamsSection.scaleunit.value)"
	$global:VirtualNetworkConfiguration["subnetName"] = $parametersVNetParamsSection.subnet1Name.value
	$global:VirtualNetworkConfiguration["vnetAddressPrefix"] = $parametersVNetParamsSection.vnetAddressPrefix.value
	$global:VirtualNetworkConfiguration["staticVirtualNetworkIPAddress"] = $parametersVNetParamsSection.StaticVirtualNetworkIPAddress.value
}

function global:GenerateCscfg
(
	
	[Parameter(Mandatory=$true)] $overriddeConfigFilePath,
	[Parameter(Mandatory=$true)] $deployment,
	[Parameter(Mandatory=$true)] $CscfgBaseFilePath,
	[Parameter(Mandatory=$true)] $parametersBaseComposite,
	[Parameter(Mandatory=$true)] $configType,
	[Parameter(Mandatory=$false)] $mdmConfigFilePath,
	[Parameter(Mandatory=$false)] $vNetParamsOverrideFullPath,
	[Parameter(Mandatory=$false)] $BuildVersion
)
{
	# Step-1 Create global hashtable 
	$global:CurrentDirectory = Convert-Path .
	$global:DeploymentConfigs = @{}
		
	if ($vNetParamsOverrideFullPath)
	{
		# Create a global level hashset to hold virtual network configuration
		$global:VirtualNetworkConfiguration = @{}
		loadVNetData $vNetParamsOverrideFullPath
	}else
	{
		$global:VirtualNetworkConfiguration = $null
	}

	# Step-2 Convert deploymentdefinition Json to Hashtable 
	# Parse
	$overriddenConfigValues = $deployment.ConfigurationOverrides;
	ConvertJsonToHashtable $overriddenConfigValues
	if ($overriddenConfigValues.CertOverrides)
	{
		$global:DeploymentCertificates= @()
		LoadCertData $overriddenConfigValues.CertOverrides
	}else
	{
		$global:DeploymentCertificates= $null
	}
	
	# Step-3 Patch Monitoring data to cscfg
	# Load analyticsConfig if EnableMonitoring parameter is true.
	$maConfigSetting = $null;
	if ($(GetServiceConfiguration "EnableAnalytics").Trim().ToLower().Equals("true"))
	{
		# Add MaConfig settings to Deployment configs
		$(LoadMonitoringConfigXML -MonitoringConfigFilePath $mdmConfigFilePath)
	}

	# Step-4 Validate Cscfg parameters
	ValidateCscfgParams 
	# Patch the build version if the build version is not null
	if ($BuildVersion)
	{
		AddServiceConfiguration ("ProductVersion") $BuildVersion;
	}
	# if the keyvaultEnabled falg is set THEN update the config file with the keyVaultUrl 
	if ($deployment.KeyVaultEnabled -eq "True")
	{
		$keyVaultPrefix = $parametersBaseComposite.Parameters.KeyvaultPrefix.Value;
		$geoIdentifier = $deployment.ParameterOverrides.geoIdentifier;
		$scaleUnit = $deployment.ParameterOverrides.scaleUnit;
		$keyVaultUrlWithoutSecretsSuffix = "https://" + $keyVaultPrefix + $geoIdentifier + $scaleUnit + ".vault.azure.net:443";
		$keyVaultUrl = $keyVaultUrlWithoutSecretsSuffix+"/secrets/";
			
		AddServiceConfiguration ("Microsoft.NorsyncDirectoryDatabase.ConnectionString") $("$keyVaultUrl"+"$($parametersBaseComposite.Parameters.sqlDatabaseSecretName.value)");
		AddServiceConfiguration ("Microsoft.WindowsAzure.Plugins.Diagnostics.ConnectionString") $("$keyVaultUrl" + "$($parametersBaseComposite.Parameters.diagnosticsStorageSecretName.value)");
		AddServiceConfiguration ("Microsoft.StorageAccountConnectionString") $("$keyVaultUrl" + "$($parametersBaseComposite.Parameters.storageAccountSecretName.value)");
		AddServiceConfiguration ("KeyVault.Is.Enabled") $deployment.KeyVaultEnabled;
		AddServiceConfiguration ("KeyVault.Url") $keyVaultUrlWithoutSecretsSuffix;
		AddServiceConfiguration ("KeyVault.ClientId") $overriddenConfigValues.KeyVaultClientId;
		AddServiceConfiguration ("KeyVault.AuthType") $overriddenConfigValues.KeyVaultAuthType;
			
		$queueName = "";
		$queueConfigurationsKeyVaultUrl = "";
		$datasyncQueueName = $parametersBaseComposite.Parameters.dataSyncServiceBusQueuePrefix.value + $geoIdentifier + $scaleUnit;
		$datasyncQueueConfigurationsKeyVaultUrl = $keyVaultUrl + $parametersBaseComposite.Parameters.dataSyncServiceBusQueueSecretName.value;
		if ($configType -eq "DataSync")
		{
			$queueName = $datasyncQueueName;
			$queueConfigurationsKeyVaultUrl = $datasyncQueueConfigurationsKeyVaultUrl;
		}
		Elseif ($configType -eq "Provisioning")
		{
			$queueName = $parametersBaseComposite.Parameters.provisioningServiceBusQueuePrefix.value + $geoIdentifier + $scaleUnit;
			$queueConfigurationsKeyVaultUrl = $keyVaultUrl+$parametersBaseComposite.Parameters.provisioningServiceBusQueueSecretName.value;
		}

		$queueConfigurationsValue = "<Queues><Queue name="""+$queueName+""" connectionstring="""+$queueConfigurationsKeyVaultUrl+""" hosttype=""1"" pollingfrequency=""5"" throttlermaximumcapacity=""100"" workitemslotsizeperperiod=""10"" /></Queues>";
		$syncQueueConfigurationsValue = "<Queues><Queue name="""+$datasyncQueueName+""" connectionstring="""+$datasyncQueueConfigurationsKeyVaultUrl+""" hosttype=""1"" pollingfrequency=""5"" throttlermaximumcapacity=""100"" workitemslotsizeperperiod=""10"" /></Queues>";
		$sqlServerConnectionString = $("$keyVaultUrl"+"$($parametersBaseComposite.Parameters.sqlServerSecretName.value)");
		$organizationDatabaseConfigurationsValue ="<Organizations><Organization OrganizationID="""+ "#ORG_ID#"+""" SqlServerConnectionString=""" +$sqlServerConnectionString+"""/></Organizations>" 

		AddServiceConfiguration ("QueueConfigurations") $queueConfigurationsValue;
		AddServiceConfiguration ("SyncQueueConfigurations") $syncQueueConfigurationsValue;
		AddServiceConfiguration ("OrganizationDatabaseConfigurations") $organizationDatabaseConfigurationsValue;
	}

	# Step-5 Patch deploymentdefinition data to cscfg 
	# This generate a new cscfg file suffixed  by GEOName under for eg., Deployment\Packages\DataSync\DeploymentConfigs\ServiceConfiguration.Cloud.cscfg_NOV.cscfg
	ApplyServiceConfigOverrides $CscfgBaseFilePath $(GetFilePath $overriddeConfigFilePath)
}

