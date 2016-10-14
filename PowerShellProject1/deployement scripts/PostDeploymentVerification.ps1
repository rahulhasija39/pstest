param
(
	[parameter(Mandatory=$true)][string] $SubscriptionId,
	[parameter(Mandatory=$true)][string] $SubscriptionName,
	[parameter(Mandatory=$true)][string] $SubscriptionCertFilePath,
	[parameter(Mandatory=$true)][string] $ServiceNames,
	[parameter(Mandatory=$true)][string] $queueName,
	[parameter(Mandatory=$true)][string] $queueConnectionString,
	[string] [Parameter(Mandatory=$True)] [ValidateNotNull()]$orgId,
	[string] [Parameter(Mandatory=$True)] [ValidateNotNull()] $orgName,
	[string] [Parameter(Mandatory=$True)] [ValidateNotNull()] $orgODataEndPoint,
	$AnalyticsMdmEndpointURL,
	$AnalyticsMdmAccountName,
	$AnalyticsMdmNamespace,
	$AnalyticsMdmCertificatePath,
	$AnalyticsMdmCertificatePassword
)

. .\Lib\Config.ps1
. .\Lib\Shared.ps1
. .\Lib\ManageCertificates.ps1

$ErrorActionPreference = "Stop"
# Make sure that it is in AzureServiceManagement mode initially to make Service cmdlets workable

Switch-AzureMode AzureServiceManagement
if(-not (Get-Module Azure))
{
	Write-Error "This script needs to be run in Azure PowerShell"
}

Set-Location -Path $PSScriptRoot

. .\Lib\WaitTillServiceReady.ps1

# Mark the start time of the script execution 
$StartTime = Get-Date 

# Step 2: Set AzureSubscriptions
$SubscriptionId = ValidateConfigParam "Azure Subscription Id" $SubscriptionId
$SubscriptionName = ValidateConfigParam "Azure Subscription Name" $SubscriptionName
$SubscriptionCertFilePath = ValidateConfigParam "Azure Subscription Management Certificate path" $SubscriptionCertFilePath
$SubscriptionCertFilePath = GetFilePath $SubscriptionCertFilePath

Write-Host -BackgroundColor DarkGreen "Subscription: Setting up the storage accounts for subscription id $($SubscriptionId)."

Set-AzureSubscription -SubscriptionId $SubscriptionId -SubscriptionName $SubscriptionName -Certificate (GetCertificate $SubscriptionCertFilePath)
Select-AzureSubscription -Current -SubscriptionId $SubscriptionId

$ServiceNames.Split(",") | ForEach {
    $ServiceName = $_
    Write-Host "Wait for Cloud service $ServiceName to be in running state."

	# Wait till Service Ready (Role instances Ready)
	WaitTillServiceReady $ServiceName
	Write-Host "Cloud Service $ServiceName is in running state.";
 }

Write-Host -BackgroundColor DarkGreen "Mobile offline deployment is in running state."


if ($AnalyticsMdmEndpointURL -ne $null)
{
	# Test MDM certificates
add-type @"
	using System.Net;
	using System.Security.Cryptography.X509Certificates;
	public class TrustAllCertsPolicy : ICertificatePolicy {
		public bool CheckValidationResult(
			ServicePoint srvPoint, X509Certificate certificate,
			WebRequest request, int certificateProblem) {
			return true;
		}
	}
"@;



	$MdmEndpoint = "$($AnalyticsMdmEndpointURL)/api/v2/config/metrics/monitoringAccount/$($AnalyticsMdmAccountName)/metricNamespace/$($AnalyticsMdmNamespace)/metric/%255CMemory%255CAvailable%2520MBytes/monitorIds"
	[System.Net.ServicePointManager]::CertificatePolicy = New-Object TrustAllCertsPolicy

	$CurrentDirectory = Convert-Path .
	$CertLocation = GetFilePath $AnalyticsMdmCertificatePath $CurrentDirectory;


	$Cert = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2($CertLocation, $AnalyticsMdmCertificatePassword);
	$r = Invoke-WebRequest -Uri $MdmEndpoint -Certificate $Cert

	# Check reponse code
	$code = [int]$r.StatusCode;
	if ([int]$r.StatusCode -eq 200)
	{
		Write-Host -BackgroundColor DarkGreen "MDM certificate verification successful"
	}
	else
	{
		Write-Host -BackgroundColor Red "MDM certificate verification failed with status code $code"
	}

}

