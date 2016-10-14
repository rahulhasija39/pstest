param 
(
	$path = "ServiceGroupRoot\\DeploymentDefinitions.json",
	[parameter(Mandatory=$false)][string] $BuildVersion = $null,
	[Parameter(Mandatory=$false)]
	[string]$DeploymentDefinitionName = "All",
	[Parameter(Mandatory=$false)]
	[string]$username = "devadmin"
)


. .\Lib\Config.ps1
. .\Lib\GenerateAcisConfig.ps1
. .\Lib\Shared.ps1
. .\Lib\ValidateAndPatchCscfg.ps1
. .\Lib\ValidateAndPatchParams.ps1

if ($BuildVersion)
{
	Set-Content .\ServiceGroupRoot\BuildVer.txt $BuildVersion
}

$ErrorActionPreference = "Stop"

$global:GUIDParamList = @("CrmDatacenterId", "KeyVaultClientId", "SitewideApi.ClientId", "AzureManagement.OAuth.ClientId", "DataCenterId", "MobileOfflineAzureAppId", "DnsZoneSubscriptionId", "AzureDnsResourceId", "CPSAppId" )

# Generate a random Alphanumeric with the passed in length
# Usage: random-Alphanumeric <length>
Function global:Generate-Random-Alphanumeric 
{
Param
(
	[parameter(Mandatory=$true)]$length
)
	$alphanumeric = 'abcdefghijklmnopqrstuvwxyz0123456789'.ToCharArray()
	return [String]::Join('', (1..$length | % { $alphanumeric | Get-Random }))
}

# A function to return a deepy copy of given object
Function Object-Deep-Copy
{
Param
(
	[parameter(Mandatory=$true)]$InputObject
)
	$ms = New-Object System.IO.MemoryStream
	$bf = New-Object System.Runtime.Serialization.Formatters.Binary.BinaryFormatter
	$bf.Serialize($ms, $InputObject)
	$ms.Position = 0
	$OutputObject = $bf.Deserialize($ms)
	$ms.Close()

	return $OutputObject
}

# A recursive function to merge two hash tables
Function mergeDeploymentData
{
Param
(
	[parameter(Mandatory=$true)]$CommonDataCenter,
	[parameter(Mandatory=$true)]$deployment
)
	# Clone a copy of CommonDatacenter
	$OverridenData = Object-Deep-Copy $CommonDataCenter
	$overrideNames = $deployment | Get-Member -MemberType Properties | ForEach-Object {$_.Name }
	foreach ($commonOverride in $overrideNames)
	{
		if($deployment.$commonOverride.GetType().Name -ieq "PSCustomObject")
		{
			if(-not $OverridenData.$commonOverride) 
			{
				Add-Member -NotePropertyName $commonOverride -NotePropertyValue $(Object-Deep-Copy $deployment.$commonOverride) –Force -inputObject $OverridenData
			}
			else
			{
				Add-Member -NotePropertyName $commonOverride -NotePropertyValue $(mergeDeploymentData $OverridenData.$commonOverride $deployment.$commonOverride) -Force -inputObject $OverridenData
			}
		}
		else{
			Add-Member -NotePropertyName $commonOverride -NotePropertyValue $deployment.$commonOverride –Force -inputObject $OverridenData
		}
	}
	return $OverridenData
}

# Deployments file contains the list of Deployments with configuration overrides
# for each deployment.  Each deployment specifies the Base RolloutSpec, ServiceModel
# Parameters and Configuration files.  The base files are then customized
# for each deployment.
$DeploymentsFile = (Get-Content -Raw -Path $path) | ConvertFrom-Json
$fullPath = Resolve-Path $path

# Folder where the customized files will be written to.
$targetFolder = Split-Path -Path $fullPath -Parent
$global:CurrentDirectory = $targetFolder
# Copy Datsync and Provisioning cscfgs from Packages to ParametersBase folder
if (Test-Path "..\\src\ProvisioningFramework\ProvisioningCloudService\ServiceConfiguration.Cloud.cscfg")
{
	if (-not $(Test-Path "ServiceGroupRoot\Configurations\\backup.Provisioning.ServiceConfiguration.cscfg"))
	{
		Copy-Item "ServiceGroupRoot\Configurations\\Provisioning.ServiceConfiguration.cscfg" "ServiceGroupRoot\Configurations\\backup.Provisioning.ServiceConfiguration.cscfg"
	}
	Copy-Item "..\\src\ProvisioningFramework\ProvisioningCloudService\ServiceConfiguration.Cloud.cscfg" "ServiceGroupRoot\Configurations\\Provisioning.ServiceConfiguration.cscfg"
}

