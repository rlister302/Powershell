
#Clean project	#Done
#Restore packages for project	#Done
#Update packages	#Done
#Update nuspec
	#Get Distinct packages for project #Done
	#Modify nuspec file #Done
#Run unit tests
#Create packages	#Done
#Publish package	#Done
#Update version in TFS

#Tools paths
$nugetPath = "C:/nuget.exe"
$msBuildPath = 'C:\Windows\Microsoft.NET\Framework64\v4.0.30319\'

#Nuget publish locations
$nugetPublishFolder = "C:\nugetPublish"
$dropLocation = "C:\nugetStage"
$packageToPublish = "C:\nugetStage\Package.1.0.0.nupkg"

#nuget sources
$nugetOrgSource = "https://api.nuget.org/v3/index.json"
$lgNugetSource = "http://ustfsproxy.am.bm.net/LGNugetServer/nuget"


#Solution mocks... This will be provided by the caller, and the directory should be all that is needed, we can get the name of the solution file with a filter, but for POC this works
#$solutionPath = "C:\Users\Listerr\Documents\Visual Studio 2015\Projects\PackageUpdaterClassLibrary\PackageUpdaterClassLibrary.sln"
#$solutionDirectory = "C:\Users\Listerr\Documents\Visual Studio 2015\Projects\PackageUpdaterClassLibrary"

#This function gets the packages from the provided file content.
function GetPackages($fileContent)
{
	$regex = '<package id="(.*?)" version="(.*?)" targetFramework="(.*?)" />'
    $matches = ([regex]$regex).Matches($fileContent)
	return $matches
}

#Get the package Id from the match and parse it
function GetPackageId($text)
{
	If ($text.Length -eq 0)
	{
		return
	}
	
	#id="x 	x will be the fifth position
	$startingPosition = 4

	#Look for the package Id with this regex pattern.
	[regex]$regex = 'id="(.*?)"'
	$result = $regex.Matches($text) 	

	#Pull a substring that excludes the 'id=' and ignores the last quote
	$packageId = ParseValue $result $startingPosition
	
	return $packageId
}

#Get the version number from the match and parse it
function GetVersion($text)
{
	#version="x 	x will be the ninth position
	$startingPosition = 9
	
	#Look for the version with this regex pattern
	[regex]$regex = 'version="(.*?)"'
	$result = $regex.Matches($text) 
	
	$version = ParseValue $result $startingPosition
	 
	return $version
}

#Parse the value from a regex match without the preceding characters based on a starting position provided by the caller
function ParseValue($text, $startingPosition)
{
	$length = $result.Value.Length
	
	$lengthToRead = ($length - 1) - $startingPosition
	
	$value = $text.Value.SubString($startingPosition, $lengthToRead)
	
	return $value
}

#Get the distinct packages by traversing the solution project folders and placing them in a dictionary as long as the key doesn't exist
function GetDistinctPackages($solutionDirectory)
{
	$packageDictionary = @{}
	#Get the directories in the solution folder, Each project folder contains a packages.config file that we will collect packages from
	$directories = Get-ChildItem -Path $solutionDirectory -Attributes Directory
	ForEach($dir in $directories)
	{
		#Use PushD so we can return to the solution root
		PushD $solutionDirectory/$dir
		
		$fileExists = Test-Path packages.config
		
		If ($fileExists)
		{
			$fileContent = Get-Content $solutionDirectory/$dir/packages.config 
			$packagesXml = GetPackages($fileContent)
			
			#for each package that we parsed 
			ForEach($package in $packagesXml)
			{
				If ($package.Length -gt 0)
				{
					$id = GetPackageId($package)
					$version = GetVersion($package)
					If (-Not ($packageDictionary.ContainsKey($id)))
					{
						$packageDictionary.Add($id, $version)
					}
				}
			}
		}
		
		#Return to solution root
		PopD
	}
	
	return $packageDictionary
}

