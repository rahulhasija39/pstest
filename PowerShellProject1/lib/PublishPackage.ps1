#This function will deploy the service with name name  and with in the location

function global:Publish
{
Param
(
	[Parameter(Mandatory=$true)][string] $ServiceName,
	[Parameter(Mandatory=$true)][string] $ServiceSlot,
	[Parameter(Mandatory=$true)][string] $packageFilePath,
	[Parameter(Mandatory=$true)][string] $configFilePath,
	[Parameter(Mandatory=$true)][string] $ServiceDeploymentLabel
)

	#This command gets if any existign deployments for the service, if no deployment found it throws an error which can be ignored.
	$deployment = Get-AzureDeployment -ServiceName $ServiceName -Slot $ServiceSlot -ErrorAction silentlycontinue 

	if ($deployment.Name -ne $null) 
	{
		Write-Host "$(Get-Date) - Deployment already exists for $($ServiceName), Upgrading deployment."
		Write-progress -id 3 -activity "Upgrading Deployment $($ServiceName)" -Status "In progress"
		#Check if PackageFilePath usually a BLOB exists
		# perform Upgrade Deployment
		$opstat = Set-AzureDeployment -ServiceName $ServiceName -Slot $ServiceSlot -Configuration $configFilePath -Package $packageFilePath -Label $ServiceDeploymentLabel -Mode Simultaneous -Upgrade
	
		Write-progress -id 3 -activity "Upgrading Deployment" -completed -Status "Complete"
	}
	else
	{
		Write-progress -id 3 -activity "Creating New Deployment $($ServiceName)" -Status "In progress"
		Write-Output "$(Get-Date) - Creating New Deployment $($ServiceName): In progress"
	
		#The following command will run 'New-AzureDeployment' comamnd to deploy the service for $RetryAttemptsCount number of times
		$opstat = New-AzureDeployment -ServiceName $ServiceName -Slot $ServiceSlot -Configuration $configFilePath -Package $packageFilePath -Label $ServiceDeploymentLabel
	
		Write-progress -id 3 -activity "Creating New Deployment" -completed -Status "Complete"
	}
}

#function to publish package
function global:PublishOld
{
Param
(
	[Parameter(Mandatory=$true)][string] $ServiceName,
	[Parameter(Mandatory=$true)][string] $ServiceSlot,
	[Parameter(Mandatory=$true)][string] $packageFilePath,
	[Parameter(Mandatory=$true)][string] $configFilePath,
	[Parameter(Mandatory=$true)][string] $ServiceDeploymentLabel
)
	#Publish Service
	Try 
	{
		Write-Output "Upgrading Azure Deployment" 
		Write-Output $ServiceName
		Write-Output $configFilePath
		Write-Output $packageFilePath
		Write-Output $ServiceDeploymentLabel
		$AzureService = Set-AzureDeployment -ServiceName $ServiceName -Slot $ServiceSlot -Configuration $configFilePath -Package $packageFilePath -Label $ServiceDeploymentLabel -Mode Simultaneous -Upgrade
		Write-Verbose ("[Finish] Deploy Service {0} updated" -f $ServiceName)
	}
	Catch
	{
		Write-Output "Creating Azure Deployment"
		Write-Output $ServiceName
		Write-Output $configFilePath
		Write-Output  $packageFilePath
		Write-Output $ServiceDeploymentLabel
		$AzureService =  New-AzureDeployment -ServiceName $ServiceName -Slot $ServiceSlot -Configuration $configFilePath -Package $packageFilePath -Label $ServiceDeploymentLabel
		Write-Verbose ("[Finish] Deploy Service {0} deployed" -f $ServiceName)
	}
}