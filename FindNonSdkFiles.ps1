cd C:\git


$allDirectories = Get-ChildItem -Path C:\git -Attributes Directory


$csProjFiles = Get-ChildItem $allDirectories -Filter *.csproj -Recurse

ForEach($dir in $allDirectories)
{
   $projectFiles = Get-ChildItem -Path $dir.FullName -Filter *.csproj -Recurse

   ForEach($file in $projectFiles)
   {
    $isSdkProject = $file | select-string Microsoft.NET.SDK -Quiet

    If (-NOT $isSdkProject)
    {
        Write-Output $file.Name 
        Write-Output $dir
        Write-Output ""
        #break;
        
    }  
   }


   

}