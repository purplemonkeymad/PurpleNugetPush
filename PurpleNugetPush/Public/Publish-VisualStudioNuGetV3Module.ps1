<#

.Synopsis
Push Powershell modules to an Artifact feed from VisualStudio dev ops.

.Description
Pushes a Powershell modules to a nuget v3 feed. The command targets the api requirements for the artifact feeds you get with MS dev ops hosted at visualstudio.

At time of creatation the official nuget libraries don't allow powershell to push to a v3 feed using authentication. Basic Auth is needed on these feeds. 

May also work on other authenticated v3 feeds.

.Parameter Credential
Username and password to authenticate with. Should be the same ones when used with the Find/Install-PSResource commands. Typically for VisualStudio devops, this is you PAT and any username, other nuget feeds might require a matching username.

.Parameter Feed
The name of the Atrifact feed. Needed and required only when using the Organisation parameter. This is sypically the named folder of the feed, ie ../_artifacts/feed/<feedname>/ or ../_packaging/<feedname>/nuget/v3/index.json

.Parameter Organisation
The name of the organisation hosting the feed. This is typically the subdomain of the feed, ie: <orgname>.visualstudio.com/

.Parameter PAT
You Personal Access Token. This is only needed if you have a different publish PAT from your normal retrival PAT. If not specified then the password from the credential parameter will be used as the publish PAT.

.Parameter Path
Path to a module folder to be uploaded. The folder name should already match the module name.

.Parameter Repository
PSResourceRepository to publish to. The repository should be a v3 feed, v3 feeds should end with `index.json`.

.Parameter Uri
Direct URI of the feed to publish to. This should be the service index not the publish endpoint.

.Example
Publish-VisualStudioNugetv3FeedModule -Credential <PSCredential> -Path <String> -Uri https://mynugetfeed.example.com/index.json
This will publish a module to the given feed. The Uri should be the service index of the nuget feed.

.Example
Publish-VisualStudioNugetv3FeedModule -Credential <PSCredential> -Path <String> -Repository myrepo
Will retrive the repository from the PowershellGet repository list called myrepo. The feed uri can been seen using `Get-PSResourceRepository myrepo`.

.Example
Publish-VisualStudioNugetv3FeedModule -Credential <PSCredential> -Organisation <String> -Feed <String> -Path <String>
Will publish to the given Organisation and Feed names in a VisualStudio hosted Artifact feed.

#>
function Publish-VisualStudioNugetv3FeedModule {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory)]
        [psCredential]$Credential,
        [Parameter(ParameterSetName="URI")]
        [uri]$Uri,
        [Parameter(ParameterSetName="Repository")]
        [string]$Repository,
        [Parameter(ParameterSetName="VSDetails",Mandatory)]
        [Alias('Organization')]
        [string]$Organisation,
        [Parameter(ParameterSetName="VSDetails",Mandatory)]
        [string]$Feed,
        [Parameter(Mandatory)]
        [ValidateScript({
            if (Test-Path -LiteralPath $_ -PathType Container ) {
                $manifestTest = Join-Path $_ -ChildPath '*.psd1'
                if (Test-Path -Path $manifestTest -PathType Leaf){
                    $true
                } else {
                    throw "Folder does not contain a powershell manifest file."
                }
            } else {
                throw "Folder path not found."
            }
        })]
        [string]$Path,
        [Parameter()]
        [string]$PAT
    )
    end {
        # check for existing temp repo
        try {
            $testrepo = Get-PSResourceRepository -Name '_Temp_VSNFPublishRepo' -ErrorAction Stop
        } catch {
            #ok lets init a repo
            Initialize-VSNFTempRepo
            $testrepo = Get-PSResourceRepository -Name '_Temp_VSNFPublishRepo' -ErrorAction Stop
        }

        if (-not $testrepo){
            Write-Error -Message "Unable to create or locate the temporary repository for publishing." -ErrorAction Stop
            return
        }

        $actualPath = Resolve-Path $Path
        $moduleFolderName = Split-Path -Path $actualPath -Leaf
        $manifestFileName = Join-Path $Path -ChildPath ($moduleFolderName + '.psd1')
        if (-not (Test-Path $manifestFileName -PathType Leaf)) {
            $manifestFileName = Get-Item (Join-Path $actualPath -ChildPath '*.psd1') -ErrorAction Stop
            if (-not $manifestFileName -or $manifestFileName.count -gt 1) {
                Write-Error "Module Manifest missing or multiple manifests found, make sure the folder has the same name as the module (and manifest.)" -ErrorAction Stop
            }
            Write-Verbose "Module name does not match manifest name, but found a single manifest so continuing."
            $manifestFileName = $manifestFileName.FullName
        }
        $manifestName = ( Get-Item $manifestFileName ).BaseName

        $ModuleProperties = Import-PowerShellDataFile $manifestFileName
        $version = $ModuleProperties.ModuleVersion
        $PredictedFilename = Join-Path $testrepo.uri.localpath.tostring() -ChildPath ($manifestName +'.' + $version + '.nupkg' )

        if (Test-Path $PredictedFilename -PathType Leaf) {
            Write-Verbose "Existing publish file exists, removing existing file."
            Remove-Item $PredictedFilename -force -ErrorAction Ignore
        }

        Publish-PSResource -Path $actualPath -Repository $testrepo.Name

        if (-not (Test-Path $PredictedFilename -PathType Leaf)){
            Write-Error "Unable to find published file, was expecting $PredictedFilename, but file not found." -TargetObject $PredictedFilename -ErrorAction Stop
        }

        $FeedParams = @{}
        foreach ( $Key in $PSBoundParameters.Keys){
            $FeedParams.$Key = $PSBoundParameters.$Key
        }

        $FeedParams.Path = $PredictedFilename

        Publish-VisualStudioNugetv3FeedFile @FeedParams
    }
}