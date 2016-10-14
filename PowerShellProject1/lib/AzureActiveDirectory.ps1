# Azure Active directory script


# This method will create the Azure AD Application and service principal associated with the same.
# This method will then return the service principal.
# the script is reentrant. So if a service principal is already existing with the same name, it will reuse it.
function global:CreateAzureADApplicationWithCertCredentials
{
param
(
    [parameter(Mandatory=$true)][string] $ADApplicationCertificateFilePath = $null,
    [parameter(Mandatory=$true)][string] $ApplicationName = $null,
    [parameter(Mandatory=$true)][string] $HomePageUri = $null,
    [parameter(Mandatory=$true)][string] $IndentifierUri = $null
)

# Initialize variables
$adApplication = $null
$adApplicationId = $null
$servicePrincipal = $null
$servicePrincipals = @()
# If the service principal is already there, do not create it again
$servicePrincipals += Get-AzureADServicePrincipal -SearchString $ApplicationName -ErrorAction Ignore
if ($servicePrincipals.Count -gt 0)
{
    Write-Warning "Warning:There is already a service principal with the same name. We will start using the same"
    Write-Warning ($servicePrincipals[0] | Format-List | Out-String)
    $servicePrincipal = $servicePrincipals[0]
    $adApplicationId = $servicePrincipal.ApplicationId 
}

if(-not $adApplicationId)
{
    # Get the AAD certificate
    $certificate = GetCertificate -certFilePath $ADApplicationCertificateFilePath
    $rawCertificateData = $certificate.GetRawCertData()
    $credential = [System.Convert]::ToBase64String($rawCertificateData)
    $startDate= $certificate.NotBefore.ToUniversalTime()
    $endDate = $certificate.NotAfter.ToUniversalTime()

    # Create a new AD application
    $adApplication = New-AzureADApplication -DisplayName $ApplicationName -HomePage $HomePageUri  -IdentifierUris $IndentifierUri -KeyValue $credential -KeyType "AsymmetricX509Cert" -KeyUsage "Verify" -StartDate $startDate -EndDate $endDate
    $adApplicationId = $adApplication.ApplicationId 
    Write-Host "Created new AD application successfully. Client ID: " $adApplication.ApplicationId

    # Create new service principal
    $servicePrincipal = New-AzureADServicePrincipal -ApplicationId $adApplicationId
    Write-Host "Created new service principal successfully"
}

# Return service principal 
return ($adApplication,$servicePrincipal)
}