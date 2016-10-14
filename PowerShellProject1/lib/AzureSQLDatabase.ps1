# This function returns the Azure SqlServer name for the passed in Database and with in the given Location

function global:Get-AzureSQLServerWithDatabaseName
{
Param
(
	[Parameter(Mandatory=$true)][string] $dbName, 
	[Parameter(Mandatory=$true)][string] $azureSqlServerLocation
)
	$sqlServerNames=(Get-AzureSqlDatabaseServer | where {$_.Location -eq $azureSqlServerLocation}).ServerName
	forEach ($sqlServerName in $sqlServerNames)
	{
		$sqlServerDatabase = Get-AzureSqlDatabase -ServerName $sqlServerName | where {$_.Name -eq $dbName}
		if ($sqlServerDatabase -ne $null)
		{
			return $sqlServerName
		}
	}
}
# This function returns the list of Azure SqlServer names with in the given Location

function global:Get-AzureSQLServerWithLocation
{
Param
(
	[Parameter(Mandatory=$true)][string] $azureSqlServerLocation
)
	$sqlServerNames=(Get-AzureSqlDatabaseServer | where {$_.Location -eq $azureSqlServerLocation}).ServerName
	return $sqlServerNames
}

# This fucntion creates new Azure Sqlserver Database with in the provided location

function global:CreateSqlServerDatabase
{
Param
(
	[Parameter(Mandatory=$true)][string] $azureSqlServerLocation,
	[Parameter(Mandatory=$true)][string] $azureSqlServerName,
	[Parameter(Mandatory=$true)][string] $databaseName,
	[Parameter(Mandatory=$true)][string] $azureSqlServerUserName,
	[Parameter(Mandatory=$true)][string] $azureSqlServerPassword,
	[Parameter(Mandatory=$true)][string] $databaseMaxSizeGB,
	[Parameter(Mandatory=$true)][string] $databaseEdition,
	[Parameter(Mandatory=$false)][string] $databasePerf,
	[Parameter(Mandatory=$true)][int] $RetryAttemptsCount,
	[Parameter(Mandatory=$true)][int]  $DelayInSecsToRetry
)

	Write-Host -BackgroundColor DarkGreen "Creating Azure SQL Database: $databaseName.."

	$serverCredential = new-object System.Management.Automation.PSCredential($azureSqlServerUserName, ($azureSqlServerPassword | ConvertTo-SecureString -asPlainText -Force))
	$databaseServer = Get-AzureSqlDatabaseServer -ServerName $azureSqlServerName
	$ctx = $databaseServer | New-AzureSqlDatabaseServerContext -Credential $serverCredential 
	if ($databasePerf)
	{
		$serviceObjective = Get-AzureSqlDatabaseServiceObjective -Context $ctx -ServiceObjectiveName $databasePerf
		#It executes New-AzureSqlDatabase command and retrys for '$DelayInSecsToRetry' number of times if any failure
		Retry-Command -Command 'New-AzureSqlDatabase' -Args @{ConnectionContext= $ctx; DatabaseName = $databaseName; Edition=$databaseEdition; MaxSizeGB =$databaseMaxSizeGB; ServiceObjective=$serviceObjective} -retries $RetryAttemptsCount -secondsDelay $DelayInSecsToRetry -Verbose
	}
	else
	{
		#It executes New-AzureSqlDatabase command and retrys for '$RetryAttemptsCount' number of times if any failure
		Retry-Command -Command 'New-AzureSqlDatabase' -Args @{ConnectionContext= $ctx; DatabaseName = $databaseName;Edition=$databaseEdition; MaxSizeGB =$databaseMaxSizeGB} -retries $RetryAttemptsCount -secondsDelay $DelayInSecsToRetry -Verbose
	}
}

# This funciton generate Connection string for the given database

function global:Get-SQLAzureDatabaseConnectionString 
{ 
Param
( 
	#Database Server Name 
	[Parameter(Mandatory=$true)][String]$DatabaseServerName, 
	#Database name 
	[Parameter(Mandatory=$true)][String]$DatabaseName, 
	#Database User Name 
	[Parameter(Mandatory=$true)][String]$SqlDatabaseUserName , 
	#Database User Password 
	[Parameter(Mandatory=$true)][String]$Password,
	#ConnectionString Suffix
	[Parameter(Mandatory=$true)][String]$ConnectionStringSuffix
) 
	return "Server=tcp:{0}.{4},1433;Database={1};User ID={2}@{0};Password={3};Trusted_Connection=False;Encrypt=True;Connection Timeout=30;" -f $DatabaseServerName, $DatabaseName, $SqlDatabaseUserName , $Password, $ConnectionStringSuffix
}

