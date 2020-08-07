###############################################
# Technology, Version and if Restart Required
###############################################
$dt_tenancy = "https://xxxxxx.live.dynatrace.com"
$dt_api_token = "<your-api-token>"
$report_csv_path = "<your-csv-path>"
$report_json_path = "<your-json-path>" # Use JSON to view full Technology Type, Edition and Version

$headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
$headers.Add("Authorization", "Api-Token "+ $dt_api_token)

$hostList = Invoke-RestMethod $dt_tenancy'/api/v1/entity/infrastructure/hosts?relateiveTime=10mins&includeDetails=false&showMonitoringCandidates=false' -Method 'GET' -Headers $headers -Body $body
$processes = Invoke-RestMethod $dt_tenancy'/api/v1/entity/infrastructure/processes?relateiveTime=10minshours' -Method 'GET' -Headers $headers -Body $body

#Put Host Id - Host Display Name in a HashMap
$hostListHash=@{}
foreach ($h in $hostList){
    $hostListHash.Add($h.entityId, $h.displayName)
    }


$report=@()
foreach ($process in $processes){
    foreach($hostEntry in ($hostListHash.GetEnumerator()| Where-Object {$_.Name -eq $($process.fromRelationships.isProcessOf)})) {$hostName=$hostEntry.Value}
    $TargetObject = New-Object PSObject -Property @{ 
                                                'id' = $($process.fromRelationships.isProcessOf); 
                                                'Host_Name'=$hostName; Process_Name = $($process.displayName); 
                                                'Process_Technology_Type' = $($process.softwareTechnologies.type); 
                                                'Process_Technology_Edition' = $($process.softwareTechnologies.edition);                                                
                                                'Process_Technology_Version' = $($process.softwareTechnologies.version);
                                                'Process_Restart_Required' = $($process.monitoringState.restartRequired)
                                                }
    $report +=  $TargetObject
}

$report | Export-Csv -Path $report_csv_path

$report | ConvertTo-Json | Out-File -Encoding utf8 $report_json_path
