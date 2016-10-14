#This function creates Servicebus queue with in the spepcified Servicebus namespace

function global:CreateServiceBusQueue
{
Param
(
	[Parameter(Mandatory=$true)][string] $AzureDeploymentLocation,
	[Parameter(Mandatory=$true)][string] $QueueName,
	[Parameter(Mandatory=$true)][string] $serviceBusNamespaceName,
	[Parameter(Mandatory=$true)][int] $LockDurationInSeconds,
	[Parameter(Mandatory=$true)][int] $ToLiveInSeconds,
	[Parameter(Mandatory=$true)][int] $DuplicateDetectionHistoryTimeWindowInSeconds,
	[Parameter(Mandatory=$true)][int] $MaxDeliveryCount,
	[Parameter(Mandatory=$true)][string] $EnablePartitioning,
	[Parameter(Mandatory=$true)][int] $EnableDeadLettering,
	[Parameter(Mandatory=$true)][int] $RetryAttemptsCount,
	[Parameter(Mandatory=$true)][int] $RetryDelayInSecs)
	
	Write-Host -BackgroundColor DarkGreen "Creating Service Bus Queue: $QueueName in namespace $serviceBusNamespaceName."
	$azureSBNamespace = Get-AzureSBNamespace -Name $serviceBusNamespaceName
	$TokenProvider = [Microsoft.ServiceBus.TokenProvider]::CreateSharedSecretTokenProvider("owner", $azureSBNamespace.DefaultKey);
	$ServiceUri = $azureSBNamespace.ServiceBusEndpoint
	$namespaceManager = New-Object -TypeName Microsoft.ServiceBus.NamespaceManager -ArgumentList $ServiceUri, $TokenProvider;

	$lockDurationTimeSpan						= [TimeSpan]::FromSeconds($LockDurationInSeconds)
	$defaultMessageTimeToLiveTimeSpan			= [TimeSpan]::FromSeconds($ToLiveInSeconds)
	$duplicateDetectionHistoryTimeWindowTimeSpan= [TimeSpan]::FromMinutes($DuplicateDetectionHistoryTimeWindowInSeconds)
	$queueDescription = New-Object -TypeName Microsoft.ServiceBus.Messaging.QueueDescription -ArgumentList $QueueName;
	$queueDescription.DefaultMessageTimeToLive				= $defaultMessageTimeToLiveTimeSpan;
	$queueDescription.DuplicateDetectionHistoryTimeWindow	= $duplicateDetectionHistoryTimeWindowTimeSpan;
	$queueDescription.LockDuration							= $lockDurationTimeSpan;
	$queueDescription.MaxDeliveryCount						= $MaxDeliveryCount;
	if($EnablePartitioning -ieq "true")
	{
		$queueDescription.EnablePartitioning					= $true;
	}
	elseif($EnablePartitioning -ieq "false")
	{
		$queueDescription.EnablePartitioning					= $false;
	}
	$queueDescription.EnableDeadLetteringOnMessageExpiration = $EnableDeadLettering;

	#Note: Retry logic has been added here instead of calling RetryCommand.ps1, as queue is created on namespace manager instance, and its not a pure cmdlet
	$retrycount = 0
	$completed = $false
	$returnData = ""
	while (-not $completed) 
	{
		try 
		{
			$namespaceManager.CreateQueue($queueDescription);
		}	
		catch [Microsoft.ServiceBus.Messaging.MessagingEntityAlreadyExistsException] 
		{
			$completed = $true
			Write-Host "The queue $($QueueName) already exists in namespace $($serviceBusNamespaceName)"
		}
		catch [System.Management.Automation.MethodException] 
		{
			if($_.Exception.Message.Contains("Error formatting a string: Index (zero based) must be greater than or equal to zero and less than the size of the argument list.."))
			{
			 Write-Error "The given Service Bus Queue Name is not valid, either it is too long or have invalid name."
			}
			else
			{
			 Write-Error $_.Exception.Message
			}
		}
		catch
		{
			if ($retrycount -ge $RetryAttemptsCount) {
				Write-Verbose ("Queue Creation failed the maximum number of {1} times." -f $RetryAttemptsCount)
				throw
			} else {
				Write-Verbose ("Queue Creation failed. Retrying in {1} seconds." -f $RetryDelayInSecs)
				Start-Sleep $RetryDelayInSecs
				$retrycount++
			}
		}
		Write-Host "Deployed Queue successfully : $QueueName"
		$completed = $true
	}
}

#This function generates Connection string for ServiceBus Queue

function GenerateServiceBusQueueConnString 
{
Param
(
	[Parameter(Mandatory=$true)][string] $serviceBusNamespaceName
)
	$azureSBNamespace = Get-AzureSBNamespace -Name $serviceBusNamespaceName
	return $azureSBNamespace.ConnectionString
}