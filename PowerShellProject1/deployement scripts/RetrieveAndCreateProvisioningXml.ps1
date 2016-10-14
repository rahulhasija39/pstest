param(
  [Parameter(Mandatory=$true)]
  [string]$ServiceGroupRoot,
  [Parameter(Mandatory=$true)]
  [string]$DeploymentDefinitionName,
  [Parameter(Mandatory=$true)]
  [string]$username,
  [Parameter(Mandatory=$true)]
  [string]$OrganizationBaseUrl,
  [Parameter(Mandatory=$true)]
  [string]$OrgId,
  [Parameter(Mandatory=$true)]
  [string]$KeyVaultCertificateName,
  [Parameter(Mandatory=$true)]
  [string]$mobileOfflineUtilityPath
)

Set-Location -Path $PSScriptRoot
$currentDirectoryForConfigFileGenerationScript = $PSScriptRoot
$parentDirectory = (Get-Item $currentDirectoryForConfigFileGenerationScript).parent.parent.FullName

# Create a log object.
$today = Get-Date
$logFileName = "RetrieveAndCreateProvisioningXml" + "_" + $today.Day + "_" + $today.Month + ".log"
$logPath = "$parentDirectory\Logs\$logFileName"
$logObject = StartLog($logPath)


$logObject.WriteInformation("Retrieving Configuration Parameters for Org Provisioning")

try
{
	# Retrieve org name from org url
	$logObject.WriteInformation("Organization base url : $OrganizationBaseUrl")
	$pos = $OrganizationBaseUrl.LastIndexOf("/")
	$orgName = $OrganizationBaseUrl.Substring($pos+1)
	$logObject.WriteInformation("Organization Name : $orgName")
	$endIndex = $OrganizationBaseUrl.LastIndexOf(":")
	$orgConnectionString = $OrganizationBaseUrl.Substring(0, $endIndex) + ".mobileoffline" + $OrganizationBaseUrl.Substring($endIndex) 
	$logObject.WriteInformation("Organization ConnectionString : $orgConnectionString")
			
	# Retrieve queue, org, key vault settings from config file
	$configurationsFolder = Join-Path $ServiceGroupRoot "Configurations"
	cd $configurationsFolder 
	$deploymentIdentifier = $username.ToLower().Substring(0,5) + $DeploymentDefinitionName.ToLower()
	$logObject.WriteInformation("Deployment DefinitionName : $DeploymentDefinitionName")
	if($DeploymentDefinitionName -eq 'DIFD')
	{
		$configFileName = "DataSync.ServiceConfiguration.$deploymentIdentifier*.cscfg"
	}
	elseif($DeploymentDefinitionName -eq 'DIFDP')
	{
		$configFileName = "Provisioning.ServiceConfiguration.$deploymentIdentifier*.cscfg"
	}
	$config = (Get-Content  .\$configFileName) -as [Xml]
	$roleElement = $config.ServiceConfiguration.Role | ? { $_.name -eq "Microsoft.Xrm.Sync.WebRole" }
	$settingElement = $roleElement.ConfigurationSettings.Setting | ? { $_.name -eq "QueueConfigurations" }
	$queueXml = $settingElement.value -as [Xml]
	$queueName = $queueXml.Queues.Queue.name
	$logObject.WriteInformation("QueueName : $queueName")
	$queueConnectionString = $queueXml.Queues.Queue.connectionstring
	$logObject.WriteInformation("Queue Connection String : $queueConnectionString")
	$keyVaultClientIdSettingElement = $roleElement.ConfigurationSettings.Setting | ? { $_.name -eq "KeyVault.ClientId" }
	$keyVaultClientId = $keyVaultClientIdSettingElement.value
	$logObject.WriteInformation("KeyVault Client Id : $keyVaultClientId")
			
	# Install Keyvault certificate and also retrieve thumbprint
	$clientCertificatePath = $currentDirectoryForDeployScript + "\$KeyVaultCertificateName"
	$logObject.WriteInformation("Retrieving thumbprint for certificate $KeyVaultCertificateName")
	$cert = Import-PfxCertificate –FilePath $clientCertificatePath cert:\localMachine\root -ErrorAction stop
	$certThumbPrint = $cert.Thumbprint
	$logObject.WriteInformation("Client certificate thumbprint : $certThumbPrint")

	# Execute script to create provisioning xml
	$logObject.WriteInformation("Creating provisioning xml")
	cd $mobileOfflineUtilityPath
	.\CreateProvisioningXml.ps1 -queueName $queueName -queueConnectionString $queueConnectionString -orgId $orgId -orgName $orgName -mobileOfflineUtilityPath $mobileOfflineUtilityPath -orgConnectionString $orgConnectionString -keyVaultClientId $keyVaultClientId -certThumbPrint $certThumbPrint
}
catch
{
	$LASTEXITCODE = 1
	$logObject.WriteError("Exception: Message " + $_.Exception.Message)
}

if($LASTEXITCODE -eq 0)
{
	$logObject.WriteInformation('Execution of script RetrieveAndCreateProvisioningXml completed successfully')
}
else
{
	$logObject.WriteInformation('Execution of script RetrieveAndCreateProvisioningXml FAILED')
}
exit $LASTEXITCODE