# This funciton generate Connection string for the given database

function global:Get-SQLAzureDatabaseODBCConnectionString 
{ 
Param
( 
	#Database Server Name 
	[Parameter(Mandatory=$true)][String]$DatabaseServerName, 
	#Database name 
	[Parameter(Mandatory=$true)][String]$DatabaseName, 
	#Database User Name 
	[Parameter(Mandatory=$true)][String]$SqlDatabaseUserName , 
	#Database User Password 
	[Parameter(Mandatory=$true)][String]$Password,
	#ConnectionString Suffix
	[Parameter(Mandatory=$true)][String]$ConnectionStringSuffix 
) 
	return "Driver={SQL Server Native Client 11.0};Server=tcp:$DatabaseServerName.$ConnectionStringSuffix,1433;Database=$DatabaseName;Uid=$SqlDatabaseUserName@$DatabaseServerName;Pwd=$Password;Encrypt=Yes;Connection Timeout=30;" 
}


# This function creates DataBase User and gives permisssions to the user. 
function global:CreateSqlDatabaseUser
{
Param
( 
	#Database Server Name 
	[Parameter(Mandatory=$true)][String]$DatabaseServerName, 
	#Database name for which user is to be created
	[Parameter(Mandatory=$true)][String]$DatabaseName, 
	#Database Server User Name 
	[Parameter(Mandatory=$true)][String]$SqlDatabaseServerUserName , 
	#Database Server User Password 
	[Parameter(Mandatory=$true)][String]$SqlDatabaseServerUserPassword,
	#ConnectionString Suffix
	[Parameter(Mandatory=$true)][String]$ConnectionStringSuffix,
	#Sql Database User Name
	[Parameter(Mandatory=$true)][String]$SqlDatabaseUserName,
	#Sql Database User Password
	[Parameter(Mandatory=$true)][String]$SqlDatabaseUserPassword
)

	# Creates the connection string to Azure server for target db with ServerUser
	[string] $AzureSQLDBConnectionString = Get-SQLAzureDatabaseConnectionString -DatabaseServerName $DatabaseServerName -DatabaseName $DatabaseName -SqlDatabaseUserName $SqlDatabaseServerUserName  -Password $SqlDatabaseServerUserPassword -ConnectionStringSuffix $ConnectionStringSuffix

	#Creates the connection with the connection string
	$AzureSqlDBConnection = new-object system.data.SqlClient.SqlConnection($AzureSQLDBConnectionString)
		
	#Open the Connection to Target DB
	$AzureSqlDBConnection.Open()

	# Create Query to Check if the Login Exists
	$LoginUserExistsQuery = "SELECT name FROM sys.database_principals where default_schema_name = 'dbo' and name = '{0}';"-f $SqlDatabaseUserName
	
	#Create Sql command which will be executed 
	$cmd = New-Object System.Data.SqlClient.SqlCommand($LoginUserExistsQuery,$AzureSqlDBConnection)
	
	#execute the commad and fetch if the login exists
	$reader = $cmd.ExecuteReader()

	if($reader.Read())
	{
		#close the reader
		$reader.close()

		# User Exists just provide him the permission. As we have updated the password up we dont have to do it again
		 #Construct the query which will give permission
		$AzureUserCreationQuery = "ALTER USER {0} WITH PASSWORD = '{1}'; EXEC sp_addrolemember 'db_owner', '{0}';" -f $SqlDatabaseUserName, $SqlDatabaseUserPassword

		#Create Sql command which will be executed 
		$usercmd = New-Object System.Data.SqlClient.SqlCommand($AzureUserCreationQuery, $AzureSqlDBConnection)
	
	
		$usercmd.ExecuteNonQuery()
	}
	else
	{
		#close the reader
		$reader.close()

		# Construct the query which will create a user in the target db and give permission
		$AzureUserCreationQuery = "CREATE USER {0} WITH PASSWORD = '{1}'; EXEC sp_addrolemember 'db_owner', '{0}';" -f $SqlDatabaseUserName, $SqlDatabaseUserPassword

		#Create Sql command which will be executed 
		$usercmd = New-Object System.Data.SqlClient.SqlCommand($AzureUserCreationQuery, $AzureSqlDBConnection)
	
	
		$usercmd.ExecuteNonQuery()
	}

	#Close the connection to Target DB
	$AzureSqlDBConnection.Close()
}