if (Test-Path "..\\src\\SyncFramework\\SyncCloudService\\SyncCloudService\\ServiceConfiguration.Cloud.cscfg"){
	if(-not $(Test-Path "ServiceGroupRoot\Configurations\\backup.DataSync.ServiceConfiguration.cscfg"))
	{
		Copy-Item "ServiceGroupRoot\Configurations\\DataSync.ServiceConfiguration.cscfg" "ServiceGroupRoot\Configurations\\backup.DataSync.ServiceConfiguration.cscfg"
	}
	Copy-Item "..\\src\\SyncFramework\\SyncCloudService\\SyncCloudService\\ServiceConfiguration.Cloud.cscfg" "ServiceGroupRoot\Configurations\\DataSync.ServiceConfiguration.cscfg"
}
# Set CWD to targetFolder
Push-Location -Path $targetFolder

# Deployments file is organized into sections. Each section
# results in a configuration for a deployment.
$datacenterNames = $DeploymentsFile | Get-Member -MemberType NoteProperty | ForEach-Object {if($_.Name -ne "__COMMON__datacenter") {$_.Name }}

# Deployment specific maps
$deploymentTypes = @("Production", "Trial", "Dedicated")
$deploymentTypePrefixMap = @{"Production" = "p"; "Trial" = "t"; "Dedicated" = "d"}
$provisioningTypeMap = @{"Production" = "Shared"; "Trial" = "Shared"; "Dedicated" = "Dedicated"}
$deploymentTypeMap = @{"Production" = "Production"; "Trial" = "Trial"; "Dedicated" = "Production"}


# Types of RolloutSpecs
$rolloutSpecTypes = @(
	"RolloutSpecDeploy", 
	"RolloutSpecServiceUpdate", 
	"RolloutSpecServiceConfigUpdate")