#Get the nuspec file by traveling to the .nuget folder and filtering the results to only contain the nuspec file
#Since the file object contains the name, we can modify the file by using it as the out file
function GetNuSpecFile($solutionRoot)
{	
	#removed .nuget for nuget
	$nuspecFile = Get-ChildItem -Path $solutionRoot/.nuget -Filter *.nuspec 

	return $nuspecFile
}

#Modify the nuspec file based on the packages collected from the packages.config files and only alter if the package is listed as a dependency
function ModifyNuSpecFile($file, $packages)
{
	$outputPath = $file.FullName
	
	$pattern = '<dependency id="{0}" version[=]["](.*?)["] />' -f $package.Key
	
	$fileContent = ($file | Get-Content | Out-String) 
	
	ForEach($package in $packages.GetEnumerator())
	{
		$pattern = '<dependency id="{0}" version[=]["](.*?)["] />' -f $package.Key
		
		$result = $fileContent -Match $pattern
		
		If ($result)
		{
			$stringToReplace = ([regex]$pattern).Match($fileContent) | Select Value
			$replaceValue =  '<dependency id="{0}" version="{1}" />' -f $package.Key, $package.Value
			$fileContent = $fileContent -Replace $stringToReplace.Value , $replaceValue
		}
	}
	
	Write-Host 'File content is '
	Write-Host $fileContent
	
	Set-Content -Path $outputPath -Value $fileContent -Force
	
}

function GetSolutionFile($solutionDirectory)
{
	$solutionFileName = Get-ChildItem -Path $solutionDirectory -Filter *.sln 
	
	Write-Host $solutionFileName.FullName

	return $solutionFileName.FullName
}

function CleanStagingDirectory()
{
	Remove-Item $dropLocation\*.nupkg
}

function GetNugetPackageToPublish()
{
	$nugetPackage = Get-ChildItem -Path $dropLocation -Filter *.nupkg
	return $nugetPackage.FullName
}

function LocateBuildInitTarget($solutionDirectory)
{
	$pattern = '(.*?)BuildInitTargets.proj'
	
	$buildFolder = '{0}/Build' -f $solutionDirectory

	$match = Get-ChildItem -Path $buildFolder | Where-Object {$_.Name -Match $pattern} 
	
	return '{0}\{1}' -f $buildFolder, $match
}

#Function to call to update packages and publish 
function UpdatePackages($solutionDirectory)
{
	#$sources = '{0};{1}' -f $lgNugetSource, $nugetPublishFolder
	$sources = '{0}' -f $lgNugetSource

	CleanStagingDirectory
	
	$solutionFileName = GetSolutionFile $solutionDirectory
	
	& $msBuildPath\msBuild $solutionFileName /t:Clean
	
	Write-Host 'Project cleaned...'
	
	& $nugetPath restore $solutionFileName -Source $sources 
	
	Write-Host 'Packages restored!'
	
	& $nugetPath update $solutionFileName -Source $sources  #list should be provided here 
	
	$packages = GetDistinctPackages $solutionDirectory
	
	$nuspecFile = GetNuSpecFile $solutionDirectory
	
	ModifyNuSpecFile $nuspecFile $packages
	
	#check in changes to TFS here
	#CheckInChanges
	
	$buildInitTargetFile = LocateBuildInitTarget $solutionDirectory
	
	#use msbuild to run the build init targets file
	#& $msBuildPath\msBuild $buildInitTargetFile
	
	
	
}

$solutionsToUpdate = New-Object System.Collections.ArrayList

#$solutionsToUpdate.Add("C:\Users\Listerr\Documents\Visual Studio 2015\Projects\PackageUpdaterClassLibrary")
#$solutionsToUpdate.Add("C:\Users\Listerr\Documents\Visual Studio 2015\Projects\DependentOnGreeter")

$solutionsToUpdate.Add("C:\TFS\Command Center\Components\EDPLFramework\Main\FrameworkBasePckgs\DeviceDriverBase\Main")

$timer = [System.Diagnostics.StopWatch]::StartNew()

$timer.Start()
	
ForEach($solution in $solutionsToUpdate)
{
	UpdatePackages $solution
}

$timer.Stop()
	
Write-Host 'Clean, update, build and nuspec modification took ' $timer.Elapsed
