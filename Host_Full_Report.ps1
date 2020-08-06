#Get Host List
$dt_tenancy = "https://xxxxxx.live.dynatrace.com"
$dt_api_token = "<your-api-token>"
$report_csv_path = "<your-csv-path>"

$headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
$headers.Add("Authorization", "Api-Token "+ $dt_api_token)
$hostList = Invoke-RestMethod $dt_tenancy'/api/v1/entity/infrastructure/hosts?relateiveTime=2hours&includeDetails=false&showMonitoringCandidates=false' -Method 'GET' -Headers $headers -Body $body
$hostCPUSystem = Invoke-RestMethod $dt_tenancy'/api/v1/timeseries/com.dynatrace.builtin:host.cpu.system?includeData=true&aggregationType=AVG&relativeTime=10mins&queryMode=TOTAL' -Method 'GET' -Headers $headers -Body $body
$hostCPUUser = Invoke-RestMethod $dt_tenancy'/api/v1/timeseries/com.dynatrace.builtin:host.cpu.user?includeData=true&aggregationType=AVG&relativeTime=10mins&queryMode=TOTAL' -Method 'GET' -Headers $headers -Body $body
$hostCPUOther = Invoke-RestMethod $dt_tenancy'/api/v1/timeseries/com.dynatrace.builtin:host.cpu.other?includeData=true&aggregationType=AVG&relativeTime=10mins&queryMode=TOTAL' -Method 'GET' -Headers $headers -Body $body
$hostMemory = Invoke-RestMethod $dt_tenancy'/api/v1/timeseries/com.dynatrace.builtin:host.mem.availablepercentage?includeData=true&aggregationType=AVG&relativeTime=10mins&queryMode=TOTAL' -Method 'GET' -Headers $headers -Body $body
$hostDisk = Invoke-RestMethod $dt_tenancy'/api/v1/timeseries/com.dynatrace.builtin:host.disk.availablespace?includeData=true&aggregationType=AVG&relativeTime=10mins&queryMode=TOTAL' -Method 'GET' -Headers $headers -Body $body


#Put Host Id - Host Display Name in a HashMap
$hostListHash=@{}
foreach ($h in $hostList){
    $hostListHash.Add($h.entityId, $h.displayName)
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
    Foreach ($Key1 in ($hostCPUUserHash.GetEnumerator() | Where-Object {$_.Name -eq $entry.Name})){$usercpuval=$Key1.Value}
    Foreach ($Key2 in ($hostCPUOtherHash.GetEnumerator() | Where-Object {$_.Name -eq $entry.Name})){$othercpuval=$Key2.Value}
    $totalCPUval = $entry.Value + $usercpuval + $othercpuval
    $hostTotalCPUHash.Add($entry.Key, $totalCPUval)
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
    Foreach ($Key in ($hostOptDiskHash.GetEnumerator() | Where-Object {$_.Key -match $disk.Name})){
        $hostOptDiskFreeHash.Add(($Key.Name -split ',')[0],[math]::Round((($Key.Value -split ' ')[1])/ 1gb, 2))
    }
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
  Foreach ($Key in ($hostVarDiskHash.GetEnumerator() | Where-Object {$_.Key -match $disk.Name})){
      $hostVarDiskFreeHash.Add(($Key.Name -split ',')[0],[math]::Round((($Key.Value -split ' ')[1])/ 1gb, 2))
      }
  }

###################
#     REPORT
###################
$report=@()
foreach ($monitoredHost in $hostListHash.GetEnumerator()){
    Foreach ($KeyA in ($hostTotalCPUHash.GetEnumerator() | Where-Object {$_.Name -eq $monitoredHost.Name})){$cpu =$KeyA.Value}
    Foreach ($KeyB in ($hostMemoryHash.GetEnumerator() | Where-Object {$_.Name -eq $monitoredHost.Name})){$memory =$KeyB.Value}
    Foreach ($KeyC in ($hostOptDiskFreeHash.GetEnumerator() | Where-Object {$_.Name -eq $monitoredHost.Name})){$optFeeDisk =$KeyC.Value}
    Foreach ($KeyD in ($hostVarDiskFreeHash.GetEnumerator() | Where-Object {$_.Name -eq $monitoredHost.Name})){$varFreeDisk =$KeyD.Value}

    $TargetProperties = @{Name=$Machine}
    $TargetObject = New-Object PSObject -Property @{ id =$monitoredHost.Name ; Name = $monitoredHost.Value ; 'CPU_Usage(%)' = $cpu ; 'Memory_Usage(%)' = $memory ; 'Opt_Disk_Available(GB)' = $optFeeDisk ; 'Var_Disk_Available(GB)' = $varFreeDisk }
    $report +=  $TargetObject
    }

$report | Export-Csv -Path $report_csv_path
