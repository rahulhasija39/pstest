param(
  [Parameter(Mandatory=$true)]
  [string]$ServiceGroupRoot,
  [Parameter(Mandatory=$false)]
  [string]$DataSyncBuildOutputFile,
  [Parameter(Mandatory=$false)]
  [string]$ProvisioningBuildOutputFile,
  [Parameter(Mandatory=$false)]
  [boolean]$isLocalPackageLink = $false
)

function FindAndReplace([string]$folderName, [string]$stringToFind, [string]$stringToReplace, [string]$filesToFind)
{
	Write-Host 'Folder:' $folderName
	cd $folderName

	$count = 0
	(findstr -spinm /c:$stringToFind $filesToFind) | foreach-object {
	  $file = $_
	  $content = (get-content $file)
	  $content = $content | foreach-object {
		($_ -replace $stringToFind, $stringToReplace)
	  }
	  $count++
	  Write-Host $count ': Processing file ' $file
	  $content | set-content -path $file
	}
}

Write-Host 'serviceGroupRoot:' $ServiceGroupRoot
$parametersFolder = Join-Path $ServiceGroupRoot "Parameters"
Write-Host 'parametersFolder:' $parametersFolder


$blobUrlSlug = "#CSPKG_BLOB_URL#"
if($DataSyncBuildOutputFile)
{
	$DataSyncBlobUrl = (Get-Content $DataSyncBuildOutputFile)
	$dataCscfg,$dataCspkg = $DataSyncBlobUrl.split(' ',2)
}
elseif($isLocalPackageLink)
{
	$dataCspkg = "bin\\SyncCloudService.cspkg"
}
else
{
	Throw "No Cloud package link provided for data sync cloud service"
}

if($ProvisioningBuildOutputFile)
{
	$ProvisioningBlobUrl = (Get-Content $ProvisioningBuildOutputFile)
	$provCscfg,$provCspkg = $ProvisioningBlobUrl.split(' ',2)
}
elseif($isLocalPackageLink)
{
	$provCspkg = "bin\\ProvisioningCloudService.cspkg"
}
else
{
	Throw "No Cloud package link provided for provisioning cloud service"
}

FindAndReplace $parametersFolder $blobUrlSlug $dataCspkg "DataSync.Parameters*.json"

FindAndReplace $parametersFolder $blobUrlSlug $provCspkg "Provisioning.Parameters*.json"

$PathSlug = "#PATHS#"
$servicePackageLink = ""
if($isLocalPackageLink)
{
    $servicePackageLink = ",`n`"servicePackageLink`""
}

FindAndReplace $parametersFolder $PathSlug $servicePackageLink "DataSync.Parameters*.json"

FindAndReplace $parametersFolder $PathSlug $servicePackageLink "Provisioning.Parameters*.json"