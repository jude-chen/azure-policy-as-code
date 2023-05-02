function Get-ModifiedFileList {
    $CurrentBranch = Get-GitBranchName
    if (($CurrentBranch -eq 'main') -or ($CurrentBranch -eq 'master')) {
        Write-Verbose 'Gathering modified files from the pull request' -Verbose
        $Diff = git diff --name-only --diff-filter=AM HEAD^ HEAD
    }
    else {
        Write-Verbose 'Gathering modified files between current branch and main' -Verbose
        $Diff = git diff --name-only --diff-filter=AM origin/main
        if ($Diff.count -eq 0) {
            Write-Verbose 'Gathering modified files between current branch and master' -Verbose
            $Diff = git diff --name-only --diff-filter=AM origin/master
        }
    }
    $ModifiedFiles = $Diff | Get-Item -Force

    return $ModifiedFiles
}

function Get-GitBranchName {
    [CmdletBinding()]
    param ()

    # Get branch name from Git
    $BranchName = git branch --show-current

    # If git could not get name, try GitHub variable
    if ([string]::IsNullOrEmpty($BranchName) -and (Test-Path env:GITHUB_REF_NAME)) {
        $BranchName = $env:GITHUB_REF_NAME
    }

    # If git could not get name, try Azure DevOps variable
    if ([string]::IsNullOrEmpty($BranchName) -and (Test-Path env:BUILD_SOURCEBRANCHNAME)) {
        $BranchName = $env:BUILD_SOURCEBRANCHNAME
    }

    return $BranchName
}

choco install armclient --source=https://chocolatey.org/api/v2/ --no-progress
ARMClient.exe spn $env:tenantId $env:servicePrincipalId $env:servicePrincipalKey
## get the changed files
$filelist = Get-ModifiedFileList
$count = $filelist.Length
Write-Host "Processing ${count} files"
For ($i = 0; $i -lt $count; $i++) {
    $file = $filelist[$i]
    ## Push policy defitions, assignments, etc.
    Write-Host "Processing file ${file}"
    if ($file -like "*\Policies\*\*.json") {
        $policy_id = $(Get-Content $file -Raw | ConvertFrom-Json).id
        Write-Host "Processing policy $policy_id"
        & ARMClient.exe PUT "${policy_id}?api-version=2021-06-01" @$file
    }
    else {
        Write-Host "Not a JSON file, skipping file ${file}"
    }
}
