#################################################################
# Use this script to check host Status before & After OneAgent Update
# 
# Returns:
# 'Host-id', 
# 'Name', 
# 'HostGroup',
# 'OneAgent_Version'
# 'CPU_Usage(%)',
# 'CPU_Load_15min',
# 'Memory_Usage(%)',
# 'Disk1-Available(GB)',
# 'Disk2-Available(GB)'  
# 'Host_Last_Seen(Date/Time)'
#
# Aggregation: AVG over last 10mins             
# 
##################################################################
$dt_tenancy = "https://xxxxxx.live.dynatrace.com"
$dt_api_token = "<your-api-token>"
$report_csv_path = "<your-csv-path>"

$disk1='/opt/dynatrace'
$disk2='/var'

#Headers
$headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
$headers.Add("Authorization", "Api-Token "+ $dt_api_token)

#API Calls
# NOTE: Filter below API calls with ManagementZones/HostGroups where available
$hostList = Invoke-RestMethod $dt_tenancy'/api/v1/entity/infrastructure/hosts?relateiveTime=2hours&includeDetails=true&showMonitoringCandidates=false' -Method 'GET' -Headers $headers -Body $body
$hostCPUSystem = Invoke-RestMethod $dt_tenancy'/api/v1/timeseries/com.dynatrace.builtin:host.cpu.system?includeData=true&aggregationType=AVG&relativeTime=10mins&queryMode=TOTAL' -Method 'GET' -Headers $headers -Body $body
$hostCPUUser = Invoke-RestMethod $dt_tenancy'/api/v1/timeseries/com.dynatrace.builtin:host.cpu.user?includeData=true&aggregationType=AVG&relativeTime=10mins&queryMode=TOTAL' -Method 'GET' -Headers $headers -Body $body
$hostCPUOther = Invoke-RestMethod $dt_tenancy'/api/v1/timeseries/com.dynatrace.builtin:host.cpu.other?includeData=true&aggregationType=AVG&relativeTime=10mins&queryMode=TOTAL' -Method 'GET' -Headers $headers -Body $body
$hostMemory = Invoke-RestMethod $dt_tenancy'/api/v1/timeseries/com.dynatrace.builtin:host.mem.availablepercentage?includeData=true&aggregationType=AVG&relativeTime=10mins&queryMode=TOTAL' -Method 'GET' -Headers $headers -Body $body
$hostDisk = Invoke-RestMethod $dt_tenancy'/api/v1/timeseries/com.dynatrace.builtin:host.disk.availablespace?includeData=true&aggregationType=AVG&relativeTime=10mins&queryMode=TOTAL' -Method 'GET' -Headers $headers -Body $body
$hostCPULoad15m = Invoke-RestMethod $dt_tenancy'/api/v2/metrics/query?metricSelector=builtin:host.cpu.load15m&resolution=Inf&from=now-15m' -Method 'GET' -Headers $headers -Body $body


$EpochStart = Get-Date 1970-01-01T12:00:00

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

$hostDiskIdHash=@{}
foreach ($property in $hostDisk.dataResult.entities.PSObject.Properties){
    $hostDiskIdHash[$property.Name] = $property.Value
    }
$hostDiskAvailableHash=@{}
foreach ($property in $hostDisk.dataResult.dataPoints.PSObject.Properties){
    $hostDiskAvailableHash[$property.Name] = $property.Value
    }

#
# $disk1
#
#Ids of disk that we care about
$hostDisk1IdHash=@{}
Foreach ($Key in ($hostDiskIdHash.GetEnumerator() | Where-Object {$_.Value -eq $disk1})){
    $hostDisk1IdHash.Add($Key.name, $Key.Value)
    }

$hostDisk1AvailableHash=@{}
foreach ($entry in $hostDisk1IdHash.GetEnumerator()){
    foreach ($item in ($hostDiskAvailableHash.GetEnumerator() | Where-Object {$_.Key -match $entry.Name})) {
        $hostDisk1AvailableHash.Add(($item.Name -split ',')[0],[math]::Round((($item.Value -split ' ')[1])/ 1gb, 2))
        }
    
    }
#
# $disk2
#
$hostDisk2IdHash=@{}
Foreach ($Key in ($hostDiskIdHash.GetEnumerator() | Where-Object {$_.Value -eq $disk2})){
    $hostDisk2IdHash.Add($Key.name, $Key.Value)
    }

$hostDisk2AvailableHash=@{}
foreach ($entry in $hostDisk2IdHash.GetEnumerator()){
    foreach ($item in ($hostDiskAvailableHash.GetEnumerator() | Where-Object {$_.Key -match $entry.Name})) {
        $hostDisk2AvailableHash.Add(($item.Name -split ',')[0],[math]::Round((($item.Value -split ' ')[1])/ 1gb, 2))
        }
    
    }

###################
#     REPORT
###################

$report=@()
foreach ($item in $hostList){
    
    $TargetObject=[PSCustomObject]@{
        Host_id =$item.entityId;
        Name = $item.displayName;
        HostGroup = $item.hostGroup.name;
        OneAgent_Version = $($item.agentVersion.major).ToString()+'.'+$($item.agentVersion.minor).ToString()+'.'+$($item.agentVersion.revision).ToString();
        'CPU_Usage(%)' = $hostTotalCPUHash[$item.entityId] ;
        CPU_Load_15min = $hostCPULoad15mHash[$item.entityId];
        'Memory_Usage(%)' = $hostMemoryHash[$item.entityId];
        "$disk1-Available(GB)" = $hostDisk1AvailableHash[$item.entityId] ;
        "$disk2-Available(GB)" = $hostDisk2AvailableHash[$item.entityId];
        'Host_Last_Seen(Date/Time)' = $EpochStart.AddMilliseconds($item.lastSeenTimestamp)
    }  
   
    $report +=  $TargetObject
    }
    
$report | Export-Csv -Path $report_csv_path