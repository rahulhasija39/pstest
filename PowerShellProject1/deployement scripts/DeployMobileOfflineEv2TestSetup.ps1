# This method is used to deploy the mobile offline cloud services using EV2
# Copy the ServiceGroupRoot folder if there are some modifications you want to keep
param(
  [Parameter(Mandatory=$true)]
  [string]$ServiceGroupRoot,
  [Parameter(Mandatory=$true)]
  [string]$DeploymentDefinitionName,
  [Parameter(Mandatory=$false)]
  [string]$username = "devadmin",
  [Parameter(Mandatory=$true)]
  [string]$OrganizationBaseUrl,
  [Parameter(Mandatory=$true)]
  [string]$AzureSubscriptionMgmtCertFileFullPath,
  [Parameter(Mandatory=$false)]
  [ValidateSet('Deploy','UpgradeService','UpgradeConfig')]
  [string]$DeploymentType = "Deploy",
  [Parameter(Mandatory=$false)]
  [int]$subnetToUse = 0,
  [Parameter(Mandatory=$false)]
  [string]$KeyVaultCertificateName = 'Moca_AAD_TIE.pfx',
  [Parameter(Mandatory=$false)]
  [boolean]$IsRunningOnCRMServer = $true,
  [Parameter(Mandatory=$false)]
  [string]$CRMServerAdminPassword = $null,
  [Parameter(Mandatory=$false)]
  [string]$ADClientAppForEv2DeploymentID = "d0d85272-4b95-44bd-904a-8fa10230dfdd",
  [Parameter(Mandatory=$true)]
  [string]$ADClientAppForEv2DeploymentKey,
  [Parameter(Mandatory=$false)]
  [boolean]$AreSecretsStoredInKeyVault = $false
)

Set-Location -Path $PSScriptRoot
$currentDirectoryForDeployScript = $PSScriptRoot

. .\Lib\FileLogger.ps1

# Create a log directory if doesnt exists and log object.
New-Item $currentDirectoryForDeployScript\Logs -type directory -Force
$logPath = Join-Path $currentDirectoryForDeployScript "Logs"
$logObject = StartLog("$logPath\DeployMobileOfflineEv2TestSetup.log")
$Ev2DeploymentLogFileName = "$logPath\Ev2DeploymentLog.log"
$mobileOfflineUtilityPath =  "$currentDirectoryForDeployScript\TestSetupAutomationArtifacts\MobileOfflineUtility"

$logObject.WriteInformation("[DeployMobileOfflineEv2TestSetup] Deploying the Azure services using Ev2")

# Generate the log file name
function global:GenerateLogFile
{	
Param
(
	[Parameter(Mandatory=$true)][string] $LogFilePath
)
	$logFileInfo = New-Item $($($(GetFilePath $LogFilePath) + "_" + $(Get-Date).ToString("yyyy_MM_dd_hh_mm_ss")) + ".log") -Type file -Force
	return $logFileInfo.FullName
}

