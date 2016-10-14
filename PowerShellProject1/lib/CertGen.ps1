#This script will generate one certificate to be used for authentication and stores the generated certificate
 # in to C:\Temp folder

 param
(
	[string] $CertificateName = $null,
	[string] $PfxCertificatePassword = $null
)
 . .\Lib\ManageCertificates.ps1
 . .\Lib\Shared.ps1

 $CertificateName = ReadAndValidateInput "Certificate Name" $CertificateName
 
 $PfxCertificatePassword = ReadAndValidateInput "Password for Pfx Certificates" $PfxCertificatePassword

 $certificatesToGenerate = @(
	@{ Name = $CertificateName; Type = "exchange" }
	);


$pfxPassword = ConvertTo-SecureString -String  $PfxCertificatePassword -AsPlainText -Force
#Get current location to set back after generating certificates
$currentLocation = Get-Location
set-location "C:\Program Files (x86)\Windows Kits\8.1\bin\x64\"
$dropDirectory = [System.IO.DirectoryInfo]("C:\Temp\" + (Get-Date).ToString("yyyy-MM-dd-HH-mm-ss"))


if (!$dropDirectory.Exists)
{
	$dropDirectory.Create()
}

foreach ($certificateToGenerate in $certificatesToGenerate)
{
	$cerFilePath = "$dropDirectory\$($certificateToGenerate.Name).cer"
	.\makecert.exe -sky $($certificateToGenerate.Type) -r -n "CN=$($certificateToGenerate.Name)" -pe -a sha1 -len 2048 -e 01/30/3001 -ss My -sr CurrentUser $cerFilePath

	$pfxFilePath = "$dropDirectory\$($certificateToGenerate.Name).pfx"
	$cert = Get-ChildItem -Path "cert:\CurrentUser\My\$(GetCertificateThumbprint $cerFilePath)"
	Export-PfxCertificate -Cert $cert -FilePath $pfxFilePath -Password $pfxPassword
}

Set-Location $currentLocation
