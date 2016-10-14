#This function sets the given secret vaule in to Azure KeyVault

function global:Set-KeyVault-Secret 
{
	Param
	(
		[Parameter(Mandatory=$true)][String]$keyName,
		[Parameter(Mandatory=$true)][String]$keyValue,
		[Parameter(Mandatory=$true)][String]$vaultName
	)

	$encryptedValue = ConvertTo-SecureString -String $keyValue -AsPlainText -Force 
	Set-AzureKeyVaultSecret -VaultName $vaultName -Name $keyName -SecretValue $encryptedValue
}

#This function gets the asked secret vaule from to Azure KeyVault

function global:Get-KeyVault-Secret
{
	Param
	(
		[Parameter(Mandatory=$true)][String]$Name,
		[Parameter(Mandatory=$true)][String]$VaultName,
		[Parameter(Mandatory=$false)][String]$DefaultValue
	)

	Try
	{
		$encryptedValue = Get-AzureKeyVaultSecret -VaultName $VaultName -Name $Name 
		return $encryptedValue.SecretValueText
	}
	Catch [System.Exception]
	{
		if ($DefaultValue)
		{
			Write-Warning "$Name not found in configuration store, so returning default value"
			return $DefaultValue 
		}
		else
		{
			return ""
		}
	}
}

#This funtion adds the currently deploying service to Azure Active directory and provides authorises 
#   it to access the Keyvault

function Add-ADApplicationCredential
{
	Param
	(
		[Parameter(Mandatory=$true)][String]$ServiceName,
		[Parameter(Mandatory=$true)][String]$KeyVaultAuthPassword,
		[Parameter(Mandatory=$true)][String]$KeyVaultName,
		[Parameter(Mandatory=$true)][String]$AzureDeploymentLocation
	)
	$subscriptionData = (Get-AzureSubscription -Current)
	$azureTenantId =  $subscriptionData.TenantId # Set your current subscription tenant ID
	$subscriptionId =  $subscriptionData.SubscriptionId # Set your current subscription tenant ID
	Write-Host "Azure TenatId: '$azureTenantId' "
	$AzureTenant = Connect-AzureAD $azureTenantId
	$adapps = Get-AzureADApplication -Name $ServiceName
	$adapp = $null
	if(!$adapps)
	{
		# Create a new AD application if not created before
		$adapp = New-AzureADApplication -DisplayName $ServiceName
	}
	else
	{
		$adapp = $adapps[0]
	}
	Write-Host $adapp
	return $adapp.appId
}
