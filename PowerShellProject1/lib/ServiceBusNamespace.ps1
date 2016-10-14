
#This function creates Servicebus namespace with in the spepcified location

function global:CreateServiceBusNamepace
{
Param
(
	[Parameter(Mandatory=$true)][string] $AzureDeploymentLocation,
	[Parameter(Mandatory=$true)][string] $NamespaceNamePrefix,
	[Parameter(Mandatory=$true)][string] $serviceBusNamespaceName,
	[Parameter(Mandatory=$true)][string] $ServiceBusType,
	[Parameter(Mandatory=$true)][int] $RetryAttemptsCount,
	[Parameter(Mandatory=$true)][int] $DelayInSecsToRetry
)
	Write-Host -BackgroundColor DarkGreen "Creating Service Bus Namespace : $serviceBusNamespaceName"
	$azureSBNamespace = Get-AzureSBNamespace -Name $serviceBusNamespaceName
	if (!$azureSBNamespace)
	{
		try
		{
			#It executes New-AzureSBNamespace command to create a Servicebus namespace on Azure and retrys for '$RetryAttemptsCount' number of times if any failure
			Retry-Command -Command 'New-AzureSBNamespace' -Args @{ Name = $serviceBusNamespaceName;Location=$AzureDeploymentLocation; NamespaceType = $ServiceBusType; CreateACSNamespace=$true } -retries $RetryAttemptsCount -secondsDelay $DelayInSecsToRetry -Verbose
			Write-Host "Created Service Bus Namespace cluster successfully : $serviceBusNamespaceName"
		}
		catch [System.Object]
		{
			if($_.Exception.Message.Contains("Bad Request - Invalid URL"))
			{
			 Write-Error "The given Service Bus Name prefix is not valid, either it is too long or have invalid name."
			}
			else
			{
			 Write-Error $_.Exception.Message
			}
		}
	}
	else
	{
		Write-Host "ServiceBus Namespace $serviceBusNamespaceName already exists."
	}
}

#This function generates Connection string for ServiceBus namespace

function GenerateSBNamespaceConnString 
{
Param
(
	[Parameter(Mandatory=$true)][string] $serviceBusNamespaceName
)
	$azureSBNamespace = Get-AzureSBNamespace -Name $serviceBusNamespaceName
	return $azureSBNamespace.ConnectionString
}