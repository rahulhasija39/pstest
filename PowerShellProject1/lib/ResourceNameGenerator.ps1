#Generates a unique resource name like ResourceNamePrefix + Location Abbreviation + RandomAlphanumeric

function global:ResourceNameGenerator
{
Param
(
	[Parameter(Mandatory=$true)][string] $ResourceNamePrefix,
	[Parameter(Mandatory=$true)][string] $Location,
	[Parameter(Mandatory=$true)][string] $DeploymentType,
	[Parameter(Mandatory=$false)][string] $RandomStringSuffix
)
	if ($ResourceNamePrefix -eq $null)
	{
		return
	}

	if ($Location)
	{
		$LocationSuffix = GetGeoLocationAbbr $Location;
	}

	if ($DeploymentType -ieq "Production")
	{
		$DeploymentTypeSuffix = "p"
	}

	if ($DeploymentType -ieq "Trial")
	{
		$DeploymentTypeSuffix = "t"
	}

	#Append location abbreviation and random string to the Resource name, to avoid name conflicts
	$ResourceName = $($ResourceNamePrefix + $LocationSuffix + $DeploymentTypeSuffix + $RandomStringSuffix).ToLower()
	
	return $ResourceName
}
