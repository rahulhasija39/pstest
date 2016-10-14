<#WaitTillServiceReady 
	It wait till all role instance are ready 
.DESCRIPTION 
	Wait till all instance of Role are ready 
.EXAMPLE 
  WaitTillServiceReady $ServiceName 
#>

function WaitTillServiceReady
{
Param(
	#Cloud Services name
	[Parameter(Mandatory = $true)]
	[String]$ServiceName
)
	Write-Verbose ("[Start] Waiting for Instance Ready")

	do
	{
		$Deploy = Get-AzureDeployment -ServiceName $ServiceName
		foreach ($Instancia in $Deploy.RoleInstanceList) 
		{
			$switch=$true
			Write-Verbose("Instance {0} is in state {1}" -f $Instancia.InstanceName, $Instancia.InstanceStatus )
			if ($Instancia.InstanceStatus -ne "ReadyRole") 
			{
				$switch=$false 
			}
		}
		if (-Not($switch)) 
		{
			Write-Verbose ("Waiting Azure Deploy running, it status is {0}" -f $Deploy.Status)
			Start-Sleep -s 10 
		}
		else
		{
			Write-Verbose ("[Finish] Waiting for Instance Ready")
		}
	}
	until($switch)
}

<# WaitTillSqlServerUpgradeComplete 
	It wait till SqlServer Upgrade Complete 
.DESCRIPTION 
	wait till SqlServer Upgrade Complete  
.EXAMPLE 
  WaitTillSqlServerUpgradeComplete $SqlServerName $ResourceGroupName 
#>

function WaitTillSqlServerUpgradeComplete
{
Param(
	[Parameter(Mandatory = $true)] [String]$SqlServerName,
	[Parameter(Mandatory = $true)] [String]$ResourceGroupName
)
	Write-Verbose ("[Start] Waiting for SqlServer Upgrade to Complete")
	$InProgress = $true
	while($InProgress)
	{
		$UpgradeData = Get-AzureSqlServerUpgrade -ServerName $SqlServerName -ResourceGroupName $ResourceGroupName

		if ($UpgradeData.Status -ieq "Queued" -or $UpgradeData.Status -ieq "InProgress")
		{
			Write-Host ("Waiting for the completion of SqlServer Upgrade to v12.0, it may take some time. Current status is: {0} " -f $UpgradeData.Status)
			Start-Sleep -s 30
		}
		elseif ($UpgradeData.Status -ieq "Completed")
		{
			$InProgress = $false 
			Write-Host "[Finish] SqlServer Upgrade to v12.0 is Completed"
		}
	}
}