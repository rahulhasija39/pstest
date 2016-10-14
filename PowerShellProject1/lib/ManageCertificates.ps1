#Store S2S authentication certificate to Keyvault

function global:Store-Authentication-Certificate 
{
Param
(
	[Parameter(Mandatory=$true)][string] $KeyVaultName,
	[Parameter(Mandatory=$true)][string] $KeyName,
	[Parameter(Mandatory=$true)][string] $S2SAuthCertificatePath,
	[Parameter(Mandatory=$true)][string] $S2SAuthPassword
)
	$cerFilePath = GetFilePath($S2SAuthCertificatePath)
	Write-Output "Verifying Certificate $cerFilePath"
	if($cerFilePath){
				
		$encryptedPassword = ConvertTo-SecureString -String $S2SAuthPassword -AsPlainText -Force 
		Add-AzureKeyVaultKey -VaultName $KeyVaultName -Name $KeyName -KeyFilePath $cerFilePath -KeyFilePassword $encryptedPassword -Destination 'HSM'
	}
	else
	{
		Write-Output "Certificate does not exist at  $cerFilePath"
	}
	
}

#This function iImports the certificate and return it

function global:GetCertificate
{
Param
(
	[Parameter(Mandatory=$true)][string] $certFilePath
)
	$cert = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2
	$cert.Import($certFilePath)
	
	if($cert -and ($cert.PublicKey.Key.KeySize -lt 2048))
	{
		Write-Warning "All Azure certificates must have a key size no less than 2048 bits: $certFilePath"
	}

	return $cert
}

#Returns the given certificate's thumbprint

function global:GetCertificateThumbprint
{
Param
(
	[Parameter(Mandatory=$true)][string] $certFilePath
)
	return (GetCertificate $certFilePath).Thumbprint
}

#This function encrypts the string using the given certificate

function global:Encrypt
{
Param
(
	[Parameter(Mandatory=$true)][string] $stringToEncrypt, 
	[Parameter(Mandatory=$true)][string] $certFilePath
)
	$cert = (GetCertificate $certFilePath)
	
	$content = new-object Security.Cryptography.Pkcs.ContentInfo -argumentList (,[Text.Encoding]::UTF8.GetBytes($stringToEncrypt))
	$env = new-object Security.Cryptography.Pkcs.EnvelopedCms $content
	$env.Encrypt((new-object System.Security.Cryptography.Pkcs.CmsRecipient($cert)))
	return [Convert]::ToBase64String($env.Encode())
}