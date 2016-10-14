# Azure Keyvault Creation :

# To run this script -

# 1. Prerequisites are Winodws Server2012R2 and .net framework .4.5.2

# 2. Install Azure PowerShell Console from here: http://www.windowsazure.com/en-us/documentation/articles/install-configure-powershell/

# 3. Install Azure Sdk 2.6

# 4. Open the "Windows Azure PowerShell" console as Administrator.

# 5. The sample command to run the script is - .\CreateAzureKeyVault.ps1 -SubscriptionId "fd799b57-566b-4300-b5fd-5116f9ce29f8" -SubscriptionName "CRM-DevTest-MoCA Offline Dev" -SubscriptionCertFilePath ".\Certificates\AzureAuthVM.cer" -AzureDeploymentLocation: "East Asia" -KeyVaultName: AzureKV081315

# 6. When the command given above is run, three scenarios may encounter -
#  a) User is prompted to enter Azure Account Username and password.
#  b) Keyvault already exists with same name under same subscription, and that can be used
#  c) Keyvault already exists but under different subscription and can not be accessed. Then an error is thrown and User is supposed to try with a different name.
#  d) Keyvault does not exists, and it will be created succefully 
#7. If keyvault is used while running deployment scripts (i.e., AzureDeployer.ps1) the following 3 parameters must be added to the commandline and also StartDeployment method signature will be changed to add these parameters.
#   -KeyVaultName 
#   -KeyVaultAuthClientID 
#   -KeyVaultAuthSecret
# 8. If any other user is expected to run the scripts(with in the subscription) GrantAzureKeyVaultAccess.ps1 should be run to allow accee to that second user. 
param
(
	[parameter(Mandatory=$true)][string] $SubscriptionId = $null,
	[parameter(Mandatory=$true)][string] $SubscriptionName = $null,
	[parameter(Mandatory=$true)][string] $SubscriptionCertFilePath = $null,
	[parameter(Mandatory=$true)][string] $AzureDeploymentLocation = $null,
	[parameter(Mandatory=$true)][string] $KeyVaultName = $null,
	[parameter(Mandatory=$true)][string] $KeyVaultAuthServiceName = $null,
	[parameter(Mandatory=$true)][string] $KeyVaultAuthSecret = $null
)

#Step-1 : Set action preference, current directory and import needed Libraries
$ErrorActionPreference = "Stop"
# Make sure that it is in AzureServiceManagement mode initially to make Service cmdlets workable
Switch-AzureMode AzureServiceManagement
if(-not (Get-Module Azure))
{
	Write-Error "This script needs to be run in Azure PowerShell"
}

Set-Location -Path $PSScriptRoot
. .\Lib\Config.ps1
. .\Lib\ManageCertificates.ps1
. .\Lib\Shared.ps1

$CurrentDirectory = Convert-Path .

#Step:2 - Import KeyVault Manager Module
# To get Keyvault manager functionality working, we need Set ExecutionPolicy to be either 'RemoteSigned' or 'Unrestricted'.
# Set ExecutionPolicy to 'RemoteSigned' checks that the downloaded scripts must be signed by a trusted publisher before they can be run.
Set-ExecutionPolicy RemoteSigned -Scope Process

# Do some initial setup for KeyVault manager
$azureKeyVaultManagerPath =  GetFilePath ".\KeyVaultManager" $CurrentDirectory
ThrowErrorIfNull $azureKeyVaultManagerPath "No module found for KeyVaultManager, the KeyVault functionality may not work."
Import-Module $azureKeyVaultManagerPath

# Step 3: Set AzureSubscriptions
$SubscriptionCertFilePath = GetFilePath $SubscriptionCertFilePath $CurrentDirectory
ThrowErrorIfNull $SubscriptionCertFilePath "No Subscription Certificate Provided"
Set-AzureSubscription -SubscriptionId $SubscriptionId -SubscriptionName $SubscriptionName -Certificate (GetCertificate $SubscriptionCertFilePath)
Select-AzureSubscription -Current -SubscriptionId $SubscriptionId

