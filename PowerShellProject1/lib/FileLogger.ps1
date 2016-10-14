
# This is a class initializer method
function global:StartLog ([string] $filepath)
{
	# A new log class with filepath property is created 
	$logclass = new-object psobject -Property @{filepath = $filepath};

	# Method to log the information
	$writeInformation = {
		param([String]$message)
		$today = Get-Date
		Add-Content -Path $this.filepath -Value ('Information [{0}] : {1}' -f $today.ToString(),$message)
	};
	
	# Method to log the Warning
	$writeWarning = {
		param([String]$message)
		$today = Get-Date
		Add-Content -Path $this.filepath -Value ('Warning [{0}] : {1}' -f $today.ToString(),$message)
	};

	# Method to log the Error
	$writeError = {
		param([String]$message)
		$today = Get-Date
		Add-Content -Path $this.filepath -Value ('Error [{0}] : {1}' -f $today.ToString(),$message)
	};
	
	# Adding all the logging methods to the log class
	Add-Member -InputObject $logclass -MemberType ScriptMethod -Name 'WriteInformation' -Value $writeInformation;
	Add-Member -InputObject $logclass -MemberType ScriptMethod -Name 'WriteWarning' -Value $writeWarning;
	Add-Member -InputObject $logclass -MemberType ScriptMethod -Name 'WriteError' -Value $writeError;
	
	return $logclass;
}