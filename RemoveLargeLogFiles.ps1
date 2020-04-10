cd C:\LandisGyr

$logFiles = ls -filter log*.log* -Recurse

$filesToRemove = New-Object Collections.Generic.List[System.IO.FileInfo]
$memorySaved = 0

ForEach ($file in $logFiles)
{
	If ($file.Length -ge 5000000)
	{
		$fileName = $file.FullName
		Write-Output "Found one greater than 5MB at $fileName"
		$filesToRemove.Add($file)
		$memorySaved += $file.Length
	}
}

$filesToRemove | Remove-Item -Force -Recurse 


#$filesToRemove | Remove-Item -Force -Recurse -WhatIf

$megsSaved = $memorySaved / 1000000
$gigsSaved = $memorySaved / 1000000000

Write-Output "Saved $megsSaved MB"
