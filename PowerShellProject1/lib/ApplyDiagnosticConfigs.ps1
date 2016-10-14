<#ApplyDiagnosticsToCloudService 
	It applys diagnostics to the service 
.DESCRIPTION 
	Enables Diagnostics logging to the service specified
.EXAMPLE 
	ApplyDiagnosticsToCloudService $ServiceName $ServiceSlot $DiagnosticsStorageAccountName $DiagnosticsConfigFilePath
#>

function global:ApplyDiagnosticsToCloudService
{
	Param
	(
		[Parameter(Mandatory=$true)][string] $ServiceName,
		[Parameter(Mandatory=$true)][string] $ServiceSlot,
		[Parameter(Mandatory=$true)][string] $DiagnosticsStorageAccountName,
		[Parameter(Mandatory=$true)][string] $DiagnosticsConfigFilePath,
		[Parameter(Mandatory=$true)][string] $RoleName,
		[Parameter(Mandatory=$false)][string] $ActiveSecretVersion = "Primary"
	)
	$deployment = Get-AzureDeployment -ServiceName $ServiceName -Slot $ServiceSlot -ErrorVariable $ErrorInfo -ErrorAction stop
	
	if (!$deployment.DeploymentId)
	{
		 Write-Error "No Deployment found for $ServiceName service to configure the diagnostics"
	}

	if($ActiveSecretVersion -ieq "Primary")
	{
		$defaultStorageKey = Get-AzureStorageKey $DiagnosticsStorageAccountName | %{ $_.Primary }
	}
	elseif($ActiveSecretVersion -ieq "Secondary")
	{
		$defaultStorageKey = Get-AzureStorageKey $DiagnosticsStorageAccountName | %{ $_.Secondary }
	}
	$storageContext = New-AzureStorageContext -StorageAccountName $DiagnosticsStorageAccountName -StorageAccountKey $defaultStorageKey
	Set-AzureServiceDiagnosticsExtension -StorageContext $storageContext -DiagnosticsConfigurationPath $DiagnosticsConfigFilePath -ServiceName $ServiceName -Slot $ServiceSlot -Role $RoleName
}