try{

	$SetupType = 'IFD'

	if($DeploymentDefinitionName -notmatch "IFD")
	{
		$SetupType = "Online"
	}

	if($SetupType -eq 'IFD')
	{
		# Clean up all the deployments
		$logObject.WriteInformation("`n[DeployMobileOfflineEv2TestSetup] Deploy Step 1: Cleaning all existing deployment files`n")
		.\RemoveDeployments.ps1
		Set-Location -Path $currentDirectoryForDeployScript
		$logObject.WriteInformation("`n[DeployMobileOfflineEv2TestSetup] Deploy Step 1: Cleaning all existing deployment files completed`n")

		# Update deployment Artifacts
		$logObject.WriteInformation("`n[DeployMobileOfflineEv2TestSetup] Deploy Step 2:Updating artifacts to use a local package if required`n")
		.\UpdateDeploymentArtifacts.ps1 -ServiceGroupRoot $ServiceGroupRoot -isLocalPackageLink $true
		Set-Location -Path $currentDirectoryForDeployScript
		$logObject.WriteInformation("`n[DeployMobileOfflineEv2TestSetup] Deploy Step 2:Updating artifacts to use a local package if required... Completed`n")
	
		# First generate deployments for the user
		$logObject.WriteInformation("`n[DeployMobileOfflineEv2TestSetup] Deploy Step 3:Generating rollout specs for the user based on the deployment definition`n")
		$logObject.WriteInformation("`n[DeployMobileOfflineEv2TestSetup] Deployment Definition Name: $DeploymentDefinitionName")
		$logObject.WriteInformation("`n[DeployMobileOfflineEv2TestSetup] Usename: $username")
		.\GenerateDeployments.ps1 -DeploymentDefinitionName $DeploymentDefinitionName -username $username 
		Set-Location -Path $currentDirectoryForDeployScript
		$logObject.WriteInformation("`n[DeployMobileOfflineEv2TestSetup] Deploy Step 3:Generating rollout specs for the user based on the deployment definition... Completed`n")

		# Update the VNET configuration to use an existing VNET
		$logObject.WriteInformation("`n[DeployMobileOfflineEv2TestSetup] Deploy Step 4: Updating VNET configurations to use the existing VNET's`n")
		.\Lib\UpdateDeploymentConfigToUseExistingVNet.ps1 -ServiceGroupRoot $ServiceGroupRoot -DeploymentDefinitionName $DeploymentDefinitionName -username $username -AzureSubscriptionCertFileFullPath $AzureSubscriptionMgmtCertFileFullPath -subnetToUse $subnetToUse -logObject $logObject
		Set-Location -Path $currentDirectoryForDeployScript
		$logObject.WriteInformation("`n[DeployMobileOfflineEv2TestSetup] Deploy Step 4: Updating VNET configurations to use the existing VNET's... Completed`n")

		# Update the organization details for IFD setup
		$logObject.WriteInformation("`n[DeployMobileOfflineEv2TestSetup] Deploy Step 5: Updating organization details in the configuration`n")
		$orgId = .\Lib\UpdateDeploymentConfigToReplaceOrgID.ps1 -ServiceGroupRoot $ServiceGroupRoot -DeploymentDefinitionName $DeploymentDefinitionName -username $username -IsRunningOnCRMServer $IsRunningOnCRMServer -CRMServerAdminPassword $CRMServerAdminPassword -OrganizationBaseUrl $OrganizationBaseUrl -logObject $logObject
		Set-Location -Path $currentDirectoryForDeployScript
		$logObject.WriteInformation("`n[DeployMobileOfflineEv2TestSetup] Deploy Step 5: Updating organization details in the configuration... Completed`n")

		
		# Update provisioning xml
		if($(Test-Path $mobileOfflineUtilityPath))
		{
			# Irrespective of whether the keyvault is used for other secrets, we always use keyvault to extract
			# queue connection string and replace in the provisioning xml
			cd $mobileOfflineUtilityPath
			.\RetrieveAndCreateProvisioningXml.ps1  -ServiceGroupRoot $ServiceGroupRoot -DeploymentDefinitionName $DeploymentDefinitionName -username $username -OrganizationBaseUrl $OrganizationBaseUrl -orgId $orgId -KeyVaultCertificateName $KeyVaultCertificateName -mobileOfflineUtilityPath $mobileOfflineUtilityPath
		}

		# Deploy the cloud service - Currently we support installing only first deployment
		$RolloutSpecFileName = ""
		switch($DeploymentType)
		{
		 "Deploy"  {$RolloutSpecFileName = "RolloutSpecDeploy.nova_" + $username.ToLower().Substring(0,5) + "_" + $DeploymentDefinitionName.ToLower() + "_production_1_.json"}
		 "UpgradeService"  {$RolloutSpecFileName = "RolloutSpecServiceUpdate.nova_" + $username.ToLower().Substring(0,5) + "_" + $DeploymentDefinitionName.ToLower() + "_production_1_.json"}
		 "UpgradeConfig"  {$RolloutSpecFileName = "RolloutSpecServiceConfigUpdate.nova_" + $username.ToLower().Substring(0,5) + "_" + $DeploymentDefinitionName.ToLower() + "_production_1_.json"}
		}
   
		# Start the deployment
		$logObject.WriteInformation("`n[DeployMobileOfflineEv2TestSetup] Deploy Step 6: Starting the Mobile offline Azure service deployment using Ev2 SDK`n")
		$deployMobileOfflineExePath = Join-Path -Path $currentDirectoryForDeployScript -ChildPath "\TestSetupAutomationArtifacts\DeployMobileOffline"
		Set-Location -Path $deployMobileOfflineExePath

		#Deploy 
		& "$deployMobileOfflineExePath\DeployMobileOffline.exe" $ServiceGroupRoot $RolloutSpecFileName $ADClientAppForEv2DeploymentID $ADClientAppForEv2DeploymentKey 2>&1 >> $Ev2DeploymentLogFileName
		if($LASTEXITCODE -eq 0)
		{
		   $logObject.WriteInformation("`n[DeployMobileOfflineEv2TestSetup] Deploy Step 6: Starting the Mobile offline Azure service deployment using Ev2 SDK ... Completed`n")
		   $logObject.WriteInformation("`n[DeployMobileOfflineEv2TestSetup] Mobile offline Azure service deployment COMPLETED succesfully`n")
		}
		else
		{
			$logObject.WriteError("`n[DeployMobileOfflineEv2TestSetup] Mobile offline Azure service deployment FAILED. For more details please look at $Ev2DeploymentLogFileName`n")
		}
	
		Set-Location -Path $currentDirectoryForDeployScript
	}
	else
	{
		# TODO Deploy Online setup
	}

}
catch{
	$logObject.WriteError("[DeployMobileOfflineEv2TestSetup] Exception while running the deployment.")
	$logObject.WriteError("[DeployMobileOfflineEv2TestSetup] Exception: Current Location :" + (Get-Location))
	$logObject.WriteError("[DeployMobileOfflineEv2TestSetup] Exception: Message " + $_.Exception.Message)
	$logObject.WriteError("`n[DeployMobileOfflineEv2TestSetup] Mobile offline Azure service deployment FAILED.")
	$LASTEXITCODE = 1
}
exit $LASTEXITCODE