# This function creates DataBase User and gives permisssions to the user. 
function global:CreateSqlServerAdmin
{
Param
( 
	#Database Server Name 
	[Parameter(Mandatory=$true)][String]$DatabaseServerName, 
	#Database Server User Name 
	[Parameter(Mandatory=$true)][String]$SqlDatabaseServerUserName , 
	#Database Server User Password 
	[Parameter(Mandatory=$true)][String]$SqlDatabaseServerUserPassword,
	#ConnectionString Suffix
	[Parameter(Mandatory=$true)][String]$ConnectionStringSuffix,
	#Sql Database User Name
	[Parameter(Mandatory=$true)][String]$SqlDatabaseServerAdmin,
	#Sql Database User Password
	[Parameter(Mandatory=$true)][String]$SqlDatabaseServerAdminPassword
)

	# Creates the connection string to Azure server for master db with ServerUser
	[string] $AzureSQLServerConnectionString = Get-SQLAzureDatabaseConnectionString -DatabaseServerName $DatabaseServerName -DatabaseName 'master' -SqlDatabaseUserName $SqlDatabaseServerUserName  -Password $SqlDatabaseServerUserPassword -ConnectionStringSuffix $ConnectionStringSuffix
	
	#Creates the connection with the connection string
	$AzureSqlServerConnection = new-object system.data.SqlClient.SqlConnection($AzureSQLServerConnectionString)

	# Open the connection to master db
	$AzureSqlServerConnection.Open()

	# Create Query to Check if the Login Exists
	$LoginExistsQuery = "SELECT name FROM sys.database_principals where default_schema_name = 'dbo' and name = '{0}';"-f $SqlDatabaseServerAdmin
	
	#Create Sql command which will be executed 
	$cmd = New-Object System.Data.SqlClient.SqlCommand($LoginExistsQuery,$AzureSqlServerConnection)
	
	#execute the commad and fetch if the login exists
	$reader = $cmd.ExecuteReader()
	
	#If Reader has value then Login exists
	if($reader.Read())
	{
		#close the reader
		$reader.close()

		#Create SQL Query to Update Login Password
		$UpdateLoginPasswordQuery = "ALTER LOGIN {0} with Password = '{1}';EXEC sp_addrolemember 'dbmanager', {0}; EXEC sp_addrolemember 'loginmanager', {0};" -f $SqlDatabaseServerAdmin, $SqlDatabaseServerAdminPassword

		#Create Sql command which will be executed 
		$cmd = New-Object System.Data.SqlClient.SqlCommand($UpdateLoginPasswordQuery,$AzureSqlServerConnection)

		#Execute the command to update the password
		$cmd.ExecuteNonQuery()
	}
	else
	{
		#close the reader
		$reader.close()

		# Construct the query which will create a login in the master db
		$AzureLoginCreationQuery = "CREATE LOGIN {0} WITH password='{1}'; CREATE USER {0} FROM LOGIN {0}; EXEC sp_addrolemember 'dbmanager', {0}; EXEC sp_addrolemember 'loginmanager', {0};" -f $SqlDatabaseServerAdmin, $SqlDatabaseServerAdminPassword
		#Create Sql command which will be executed 
		$cmd = New-Object System.Data.SqlClient.SqlCommand($AzureLoginCreationQuery,$AzureSqlServerConnection)

		$cmd.ExecuteNonQuery()
	}
	#Close the Connection to Master DB
	$AzureSqlServerConnection.Close()
}
# This function creates DataBase User and gives permisssions to the user. 
function global:CheckSqlServerFirewallRule
{
Param
( 
	#Database Server Name 
	[Parameter(Mandatory=$true)][String]$DatabaseServerName, 
	#FirewallRuleName which needs to be compared
	[Parameter(Mandatory=$true)][String]$FirewallRuleName 
)
	$ruleArray = Get-AzureSqlDatabaseServerFirewallRule -ServerName $DatabaseServerName

	$ruleExists = $FALSE
	ForEach($rule in $ruleArray) 
	{
		if($ruleArray.RuleName -eq $FirewallRuleName)
		{
			$ruleExists = $TRUE
			break
		}
	}
	return $ruleExists
}

