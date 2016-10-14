param
(
	[parameter(Mandatory=$true)][string] $SiteMachineName,
	[parameter(Mandatory=$true)][string] $SqlScriptPath
)

# Validate Input Paramater
function global:ReadAndValidateInput
{
param
(
	[parameter(Mandatory=$true)]$InputParamName,
	[parameter(Mandatory=$false)]$InputParam
)
	if(!$InputParam)
	{
		$InputParam = Read-Host "Please enter the $InputParamName"
	}

	if (!$InputParam)
	{
		Write-Error "No value for $InputParamName is specified"
	}
	return $InputParam
}

$SiteMachineName = ReadAndValidateInput "Site Machine Name:" $SiteMachineName
$SqlScriptPath = ReadAndValidateInput "Sql Script Path:" $SqlScriptPath

$CurrentDirectory = Convert-Path .

Set-Location SQLSERVER:\SQL\$SiteMachineName\DEFAULT\Databases\mscrm_config_sitewide
Invoke-Sqlcmd -InputFile $SqlScriptPath

cd $CurrentDirectory

write-host "`n"
write-host "`n"
