# This function creates Azure sql server with the given name and with in the given location

function global:CreateSqlServer
{
Param
(
	[Parameter(Mandatory=$true)][string] $azureSqlServerLocation,
	[Parameter(Mandatory=$true)][string] $azureSqlServerUserName,
	[Parameter(Mandatory=$true)][string] $azureSqlServerPassword,
	[Parameter(Mandatory=$true)][int] $RetryAttemptsCount,
	[Parameter(Mandatory=$true)][int] $DelayInSecsToRetry,
	[Parameter(Mandatory=$true)][string] $version
)

	#Note: Retry logic has been added here instead of calling RetryCommand.ps1, as queue is created on namespace manager instance, and its not a pure cmdlet
	$retrycount = 0
	$completed = $false
	$ServerName = ""
	$serverCreated = $false
	$v12Server = $false

	try
	{
		$databaseServer = Retry-Command -Command 'New-AzureSqlDatabaseServer' -Args @{ location = $azureSqlServerLocation;AdministratorLogin=$azureSqlServerUserName;AdministratorLoginPassword =$azureSqlServerPassword;version=$version} -retries $RetryAttemptsCount -secondsDelay $DelayInSecsToRetry -Verbose
		$ServerName = $databaseServer.ServerName
		$serverCreated = $true
		$v12Server = $true
	}
	catch
	{
		#Error message:
		#Location 'East US' is not accepting creation of new Azure SQL Database Servers of version '12.0' at this time.  This location only supports 
		#the following server versions: '2.0'.  Please retry using a supported server version. Error Code: 40856.Exception.Message

		if($_.Exception.Message.Contains("Error Code: 40856"))
		{
			Write-Host "Failed to create SqlServer with Version: $version at Azure Location: $azureSqlServerLocation, hence creating it with Basic version 2.0 and then upgrade."
			
			# Create New SQLServer with basic version:2.0
			# And the follwoing line executes New-AzureSqlDatabaseServer command and retrys for '$RetryAttemptsCount' number of times if any failure
			$databaseServer = Retry-Command -Command 'New-AzureSqlDatabaseServer' -Args @{ location = $azureSqlServerLocation;AdministratorLogin=$azureSqlServerUserName;AdministratorLoginPassword =$azureSqlServerPassword;version=2.0} -retries $RetryAttemptsCount -secondsDelay $DelayInSecsToRetry -Verbose
			$ServerName = $databaseServer.ServerName
			$serverCreated = $true
		}
		if (-not $serverCreated)
		{
			throw
		}
	}

	$switchToServiceManagement = $true

	if (-not $v12Server)
	{
		# Switch to AzureResourceManagerMode to make use of ResourceManager Cmdlets
		Switch-AzureMode AzureResourceManager

		# Add Azure Account
		$userData = Add-AzureAccount
	}
	
	while (-not $v12Server)
	{
		try
		{
			# Switch to AzureResourceManagerMode to make use of ResourceManager Cmdlets
			Switch-AzureMode AzureResourceManager

			# Add Azure Account
			$userData = Add-AzureAccount

			# Default ResourceGroupName
			$ResourceGroupName = Get-AzureResource -ResourceName $ServerName | % {$_.ResourceGroupName}
				
			# Start SqlServer upgrade to latest version
			$upgradeData = Start-AzureSqlServerUpgrade -ServerName $ServerName -ServerVersion $version -ResourceGroupName $ResourceGroupName
				
			# Wait till Upgrade is completed as Script would fail if the sql server is lesser than 12.0 version
			WaitTillSqlServerUpgradeComplete $ServerName $ResourceGroupName

			$v12Server = $true
		}
		catch 
		{
			if ($retrycount -ge $RetryAttemptsCount)
			{
				Write-Host "SqlServer upgrade to v12.0 failed for the maximum number of $RetryAttemptsCount times."
				throw
			}
			else 
			{
				Write-Host "SqlServer upgrade to v12.0 failed. Retrying in $DelayInSecsToRetry seconds."
				$retrycount++
				Start-Sleep $DelayInSecsToRetry
			}
		}
	}
	
	if($switchToServiceManagement)
	{
		# Switch back to AzureServiceManagement mode
		Switch-AzureMode AzureServiceManagement
	}
	
	return $databaseServer.ServerName
}
