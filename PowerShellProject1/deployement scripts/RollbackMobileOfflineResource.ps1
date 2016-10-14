# Run command : RollbackMobileOfflineResource.ps1 -SubscriptionId fd799b57-566b-4300-b5fd-5116f9ce29f8 -SubscriptionName "CRM-DevTest-MoCA Offline Dev" -SubscriptionCertFilePath "D:\MicrosoftCrmDataSync3\Deployment\.\Certificates\AzureAuthVM.cer" -ResourceName "crmmostorageeapkamal" -ResourceType "StorageAccount"
# If in the above command SubscriptionName and CertificatePath parameters are not provided then Add-AzureAccount command is executed which prompts user to enter the credentials. This is specifically to rollover Azure resource that are created by azure resource management cmdlets.

param
(
	[parameter(Mandatory=$true)][string] $SubscriptionId = $null,
	[parameter(Mandatory=$false)][string] $SubscriptionName = $null,
	[parameter(Mandatory=$false)][string] $SubscriptionCertFilePath = $null,
	[parameter(Mandatory=$true)][string] $ResourceType = $null,
	[parameter(Mandatory=$true)][string] $ResourceName = $null
)

$ErrorActionPreference = "Stop"

# Make sure that it is in AzureServiceManagement mode initially to make Service cmdlets workable
Switch-AzureMode AzureServiceManagement
if(-not (Get-Module Azure))
{
	Write-Error "This script needs to be run in Azure PowerShell"
}

. .\Lib\ManageCertificates.ps1
. .\Lib\Config.ps1
. .\Lib\VirtualNetworkActions.ps1


# This function retrieves the resource from the list and removes it from Azure

function RemoveResource
{
Param
(
	[Parameter(Mandatory=$true)][string] $ResourceType,
	[Parameter(Mandatory=$true)][string] $ResourceData
)
	# Added the code in try/catch block not to interrupt the deletion of next set of resources even if there is any failure in middle
	try
	{
		switch ($ResourceType)
		{
			"AzureSqlDatabase" 
			{
				$paramList = $ResourceData.Split(',')
				Remove-AzureSqlDatabase -DatabaseName $paramList[0] -ServerName $paramList[1] -force
				continue
			}

			"TrafficManager" 
			{
				Remove-AzureTrafficManagerProfile -Name $ResourceData -force
				continue
			}

			"StorageBlob" 
			{ 
				$paramList = $ResourceData.Split(',')
				Remove-AzureStorageBlob -Blob $paramList[0] -Container $paramList[1] -force
				continue
			}

			"AzureServiceDiagnosticsExtension" 
			{
				Remove-AzureServiceDiagnosticsExtension $ResourceData
				continue
			}

			"ServicebusQueue" 
			{
				$paramList = $ResourceData.Split(',')
				$azureSBNamespace = Get-AzureSBNamespace -Name $paramList[1]
				if($azureSBNamespace )
				{
					$TokenProvider = [Microsoft.ServiceBus.TokenProvider]::CreateSharedSecretTokenProvider("owner", $azureSBNamespace.DefaultKey);
					$ServiceUri = $azureSBNamespace.ServiceBusEndpoint
					$namespaceManager = New-Object -TypeName Microsoft.ServiceBus.NamespaceManager -ArgumentList $ServiceUri, $TokenProvider;
					$namespaceManager.DeleteQueue($paramList[0])
				}
				continue
			}
			
			"ServiceBusNamespace" 
			{
				Remove-AzureSBNamespace $ResourceData -Force
				continue
			}

			"AzureSqlServer"
			{
				Remove-AzureSqlDatabaseServer -ServerName $ResourceData -force
				continue
			}

			"Deployment" 
			{ 
				$paramList = $ResourceData.Split(',')
				Remove-AzureDeployment $paramList[0] -Slot $paramList[1] -Force
				continue
			}

			"StorageAccount" 
			{
				Remove-AzureStorageAccount -StorageAccountName $ResourceData
				continue
			}

			"CloudService" 
			{
				$azureService = Get-AzureService | Where-Object {$_.ServiceName -eq $ResourceData}
				if ($azureService -ne $null)
				{
					Remove-AzureService -ServiceName $ResourceData -force
				}
				continue
			}

			"KeyVault" 
			{
				Switch-AzureMode AzureResourceManager
				Remove-AzureKeyVault -VaultName $ResourceData -force
				Switch-AzureMode AzureServiceManagement
				continue
			}

			"ResourceGroup" 
			{
				Switch-AzureMode AzureResourceManager
				Remove-AzureResourceGroup -ResourceGroupName $ResourceData -force
				Switch-AzureMode AzureServiceManagement
				continue
			}

			"VirtualNetwork"
			{
				$paramList = $ResourceData.Split(',')
				DeleteVirtualNetwork $paramList[0] $paramList[1]
				continue
			}

			"AzureADServicePrincipal"
			{
				Switch-AzureMode AzureResourceManager
				Remove-AzureADServicePrincipal -ObjectId $ResourceData -Force
				Switch-AzureMode AzureServiceManagement
				continue
			}

			"AzureDnsZone"
			{
				Switch-AzureMode AzureResourceManager
				# To clean DnsZone ResourceGroupName and DnsZoneName are required to be passed as parameters
				$paramList = $ResourceData.Split(',')
				Remove-AzureDnsZone -ResourceGroupName $paramList[0] -Name $paramList[1] -Force
				Switch-AzureMode AzureServiceManagement
				continue
			}

			"AzureADApplication"
			{
				Switch-AzureMode AzureResourceManager
				Remove-AzureADApplication -ApplicationObjectId $ResourceData -Force
				Switch-AzureMode AzureServiceManagement
				continue
			}
		}
			
	}
	catch
	{
		Write-Host $_.Exception.Message
		Write-Warning "Script failed to execute and unable to rollback one or more resources. Please check manually and delete the resources." 
		# By default set Azure mode to ServiceManagement not to fail the rollback process if the script is failed in ResourceManager mode
		Switch-AzureMode AzureServiceManagement
	}
}

### Start of the script to remove the resources given in input text file

$global:CurrentDirectory = Convert-Path .

#Read out First line and Set subscription details
if($SubscriptionCertFilePath -and $SubscriptionName)
{
	$SubscriptionCertFilePath = GetFilePath $SubscriptionCertFilePath
	Set-AzureSubscription -SubscriptionId $SubscriptionId -SubscriptionName $SubscriptionName -Certificate (GetCertificate $SubscriptionCertFilePath)
	Select-AzureSubscription -Current -SubscriptionId $SubscriptionId
}

# execute below function to remove the resources
RemoveResource $ResourceType $ResourceName

 
