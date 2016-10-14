param(
    [Parameter(Mandatory=$true)]
    [string]$ServiceGroupRoot,
    [Parameter(Mandatory=$true)]
    [string]$DeploymentDefinitionName,
    [Parameter(Mandatory=$false)]
    [string]$username = "devadmin",
    [Parameter(Mandatory=$true)]
    [string]$AzureSubscriptionCertFileFullPath,
    [Parameter(Mandatory=$false)]
    [int]$subnetToUse = 0,
    [Parameter(Mandatory=$false)]
    [Object]$logObject = $null
)

Set-Location -Path $PSScriptRoot

. .\ManageCertificates.ps1
. .\FindAndReplaceStringInFiles.ps1
. .\FileLogger.ps1

$ServiceGroupRoot = $ServiceGroupRoot.Trim()
$ServiceGroupRoot = $ServiceGroupRoot.Trim('\')

if($logObject -eq $null)
{
    # Create a log directory if doesnt exists and log object.
    New-Item $PSScriptRoot\..\Logs -type directory -Force
    $logPath = "$PSScriptRoot\..\Logs"
    $logObject = StartLog("$logPath\UpdateDeploymentConfigToUseExistingVNet.log")
}

# Method to look at the set of subnets available and use one of them
function GetAvailableSubnet([string]$subscriptionId, [string]$subscriptionName, [string]$vNetName)
{
    $retval = $null
    $logObject.WriteInformation("[UpdateDeploymentConfigToUseExistingVNet]: Getting Available subnet.. SubscriptionCertFilePath: $AzureSubscriptionCertFileFullPath")
    # Connect to azure subscription
    Set-AzureSubscription -SubscriptionId $subscriptionId -SubscriptionName $subscriptionName -Certificate (GetCertificate $AzureSubscriptionCertFileFullPath) -ErrorAction Stop
    Select-AzureSubscription -Current -SubscriptionId $subscriptionId -ErrorAction Stop
    $i = 0

    # Try for 1000 times and if it fails, just return failure
    while($i -lt 1000)
    {
        $randomSubnet = Get-Random -minimum 1 -maximum 50 -SetSeed (Get-Date).Millisecond
        
        $logObject.WriteInformation("[UpdateDeploymentConfigToUseExistingVNet]:Random Number generated is" + $randomSubnet)
        $logObject.WriteInformation("[UpdateDeploymentConfigToUseExistingVNet]:Testing if subnet is picked up  Subnet-" + $randomSubnet)
        # Use the default load balancer ID
        $ipAddressToTest = "10." + $randomSubnet + ".2.4"

        # Test if the static IP is already assigned
        $IPAddressState = Test-AzureStaticVNetIP -VNetName $vNetName -IPAddress $ipAddressToTest -ErrorAction Ignore
        if(!($IPAddressState -eq $null) -and ($IPAddressState.IsAvailable))
        {  
            return $randomSubnet
        }
        $logObject.WriteInformation("[UpdateDeploymentConfigToUseExistingVNet]:This subnet is already used or failed to connect to VNET. Retrying..")
        $i++        
    }
    $logObject.WriteError("[UpdateDeploymentConfigToUseExistingVNet]: Unable to find a subnet which is free")
    Throw "Unable to find unassigned subnet"
}

# A mapper method that returns the location ID given a location
function GetVNetScaleUnit([string] $azureLocation)
{
    switch($azureLocation)
    {
        "East Asia" {return "ifd_ea"}
        "East US" {return "ifd_eu"}
        "South Central US" {return "ifd_scu"}
        "East US 2" {return "ifd_eu2"}
        "North Europe" {return "ifd_ne"}
        "West Europe" {return "ifd_we"}
        "Southeast Asia" {return "ifd_sa"}
    }
}

# Now start updating the deployments generated for IFD setup

$logObject.WriteInformation("[UpdateDeploymentConfigToUseExistingVNet]: ServiceGroupRoot: $ServiceGroupRoot")
$configurationsFolder = Join-Path $ServiceGroupRoot "Configurations"
$logObject.WriteInformation("[UpdateDeploymentConfigToUseExistingVNet]: ConfigurationsFolder: $configurationsFolder")
$parametersFolder = Join-Path $ServiceGroupRoot "Parameters"
$logObject.WriteInformation("[UpdateDeploymentConfigToUseExistingVNet]: ParametersFolder: $parametersFolder")
cd $parametersFolder

# Get the VNET details

$deploymentIdentifier = $username.ToLower().Substring(0,5) + $DeploymentDefinitionName.ToLower()
$vNetParamFilename = "VNet.Parameters.$deploymentIdentifier*.json"

#For each configuration

Get-ChildItem $parametersFolder -Filter $vNetParamFilename | foreach-object {
    cd $parametersFolder
    $file = $_
    $fullDeploymentIdentifier = $file.BaseName.Substring(16)
    $logObject.WriteInformation("[UpdateDeploymentConfigToUseExistingVNet]:vNetParamFilename that is being updated : $file")
    $logObject.WriteInformation("[UpdateDeploymentConfigToUseExistingVNet]:Deployment Identifier: $fullDeploymentIdentifier")
      
    $configContent = (get-content -Raw $file | ConvertFrom-Json)
      
    #Get the azure subscription ID which is used for this specific deployment
    $DeploymentDefFile =  $ServiceGroupRoot + "\DeploymentDefinitions.json"
    $DeploymentDefContent =  (get-content -Raw $DeploymentDefFile | ConvertFrom-Json)
    $deploymentDefinition  = $DeploymentDefContent.$DeploymentDefinitionName
    $azureSubscriptionId = $deploymentDefinition.AzureSubscriptionId
    $azureSubscriptionName = $deploymentDefinition.AzureSubscriptionName
    $azureLocation = $deploymentDefinition.Location
    $logObject.WriteInformation("[UpdateDeploymentConfigToUseExistingVNet]:Getting Azure subscription details from deployment definition")
    $logObject.WriteInformation("[UpdateDeploymentConfigToUseExistingVNet]:Azure subscription ID:  $azureSubscriptionId")
    $logObject.WriteInformation("[UpdateDeploymentConfigToUseExistingVNet]:Azure subscription Name:  $azureSubscriptionName")
    $logObject.WriteInformation("[UpdateDeploymentConfigToUseExistingVNet]:Location:  $azureLocation")

    #Get all the contents from VNET file specific to this deployment
    $oldScaleunit = [System.String]::Copy($configContent.parameters.scaleUnit.value)
    $oldGeoIdentifier = [System.String]::Copy($configContent.parameters.geoIdentifier.value)
    $oldVnetNamePrefix = [System.String]::Copy($configContent.parameters.vnetNamePrefix.value)
    $oldVnetAddressPrefix = [System.String]::Copy($configContent.parameters.vnetAddressPrefix.value)
    $oldSubnet1Prefix = [System.String]::Copy($configContent.parameters.subnet1Prefix.value)
    $oldSubnet1Name = [System.String]::Copy($configContent.parameters.subnet1Name.value)
    $oldStaticVirtualNetworkIPAddress = [System.String]::Copy($configContent.parameters.StaticVirtualNetworkIPAddress.value)

    $scaleUnit = [string](GetVNetScaleUnit -azureLocation $azureLocation)
    $logObject.WriteInformation("[UpdateDeploymentConfigToUseExistingVNet]: Getting the available subnet")
    if($subnetToUse -eq 0)
    {
        $subnetToUse = GetAvailableSubnet -subscriptionId $azureSubscriptionId -subscriptionName $azureSubscriptionName -vNetName "mobileoffline_vnetdev$scaleUnit"
    }
    $logObject.WriteInformation("[UpdateDeploymentConfigToUseExistingVNet]:VNET's subnet selected: Subnet-$subnetToUse")
    $logObject.WriteInformation("[UpdateDeploymentConfigToUseExistingVNet]:Updating new VNET details in cscfg and params files")

    # Update them with dev setup specific values
    $configContent.parameters.scaleUnit.value = $newScaleunit = $scaleUnit
    $configContent.parameters.geoIdentifier.value = $newGeoIdentifier = "dev"
    $configContent.parameters.vnetNamePrefix.value = $newVnetNamePrefix = "mobileoffline_vnet"
    $configContent.parameters.vnetAddressPrefix.value = $newVnetAddressPrefix = "10.0.0.0/8"
    $configContent.parameters.subnet1Prefix.value = $newSubnet1Prefix = "10." + $subnetToUse + ".0.0/16"
    $configContent.parameters.subnet1Name.value = $newSubnet1Name = "Subnet-" + $subnetToUse
    $configContent.parameters.StaticVirtualNetworkIPAddress.value = $newStaticVirtualNetworkIPAddress = "10." + $subnetToUse + ".2.4"

    $oldVirtualNetworkSite = $oldVnetNamePrefix + $oldGeoIdentifier + $oldScaleunit
    $newVirtualNetworkSite = $newVnetNamePrefix + $newGeoIdentifier + $newScaleunit

    # Write it back to file
    $configContent | ConvertTo-Json -Depth 999 | Out-File $file -Encoding utf8
    
    $logObject.WriteInformation("[UpdateDeploymentConfigToUseExistingVNet]: Replacing the VNET information in the configuration files")
      
    #Replace values in config file too
    FindAndReplace $configurationsFolder $oldVirtualNetworkSite $newVirtualNetworkSite "DataSync.ServiceConfiguration.$fullDeploymentIdentifier.cscfg"
    FindAndReplace $configurationsFolder $oldVirtualNetworkSite $newVirtualNetworkSite "Provisioning.ServiceConfiguration.$fullDeploymentIdentifier.cscfg"

    FindAndReplace $configurationsFolder $oldSubnet1Name $newSubnet1Name "DataSync.ServiceConfiguration.$fullDeploymentIdentifier.cscfg"
    FindAndReplace $configurationsFolder $oldSubnet1Name $newSubnet1Name "Provisioning.ServiceConfiguration.$fullDeploymentIdentifier.cscfg"

    FindAndReplace $configurationsFolder $oldStaticVirtualNetworkIPAddress $newStaticVirtualNetworkIPAddress "DataSync.ServiceConfiguration.$fullDeploymentIdentifier.cscfg"
    FindAndReplace $configurationsFolder $oldStaticVirtualNetworkIPAddress $newStaticVirtualNetworkIPAddress "Provisioning.ServiceConfiguration.$fullDeploymentIdentifier.cscfg"


    #TODO: Modify Acis Config for online deployments

    # Updating the registry file too
    # Unfortunately findstr doesnt work on registry files. So creating a new reg file
    $logObject.WriteInformation("[UpdateDeploymentConfigToUseExistingVNet]: Creating the registry entry for the ")
    $DepAutomationArtifactsFolder = Join-Path $ServiceGroupRoot "\..\TestSetupAutomationArtifacts"
    $cloudServiceSlug = "#CLOUD_SERVICE_NAME#"
    $registryContent = Get-Content -Raw $DepAutomationArtifactsFolder\NorsyncConnectionStringForIFD.reg
    $modifiedRegistryContent = $registryContent -replace $cloudServiceSlug, "datasync$fullDeploymentIdentifier"
    $fileObject = new-object -comobject scripting.filesystemobject -ErrorAction Stop
    $file = $fileObject.CreateTextFile("$DepAutomationArtifactsFolder\NorsyncConnectionStringForIFD_$fullDeploymentIdentifier.reg" ,$true)  #will overwrite any existing file 
    $file.write($modifiedRegistryContent)
    $file.close()
    $logObject.WriteInformation("[UpdateDeploymentConfigToUseExistingVNet]: Update completed for the file.")
        
}

