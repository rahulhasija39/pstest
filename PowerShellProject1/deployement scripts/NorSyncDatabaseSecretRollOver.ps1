#Run command : .\NorSyncDatabaseSecretRollOver.ps1 –SubscriptionId "fd799b57-566b-4300-b5fd-5116f9ce29f8" -SubscriptionName "CRM-DevTest-MoCA Offline Dev" -SubscriptionCertFilePath ".\Certificates\ManagementCertificate.cer" -AzureSqlDatabaseName "norsyncdirdbeapea001" -CurrentActiveSecretVersion "Primary"

param
(
	[parameter(Mandatory=$true)][string] $SubscriptionId = $null,
	[parameter(Mandatory=$true)][string] $SubscriptionName = $null,
	[parameter(Mandatory=$true)][string] $SubscriptionCertFilePath = $null,
	[parameter(Mandatory=$true)][string] $AzureSqlDatabaseName,
    [Parameter(Mandatory=$true)][string] $CurrentActiveSecretVersion,
	[Parameter(Mandatory=$false)][string] $ServerAdmin = "crmmobilesa",
	[Parameter(Mandatory=$false)][string] $ConnectionStringSuffix = "database.windows.net"
)
$ErrorActionPreference = "Stop"
# Make sure that it is in AzureServiceManagement mode initially to make Service cmdlets workable
Switch-AzureMode AzureServiceManagement
if(-not (Get-Module Azure))
{
	Write-Error "This script needs to be run in Azure PowerShell"
}

. .\Lib\ManageCertificates.ps1
. .\Lib\AzureSQLDatabase.ps1
. .\Lib\RandomPassword.ps1

$global:CurrentDirectory = Convert-Path .
$SubscriptionCertFilePath = GetFilePath $SubscriptionCertFilePath
#Step-1: Set Azure subscription
Set-AzureSubscription -SubscriptionId $SubscriptionId -SubscriptionName $SubscriptionName -Certificate (GetCertificate $SubscriptionCertFilePath)
Select-AzureSubscription -Current -SubscriptionId $SubscriptionId

# Reset password for real admin of ServerName
$ServerAdmin = "crmmobilesa"
# Generate random password for sql server
$AzureSqlAdminPassword = Generate-Random-Password

# Get the sql server name from db name
$sqlServerNames=Get-AzureSqlDatabaseServer
forEach ($sqlServerName in $sqlServerNames)
{
	$sqlServerDatabase = Get-AzureSqlDatabase -ServerName $($sqlServerName).ServerName | where {$_.Name -eq $AzureSqlDatabaseName}
	if ($sqlServerDatabase -ne $null)
	{
		$AzureSqlServerName = $($sqlServerName).ServerName
	}
}

if(!$AzureSqlServerName)
{
	Write-Error "Could not found sql server with $AzureSqlDatabaseName database on subscription id $SubscriptionId"
}

# Reset the sql server admin password
Set-AzureSqlDatabaseServer -ServerName $AzureSqlServerName -AdminPassword $AzureSqlAdminPassword

#Check if the ServerFirewall rule is set or not
$isFirewallRuleSet = CheckSqlServerFirewallRule $AzureSqlServerName "ClientDeploymentRule"
			
if($isFirewallRuleSet)
{
	# Temporary relax sql server firewall rule to allow deployment script to create User in DB
	Set-AzureSqlDatabaseServerFirewallRule -ServerName $AzureSqlServerName -RuleName "ClientDeploymentRule" -StartIPAddress 0.0.0.0 -EndIPAddress 255.255.255.255
}
else
{
	# Temporary relax sql server firewall rule to allow deployment script to create User in DB
	New-AzureSqlDatabaseServerFirewallRule -ServerName $AzureSqlServerName -RuleName "ClientDeploymentRule" -StartIPAddress 0.0.0.0 -EndIPAddress 255.255.255.255
}

#Generate connection string for Azure SQLServer with master database.
[string] $AzureSQLServerConnectionString = Get-SQLAzureDatabaseConnectionString -DatabaseServerName $AzureSqlServerName -DatabaseName 'master' -SqlDatabaseUserName $ServerAdmin -Password $AzureSqlAdminPassword -ConnectionStringSuffix $ConnectionStringSuffix

#Step-2 Check the $CurrentActiveSecretVersion
if ($CurrentActiveSecretVersion -eq "Primary")
{
	# Current active user is norsyncdbadmin1 so we need to rollover to norsyncdbadmin2
	$azureSqlDbUserName = "norsyncdbadmin2"
	$azureSqlDbUserPassword = Generate-Random-Password
	
	#Creates or Resets the password for the server user
	CreateSqlDatabaseUser $AzureSqlServerName $AzureSqlDatabaseName $ServerAdmin $AzureSqlAdminPassword $ConnectionStringSuffix $azureSqlDbUserName $azureSqlDbUserPassword
	
	#Generate The new connection string
	[string] $AzureSQLServerConnectionString = Get-SQLAzureDatabaseConnectionString -DatabaseServerName $AzureSqlServerName -DatabaseName $AzureSqlDatabaseName -SqlDatabaseUserName $azureSqlDbUserName  -Password $azureSqlDbUserPassword -ConnectionStringSuffix $ConnectionStringSuffix
	
	#Set the ActiveSecterVerion to Secondary
	$activeSecretVersion = "Secondary"
}
elseif ($CurrentActiveSecretVersion -eq "Secondary")
{
	# Current active user is norsyncdbadmin2 so we need to rollover to norsyncdbadmin1
	$azureSqlDbUserName = "norsyncdbadmin1"
	$azureSqlDbUserPassword = Generate-Random-Password
	
	#Creates or Resets the password for the database user
	CreateSqlDatabaseUser $AzureSqlServerName $AzureSqlDatabaseName $ServerAdmin $AzureSqlAdminPassword $ConnectionStringSuffix $azureSqlDbUserName $azureSqlDbUserPassword
	
	#Generate The new connection string
	[string] $AzureSQLServerConnectionString = Get-SQLAzureDatabaseConnectionString -DatabaseServerName $AzureSqlServerName -DatabaseName $AzureSqlDatabaseName -SqlDatabaseUserName $azureSqlDbUserName  -Password $azureSqlDbUserPassword -ConnectionStringSuffix $ConnectionStringSuffix
	
	#Set the ActiveSecterVerion to Primary
	$activeSecretVersion = "Primary"
}
else
{
	Write-Error "activeAdmin can have two values 'Primary' or 'Secondary' "
}

#Update Sql Server Firewall rules after we have done all the operation on db
Set-AzureSqlDatabaseServerFirewallRule -ServerName $AzureSqlServerName -RuleName "ClientDeploymentRule" -StartIPAddress 0.0.0.0 -EndIPAddress 0.0.0.0

Write-Host -BackgroundColor DarkGreen "Run the below CrmLive command on corresponding crm site"

[string] $crmLiveCommand = "Crmlive AzureResource Update `"-ResourceName:$AzureSqlDatabaseName`" `"-ResourceType:AzureSqlDatabase`"  `"-SubscriptionId:$SubscriptionId`" `"-ResourceConnectionString:$AzureSQLServerConnectionString`" `"-ActiveSecretVersion:$activeSecretVersion`""

Write-Host $crmLiveCommand
