
#This function create Cloud Service on Azure with the passed in name in the given location

function global:CreateService
{
	Param
	(
		[Parameter(Mandatory=$true)][string] $ServiceName,
		[Parameter(Mandatory=$true)][string] $ServiceLocation,
		[Parameter(Mandatory=$true)][int] $RetryAttemptsCount,
		[Parameter(Mandatory=$true)][int]  $DelayInSecsToRetry
	)

	$azureServiceNames = Get-AzureService | foreach { $_.ServiceName }

	if ($azureServiceNames -contains $ServiceName)
	{
		Write-Host "Azure Cloud Service - $ServiceName already exists"
	}
	else
	{
		Write-Output "Creating Azure Cloud Service - $ServiceName..."
		if ($ServiceLocation)
		{
			try
			{
				# It executes New-AzureService command and retrys for '$RetryAttemptsCount' number of times if any failure
				Retry-Command -Command 'New-AzureService' -Args @{ ServiceName = $ServiceName;Location=$ServiceLocation } -retries $RetryAttemptsCount -secondsDelay $DelayInSecsToRetry -Verbose
			}
			catch [System.Object]
			{
				if($_.Exception.Message.Contains("BadRequest: The hosted service name is invalid."))
				{
					Write-Error "The given Azure Service Name prefix isn’t valid. It’s either too long or has invalid characters."
				}
				else
				{
					Write-Error $_.Exception.Message
				}
			}

		}
		else
		{
			Write-Error "Location for service - $ServiceName is not provided..."
		}
	}
}

#Generates Endpoint for the passed in Service
function GenerateServiceEndpoint
{
	Param
	(
		[Parameter(Mandatory=$true)][string] $ServiceName,
		[Parameter(Mandatory=$true)][String] $ConnectionStringSuffix
	)
	$serviceEndpoint = "{0}.{1}" -f $ServiceName, $ConnectionStringSuffix
	return $serviceEndpoint
}
