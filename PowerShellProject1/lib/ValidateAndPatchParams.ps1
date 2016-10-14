function global:GenerateParams
(
	[Parameter(Mandatory=$true)] $overrideParamFilePath,
	[Parameter(Mandatory=$true)] $overrideParams,
	[Parameter(Mandatory=$true)] $parametersBase,
	[Parameter(Mandatory=$true)] $keyvaultEnabled,
	[Parameter(Mandatory=$false)] $compositeParametersFile
)
{
	foreach ($baseParam in $parametersBase.Parameters.PSObject.Properties)
	{
		foreach ($overrideParam in $overrideParams.PSObject.Properties)
		{
			ThrowErrorIfNull $overrideParam.Name $overrideParam.Value
			if ($overrideParam.Name -eq $baseParam.Name)
			{
				if($baseParam.Name -in $GUIDParamList)
				{
					ValidateGuid $overrideParam.Name $overrideParam.Value
				}
				$baseParam.Value.value = $overrideParam.Value;
			}
		}
	}

	# Update Secrets/Replacements section
	if ($parametersBase.secrets -and $parametersBase.secrets.Replacements)
	{
		if ((Select-String -InputObject $overrideParamFilePath -Pattern datasync.parameters -AllMatches) -ne $null -and $compositeParametersFile -ne $null)
		{
			# Update DataSync keyvaults
			UpdateDataSyncKeyVaults $overrideParams $compositeParametersFile $parametersBase $keyvaultEnabled
		}
		Elseif ((Select-String -InputObject $overrideParamFilePath -Pattern provisioning.parameters -AllMatches) -ne $null -and $compositeParametersFile -ne $null)
		{
			# Update Provisioning keyvaults
			UpdateProvisioningKeyVaults $overrideParams $compositeParametersFile $parametersBase $keyvaultEnabled
		}
	}

	# Update Secrets/Certificates section
	$certOverrideParams = $overrideParams.CertOverrides
	if ($parametersBase.secrets -and $parametersBase.secrets.Certificates){
		$Certificates = $parametersBase.secrets.Certificates
		foreach($baseCert in $Certificates){
			foreach($cert in $certOverrideParams.PSObject.Properties){
				if ($baseCert.Name -eq $cert.Name)
				{
					$baseCert.ContentReference = $cert.Value.ContentReference
				}
			}
		}
	}

	# Create deployment specific params file
	Write-Host "creating deployment specific params file - $overrideParamFilePath"
	$parametersBase | ConvertTo-Json -depth 64 | Set-Content -path $overrideParamFilePath
}

function UpdateDataSyncKeyVaults
(
	[Parameter(Mandatory=$true)] $overrideParams,
	[Parameter(Mandatory=$true)] $compositeParametersFile,
	[Parameter(Mandatory=$true)] $parametersBase,
	[Parameter(Mandatory=$true)] $keyvaultEnabled
)
{
	#Update the keyvault urls in the Datasync params file
	$compositeParameters= Get-Content -Raw -Path $compositeParametersFile | ConvertFrom-Json

	$keyVaultPrefix = $compositeParameters.Parameters.KeyvaultPrefix.Value;
	$geoIdentifier = $overrideParams.geoIdentifier;
	$scaleUnit = $overrideParams.scaleUnit;
	$keyVaultUrl = "https://"+ $keyVaultPrefix+$geoIdentifier+$scaleUnit+".vault.azure.net:443/secrets/";

	if ($keyvaultEnabled -eq "False")
	{
		Add-Member -NotePropertyName "__NorSync_ConnectionString__" -NotePropertyValue ($keyVaultUrl+$compositeParameters.Parameters.sqlDatabaseSecretName.Value) –Force -inputObject $parametersBase.secrets.Replacements
		Add-Member -NotePropertyName "__Storage_ConnectionString__" -NotePropertyValue ($keyVaultUrl+$compositeParameters.Parameters.storageAccountSecretName.Value) –Force -inputObject $parametersBase.secrets.Replacements
		Add-Member -NotePropertyName "__DiagnosticStorage_ConnectionString__" -NotePropertyValue ($keyVaultUrl+$compositeParameters.Parameters.diagnosticsStorageSecretName.Value) –Force -inputObject $parametersBase.secrets.Replacements
		Add-Member -NotePropertyName "__Queue_ConnectionString__" -NotePropertyValue ($keyVaultUrl+$compositeParameters.Parameters.dataSyncServiceBusQueueSecretNameWithXml.Value) –Force -inputObject $parametersBase.secrets.Replacements
		Add-Member -NotePropertyName "__Sync_Queue_ConnectionStrings__" -NotePropertyValue ($keyVaultUrl+$compositeParameters.Parameters.dataSyncServiceBusQueueSecretNameWithXml.Value) –Force -inputObject $parametersBase.secrets.Replacements
		Add-Member -NotePropertyName "__Org_Database_ConnectionStrings__" -NotePropertyValue ($keyVaultUrl+$compositeParameters.Parameters.sqlDatabaseSecretName.Value) –Force -inputObject $parametersBase.secrets.Replacements
	}

	$parametersBase.secrets.Replacements.__SitewideApiAppKey__ = $overrideParams.SitewideApiAppKey;
	if($overrideParams.AuthBasicUserPassword)
	{
		$parametersBase.secrets.Replacements.__OrganizationAuthSecret__ = $overrideParams.AuthBasicUserPassword;
	}
}

