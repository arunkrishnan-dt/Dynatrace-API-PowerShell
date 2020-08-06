# NOTE: INCOMPLETE SCRIPT
#################################################################
﻿# Use this script to check Technology versions in your environment
##################################################################
﻿$dt_tenancy = "https://xxxxxx.live.dynatrace.com"
$dt_api_token = "<your-api-token>"
$report_csv_path = "<your-csv-path>"

$headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
$headers.Add("Authorization", "Api-Token "+ $dt_api_token)

$processes = Invoke-RestMethod $dt_tenancy'/api/v1/entity/infrastructure/processes' -Method 'GET' -Headers $headers -Body $body

$report=@()
foreach ($process in $processes){
    $TargetObject = New-Object PSObject -Property @{ id =$process.fromRelationships.isProcessOf ; Process_Name = $process.displayName ; 'Process_Technology' = $process.softwareTechnologies.type ; 'Process_Technology_Version' = $process.softwareTechnologies.version ; 'Process_Technology_Edition' = $process.softwareTechnologies.edition }
    $report +=  $TargetObject
}

$report | Export-Csv -Path $report_csv_path
