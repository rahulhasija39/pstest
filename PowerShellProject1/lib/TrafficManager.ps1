
#This function checks and throws an error if Traffic manager already exists, otherwise creates one

function CreateTrafficManager
{
param
(
		[parameter(Mandatory=$true)][String] $ProfileName,
		[parameter(Mandatory=$true)][String] $LoadBalancingMethod,
		[parameter(Mandatory=$true)][String] $MonitorProtocol,
		[parameter(Mandatory=$true)] [String]$MonitorPort,
		[parameter(Mandatory=$true)][int] $RetryAttemptsCount, 
		[parameter(Mandatory=$true)][int] $DelayInSecsToRetry 
)
	
	Try
	{
		$TrafficManagerProfile = Get-AzureTrafficManagerProfile -Name $ProfileName
		Write-Host "TrafficManager with ProfileName '{0}' already exists." -f $ProfileName
	}
	Catch
	{
		$message = "Creating new Traffic Manager  with ProfileName '{0}'." -f $ProfileName
		Write-Verbose $message
		#Prepare domain name based on profile name
		$DomainName = $($ProfileName).ToLower() + ".trafficmanager.net"

		#It executes New-AzureTrafficManagerProfile command to create a Trafficmanager on Azure and retrys for '$RetryAttemptsCount' number of times if any failure
		Retry-Command -Command 'New-AzureTrafficManagerProfile' -Args @{ Name = $ProfileName;DomainName = $DomainName; LoadBalancingMethod = $LoadBalancingMethod; Ttl = 30; MonitorProtocol = $MonitorProtocol; MonitorPort = $MonitorPort; MonitorRelativePath ="/" } -retries $RetryAttemptsCount -secondsDelay $DelayInSecsToRetry -Verbose
		
		$message = "Traffic Manager '{0}' created." -f $ProfileName
		Write-Verbose $message
	}
}

#This function adds Service end point to an already created traffic manager 

function SetServiceEndpointToTrafficManager
{
	 param
	 (
		[parameter(Mandatory=$true)][String] $ProfileName,
		[parameter(Mandatory=$true)][String] $serviceEndpoint
	)
	$TrafficManagerProfile = Get-AzureTrafficManagerProfile -Name $ProfileName
	Write-Verbose "Setting Endpoint..."
	Set-AzureTrafficManagerEndpoint -TrafficManagerProfile $TrafficManagerProfile -DomainName $serviceEndpoint -Status Enabled -Type CloudService | Set-AzureTrafficManagerProfile
	$message = "Updated Endpoint '{0}' on Traffic Manager '{1}'." -f $serviceEndpoint, $ProfileName
	Write-Verbose $message
}

#This fucntion generates Traffic manager end point.

function GenerateTrafficManagerEndpoint
{
param
(
	[parameter(Mandatory=$true)][String]$ProfileName
)
	return $($ProfileName).ToLower() + ".trafficmanager.net"
}
