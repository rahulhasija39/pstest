#This function creates storage account with in the spepcified location

function global:CreateStorageAccount
{
Param
(
	[Parameter(Mandatory=$true)][string] $AzureDeploymentLocation,
	[Parameter(Mandatory=$true)][string] $storageAccountName,
	[Parameter(Mandatory=$true)][string] $AccountNamePrefix,
	[Parameter(Mandatory=$true)][int] $RetryAttemptsCount,
	[Parameter(Mandatory=$true)][int] $DelayInSecsToRetry)
	$azureStorageAccounts = Get-AzureStorageAccount
	$azureStorageAccount = $azureStorageAccounts | where {$_.StorageAccountName -eq $storageAccountName}
	if ($azureStorageAccount)
	{
		Write-Host "Azure Storage Account '$storageAccountName' already exists."
	}
	else
	{
		Write-Host "Creating Azure Storage Account: '$storageAccountName' ... under Location: '$AzureDeploymentLocation' "
		try
		{
			#It executes New-AzureStorageAccount command to create a Servicebus namespace on Azure and retrys for '$RetryAttemptsCount' number of times if any failure
			Retry-Command -Command 'New-AzureStorageAccount' -Args @{ StorageAccountName = $storageAccountName;Location=$AzureDeploymentLocation } -retries $RetryAttemptsCount -secondsDelay $DelayInSecsToRetry -Verbose
		}
		catch [System.ArgumentException]
		{
			if($_.Exception.Message.Contains("Specified argument was out of the range of valid values."))
			{
				Write-Error "The given Storage Account Name prefix isn’t valid. It’s either too long or has invalid characters."
			}
			else
			{
				Write-Error $_.Exception.Message
			}
		}

	}
}

#This function generates connection string for the given storage account.

function GenerateStorageAccountConnString ($storageAccountName)
{
	$azureStorageAccount = Get-AzureStorageAccount -StorageAccountName $storageAccountName
	# Get the access key of the storage account 
	$StorageKey =  Get-AzureStorageKey $storageAccountName | %{ $_.Primary }

	# Generate the connection string of the storage account 
	$connectionString ="DefaultEndpointsProtocol=https;AccountName={0};" -f $storageAccountName
	$connectionString =$connectionString + "AccountKey={0}" -f $StorageKey
	
	return $connectionString
}

#This function creates storage table to be used by event processor role

function global:CreateStorageTable
{
Param
(
	[Parameter(Mandatory=$true)][string] $storageTableName,
	[Parameter(Mandatory=$true)][int] $RetryAttemptsCount,
	[Parameter(Mandatory=$true)][int] $DelayInSecsToRetry)
	$azureStorageTables = Get-AzureStorageTable
	$azureStorageTable = $azureStorageTables | where {$_.Name -eq $storageTableName}
	if ($azureStorageTable)
	{
		Write-Host "Azure Storage Table '$storageTableName' already exists."
	}
	else
	{
		Write-Host "Creating Azure Storage Table: '$storageTableName'"
		try
		{
			#It executes New-AzureStorageTable command to create a storage Table on Azure and retrys for '$RetryAttemptsCount' number of times if any failure
			Retry-Command -Command 'New-AzureStorageTable' -Args @{ Name = $storageTableName;} -retries $RetryAttemptsCount -secondsDelay $DelayInSecsToRetry -Verbose
		}
		catch [System.ArgumentException]
		{
			if($_.Exception.Message.Contains("Specified argument was out of the range of valid values."))
			{
				Write-Error "The given Storage Table Name isn’t valid. It’s either too long or has invalid characters."
				Write-Error $_.Exception.Message
			}
			else
			{
				Write-Error $_.Exception.Message
			}
		}
	}
}