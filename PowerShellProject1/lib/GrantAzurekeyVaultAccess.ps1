# This script must be run after CreateAzureKeyvault.ps1 (i.e., after creating KeyVault) to assign Access policy to an user.

# To run this script -

# 1. Prerequisites are Winodws Server2012R2 and .net framework .4.5.2

# 2. Install Azure PowerShell Console from here: http://www.windowsazure.com/en-us/documentation/articles/install-configure-powershell/

# 3. Install Azure Sdk 2.6 

# 4. Open the "Windows Azure PowerShell" console as Administrator.

# 5. Make sure to use the same subscription details and KeyVault name used while creating Keyvault

# 6. The sample command to run the script is - .\GrantAzureKeyVaultAccess.ps1 -SubscriptionId "fd799b57-566b-4300-b5fd-5116f9ce29f8" -SubscriptionName "CRM-DevTest-MoCA Offline Dev" -SubscriptionCertFilePath ".\Certificates\AzureAuthVM.cer" -UserToGrantAccess: "dsfsdfdsf.xyz" -KeyVaultName: AzureKV081315

param
(
	[parameter(Mandatory=$true)][string] $SubscriptionId = $null,
	[parameter(Mandatory=$true)][string] $SubscriptionName = $null,
	[parameter(Mandatory=$true)][string] $SubscriptionCertFilePath = $null,
	[parameter(Mandatory=$true)][string] $UserToGrantAccess = $null,
	[parameter(Mandatory=$true)][string] $KeyVaultName = $null
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

. .\Lib\ManageCertificates.ps1

$CurrentDirectory = Convert-Path .

# Step 2: Set AzureSubscriptions
$SubscriptionCertFilePath = GetFilePath $SubscriptionCertFilePath $CurrentDirectory
ThrowErrorIfNull $SubscriptionCertFilePath "No Subscription Certificate Provided"
Set-AzureSubscription -SubscriptionId $SubscriptionId -SubscriptionName $SubscriptionName -Certificate (GetCertificate $SubscriptionCertFilePath)
Select-AzureSubscription -Current -SubscriptionId $SubscriptionId

#Step-3: Switch Azure mode to AzureResourceManager to get resource cmdlets work and Connect to Azure
Switch-AzureMode AzureResourceManager
Add-AzureAccount

#Step-4: Assign Keyvault access policy for the given user
Set-AzureKeyVaultAccessPolicy -VaultName $KeyVaultName -UserPrincipalName $UserToGrantAccess -PermissionsToKeys encrypt,decrypt,get -PermissionsToSecrets all

#Switch Azure mode to AzureServiceManagement to get management cmdlets work
Switch-AzureMode AzureServiceManagement
Write-Verbose "User - $UserToGrantAccess has been given access to use KeyVault - $KeyVaultName."