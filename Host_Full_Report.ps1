#Get Host List
$dynatracetenany = "https://xxxxxx.live.dynatrace.com"
$dynatracetoken = "<your-api-token>"

$headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
$headers.Add("Authorization", "Api-Token "+$dynatracetoken)
$hostList = Invoke-RestMethod $dynatracetenany'/api/v1/entity/infrastructure/hosts?relateiveTime=2hours&includeDetails=false&showMonitoringCandidates=false' -Method 'GET' -Headers $headers -Body $body
$hostCPUSystem = Invoke-RestMethod $dynatracetenany'/api/v1/timeseries/com.dynatrace.builtin:host.cpu.system?includeData=true&aggregationType=AVG&relativeTime=10mins&queryMode=TOTAL' -Method 'GET' -Headers $headers -Body $body
$hostCPUUser = Invoke-RestMethod $dynatracetenany'/api/v1/timeseries/com.dynatrace.builtin:host.cpu.user?includeData=true&aggregationType=AVG&relativeTime=10mins&queryMode=TOTAL' -Method 'GET' -Headers $headers -Body $body
$hostCPUOther = Invoke-RestMethod $dynatracetenany'/api/v1/timeseries/com.dynatrace.builtin:host.cpu.other?includeData=true&aggregationType=AVG&relativeTime=10mins&queryMode=TOTAL' -Method 'GET' -Headers $headers -Body $body
$hostMemory = Invoke-RestMethod $dynatracetenany'/api/v1/timeseries/com.dynatrace.builtin:host.mem.availablepercentage?includeData=true&aggregationType=AVG&relativeTime=10mins&queryMode=TOTAL' -Method 'GET' -Headers $headers -Body $body
$hostDisk = Invoke-RestMethod $dynatracetenany'/api/v1/timeseries/com.dynatrace.builtin:host.disk.availablespace?includeData=true&aggregationType=AVG&relativeTime=10mins&queryMode=TOTAL' -Method 'GET' -Headers $headers -Body $body

#Put Host Id - Host Display Name in a HashMap
$hostHash=@{}
foreach ($h in $hostList){
    $hostHash.Add($h.entityId, $h.displayName)
    }

###################
#       CPU        
##################
#System+User+Other

#System
$hostCPUSystemHash=@{}
foreach ($cpusys in $hostCPUSystem.dataResult.dataPoints.PSObject.Properties){
    $hostCPUSystemHash.Add($cpusys.Name, [math]::Round((($cpusys.Value -split ' ')[1]), 2))
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

$hostHash
$hostTotalCPUHash
$hostMemoryHash

$report=@()
foreach ($monitoredHost in $hostHash.GetEnumerator()){
    Foreach ($KeyA in ($hostTotalCPUHash.GetEnumerator() | Where-Object {$_.Name -eq $monitoredHost.Name})){$cpu =$KeyA.Value}
    Foreach ($KeyB in ($hostMemoryHash.GetEnumerator() | Where-Object {$_.Name -eq $monitoredHost.Name})){$memory =$KeyB.Value} 
    $TargetProperties = @{Name=$Machine}  
    $TargetObject = New-Object PSObject -Property @{ id =$monitoredHost.Name ; Name = $monitoredHost.Value ; CPU_Usage = $cpu ; Memory_Usage = $memory }  
    $report +=  $TargetObject
    }
$report | Export-Csv -Path "<report path>"