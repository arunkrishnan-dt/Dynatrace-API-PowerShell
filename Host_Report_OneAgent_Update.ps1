#################################################################
# Use this script to check host Status before & After OneAgent Update
# 
# Returns:
# 'Host-id', 
# 'Name', 
# 'HostGroup',
# 'CPU_Usage(%)',
# 'CPU_Load_15min',
# 'Memory_Usage(%)',
# 'Opt_Disk_Available(GB)',
# 'Var_Disk_Available(GB)'  
#
# Aggregation: AVG over last 10mins             
# 
##################################################################
$dt_tenancy = "https://xxxxxx.live.dynatrace.com"
$dt_api_token = "<your-api-token>"
$report_csv_path = "<your-csv-path>"


# NOTE: Filter below API calls with ManagementZones/HostGroups where available
$headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
$headers.Add("Authorization", "Api-Token "+ $dt_api_token)
$hostList = Invoke-RestMethod $dt_tenancy'/api/v1/entity/infrastructure/hosts?relateiveTime=2hours&includeDetails=true&showMonitoringCandidates=false' -Method 'GET' -Headers $headers -Body $body
$hostCPUSystem = Invoke-RestMethod $dt_tenancy'/api/v1/timeseries/com.dynatrace.builtin:host.cpu.system?includeData=true&aggregationType=AVG&relativeTime=10mins&queryMode=TOTAL' -Method 'GET' -Headers $headers -Body $body
$hostCPUUser = Invoke-RestMethod $dt_tenancy'/api/v1/timeseries/com.dynatrace.builtin:host.cpu.user?includeData=true&aggregationType=AVG&relativeTime=10mins&queryMode=TOTAL' -Method 'GET' -Headers $headers -Body $body
$hostCPUOther = Invoke-RestMethod $dt_tenancy'/api/v1/timeseries/com.dynatrace.builtin:host.cpu.other?includeData=true&aggregationType=AVG&relativeTime=10mins&queryMode=TOTAL' -Method 'GET' -Headers $headers -Body $body
$hostMemory = Invoke-RestMethod $dt_tenancy'/api/v1/timeseries/com.dynatrace.builtin:host.mem.availablepercentage?includeData=true&aggregationType=AVG&relativeTime=10mins&queryMode=TOTAL' -Method 'GET' -Headers $headers -Body $body
$hostDisk = Invoke-RestMethod $dt_tenancy'/api/v1/timeseries/com.dynatrace.builtin:host.disk.availablespace?includeData=true&aggregationType=AVG&relativeTime=10mins&queryMode=TOTAL' -Method 'GET' -Headers $headers -Body $body
$hostCPULoad15m = Invoke-RestMethod $dt_tenancy'/api/v2/metrics/query?metricSelector=builtin:host.cpu.load15m&resolution=Inf&from=now-15m' -Method 'GET' -Headers $headers -Body $body


###############
#    HOST
###############

#Put Host Id - Host Display Name in a HashMap
$hostListHash=@{}
foreach ($h in $hostList){
    $hostListHash.Add($h.entityId, $h.displayName)
    }

$hostGroupHash=@{}
foreach ($h in $hostList){
    $hostGroupHash.Add($h.entityId, $h.hostGroup.name)
    }

$hostOneAgentVersionHash=@{}
foreach ($h in $hostList){
    $hostOneAgentVersionHash.Add($h.entityId, $($h.agentVersion.major).ToString()+'.'+$($h.agentVersion.minor).ToString()+'.'+$($h.agentVersion.revision).ToString())
    }

$EpochStart = Get-Date 1970-01-01T12:00:00
$hostLastSeenHash=@{}
foreach ($h in $hostList){
    $dateTime=$EpochStart.AddMilliseconds($h.lastSeenTimestamp)    
    $hostLastSeenHash.Add($h.entityId, $dateTime )
    }

###################
#       CPU
##################
#System+User+Other

#System
$hostCPUSystemHash=@{}
foreach ($cpuSys in $hostCPUSystem.dataResult.dataPoints.PSObject.Properties){
    $hostCPUSystemHash.Add($cpuSys.Name, [math]::Round((($cpuSys.Value -split ' ')[1]), 2))
    }
#User
$hostCPUUserHash=@{}
foreach ($cpuUser in $hostCPUUser.dataResult.dataPoints.PSObject.Properties){
    $hostCPUUserHash.Add($cpuUser.Name, [math]::Round((($cpuUser.Value -split ' ')[1]), 2))
    }
