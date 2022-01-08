
$results = @()
foreach($region in $regionlist)


{
set-defaultawsregion $region 
$ec2 = (get-ec2instance).instances|? {$_.State.Name.Value -eq 'Stopped'}

foreach ($instance in $ec2)
{ $name = ($instance.tags|?{$_.key -eq 'Name'}).Value
  $instanceid = $instance.InstanceId
  $shutdown = $instance.StateTransitionReason 
  $shutdownreason = $instance.StateReason.Message

$getmonth = (get-date -UFormat '%Y-%m')

if($shutdownreason -like 'Client.Instance*') {
if($instance.tags.key -notcontains "Terminate")
{

$tag = New-Object Amazon.EC2.Model.Tag
$tag.Key = "Terminate"
$tag.Value = "$getmonth"

    New-EC2Tag -Resource $instanceid -Tag $tag}
}

if($shutdown  -like 'User initiated (20*') {

$stopdate = '202'+(($shutdown -split '202')[1].substring(0,4))

$tag = New-Object Amazon.EC2.Model.Tag
$tag.Key = "Terminate"
$tag.Value = "$stopdate"

    New-EC2Tag -Resource $instanceid -Tag $tag
    }
    else {Write-Output $shutdown $shutdownreason}
}
}
$results| export-csv -Path C:\users\administrator\desktop\stoppedinstances.csv 

