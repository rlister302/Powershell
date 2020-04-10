param ([string] $parentDirectory)


	Write-Output $parentDirectory
	$childrenDirectories = Get-ChildItem -Path $parentDirectory -Attributes Directory -Recurse
	
	ForEach($dir in $childrenDirectories)
	{
	
		$theDir = $dir.FullName
		$fullBinPath = "$theDir\bin"
		$binExists = Test-Path $fullBinPath

		
		If ($binExists)
		{
			Write-Output "Removing bin files from $fullBinPath"
			
			
			#Write-Output "Output from get-childitem -path  is "
			Get-ChildItem -Path "$fullBinPath" -Recurse -File
			
			
			
			Get-ChildItem -Path "$fullBinPath" -Recurse -File | Remove-Item -Force -Recurse
			Get-ChildItem -Path "$fullBinPath" -Attributes Directory -Recurse | Remove-Item -Force -Recurse
		}
		$fullObjPath = "$theDir\obj"
		$objExists = Test-Path $fullObjPath
		
		if ($objExists)
		{
			Write-Output "Removing obj files from $fullObjPath"
			
			
			#Write-Output "Output from get-childitem -path  is "
			Get-ChildItem -Path "$fullObjPath" -File -Recurse
			
			
			Get-ChildItem -Path "$fullObjPath" -File -Recurse | Remove-Item -Force -Recurse
			Get-ChildItem -Path "$fullObjPath" -Attributes Directory -Recurse | Remove-Item -Force -Recurse
		}
	
	}




