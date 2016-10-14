------------------------------------------------------------------------------------------------------------------------
-------------Help Guide to Generate the MDM parameters ---------------------------------------------
------------------------------------------------------------------------------------------------------------------------
--This Readme File explains the purpose of this script. 

This is a pre-deployment step and is a manual step. 
The script helps generate cloud config files based on ServiceConfiguration.cscfg for the deployment. 
Usage: 
---------
.\GenerateMdmConfigParameters.ps1 -certFullPath 'E:\Code\Deployment\Certificates\mdm.pfx' -certPasword '****' -dataSyncConfigFullPath  'E:\Code\src\SyncFramework\SyncCloudService\SyncCloudService\ServiceConfiguration.Cloud.cscfg' -geoName 'NAM' -envName 'Test' 
------------------------------------------------------------------------------------------------------------------------

Steps:
=======
a) Prerequisites before proceeding: 
1.	Certificate for the environment that you want to install. e.g. Prod, test.
2.	Password for the certificate.
3.	CSCFG file path.

b) Which Certificate?
Please get the MDM certificate and password for the environment that you are installing on.

c) Location of CSCFG file:
Get the CSCFG file from 
\\crmbuilds\Builds\VSOCloudBuilds\MicrosoftCrmDataSync\git_master\1.1.0.0030\retail\ServiceGroupRoot\ServiceGroupRoot\Configurations


d) Steps to get Configuration parameters for MDM 
1.	Open the power shell ISE as administrator.
2.	Go to the path where you have GenerateMdmConfigParameters.ps1 file and run that file below.
		PS E:\Code\NorSync1907\Deployment> ..\GenerateMdmConfigParameters.ps1 
3.	While executing file you need to pass below parameters as:

.\GenerateMdmConfigParameters.ps1 -certFullPath 'E:\Code\Deployment\Certificates\mdm.pfx' -certPasword '****' -dataSyncConfigFullPath  'E:\Code\src\SyncFramework\SyncCloudService\SyncCloudService\ServiceConfiguration.Cloud.cscfg' -geoName 'NAM' -envName 'Test' 





Parameters explained:
============================
$certFullPath provide Certificate path e.g. E:\Code\Deployment\Certificates\mdm.pfx
$certPasword provide password for certificate that is given.
$dataSyncConfigFullPath prive the path for configuration file e.g. E:\Code\src\SyncFramework\SyncCloudService\SyncCloudService\ServiceConfiguration.Cloud.cscfg
$geoName passing geo location 'NAM','APJ','EUR','APJ','SAM','JPN','OCE','IND' [ this needs to be updated on addition / removal of geo location]
$envName pass the environment name any of 'TEST','TIE','INT','PROD' [ this needs to be updated on addition / removal of environment type]

------------------------------------------------------------------------------------------------------------------------
