$regionlist = @('us-west-1','us-west-2')
foreach($region in $regionlist)
{

write-output "Setting expiration tags in $region"
Set-DefaultAWSRegion $region
$bucketname = "<redacted>-backups-$region"

$nextMarker = $null
$keysPerPage = 100000

do{
$filelist = get-s3object -BucketName $bucketname -MaxKey $keysPerPage -Marker $nextMarker|?{$_.Key -like '*/Database/*'}
$nextMarker = $AWSHistory.LastServiceResponse.NextMarker
$deletecount = 0
foreach($file in $filelist)
{
  Remove-S3ObjectTagSet -Key $file.key -BucketName $bucketname -Force
    if((get-date $file.LastModified).Day -eq '1') {
    $Tags = New-Object Amazon.S3.Model.Tag
    $Tags.Key = "delete_after_6_month"
    $Tags.Value = 'false'
    Write-S3ObjectTagSet -BucketName $bucketname -Key $file.Key -Tagging_TagSet $Tags
    Write-Output "Tag added for"$file.Key
    }
    else{
    $Tags = New-Object Amazon.S3.Model.Tag
    $Tags.Key = "delete_after_6_month"
    $Tags.Value = 'true'
    Write-S3ObjectTagSet -BucketName $bucketname -Key $file.Key -Tagging_TagSet $Tags

        }
}
}
while ($nextMarker)

}