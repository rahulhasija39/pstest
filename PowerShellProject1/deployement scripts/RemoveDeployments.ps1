remove-item -rec ServiceGroupRoot\RolloutSpec*.*.json
remove-item -rec ServiceGroupRoot\RolloutSpecCloudService.*.json
remove-item -rec ServiceGroupRoot\Acis\AcisConfig.*.json
remove-item -rec ServiceGroupRoot\RolloutSpecDnsZone.*.json
remove-item -rec ServiceGroupRoot\ServiceModel.*.json
remove-item -rec ServiceGroupRoot\Configurations\DataSync.ServiceConfiguration.*.cscfg
remove-item -rec ServiceGroupRoot\Configurations\Provisioning.ServiceConfiguration.*.cscfg
remove-item -rec ServiceGroupRoot\Parameters\DataSync.Parameters.*.json
remove-item -rec ServiceGroupRoot\Parameters\Composite.Parameters.*.json
remove-item -rec ServiceGroupRoot\Parameters\DnsZone.Parameters.*.json
remove-item -rec ServiceGroupRoot\Parameters\Provisioning.Parameters.*.json
remove-item -rec ServiceGroupRoot\Parameters\VNet.Parameters.*.json
remove-item -rec ServiceGroupRoot\Parameters\Provisioning.RolloutParameters.*.json
remove-item -rec ServiceGroupRoot\Parameters\DataSync.RolloutParameters.*.json

if (Test-Path "ServiceGroupRoot\Configurations\\backup.Provisioning.ServiceConfiguration.cscfg")
{
	Copy-Item "ServiceGroupRoot\Configurations\\backup.Provisioning.ServiceConfiguration.cscfg" "ServiceGroupRoot\Configurations\\Provisioning.ServiceConfiguration.cscfg"
}

if (Test-Path "backup.ServiceGroupRoot\Configurations\\DataSync.ServiceConfiguration.cscfg")
{
	Copy-Item "backup.ServiceGroupRoot\Configurations\\DataSync.ServiceConfiguration.cscfg" "ServiceGroupRoot\Configurations\\DataSync.ServiceConfiguration.cscfg" 
}
