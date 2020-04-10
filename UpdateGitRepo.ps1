param([string] $gitDirectory, [bool] $recurse)
#$gitDirectory is your main directory where git projects are stored
#$recurse is only necessary if you have git directories deeper in your main directory
#C:\git----
#          |
#          project1
#          project2
#          directory ------
#                         |
#                         project3


#Branch that is currently in use will be in format * branchName
#Remove any white space and special characters so we can call git config branch."branchName"
#To extract properties 
function ParseLocalBranchName($branch)
{
	$newBranch = $branch.Trim('*')
	$newBranch = $newBranch.Trim()
	return $newBranch
}

#Remote branch name will be in format of refs/heads/remoteBranchName
#In order to rebase onto proper remote branch, we need the upstream branch
function ParseRemoteBranchName($branch)
{
	$indexToStart = -1
	For ($i = $branch.Length; $i -gt 0; $i--)
	{
		If ($branch[$i] -eq '/')
		{
			#refs/head/master
			#This if statement catches the /master, so set index to + 1
			# so we only have master, not /master
			$indexToStart = $i + 1
			break;
		}
	}
	
	If($indexToStart -ne -1)
	{
		$remoteBranchName = $branch.SubString($indexToStart, ($branch.Length - $indexToStart));
	}
	Else
	{
		Write-Output "Branch name provided did not follow structure of refs/head/branchName"
	}
	
	return $remoteBranchName
}

#Recurses through all directories and subdirectories and returns only top level directory with .git folder
function GetGitDirectories($gitDirectory, $recurse)
{	
	$directories = New-Object Collections.Generic.List[System.IO.DirectoryInfo]
	# May want to remove this $gitRepo thing once done, could just be used for testing, but maybe not
	if ($recurse -eq $true)
	{
		$directories = Get-ChildItem $gitDirectory -Attributes Directory -Recurse
	}
	Else
	{
		$directories = Get-ChildItem $gitDirectory -Attributes Directory
	}
	
	$gitDirectories = New-Object Collections.Generic.List[System.IO.DirectoryInfo]
	$dirLength = $directories.Length
	$counter = 0
	ForEach ($dir in $directories)
	{
		Push-Location $dir.FullName
		$name = $dir.FullName
		If (Test-Path .git)
		{
			$gitDirectories.Add($dir)
		}
		
		$percentComplete = ($counter/$dirLength) * 100

        Write-Progress -Activity $name -Status "Progress" -PercentComplete $percentComplete
		$counter++
		Pop-Location
	}

	Write-Progress -Activity 'Complete' "Progress" -PercentComplete 100 -Completed
	
	return $gitDirectories
}

function CheckoutMaster()
{
	$directories = GetGitDirectories
	
	ForEach($dir in $directories)
	{
		Push-Location $dir.FullName
		
		git checkout master
		
		Pop-Location
	}
}
	
	
	#Start of script
    If ($gitDirectory -eq '' -OR $gitDirectory -eq $null )
	{
		$gitDirectory = 'C:\git'
	}

	Write-Output "Gathering all git directories in base folder $gitDirectory..."

	$directories = GetGitDirectories $gitDirectory $recurse
	Write-Output "Directories gathered."
	
	ForEach($dir in $directories)
	{
		Push-Location $dir.FullName
		
		$repoStatus = git status
		
		Write-Output $dir.Name
		Write-Output "-------------------------------------------------"
		
		#Check to see that the repository is clean, otherwise, skip this repository
		#Later, I would like to add a flag to reset the repository
		If ($repoStatus -Match 'nothing to commit')
		{
			Write-Output "Repository $dir is clean"
		}
		Else
		{
			Write-Output "Repository $dir is not clean"
			Write-Output "Changes are detected in the index... skipping this repository"
			Write-Output "-------------------------------------------------"
			Write-Output ""
			#Travel back to the base git directory and stop working with this repository
			Pop-Location
			continue;
		}
		
		#Get the changes that are in the remote repository
		git fetch
		
		#Get the name of the remote repository from the configuration file
		#Usually, this is origin, but don't assume it is
		$remoteName = git remote show
		
		#Get all the local branches from this repository
		$branches = git branch --list
		
		ForEach($branch in $branches)
		{
			$parsedLocalBranch = ParseLocalBranchName($branch)
			Write-Output $parsedLocalBranch
			Write-Output "-------------------------------------------------"
	
			#The merge property will contain a name like refs/head/master 
			#that we can parse to get the remote branch name
			$remote = git config branch."$parsedLocalBranch".merge
			
			#If the branch name is not empty or null, then we have an upstream branch
			If ($remote -ne '' -AND $remote -ne $null )
			{
				$parsedRemoteBranchName = ParseRemoteBranchName($remote)
				
				#Write-Output "expected command is git rebase $remoteName/$parsedRemoteBranchName $parsedLocalBranch"
				#Run the git rebase command with the parsed variables
				git rebase $remoteName/$parsedRemoteBranchName $parsedLocalBranch
			}
			Else
			{
				Write-Output "This branch is not set to track an upstream branch"
				Write-Output "Branch: $parsedLocalBranch Repository: $dir"
			}
			
			Write-Output "-------------------------------------------------"
			Write-Output ""
		}
		
		Write-Output "Workflow for repository $dir is finished..."
		Write-Output ""
		
		
		Pop-Location
	}


