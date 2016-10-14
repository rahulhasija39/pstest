# This script is used to generate provisioning xml
param(
  [Parameter(Mandatory=$true)]
  [string]$queueName,
  [Parameter(Mandatory=$true)]
  [string]$queueConnectionString,
  [Parameter(Mandatory=$true)]
  [string]$orgId,
  [Parameter(Mandatory=$true)]
  [string]$orgName,
  [Parameter(Mandatory=$true)]
  [string]$mobileOfflineUtilityPath,
  [Parameter(Mandatory=$true)]
  [string]$orgConnectionString,
  [Parameter(Mandatory=$true)]
  [string]$keyVaultClientId,
  [Parameter(Mandatory=$true)]
  [string]$certThumbPrint
)

Set-Location -Path $PSScriptRoot
$currentDirectoryForCreateProvisioningXmlScript = $PSScriptRoot
$parentDirectory = (Get-Item $currentDirectoryForCreateProvisioningXmlScript).parent.parent.FullName

# Create a log object.
$today = Get-Date
$logFileName = "CreateProvisioningXml" + "_" + $today.Day + "_" + $today.Month + ".log"
$logPath = "$parentDirectory\Logs\$logFileName"
$logObject = StartLog($logPath)

try
{
	# Retrieve sample provisioning xml
	$logObject.WriteInformation("Retrieving sample Provisioning config xml")
	$sampleProvisioningConfigXmlPath = ($mobileOfflineUtilityPath + '\SampleSendProvisioningConfig.xml')
	[xml]$XMLDocument = Get-Content -Path $sampleProvisioningConfigXmlPath

	# set queue and keyvault information
	$logObject.WriteInformation("Updating config parameters in provisioning config xml")
	$XMLDocument.MobileOfflineUtilityConfig.ServiceBus.queueName = $queueName
	$XMLDocument.MobileOfflineUtilityConfig.ServiceBus.queueConnectionString = $queueConnectionString
	$XMLDocument.MobileOfflineUtilityConfig.ServiceBus.useKeyVault = 'true'
	$XMLDocument.MobileOfflineUtilityConfig.ServiceBus.keyvaultClientId = $keyVaultClientId
	$XMLDocument.MobileOfflineUtilityConfig.ServiceBus.keyVaultCertThumbprint = $certThumbPrint

	# Remove all the extra organization nodes
	$logObject.WriteInformation("Removing all the extra organization nodes from provisioning config xml")
	$organizationList = $XMLDocument.MobileOfflineUtilityConfig.Organizations.Organization
	$XMLDocument.MobileOfflineUtilityConfig.Organizations.RemoveAll()
	$XMLDocument.SelectSingleNode("//Organizations").AppendChild($organizationList[0])

	# Set organization information
	$logObject.WriteInformation("Updating organization information in provisioning config xml")
	$XMLDocument.MobileOfflineUtilityConfig.Organizations.Organization.id  = $orgId
	$XMLDocument.MobileOfflineUtilityConfig.Organizations.Organization.name  = $orgName
	$XMLDocument.MobileOfflineUtilityConfig.Organizations.Organization.connectionString  = $orgConnectionString
	$XMLDocument.Save($mobileOfflineUtilityPath + '\MobileOfflineProvisioningConfiguration.xml');
}
catch
{
	$LASTEXITCODE = 1
	$logObject.WriteError("Exception: Message " + $_.Exception.Message)
}

if($LASTEXITCODE -eq 0)
{
	$logObject.WriteInformation('Execution of script CreateProvisioningXml completed successfully')
}
else
{
	$logObject.WriteInformation('Execution of script CreateProvisioningXml FAILED')
}
exit $LASTEXITCODE