#Step-4: Validate azure location and Keyvault name
# Get the list of valid Azure Geo locations
if (-not $global:ValidAzureLocations)
{
	$global:ValidAzureLocations = Get-AzureLocation | % {$_.Name}  # (West US, East Asia, East US 2, North Europe, Southeast Asia, West Europe)
}
if($global:ValidAzureLocations -notcontains $AzureDeploymentLocation)
{
	Write-Error "Invalid Azure Location: $AzureDeploymentLocation. Valid options are $($global:ValidAzureLocations)"
}

if($KeyVaultName)
{
	if(-not $KeyVaultAuthServiceName)
	{
		$KeyVaultAuthServiceName = ReadAndValidateInput "KeyVault Auth ServiceName" $KeyVaultAuthServiceName
	}
	if(-not $KeyVaultAuthSecret)
	{
		$KeyVaultAuthSecret = ReadAndValidateInput "KeyVault Auth Password" $KeyVaultAuthSecret
	}
}
#Step-5: Create azure key vault
#Switch Azure mode to AzureResourceManager to get resource cmdlets work
Switch-AzureMode AzureResourceManager
Add-AzureAccount

#Create a keyvault
#Note: The following command prompts to enter user credentials, need to find a better way of doing if can
$vault = Get-AzureKeyVault -VaultName $KeyVaultName -ErrorAction SilentlyContinue
if ($vault)
{
	Write-Verbose "Matching keyvault found, using it - $KeyVaultName"
}
else
{
	New-AzureResourceGroup -Name $KeyVaultName -Location $AzureDeploymentLocation
	New-AzureKeyVault -VaultName $KeyVaultName -ResourceGroupName $KeyVaultName -Location $AzureDeploymentLocation
	$vault = Get-AzureKeyVault -VaultName $KeyVaultName
	#Vault URI would be something like -https://<VaultName>.vault.azure.net/
}
$subscriptionData = (Get-AzureSubscription -Current)
$azureTenantId =  $subscriptionData.TenantId # Set your current subscription tenant ID
$subscriptionId =  $subscriptionData.SubscriptionId # Set your current subscription tenant ID
Write-Host "Azure TenatId: '$azureTenantId' "
$AzureTenant = Connect-AzureAD $azureTenantId
$adapps = Get-AzureADApplication -Name $KeyVaultAuthServiceName
$adapp = $null
$AuthClientID = $null
if(!$adapps)
{
	# Create a new AD application if not created before
	$azureAdApplication = New-AzureADApplication -DisplayName $KeyVaultAuthServiceName -HomePage "https://$KeyVaultAuthServiceName" -IdentifierUris "https://$KeyVaultAuthServiceName" -Password $KeyVaultAuthSecret
	$AuthClientID = $azureAdApplication.ApplicationId
}
else
{
	$azureAdApplication = $adapps[0]
	$AuthClientID = $azureAdApplication.appID
}
$servicePrincipals = Get-AzureADServicePrincipal -SearchString $KeyVaultAuthServiceName
if(-not $servicePrincipals)
{
	$servicePrincipal = New-AzureADServicePrincipal -ApplicationId $azureAdApplication.ApplicationId
	New-AzureRoleAssignment -RoleDefinitionName Contributor -ServicePrincipalName $AuthClientID
}else
{
	$servicePrincipal = $servicePrincipals[0] 
}

Write-Host $azureAdApplication
Set-AzureKeyVaultAccessPolicy -VaultName $KeyVaultName -ObjectId $servicePrincipal.Id -PermissionsToKeys encrypt,decrypt,get -PermissionsToSecrets all
#Switch Azure mode to AzureServiceManagement to get management cmdlets work
Switch-AzureMode AzureServiceManagement
Write-Verbose "Key vault - $KeyVaultName is ready to use."
Write-Verbose "Use the combination of AuthClientID -'$AuthClientID' and Secret - '$KeyVaultAuthSecret' to access the Keyvault in further steps."
