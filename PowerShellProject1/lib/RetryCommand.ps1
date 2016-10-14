#This function re-runs the sending $command for specified number $retries when it mets any failure

function global:Retry-Command
{
	param (
	[Parameter(Mandatory=$true)][string]$command, 
	[Parameter(Mandatory=$true)][hashtable]$args, 
	[Parameter(Mandatory=$true)][int]$retries, 
	[Parameter(Mandatory=$true)][int]$secondsDelay
	)
	
	# Setting ErrorAction to Stop is important. This ensures any errors that occur in the command are 
	# treated as terminating errors, and will be caught by the catch block.
	$args.ErrorAction = "Stop"
	
	$retrycount = 0
	$completed = $false
	$returnData = ""
	while (-not $completed) {

		try {

			$returnData = & $command @args
			Write-Verbose ("Command [{0}] succeeded." -f $command)
			$completed = $true

		} catch {

			if ($retrycount -ge $retries) {
				Write-Verbose ("Command [{0}] failed the maximum number of {1} times." -f $command, $retrycount)
				#The error would be caught in AzureDeployer.ps1' s catch block and handled.
				throw
			} else {
				Write-Verbose ("Command [{0}] failed. Retrying in {1} seconds." -f $command, $secondsDelay)
				Start-Sleep $secondsDelay
				$retrycount++
			}
		}
	}
	return $returnData
}