#Other
$hostCPUOtherHash=@{}
foreach ($cpuOther in $hostCPUOther.dataResult.dataPoints.PSObject.Properties){
    $hostCPUOtherHash.Add($cpuOther.Name, [math]::Round((($cpuOther.Value -split ' ')[1]), 2))
    }

#Total CPU
$hostTotalCPUHash = @{}
Foreach ($entry in $hostCPUSystemHash.GetEnumerator()){  
    $totalCPUval = $entry.Value + $hostCPUUserHash[$entry.Name] + $hostCPUOtherHash[$entry.Name]
    $hostTotalCPUHash.Add($entry.Key, $totalCPUval)
    }

#CPULoad15min
$hostCPULoad15mHash=@{}
foreach ($cpuLoad15m in $hostCPULoad15m.result.data){
    $hostCPULoad15mHash.Add($($cpuLoad15m.dimensions), [math]::Round($($cpuLoad15m.values), 2))
    }


###################
#       Memory
##################
$hostMemoryHash=@{}
foreach ($memory in $hostMemory.dataResult.dataPoints.PSObject.Properties){
    $usedMemory = 100 - [math]::Round((($memory.Value -split ' ')[1]), 2)
    $hostMemoryHash.Add($memory.Name, $usedMemory)
    }

###################
#       Disk
##################

$enityIdhash=@{}
foreach ($property in $hostDisk.dataResult.entities.PSObject.Properties){
    $enityIdhash[$property.Name] = $property.Value
    }
#
# /opt/dynatrace
#
#Ids of disk that we care about
$hostOptDiskIdHash=@{}
Foreach ($Key in ($enityIdhash.GetEnumerator() | Where-Object {$_.Value -eq "/opt/dynatrace"})){
    $hostOptDiskIdHash.Add($Key.name, $Key.Value)
    }

$hostOptDiskHash=@{}
foreach ($property in $hostDisk.dataResult.dataPoints.PSObject.Properties){
    $hostOptDiskHash[$property.Name] = $property.Value
    }

#Disk-AvailableSpace Hash
$hostOptDiskFreeHash=@{}
foreach ($disk in $hostOptDiskIdHash.GetEnumerator()){
    $hostOptDiskFreeHash.Add(($disk.Key -split ',')[0],[math]::Round((($hostOptDiskHash[$disk.Key] -split ' ')[1])/ 1gb, 2))
}

#
# /var
#
$hostVarDiskIdHash=@{}
Foreach ($Key in ($enityIdhash.GetEnumerator() | Where-Object {$_.Value -eq "/var"})){
    $hostVarDiskIdHash.Add($Key.name, $Key.Value)
    }

$hostVarDiskHash=@{}
Foreach ($property in $hostDisk.dataResult.dataPoints.PSObject.Properties){
    $hostVarDiskHash[$property.Name] = $property.Value
    }

#Disk-AvailableSpace Hash
$hostVarDiskFreeHash=@{}
Foreach ($disk in $hostVarDiskIdHash.GetEnumerator()){
    $hostVarDiskFreeHash.Add(($Key.Name -split ',')[0],[math]::Round((($hostVarDiskHash[$disk.Key] -split ' ')[1])/ 1gb, 2))
  }

###################
#     REPORT
###################
$report=@()
foreach ($monitoredHost in $hostListHash.GetEnumerator()){    
  
    $TargetObject = New-Object PSObject -Property @{ 'Host-id' =$monitoredHost.Name;
                                                     'Name' = $monitoredHost.Value;
                                                     'HostGroup' = $hostGroupHash[$monitoredHost.Name];
                                                     'OneAgent_Version' = $hostOneAgentVersionHash[$monitoredHost.Name];
                                                     'CPU_Usage(%)' = $hostTotalCPUHash[$monitoredHost.Name] ;
                                                     'CPU_Load_15min' = $hostCPULoad15mHash[$monitoredHost.Name];
                                                     'Memory_Usage(%)' = $hostMemoryHash[$monitoredHost.Name];
                                                     'Opt_Disk_Available(GB)' = $hostOptDiskFreeHash[$monitoredHost.Name] ;
                                                     'Var_Disk_Available(GB)' = $hostVarDiskFreeHash[$monitoredHost.Name];
                                                     'Host_Last_Seen(DateTime)' = $hostLastSeenHash[$monitoredHost.Name] }
    $report +=  $TargetObject
    }

$report | Select 'Host-id', 'Name', 'HostGroup', 'OneAgent_Version', 'CPU_Usage(%)', 'CPU_Load_15min', 'Memory_Usage(%)', 'Opt_Disk_Available(GB)', 'Var_Disk_Available(GB)', 'Host_Last_Seen(DateTime)'   | Export-Csv -Path $report_csv_path