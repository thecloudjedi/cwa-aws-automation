new-item -name 'cwlresults' -Path "$home\Desktop" -ItemType directory

$badip = '<ip>'

$nexttoken = $null
$lasttoken = $null
$eni = '<redacted>'
$region = '<region>'
Set-DefaultAWSRegion $region
$starttime = Get-Date '2019-08-30 00:00:00Z' 
$endtime = Get-Date '2019-09-03 00:00:00Z' 

do{
$getevents = Get-CWLLogEvent -LogGroupName 'ltcloudwatch' -LogStreamName "$eni-all" -StartTime $starttime -EndTime $endtime -NextToken $nexttoken
$logs = $getevents.Events|?{$_.message.split(' ')[3] -match $badip -or $_.message.split(' ')[4] -match $badip}
$lasttoken = $nexttoken
$nexttoken = $getevents.NextbackwardToken
#write-output $nexttoken
foreach ($log in $logs)
{
$timestamp= ($log).timestamp 
$unix = get-date(($log).timestamp) -uformat "%s"
$line = $log.Message,$timestamp -join "`t"
$path = "$home\cwlresults\logresults$unix.txt"
$line|out-file $path -Append
}

}
until
(
$lasttoken -eq $nexttoken
)