function UpdateProvisioningKeyVaults
(
	[Parameter(Mandatory=$true)] $overrideParams,
	[Parameter(Mandatory=$true)] $compositeParametersFile,
	[Parameter(Mandatory=$true)] $parametersBase,
	[Parameter(Mandatory=$true)] $keyvaultEnabled
)
{
	# Update the keyvault urls in the provision params file
	$compositeParameters = Get-Content -Raw -Path $compositeParametersFile | ConvertFrom-Json;

	$keyVaultPrefix = $compositeParameters.Parameters.KeyvaultPrefix.Value;
	$geoIdentifier = $overrideParams.geoIdentifier;
	$scaleUnit = $overrideParams.scaleUnit;
	$keyVaultUrl = "https://"+ $keyVaultPrefix+$geoIdentifier+$scaleUnit+".vault.azure.net:443/secrets/";

	if ($keyvaultEnabled -eq "False")
	{
		Add-Member -NotePropertyName "__DiagnosticStorage_ConnectionString__" -NotePropertyValue ($keyVaultUrl+$compositeParameters.Parameters.diagnosticsStorageSecretName.Value) –Force -inputObject $parametersBase.secrets.Replacements
		Add-Member -NotePropertyName "__Queue_ConnectionString__" -NotePropertyValue ($keyVaultUrl+$compositeParameters.Parameters.provisioningServiceBusQueueSecretNameWithXml.Value) –Force -inputObject $parametersBase.secrets.Replacements
		Add-Member -NotePropertyName "__Sync_Queue_ConnectionStrings__" -NotePropertyValue ($keyVaultUrl+$compositeParameters.Parameters.dataSyncServiceBusQueueSecretNameWithXml.Value) –Force -inputObject $parametersBase.secrets.Replacements
		Add-Member -NotePropertyName "__Org_Database_ConnectionStrings__" -NotePropertyValue ($keyVaultUrl+$compositeParameters.Parameters.sqlDatabaseSecretName.Value) –Force -inputObject $parametersBase.secrets.Replacements
	}
	$parametersBase.secrets.Replacements.__SitewideApiAppKey__ = $overrideParams.SitewideApiAppKey;
	if($overrideParams.AuthBasicUserPassword)
	{
		$parametersBase.secrets.Replacements.__OrganizationAuthSecret__ = $overrideParams.AuthBasicUserPassword;
	}
}

function global:GenerateRolloutParams
(
	[Parameter(Mandatory=$true)] $overridenRolloutParamFilePath,
	[Parameter(Mandatory=$true)] $monitoringConfigFilePath,
	[Parameter(Mandatory=$true)] $rolloutParametersBase
)
{
	[xml]$configXml = Get-Content $MonitoringConfigFilePath
	
	if (!$configXml)
	{
		Write-Error "Failed to load Monitoring XML config"
		return $null
	}
	if ($configXml.Settings["AnalyticsMdmAccountName"])
	{
		$rolloutParametersBase.MdmHealthCheckParameters.MonitoringAccountName = $configXml.Settings["AnalyticsMdmAccountName"].InnerText.Trim()
	}
	if ($configXml.Settings["AnalyticsMdmEndpointURL"])
	{
		$mdmsettingEnpointUrl = $configXml.Settings["AnalyticsMdmEndpointURL"].InnerText.TrimEnd("/"," ")
		$MdmHealthCheckEndPointSuffix = $($rolloutParametersBase.MdmHealthCheckParameters.MdmHealthCheckEndPoint -split ":", 3)[2]
		$rolloutParametersBase.MdmHealthCheckParameters.MdmHealthCheckEndPoint = $mdmsettingEnpointUrl + ":" + $MdmHealthCheckEndPointSuffix
	}

	# Create deployment specific params file
	Write-Host "creating deployment specific rollout params file - $overridenRolloutParamFilePath"
	$rolloutParametersBase | ConvertTo-Json -depth 64 | Set-Content -path $overridenRolloutParamFilePath
}