#Grabbing all of the regions
$regionlist=get-ec2region|select -expand regionname;

foreach($_value in $regionlist) 

{$region = $_value;
$interval= '604800'; #This is the number of seconds that each record will consist of. for example, 1800 splits records into 30 min intervals. 604,800 is 7 days' of seconds#
$split= '168'; #The number of hours back that the records will start from. 24 for 1 day, 168 for 7 days#
set-defaultawsregion $_value;
$time= Get-Date;
$starttime= ($time.AddHours(-$split)).ToUniversalTime(); #The time the record will begin#
$endtime= $time.ToUniversalTime(); #The time the records will end. Will probably always be set to now#
$metricname= 'BurstBalance'; #The metric name from CloudWatch#
$namespace='AWS/EBS'; #The service that the metric exists within. Will usually be EBS or EC2 for our purposes#
$testlist = get-cwmetrics -Namespace $namespace -MetricName $metricname|select -expandproperty dimensions; #This is the call to pull the list of resources that have this metric (Volumes/Instances)#
$list2= $testlist.value;
foreach ($_value in $list2) 

{$Dimension1 = New-Object 'Amazon.CloudWatch.Model.Dimension';
$Dimension1.Name = 'VolumeId';
$Dimension1.Value = $_value;
$volume= $_value;

$getvolumeinformation= get-ec2volume -volumeid $volume -ErrorVariable voloutput #Gets info about the drive, so we can see if it is burstable, and what it is attached as#
if(-not $voloutput -and ($_.attachment.device -notlike 'xvd*')) #This filters out volumes that may no longer exist, and only gives us volumes with /dev/sda1 or /dev/sda2 attachment (C and D drive)
{
$volumetype = $getvolumeinformation.VolumeType.value
$Attachmenttype= $getvolumeinformation.Attachment.device


$volinfo=get-ec2volume -VolumeId $volume|select -ExpandProperty attachments
$instance=$volinfo.instanceid #Getting Instance ID for dataset#

$instanceinfo=get-ec2instance -Instance $instance|select -ExpandProperty instances
$instancetype=$instanceinfo.instancetype.value #Getting Instance Type for dataset#

$name=$instanceinfo|select -ExpandProperty tags|where-object{$_.Key -eq 'Name'}|select -ExpandProperty value
$type=$instanceinfo|select -ExpandProperty tags|where-object{$_.Key -eq 'Type'}|select -ExpandProperty value

$instance = "$volume/$volumetype/$Attachmenttype" #I just added this in to out put the Volume ID, type, and attachment into the dataset without modifying the table#

$datapoints=Get-CWMetricStatistics -Namespace $namespace -MetricName $metricname -Dimensions $dimension1 -UtcEndTime $endtime -Period $interval -UtcStartTime $starttime -Statistics 'Minimum','Maximum','Average','Sum','SampleCount' -Unit 'Percent'|select -expandproperty datapoints|sort-object timestamp;
$datalist= $datapoints|select minimum,maximum,average,@{Expression={($_.Timestamp.addhours(4)).tostring("s")+"Z"};n="Timestamp"}
$datalist| add-member -MemberType NoteProperty -Name 'InstanceID' -Value $instance;
$datalist| add-member -MemberType NoteProperty -Name 'MetricName' -Value $metricname; 
$datalist| add-member -MemberType NoteProperty -Name 'Region' -Value $region;
$datalist| add-member -MemberType NoteProperty -Name 'InstanceType' -Value $instancetype
$datalist| add-member -MemberType NoteProperty -Name 'Name' -Value $name
$datalist| add-member -MemberType NoteProperty -Name 'Type' -Value $type
$datalist| add-member -MemberType NoteProperty -Name 'VolumeType' -Value $volumetype
<#
foreach($_value in $datalist) {

$jsonvalues= $_value|convertTo-json

$response = Invoke-RestMethod "$URI/ltcloudwatch/volumecredits/" -Method Post -Body $jsonvalues -ContentType 'application/json' 
}
#>


$datalist|foreach-object{

   $instance = $_.instanceid;
    $region=$_.region;
    $metric = $_.metricname
    $min=$_.minimum;
    $max= $_.maximum;
    $avg=$_.average;
    $sum=$_.sum;
    $timetemp= $_.timestamp; 
    $timestamp=get-date $timetemp; 
    $time= $timestamp.ToString('yyyy-MM-dd HH:mm:ss')

$statement= "('$instance','$region','$time','$metric','$max','$min','$avg','$sum'),"
write-output $statement
<#
$statement|out-file -FilePath C:\windows\temp\diskqueuestatements.txt -NoClobber -append

$MyQuery = .\mysql.exe --host <redacted> --user=powershell --password=$Pwd <dbname> -e "
use <dbname>;
INSERT IGNORE INTO aws_cloudwatch (instanceid,region,timestamp,metric,maximum,minimum,average,sum) 
VALUES ('$instance','$region','$time','$metric','$max','$min','$avg','$sum')" ;
#>
} 
}; #else {Clear-Variable voloutput}

}
};