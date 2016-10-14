# $certFullPath provide Certificate path e.g.E:\Code\Deployment\Certificates\mdm.pfx
# $certPasword provide password for certificate that is given
# $dataSyncConfigFullPath prive the path for configuration file  e.g. E:\Code\src\SyncFramework\SyncCloudService\SyncCloudService\ServiceConfiguration.Cloud.cscfg
# $geoName passing geo location 'NAM','APJ','EUR','APJ','SAM','JPN','OCE','IND'
# $envName pass the envinoment name any of 'TEST','TIE','INT','PROD'
# execute it as .\GenerateMdmConfigParameters.ps1 -certFullPath 'E:\Code\Deployment\Certificates\mdm.pfx' -certPasword '****' -dataSyncConfigFullPath  'E:\Code\src\SyncFramework\SyncCloudService\SyncCloudService\ServiceConfiguration.Cloud.cscfg' -geoName 'NAM' -envName 'Test'

param(
  [Parameter(Mandatory=$true)]
  [string]$certFullPath,
  [Parameter(Mandatory=$true)]
  [string]$certPasword,
  [Parameter(Mandatory=$true)]
  [string]$dataSyncConfigFullPath,
  [Parameter(Mandatory=$true)]
  [ValidateSet('NAM','APJ','EUR','APJ','SAM','JPN','OCE','IND')]
  [string]$geoName,
  [Parameter(Mandatory=$true)]
  [ValidateSet('TEST','TIE','INT','PROD')]
  [string]$envName
)

Import-Module ".\ServiceGroupRoot\Mds\MdsDeployment.psm1";

# Getting the certificate details by passing the certificate url and its password
$cert = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2 ($CertFullPath, $CertPasword);
Add-CmaSettingsToCscfg -EnvironmentName $envName -GeoName $geoName -ServiceConfiguration $dataSyncConfigFullPath -MdmCertificate $cert -UseAutoKey;

Write-Host "Configuration change of MDM Parameter in file:" $dataSyncConfigFullPath  " replace successfully!!"