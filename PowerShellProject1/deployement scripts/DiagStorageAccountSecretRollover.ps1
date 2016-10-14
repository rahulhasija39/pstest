# This script needs to be run after the secret rollover to correct the reference of the secret key

#Example: .\PostSecretRollover.ps1 –SubscriptionId "fd799b57-566b-4300-b5fd-5116f9ce29f8" -SubscriptionName "CRM-DevTest-MoCA Offline Dev" -SubscriptionCertFilePath ".\Certificates\ManagementCertificate.cer" -ServiceName "datasynceapshghosal" -DeploymentSlot "Production" -diagStorageAccountName "crmmodiageapshghosal" -DiagnoticsConfigFileNames "D:\Deployment_ALL\Deployment\Packages\DataSync\Extensions\PaaSDiagnostics.Microsoft.Xrm.Sync.NorSyncWebRole.PubConfig.xml,D:\Deployment_ALL\Deployment\Packages\DataSync\Extensions\PaaSDiagnostics.Microsoft.Xrm.Sync.WebRole.PubConfig.xml" -RoleNames "Microsoft.Xrm.Sync.NorSyncWebRole,Microsoft.Xrm.Sync.WebRole" -ActiveSceretVerison "Secondary"
#For $DiagnoticsConfigFileNames, the entire file path has to be given along with the file extension(.xml)
#For $RoleNames, all the roles pertaining to the concerned cloud service have to be provided and in the same order as the corresponding $DiagnoticsConfigFileNames
#e.g. if the role names are in the order of "Microsoft.Xrm.Sync.NorSyncWebRole,Microsoft.Xrm.Sync.WebRole" (NorSyncWebRole , WebRole)
#then the $DiagnosticFileNames should be in the order "D:\Deployment_ALL\Deployment\Packages\DataSync\Extensions\PaaSDiagnostics.Microsoft.Xrm.Sync.NorSyncWebRole.PubConfig.xml,D:\Deployment_ALL\Deployment\Packages\DataSync\Extensions\PaaSDiagnostics.Microsoft.Xrm.Sync.WebRole.PubConfig.xml" (NorSyncWebRole , WebRole)

param
(
    [parameter(Mandatory=$true)][string] $SubscriptionId = $null,
	[parameter(Mandatory=$true)][string] $SubscriptionName = $null,
	[parameter(Mandatory=$true)][string] $SubscriptionCertFilePath = $null,
    [parameter(Mandatory=$true)][string] $ServiceName = $null,
    [parameter(Mandatory=$true)][string] $DeploymentSlot = $null,
    [parameter(Mandatory=$true)][string] $diagStorageAccountName = $null,
    [parameter(Mandatory=$true)][string] $RoleNames = $null,
    [parameter(Mandatory=$true)][string] $DiagnoticsConfigFileNames = $null,
    [parameter(Mandatory=$true)][string] $ActiveSceretVerison = $null
)
$ErrorActionPreference = "Stop"
# Make sure that it is in AzureServiceManagement mode initially to make Service cmdlets workable
Switch-AzureMode AzureServiceManagement
if(-not (Get-Module Azure))
{
	Write-Error "This script needs to be run in Azure PowerShell"
}

. .\Lib\ApplyDiagnosticConfigs.ps1
. .\Lib\ManageCertificates.ps1
. .\Lib\StorageAccount.ps1
. .\Lib\Config.ps1

#Step-1: Get Management Certificate
$CurrentDirectory = Convert-Path .
$SubscriptionCertFilePath = GetFilePath $SubscriptionCertFilePath $CurrentDirectory

#Step-2: Set Azure subscription
Set-AzureSubscription -SubscriptionId $SubscriptionId -SubscriptionName $SubscriptionName -Certificate (GetCertificate $SubscriptionCertFilePath)
Select-AzureSubscription -Current -SubscriptionId $SubscriptionId

#Step-3: Retrieve individual parameter
$Roles = $RoleNames -split ","
$DiagnoticsConfigFiles = $DiagnoticsConfigFileNames -split ","
$noOfRoles = $Roles.Length
for ($i=0; $i -lt $noOfRoles; $i++)
{
    # Enable diagnostics configs - this enables Diagnsotics on the service and allocates specified storage account for the logs
	if ($diagStorageAccountName)
	{
		$DiagnoticsConfigOverrideFileName = ApplyDiagnsoticsConfigOverrides $DiagnoticsConfigFiles[$i] $diagStorageAccountName
		ApplyDiagnosticsToCloudService $ServiceName $DeploymentSlot $diagStorageAccountName $DiagnoticsConfigOverrideFileName $Roles[$i] $ActiveSceretVerison
	}
}