# Get Certificate Data which is common to all Deployments
$CommonDataCenter = $DeploymentsFile.__COMMON__datacenter
# Process each deployment listed in the Deployments file.
foreach ($datacenterName in $datacenterNames)
{
	# Do we need just one data center's deployment definitions or all
	if(![string]::Equals($DeploymentDefinitionName,"All") -and ![string]::Equals($DeploymentDefinitionName,$datacenterName))
	{ continue}
 
	$deployment = $DeploymentsFile.$datacenterName

	if($datacenterName -match "DIFD*")
	{
		$deployment | Add-Member -NotePropertyName Geo -NotePropertyValue $username.Substring(0,5) -Force
	}
	
	$geoIdentifier = $deployment.Geo.ToLower() + $datacenterName.ToLower()
	$deployment = mergeDeploymentData $CommonDataCenter $deployment 

	# Datacenter specific overrides
	$deployment | Add-Member -NotePropertyName ResourceGroupPrefix -NotePropertyValue "crmmo" -Force
	$deployment.ParameterOverrides | Add-Member -NotePropertyName geoIdentifier -NotePropertyValue $geoIdentifier -Force
	$deployment.ParameterOverrides | Add-Member -NotePropertyName Location -NotePropertyValue $deployment.Location -Force
	
	#Patch RolloutParamaters with MDM Data per Geo , as they remain across all deployments in a Geo
	CheckFileExists $deployment.DataSyncRolloutParametersBase "Datasync Rollout Parameters file"
	$dataSyncRolloutParametersBasePath = Join-Path -Path $targetFolder -ChildPath $deployment.DataSyncRolloutParametersBase

	CheckFileExists $deployment.MdmAnalyticsConfigFile "MDM Configurations"
	$mdmConfigFilePath = Join-Path -Path $targetFolder -ChildPath $deployment.MdmAnalyticsConfigFile

	# Datasync - Rollout Params
	$rolloutParametersBaseDataSync = Get-Content -Raw -Path $dataSyncRolloutParametersBasePath | ConvertFrom-Json
	$datasyncRolloutParamsOverrideFullPath = Join-Path -Path $targetFolder -ChildPath "Parameters\DataSync.RolloutParameters.$geoIdentifier.json"
	GenerateRolloutParams $datasyncRolloutParamsOverrideFullPath $mdmConfigFilePath $rolloutParametersBaseDataSync

	# provisioning - Rollout Params
	CheckFileExists $deployment.ProvisioningRolloutParametersBase "Provisioning Rollout Parameters Base"
	$provisioningRolloutParametersBasePath = Join-Path -Path $targetFolder -ChildPath $deployment.ProvisioningRolloutParametersBase
	$rolloutParametersBaseProvisioning = Get-Content -Raw -Path $provisioningRolloutParametersBasePath | ConvertFrom-Json
	$provisioningRolloutParamsOverrideFullPath = Join-Path -Path $targetFolder -ChildPath "Parameters\Provisioning.RolloutParameters.$geoIdentifier.json"
	GenerateRolloutParams $provisioningRolloutParamsOverrideFullPath $mdmConfigFilePath $rolloutParametersBaseProvisioning

	Get-Random -SetSeed $deployment.Seed
	foreach ($deploymentType in $deploymentTypes)
	{
		$instanceCount = $deployment.$deploymentType.InstanceCount
			
		# Deployment type specific overrides
		$deployment.ParameterOverrides | Add-Member -NotePropertyName DeploymentType -NotePropertyValue $deploymentTypeMap.$deploymentType -Force
		$deployment.ParameterOverrides | Add-Member -NotePropertyName ProvisioningType -NotePropertyValue $provisioningTypeMap.$deploymentType -Force
		$deployment.ConfigurationOverrides | Add-Member -NotePropertyName DeploymentType -NotePropertyValue $deploymentTypeMap.$deploymentType -Force

		for ($deploymentIndex = 1; $deploymentIndex -le $instanceCount; $deploymentIndex ++)
		{
			$suffixLength = 10 - $geoIdentifier.Length 
			$randomSuffix = ""

			if($suffixLength -gt 0 -and $datacenterName -notmatch "DIFD*")
			{
				$randomSuffix = Generate-Random-Alphanumeric($suffixLength)
			}

			$scaleUnit = $deploymentTypePrefixMap.$deploymentType + $deploymentIndex + $randomSuffix
			$deploymentName = $geoIdentifier + $scaleUnit 

			$rolloutName = 
				$deployment.ConfigurationOverrides.EnvironmentType.ToLower() + "_"  + 
				$deployment.Geo.ToLower() + "_" + 
				$datacenterName.ToLower() + "_" + 
				$deploymentType.ToLower() + "_" +
				$deploymentIndex + "_" +
				$randomSuffix
			
			# Apply per deployment overrides
			$deployment.ParameterOverrides | Add-Member -NotePropertyName scaleUnit -NotePropertyValue $scaleUnit -Force
			
			Write-Host "Generating files for datacenter: $deploymentName"

			# Get the location of the base ServiceModel, Configuration and Parameters files.
			CheckFileExists $deployment.ServiceModelBase "Service Model Base"
			$serviceModelBasePath = Join-Path -Path $targetFolder -ChildPath $deployment.ServiceModelBase
			
			CheckFileExists $deployment.DataSyncConfigurationBase "Datasync Config Base"
			$dataSyncConfigBasePath = Join-Path -Path $targetFolder -ChildPath $deployment.DataSyncConfigurationBase 
			
			CheckFileExists $deployment.ProvisioningConfigurationBase "Provisioning Config Base"
			$provisioningConfigBasePath = Join-Path -Path $targetFolder -ChildPath $deployment.ProvisioningConfigurationBase 
			
			CheckFileExists $deployment.DataSyncParametersBase "Datasync Parameters Base"
			$dataSyncParametersBasePath = Join-Path -Path $targetFolder -ChildPath $deployment.DataSyncParametersBase

			CheckFileExists $deployment.DataSyncParametersBase "Provisioning Parameters Base"
			$provisioningParametersBasePath = Join-Path -Path $targetFolder -ChildPath $deployment.ProvisioningParametersBase
			
			CheckFileExists $deployment.CompositeParametersBase "Composite Parameters Base"
			$compositeParametersBasePath = Join-Path -Path $targetFolder -ChildPath $deployment.CompositeParametersBase

			CheckFileExists $deployment.DnsZoneParametersBase "DnsZone Parameters Base"
			$dnsZoneParametersBasePath = Join-Path -Path $targetFolder -ChildPath $deployment.DnsZoneParametersBase

			CheckFileExists $deployment.VNetParametersBase "VNet Parameters Base"
			$vNetParametersBasePath = Join-Path -Path $targetFolder -ChildPath $deployment.VNetParametersBase
			
			
			# Load the base files
			$serviceModelBase = Get-Content -Raw -Path $serviceModelBasePath | ConvertFrom-Json
			[xml]$dataSyncConfigBase = Get-Content -Path $dataSyncConfigBasePath
			[xml]$provisioningConfigBase = Get-Content -Path $provisioningConfigBasePath

			# Get the folder where the customized RolloutSpec, ServiceModel, Configuration and Parameters files
			# for this deployment will be placed.  The customized files will be placed in the same folder where
			# the corresponding base file is located.
			$serviceModelFolder = Split-Path -Path $serviceModelBasePath -Parent
			$dataSyncConfigFolder = Split-Path -Path $dataSyncConfigBasePath -Parent
			$provisioningConfigFolder = Split-Path -Path $provisioningConfigBasePath -Parent
			$parametersFolder = Split-Path -Path $dataSyncParametersBasePath -Parent

			# Construct the relative path names for the customized RolloutSpec, ServiceModel, Configuration
			# and Parameters files for this deployment.
			$serviceModelPath = "ServiceModel.$deploymentName.json"
			$dataSyncConfigPath = "Configurations\DataSync.ServiceConfiguration.$deploymentName.cscfg"
			$provisioningConfigPath = "Configurations\Provisioning.ServiceConfiguration.$deploymentName.cscfg"
			$paramsPath = "Parameters\Parameters.$deploymentName.json"

			foreach ($rolloutSpecType in $rolloutSpecTypes)
			{
				# Customize the RolloutSpec for this deployment by pointing it to the
				# ServiceModel for this deployment and updating the orchestrated steps
				$rolloutSpecBasePath = Join-Path -Path $targetFolder -ChildPath "$rolloutSpecType.json"
				CheckFileExists $rolloutSpecBasePath "Rollout Spec Base"
				$rolloutSpecBase = Get-Content -Raw -Path $rolloutSpecBasePath | ConvertFrom-Json
				$rolloutSpecPath = "$rolloutSpecType.$rolloutName.json"

				$rolloutSpecBase.RolloutMetadata.ServiceModelPath = $serviceModelPath
				foreach ($orchestratedStep in $rolloutSpecBase.OrchestratedSteps)
				{
					$orchestratedStep.TargetName += "." + $deploymentName
				}

				# Remove the orchestrated steps based on the configuration
				if($deployment.DeployDatasyncService -eq "False")
				{
					$newRolloutSpecBaseOrchestratedSteps = $rolloutSpecBase.OrchestratedSteps | Where-Object {$_.Name -ne "Rollout_DataSync" }
					$rolloutSpecBase.OrchestratedSteps = @($newRolloutSpecBaseOrchestratedSteps)
				}

				if($deployment.DeployProvisioningService -eq "False")
				{
					$deleteOrchestratedStep = ""
					switch($rolloutSpecType)
					{
						"RolloutSpecDeploy" {$deleteOrchestratedStep =  "Rollout_Provisioning" }
						"RolloutSpecServiceUpdate" {$deleteOrchestratedStep =  "Rollout_ProvisioningUpdate" }
						"RolloutSpecServiceConfigUpdate" {$deleteOrchestratedStep =  "Rollout_ProvisioningUpdateConfigOnly" }
					}
                   
					$newRolloutSpecBaseOrchestratedSteps = $rolloutSpecBase.OrchestratedSteps | Where-Object {$_.Name -ne $deleteOrchestratedStep }
					$rolloutSpecBase.OrchestratedSteps = @($newRolloutSpecBaseOrchestratedSteps)
				}

				if($deployment.DeployVNet -eq "False" -and $rolloutSpecType -eq "RolloutSpecDeploy")
				{
					# Remove VNET step
					$newRolloutSpecBaseOrchestratedSteps = $rolloutSpecBase.OrchestratedSteps | Where-Object {$_.Name -ne "Rollout_VNet" }

					# Remove VNET dependency from Composite step
					$compositestep = $newRolloutSpecBaseOrchestratedSteps | Where-Object {$_.Name -eq "Rollout_Composite"}
					$newcompositeStep = $compositestep | Select-Object -Property * -ExcludeProperty 'DependsOn'
					$newRolloutSpecBaseOrchestratedSteps[0] = $newcompositeStep
					$rolloutSpecBase.OrchestratedSteps = @($newRolloutSpecBaseOrchestratedSteps)
					
				}

				# Construct full path for the RolloutSpec and write it out	
				$rolloutSpecFullPath = Join-Path -Path $targetFolder -ChildPath $rolloutSpecPath
				Write-Host "Writing Customized RolloutSpec: $rolloutSpecFullPath"
				$rolloutSpecBase | ConvertTo-Json -depth 64 | Set-Content -path $rolloutSpecFullPath
			}

			# Customize the ServiceModel for this deployment by setting the appropriate
			# values in the ServiceResourceGroup  entry.  Point the ServiceResource
			# to the customized parameters file for this deployment.
			$serviceResourceGroup = $serviceModelBase.ServiceResourceGroups[0]
			$serviceResourceGroup.AzureResourceGroupName = $deployment.ResourceGroupPrefix + $deploymentName

			ValidateGuid "AzureSubscriptionId" $deployment.AzureSubscriptionId 
			$serviceResourceGroup.AzureSubscriptionId = $deployment.AzureSubscriptionId

			ThrowErrorIfNull $deployment.Location "Deployment Location"
			$serviceResourceGroup.Location = $deployment.Location

			foreach ($serviceResource in $serviceResourceGroup.ServiceResources)
			{
				$serviceResource.Name += "." + $deploymentName
				$serviceResource.ArmParametersPath = $serviceResource.ArmParametersPath.Replace("json", "$deploymentName.json")
			}

			# Customize the setting for the Vnet ServiceResourceGroup
			$serviceResourceGroupVNet = $serviceModelBase.ServiceResourceGroups[1]
			$serviceResourceGroupVNet.AzureSubscriptionId = $deployment.AzureSubscriptionId
			$serviceResourceGroupVNet.Location = $deployment.VNetResourceGroupLocation

			foreach ($serviceResource in $serviceResourceGroupVNet.ServiceResources)
			{
				ThrowErrorIfNull $serviceResource.Name "Service Resource Name"
				$serviceResource.Name += "." + $deploymentName
				$serviceResource.ArmParametersPath = $serviceResource.ArmParametersPath.Replace("json", "$deploymentName.json")
				if ($serviceResource.RolloutParametersPath)
				{
					$serviceResource.RolloutParametersPath = $serviceResource.RolloutParametersPath.Replace("json", "$deploymentName.json")
				}
			}

			# Customize the Parameters for this deployment by replacing the overridden
			# parameters values specified in "ParameterOverrides"

			$KeyVaultEnabledInBuild = "True"
			if ($deployment.KeyVaultEnabled -and $deployment.KeyVaultEnabled -eq "False")
			{
				$KeyVaultEnabledInBuild = "False"
			}

			# Datasync
			$parametersBaseDataSync = Get-Content -Raw -Path $dataSyncParametersBasePath | ConvertFrom-Json
			$datasyncParamsOverrideFullPath = Join-Path -Path $targetFolder -ChildPath "Parameters\Datasync.Parameters.$deploymentName.json"
			# Customize the Parameters for this deployment by pointing the serviceConfigurationLink.value
			# property to the customized configuration file for this deployment
			$parametersBaseDataSync.parameters.serviceConfigurationLink.value = $dataSyncConfigPath
			GenerateParams $datasyncParamsOverrideFullPath $deployment.ParameterOverrides $parametersBaseDataSync -keyvaultEnabled $KeyVaultEnabledInBuild $compositeParametersBasePath

			# provisioning
			$parametersBaseProvisioning = Get-Content -Raw -Path $provisioningParametersBasePath | ConvertFrom-Json
			$provisioningParamsOverrideFullPath = Join-Path -Path $targetFolder -ChildPath "Parameters\Provisioning.Parameters.$deploymentName.json"
			# Customize the Parameters for this deployment by pointing the serviceConfigurationLink.value
			# property to the customized configuration file for this deployment
			$parametersBaseProvisioning.parameters.serviceConfigurationLink.value = $provisioningConfigPath
			GenerateParams $provisioningParamsOverrideFullPath $deployment.ParameterOverrides $parametersBaseProvisioning -keyvaultEnabled $KeyVaultEnabledInBuild $compositeParametersBasePath

			# AzureDNSZone
			$parametersBaseDnsZone = Get-Content -Raw -Path $dnsZoneParametersBasePath | ConvertFrom-Json
			$dnsZoneParamsOverrideFullPath = Join-Path -Path $targetFolder -ChildPath "Parameters\DnsZone.Parameters.$deploymentName.json"
			GenerateParams $dnsZoneParamsOverrideFullPath $deployment.ParameterOverrides $parametersBaseDnsZone -keyvaultEnabled $KeyVaultEnabledInBuild

			# Composite
			$parametersBaseComposite = Get-Content -Raw -Path $compositeParametersBasePath | ConvertFrom-Json
			$compositeParamsOverrideFullPath = Join-Path -Path $targetFolder -ChildPath "Parameters\Composite.Parameters.$deploymentName.json"
			GenerateParams $compositeParamsOverrideFullPath $deployment.ParameterOverrides $parametersBaseComposite -keyvaultEnabled $KeyVaultEnabledInBuild

			# VNet
			$parametersBaseVNet = Get-Content -Raw -Path $vNetParametersBasePath | ConvertFrom-Json
			$vNetParamsOverrideFullPath = Join-Path -Path $targetFolder -ChildPath "Parameters\VNet.Parameters.$deploymentName.json"
			GenerateParams $vNetParamsOverrideFullPath $deployment.ParameterOverrides $parametersBaseVNet -keyvaultEnabled $KeyVaultEnabledInBuild

			# Customize the Configuration for this deployment by replacing the overridden
			# configuration values specified in "ConfigurationOverrides"
			$dataSyncConfigFullPath = Join-Path -Path $targetFolder -ChildPath $dataSyncConfigPath
			$provisioningConfigFullPath = Join-Path -Path $targetFolder -ChildPath $provisioningConfigPath

			Add-Member -NotePropertyName "AppDynamics-Application" -NotePropertyValue $($parametersBaseDataSync.parameters.serviceDomainNamePrefix.value + $deploymentName) –Force -inputObject $deployment.ConfigurationOverrides	
			GenerateCscfg $dataSyncConfigFullPath $deployment $deployment.DataSyncConfigurationBase $parametersBaseComposite "DataSync" $mdmConfigFilePath $vNetParamsOverrideFullPath -BuildVersion $BuildVersion

			Add-Member -NotePropertyName "AppDynamics-Application" -NotePropertyValue $($parametersBaseProvisioning.parameters.serviceDomainNamePrefix.value + $deploymentName) –Force -inputObject $deployment.ConfigurationOverrides
			GenerateCscfg $provisioningConfigFullPath $deployment $deployment.ProvisioningConfigurationBase  $parametersBaseComposite "Provisioning" $mdmConfigFilePath -BuildVersion $BuildVersion

			#AcisConfig
			$acisConfigFullPath = Join-Path -Path $targetFolder -ChildPath "Acis\\AcisConfig.$rolloutName.json"
			GenerateAcisConfig $acisConfigFullPath $deployment $compositeParamsOverrideFullPath $provisioningParamsOverrideFullPath $datasyncParamsOverrideFullPath $vNetParamsOverrideFullPath $deployment.AzureSubscriptionId

			# Construct the full path names for the customized RolloutSpec, ServiceModel, Configuration
			# and Parameters files for this deployment.  The files will be placed under the folder where
			# DeploymentDefintions.json is located.
			$serviceModelFullPath = Join-Path -Path $targetFolder -ChildPath $serviceModelPath

			# Write the customized files to the appropriate locations
			Write-Host "Writing Customized ServiceModel: $serviceModelFullPath"
			$serviceModelBase | ConvertTo-Json -depth 64 | Set-Content -path $serviceModelFullPath
		}
	}
}

Pop-Location

