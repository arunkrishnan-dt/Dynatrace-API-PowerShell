$dynatracetenany = "https://xxxxxx.live.dynatrace.com"
$dynatracetoken = "<your-api-token>"
$dynatracetenany
$dynatracetoken
$headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
$headers.Add("Authorization", "Api-Token "+$dynatracetoken)

$response = Invoke-RestMethod $dynatracetenany'/api/v1/timeseries/com.dynatrace.builtin:host.disk.availablespace?includeData=true&aggregationType=AVG&relativeTime=10mins&entity=HOST-93F2022DFD27B551&queryMode=TOTAL' -Method 'GET' -Headers $headers -Body $body
#$response | ConvertTo-Json
#$result=$response.dataResult.entities
$hash=@{}
foreach ($property in $response.dataResult.entities.PSObject.Properties){
    $hash[$property.Name] = $property.Value
    }
Foreach ($Key in ($hash.GetEnumerator() | Where-Object {$_.Value -eq "/"})){
    $driveid=$Key.name
    }

$hash2=@{}
foreach ($property in $response.dataResult.dataPoints.PSObject.Properties){
    $hash2[$property.Name] = $property.Value
    }
Foreach ($Key in ($hash2.GetEnumerator() | Where-Object {$_.Key -match $driveid})){
    $diskspace=$Key.Value
    }
$freespace=[math]::Round((($diskspace[0] -split ' ')[1])/ 1gb, 2)
"$freespace GB"



