#Get Abbrevation for the passed in location. For eg., if Location is 'West Asia', abbreavation will be  "WA "

function global:GetGeoLocationAbbr
{
Param
(
	[Parameter(Mandatory=$true)][string] $location
)
	return [system.String]::Join("", ($location.Split(" ") | foreach {$_[0]})).ToLower()
}

#Reads password as Secure string.

function global:RequestPasswordFromUser
{
Param
(
	[Parameter(Mandatory=$true)][string] $message
)
	$pass = Read-Host $message -AsSecureString
	return [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($pass))
}

#This function throws error if passed in value is not a GUID
function global:ValidateGuid
{
Param
(
	[Parameter(Mandatory=$true)][string] $ParamName,
	[Parameter(Mandatory=$false)][string] $ParamValue
)
	if(-not $($ParamValue -match("^(\{){0,1}[0-9a-fA-F]{8}\-[0-9a-fA-F]{4}\-[0-9a-fA-F]{4}\-[0-9a-fA-F]{4}\-[0-9a-fA-F]{12}(\}){0,1}$")))
	{
		Write-Error "Invalid Guid provided for $ParamName"
	}

}
# This function checks if file exists, else throws error
function global:CheckFileExists
{
param
(
	[parameter(Mandatory=$true)][String] $FilePath,
	[parameter(Mandatory=$true)][String] $FileDescription
)
	if(-not $FilePath  -or -not $(Test-Path( $(GetFilePath $FilePath))))
	{
		Write-Error "No valid file found for $FileDescription"
	}
}

#It checks if file exists, if not creates one

function global:Ensure-File-Exists
{
param
(
	[parameter(Mandatory=$true)][String]$FilePath
)
	#If not exists already, create one
	$FilePath = $(GetFilePath $FilePath)
	#"Test-Path" is a powershell built-in function to test if file exists and returns a boolean true/false value
	if(-not $(Test-Path( $FilePath)) )
	{
		New-Item $FilePath -type file -force
	}
	return $FilePath
}

# Generate a random Alphanumeric with the passed in length
# Usage: random-Alphanumeric <length>

Function global:Generate-Random-Alphanumeric 
{
Param
(
	[parameter(Mandatory=$true)]$length
)
	$alphanumeric = 'abcdefghijklmnopqrstuvwxyz0123456789'.ToCharArray()
	return [String]::Join('', (1..$length | % { $alphanumeric | Get-Random }))
}

# This function trys to read the input from user, and throws error if it is null 

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

# This function throws error if the input is null 

function global:ThrowErrorIfNull
{
param
(
	[parameter(Mandatory=$false)]$InputParam,
	[parameter(Mandatory=$true)]$ValidateMsg
)
	if (!$InputParam)
	{
		Write-Error $ValidateMsg
	}
}

# This function validates the given parameter and gracefully exits the application if it is null

function global:ValidateConfigParam
{
param
(
	[parameter(Mandatory=$true)]$ConfigParamName,
	[parameter(Mandatory=$true)]$ConfigParam
)
	if (!$ConfigParam)
	{
		Write-Warning "Please update the parameter $ConfigParamName in config xml and re-run the script."
		Exit
	}else
	{
		return $ConfigParam
	}
}