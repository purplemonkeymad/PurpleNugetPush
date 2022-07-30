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