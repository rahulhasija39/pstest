# This is very specific to IFD test setup and is not required in Online environments

param(
  [Parameter(Mandatory=$true)]
  [string]$ServiceGroupRoot,
  [Parameter(Mandatory=$true)]
  [string]$DeploymentDefinitionName,
  [Parameter(Mandatory=$false)]
  [boolean]$IsRunningOnCRMServer = $true,
  [Parameter(Mandatory=$false)]
  [string]$CRMServerAdminPassword = $null,
  [Parameter(Mandatory=$false)]
  [string]$username = "devadmin",
  [Parameter(Mandatory=$false)]
  [string]$OrganizationBaseUrl,
  [Parameter(Mandatory=$false)]
  [Object]$logObject = $null
)

Set-Location -Path $PSScriptRoot

. .\FindAndReplaceStringInFiles.ps1
. .\FileLogger.ps1

if($logObject -eq $null)
{
    # Create a log directory if doesnt exists and log object.
    New-Item $PSScriptRoot\..\Logs -type directory -Force
    $logPath = "$PSScriptRoot\..\Logs"
    $logObject = StartLog("$logPath\UpdateDeploymentConfigToReplaceOrgID.log")
}

$logObject.WriteInformation("[UpdateDeploymentConfigToReplaceOrgID]: ServiceGroupRoot: $ServiceGroupRoot")
$configurationsFolder = Join-Path $ServiceGroupRoot "Configurations"
$logObject.WriteInformation("[UpdateDeploymentConfigToReplaceOrgID]: ConfigurationsFolder: $configurationsFolder")

$OrganizationId = $null

if($IsRunningOnCRMServer)
{
    #Get organization Id from the database
    $list = Invoke-Sqlcmd -Query "Select * from Sys.Databases"
    $database = $list | Where-Object {$_.name -match "_mscrm"}
    $logObject.WriteInformation(('[UpdateDeploymentConfigToReplaceOrgID] Organization database retrieved: {0} ' -f $database.name))
    $logObject.WriteInformation('[UpdateDeploymentConfigToReplaceOrgID] Retrieving Organization ID from DB')
    $OrganizationBaseObj = Invoke-Sqlcmd -database $database.name -Query "Select OrganizationId from OrganizationBase"
    $OrganizationId = $OrganizationBaseObj.OrganizationId.ToString()
}
else {
    #Add credential informations
    if([string]::IsNullOrEmpty($OrganizationBaseUrl))
    {
        $logObject.WriteError("[UpdateDeploymentConfigToReplaceOrgID]: Organization base URL is null or empty")
        Throw "Organization base URL cannot be null or empty."
    }
    $orgHostName = ([System.Uri]$OrganizationBaseUrl).Host
    if([string]::IsNullOrEmpty($orgHostName))
    {
        $logObject.WriteError("[UpdateDeploymentConfigToReplaceOrgID]: Organization base URL format is wrong")
        Throw "Organization base URL format is wrong. Sample format:http://vamshichifd2:5555/org1"
    }
    $logObject.WriteInformation("[UpdateDeploymentConfigToReplaceOrgID]: Using the default credentials");

    $orgDomain = $orgHostName+"DOM"
    $user = $orgDomain+"\Administrator"
    $password = ConvertTo-SecureString -AsPlainText $CRMServerAdminPassword -Force -ErrorAction Stop
    $cred = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $user, $password

    #Get the organization ID
    # Remove trailing spaces and /
    $OrganizationBaseUrl = $OrganizationBaseUrl.Trim()
    $OrganizationBaseUrl = $OrganizationBaseUrl.TrimEnd('/')

    $logObject.WriteInformation("[UpdateDeploymentConfigToReplaceOrgID]: Creating the URI")
    #Create URI
    $orgUri = $OrganizationBaseUrl + "/api/data/v8.0/RetrieveCurrentOrganization(AccessType=Microsoft.Dynamics.CRM.EndpointAccessType'Default')"
    $logObject.WriteInformation("[UpdateDeploymentConfigToReplaceOrgID]: URI to get the organization ID $orgUri")
    $logObject.WriteInformation("[UpdateDeploymentConfigToReplaceOrgID]:Invoking the OData call to get organization information")
    $organizationInfo = Invoke-RestMethod -Uri $orgUri -Credential $cred -ErrorAction Stop
    $OrganizationId = $organizationInfo.Detail.OrganizationId
}

$logObject.WriteInformation("[UpdateDeploymentConfigToReplaceOrgID]:OrganizationId: $OrganizationId")

$orgIdSlug = "#ORG_ID#"
$deploymentIdentifier = $username.ToLower().Substring(0,5) + $DeploymentDefinitionName.ToLower()

$logObject.WriteInformation("[UpdateDeploymentConfigToReplaceOrgID]:Replacing organization information in all the cscfg files")
FindAndReplace $configurationsFolder $orgIdSlug $OrganizationId "DataSync.ServiceConfiguration.$deploymentIdentifier*.cscfg"

FindAndReplace $configurationsFolder $orgIdSlug $OrganizationId "Provisioning.ServiceConfiguration.$deploymentIdentifier*.cscfg"

return $OrganizationId