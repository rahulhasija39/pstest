# Set HTTP request headers to include Authorization header

$RequestHeader = @{
			"x-ms-version" = "2013-10-01";
			"Accept" = "application/json"
			}

$ContentType = "application/json;charset=utf-8"

#It creates Azure management URI which is used while setting AutoScalling

function global:CreateAzureMangementURI
{
	Param
	(
		[Parameter(Mandatory=$true)][string] $SubscriptionId,
		[Parameter(Mandatory=$true)][string] $CloudServiceName,
		[Parameter(Mandatory=$true)][string] $DeplymentSlot,
		[Parameter(Mandatory=$true)][string] $RoleName
	)
	return "https://management.core.windows.net/$SubscriptionId/services/monitoring/autoscalesettings?resourceId=/hostedservices/$CloudServiceName/deploymentslots/$DeplymentSlot/roles/$RoleName"
}

#It creates a Request body for CPU autoscaling in JSON encoded format

function global:EncodeJsonBodyCPU
{	
	Param
	(
		[Parameter(Mandatory=$true)][string] $Location, 
		[Parameter(Mandatory=$true)][string] $MinInstancesCpu, 
		[Parameter(Mandatory=$true)][string] $MaxInstancesCpu, 
		[Parameter(Mandatory=$true)][string] $DefaultInstancesCpu, 
		[Parameter(Mandatory=$true)][string] $CpuMetricSource,
		[Parameter(Mandatory=$true)][string] $CpuThresholdScaleUp,
		[Parameter(Mandatory=$true)][string] $CpuThresholdScaleDown,
		[Parameter(Mandatory=$true)][string] $InstanceCountUpCpu,
		[Parameter(Mandatory=$true)][string] $InstanceCountDownCpu
	)
	$JsonBodyCpu = @"
	{
		"Name": "scale-workerrole-cpu",
		"Type": "Microsoft.Insights/autoscaleSettings",
		"Location": "$Location",

		"Profiles": [
			{
			"Name": "CPU Based Scaling",
			"Capacity": {
				"Minimum": "$MinInstancesCpu",
				"Maximum": "$MaxInstancesCpu",
				"Default": "$DefaultInstancesCpu"
			},
			"Rules": [
				{
				"MetricTrigger": {
					"MetricName": "Percentage CPU",
					"MetricNamespace": "",
					"MetricSource": "$CpuMetricSource",
					"TimeGrain": "PT5M",
					"Statistic": "Average",
					"TimeWindow": "PT45M",
					"TimeAggregation": "Average",
					"Operator": "GreaterThanOrEqual",
					"Threshold": $CpuThresholdScaleUp
				},
				"ScaleAction": {
					"Direction": "Increase",
					"Type": "ChangeCount",
					"Value": "$InstanceCountUpCpu",
					"Cooldown": "PT45M"
				}
			},
			{
				"MetricTrigger": {
					"MetricName": "Percentage CPU",
					"MetricNamespace": "",
					"MetricSource": "$CpuMetricSource",
					"TimeGrain": "PT5M",
					"Statistic": "Average",
					"TimeWindow": "PT45M",
					"TimeAggregation": "Average",
					"Operator": "LessThanOrEqual",
					"Threshold": $CpuThresholdScaleDown
				},
				"ScaleAction": {
					"Direction": "Decrease",
					"Type": "ChangeCount",
					"Value": "$InstanceCountDownCpu",
					"Cooldown": "PT60M"
				}
				}
			]
			}
			],
			"Enabled": true
		}
"@
	return $JsonBodyCpu
}

#It creates a Request body for Queue autoscaling in JSON encoded format

function global:EncodeJsonBodyQueue
{
	Param
	(
		[Parameter(Mandatory=$true)][string] $Location,
		[Parameter(Mandatory=$true)][string] $MinInstancesQueue,
		[Parameter(Mandatory=$true)][string] $MaxInstancesQueue,
		[Parameter(Mandatory=$true)][string] $DefaultInstancesQueue,
		[Parameter(Mandatory=$true)][string] $QueueMetricSource, 
		[Parameter(Mandatory=$true)][string] $QueueThresholdScaleUp,
		[Parameter(Mandatory=$true)][string] $QueueThresholdScaleDown,
		[Parameter(Mandatory=$true)][string] $InstanceCountUpQueue,
		[Parameter(Mandatory=$true)][string] $InstanceCountDownQueue
	)
	# Build JSON web request for Queue 
	$JsonBodyQueue = @"
	{
		"Name": "scale-workerrole-queue",
		"Type": "Microsoft.Insights/autoscaleSettings",
		"Location": "$Location",
	
		"Profiles":
		[
			{
			"Name": "Queue Based Scaling",
			"Capacity": {
				"Minimum": "$MinInstancesQueue",
				"Maximum": "$MaxInstancesQueue",
				"Default": "$DefaultInstancesQueue"
			},
			"Rules": [
				{
					"MetricTrigger": {
						"MetricName": "MessageCount",
						"MetricNamespace": "",
						"MetricSource": "$QueueMetricSource",
						"TimeGrain": "PT5M",
						"Statistic": "Average",
						"TimeWindow": "PT45M",
						"TimeAggregation": "Average",
						"Operator": "GreaterThanOrEqual",
						"Threshold": $QueueThresholdScaleUp
					},
					"ScaleAction": {
						"Direction": "Increase",
						"Type": "ChangeCount",
						"Value": "$InstanceCountUpQueue",
						"Cooldown": "PT30M"
					}
				},
				{
				"MetricTrigger": {
					"MetricName": "MessageCount",
					"MetricNamespace": "",
					"MetricSource": "$QueueMetricSource",
					"TimeGrain": "PT5M",
					"Statistic": "Average",
					"TimeWindow": "PT45M",
					"TimeAggregation": "Average",
					"Operator": "LessThanOrEqual",
					"Threshold": $QueueThresholdScaleDown
				},
				"ScaleAction": {
					"Direction": "Decrease",
					"Type": "ChangeCount",
					"Value": "$InstanceCountDownQueue",
					"Cooldown": "PT60M"
				}
				}
			]
			}
		],
		"Enabled": true
	}
"@
	return $JsonBodyQueue
}


#It sets AutoScaling settings using Rest API with the specified parameters, call this method from Driver script

function global:SetAutoScaleSetting
{
	Param
	(
		[Parameter(Mandatory=$true)][string] $RequestBody,
		[Parameter(Mandatory=$true)] $Certificate,
		[Parameter(Mandatory=$true)][string] $AzureMgmtUri
	) 
	$Response = Invoke-RestMethod -Certificate $($Certificate) -Uri $($AzureMgmtUri) -Method Put -Headers $($requestHeader) -Body $($RequestBody) -ContentType $($contentType)
	return $Response
}

#It gets AutoScaling settings using Rest API with the specified parameters, call this method from Driver script

function global:GetAutoScaleSetting
{
	Param
	(
		[Parameter(Mandatory=$true)] $Certificate, 
		[Parameter(Mandatory=$true)][string] $AzureMgmtUri
	)
	$Response = Invoke-RestMethod -Uri $($AzureMgmtUri) -Certificate $($Certificate) -Method Get -Headers $RequestHeader
	$Response | ConvertTo-Json
	return $Response
}