
#This function uploads a file to Azure storage blob in the given Storage account and Container

function ExecuteDeploymentActionUploadFileToBlob
{
Param
(
	[Parameter(Mandatory=$true)][string] $FilePath,
	[Parameter(Mandatory=$true)][string] $ContainerName,
	[Parameter(Mandatory=$true)][string] $BlobName,
	[Parameter(Mandatory=$true)][string] $StorageAccountName,
	[Parameter(Mandatory=$true)][string] $ServiceConfigFile,
	[Parameter(Mandatory=$true)][string] $ServiceLocation,
	[Parameter(Mandatory=$true)][int] $RetryAttemptsCount,
	[Parameter(Mandatory=$true)][int] $DelayInSecsToRetry
)
	$fileinfo = get-item (GetFilePath($PreDeploymentAction.FilePath))
	if (!$fileinfo.Exists)
	{
		Write-Error "Specified file for upload does not exist: $($fileinfo.FullName)"
	}
	
	$defaultStorageKey = Get-AzureStorageKey $StorageAccountName | %{ $_.Primary }
	$context = New-AzureStorageContext -StorageAccountName $StorageAccountName -StorageAccountKey $defaultStorageKey
	$hasContainer = Get-AzureStorageContainer -Context $context | where {$_.Name -eq $ContainerName}
	
	if (!$hasContainer)
	{
		#It executes New-AzureStorageContainer command to create new storage container and retrys for '$DelayInSecsToRetry' number of times if any failure
		Retry-Command -Command 'New-AzureStorageContainer' -Args @{Name = $ContainerName; Permission='Container'; Context = $context } -retries $RetryAttemptsCount -secondsDelay $DelayInSecsToRetry -Verbose
	}

	Write-Output "Uploading $($fileinfo.FullName) file to StorageAccount: $StorageAccountName Container: $($ContainerName)"

	#It executes Set-AzureStorageBlobContent command to create new storage container and retrys for '$DelayInSecsToRetry' number of times if any failure
	Retry-Command -Command 'Set-AzureStorageBlobContent' -Args @{Blob = $BlobName; Container = $ContainerName; File = $($fileinfo.FullName); Context = $context; Force = $null } -retries $RetryAttemptsCount -secondsDelay $DelayInSecsToRetry -Verbose
	
	$blob = Get-AzureStorageBlob -Container $ContainerName -Context $context -Blob $BlobName -ErrorAction stop
	$blobUri = $blob.ICloudBlob.uri.AbsoluteUri
		
	if( $fileinfo.FullName -Match ".cspkg")
	{
		#Add service package URI to be used while deployingthe service
		AddServiceConfiguration "ServicePackageFile" $blobUri
	}
	elseif($fileinfo.FullName -Match ".cscfg")
	{
		#Store BlobUri , Container name and blob name to be used while deploying the service
		AddServiceConfiguration "ServiceConfigFile" $blobUri
		AddServiceConfiguration "ServiceConfigFileContainer"  $ContainerName
		AddServiceConfiguration "ServiceConfigFileBlob"  $BlobName
	}
}

#This function copies a file from Azure storage blob to local path 

function global:Copy-FileFromAzureStorageToLocal
{
Param
(
	[Parameter(Mandatory=$true)][string] $BlobName,
	[Parameter(Mandatory=$true)][string] $ContainerName,
	[Parameter(Mandatory=$true)][string] $TempFilePath
) 
	$TempFileLocation = $("$TempFilePath\$BlobName" + ".xml") 
	Write-Verbose "Downloading $BlobName from Azure Blob Storage to $TempFileLocation" 
	$blob = Get-AzureStorageBlobContent -blob $BlobName -container $ContainerName -destination $TempFileLocation -force 
	Write-Output $TempFileLocation  
}