# Create a new XML File with config root node
[System.XML.XMLDocument]$oXMLDocument=New-Object System.XML.XMLDocument
# New Node
[System.XML.XMLElement]$oXMLRoot=$oXMLDocument.CreateElement("MobileOfflineUtilityConfig")
# Append as child to an existing node
$oXMLDocument.appendChild($oXMLRoot)  2>&1 | Out-Null

#Generate service bus info
[System.XML.XMLElement]$_serviceBusInfo = $oXMLDocument.CreateElement("ServiceBus");
	[System.XML.XMLElement]$_queueName = $oXMLDocument.CreateElement("queueName");
	$_queueName.InnerText = $queueName
	[System.XML.XMLElement]$_queueConnectionString=$oXMLDocument.CreateElement("queueConnectionString");
	$_queueConnectionString.InnerText = $queueConnectionString;
	$_serviceBusInfo.appendChild($_queueName)  2>&1 | Out-Null;
	$_serviceBusInfo.appendChild($_queueConnectionString)  2>&1 | Out-Null;
$oXMLRoot.appendChild($_serviceBusInfo)  2>&1 | Out-Null;

# Generate Organizations info
[System.XML.XMLElement]$_Organizations=$oXMLDocument.CreateElement("Organizations")
	[System.XML.XMLElement]$_Organization=$oXMLDocument.CreateElement("Organization")
		[System.XML.XMLElement]$_id=$oXMLDocument.CreateElement("id")
		$_id.InnerText = $orgId
		[System.XML.XMLElement]$_name=$oXMLDocument.CreateElement("name");
		$_name.InnerText = $orgName
		[System.XML.XMLElement]$_connectionString=$oXMLDocument.CreateElement("connectionString");
		$_connectionString.InnerText = $orgODataEndPoint;
		$_Organization.appendChild($_id)  2>&1 | Out-Null;
		$_Organization.appendChild($_name)  2>&1 | Out-Null;
		$_Organization.appendChild($_connectionString)  2>&1 | Out-Null;
	$_Organizations.appendChild($_Organization)  2>&1 | Out-Null;
$oXMLRoot.appendChild($_Organizations)  2>&1 | Out-Null;

#Generate WorkItem info
[System.XML.XMLElement]$_WorkItem=$oXMLDocument.CreateElement("WorkItem")
	[System.XML.XMLElement]$_WorkItemParameters=$oXMLDocument.CreateElement("WorkItemParameters")
	$_WorkItemParameters.SetAttribute("type","MobileOfflineDeploymentVerification")  2>&1 | Out-Null
	$_WorkItem.appendChild($_WorkItemParameters)  2>&1 | Out-Null;
	$_WorkItemParameters.InnerText = "";
$oXMLRoot.appendChild($_WorkItem)  2>&1 | Out-Null;


# Save to File
$outFileLocation = [string]$PWD + "\" + "config.xml";
$oXMLDocument.Save($outFileLocation)

# Post message to the queue

Write-Host -BackgroundColor DarkGreen "Posting verification message to the queue..."

# TODO uncomment below line once build definition is changed to include the exe
.\Tools\MobileOfflineUtility\MobileOfflineUtility.exe --mode=Send --config=$outFileLocation

# Mark the finish time of the script execution
$finishTime = Get-Date 

# Output the time consumed in seconds
Write-Host ("Total time used (seconds): {0}." -f ($finishTime - $StartTime).TotalSeconds) 
