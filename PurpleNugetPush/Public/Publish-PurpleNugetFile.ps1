<#

.Synopsis
Push nuget files to a Artifact feed from VisualStudio dev ops.

.Description
Pushes a nuget file to a nuget v3 feed. The command targets the api requirements for the artifact feeds you get with MS dev ops hosted at visualstudio.

At time of creatation the official nuget libraries don't allow powershell to push to a v3 feed using authentication. Basic Auth is needed on these feeds. 

May also work on other authenticated v3 feeds.

.Parameter Credential
Username and password to authenticate with. Should be the same ones when used with the Find/Install-PSResource commands. Typically for VisualStudio devops, this is you PAT and any username, other nuget feeds might require a matching username.

.Parameter Feed
The name of the Atrifact feed. Needed and required only when using the Organisation parameter. This is sypically the named folder of the feed, ie ../_artifacts/feed/<feedname>/ or ../_packaging/<feedname>/nuget/v3/index.json

.Parameter File
Path to file to be uploaded. Should be a .nuget file for best results.

.Parameter Organisation
The name of the organisation hosting the feed. This is typically the subdomain of the feed, ie: <orgname>.visualstudio.com/

.Parameter PAT
You Personal Access Token. This is only needed if you have a different publish PAT from your normal retrival PAT. If not specified then the password from the credential parameter will be used as the publish PAT.

.Parameter Repository
PSResourceRepository to publish to. The repository should be a v3 feed, v3 feeds should end with `index.json`.

.Parameter Uri
Direct URI of the feed to publish to. This should be the service index not the publish endpoint.

.Example
Publish-PurpleNugetFile -Credential <PSCredential> -File module.0.0.1.nupkg -Uri https://mynugetfeed.example.com/index.json
This will directly publish a file to the given feed. The Uri should be the service index of the nuget feed.

.Example
Publish-PurpleNugetFile -Credential <PSCredential> -File module.0.0.1.nupkg -Repository myrepo
Will retrive the repository from the PowershellGet repository list called myrepo. The feed uri can been seen using `Get-PSResourceRepository myrepo`.

.Example
Publish-PurpleNugetFile -Credential <PSCredential> -Organisation <String> -Feed <String> -File <String>
Will publish to the given Organisation and Feed names in a VisualStudio hosted Artifact feed.

#>
function Publish-PurpleNugetFile {
    [CmdletBinding(DefaultParameterSetName="URI")]
    Param(
        [Parameter(Mandatory)]
        [psCredential]$Credential,
        [Parameter(ParameterSetName="URI")]
        [uri]$Uri,
        [Parameter(ParameterSetName="Repository")]
        [ArgumentCompleter(
            {
                param($Command, $Parameter, $WordToComplete, $CommandAst, $FakeBoundParams)
                # Do completion here.
                (Get-PSResourceRepository ($WordToComplete+ '*')).Name
            }
        )]
        [string]$Repository,
        [Parameter(ParameterSetName="VSDetails",Mandatory)]
        [Alias('Organization')]
        [string]$Organisation,
        [Parameter(ParameterSetName="VSDetails",Mandatory)]
        [string]$Feed,
        [Parameter(Mandatory)]
        [ValidateScript({
            if (Test-Path -LiteralPath $_ -PathType Leaf) {
                $true
            } else {
                throw "File path not found."
            }
        })]
        [Alias('Path')]
        [string]$File,
        [Parameter()]
        [string]$PAT
    )
    end {

        $endpointURI = Switch ($PSCmdlet.ParameterSetName){
            'URI' { $Uri }
            'VSDetails' {
                "https://$Organisation.pkgs.visualstudio.com/_packaging/$Feed/nuget/v3/index.json"
            }
            "Repository" {
                try {
                    $repo = Get-PSResourceRepository -Name $Repository
                } catch {
                    Write-Error "Unable to get Repo Feed address, try Uri instead. Ensure you have PowershellGet Preview 3.0 or higher to use this feature." -ErrorAction Stop
                }
                if (-not $repo) {
                    return # if we are here either the try catch errored so no command, or the comand didn't return anything so should have alread given an error.
                }
                $repo.uri
            }
            Default { Write-Error "ParameterSet not Yet Implimented" -Category NotImplemented -ErrorAction Stop }
        }
        $endpointResult = Invoke-RestMethod -Uri $endpointURI -Credential $Credential -ErrorAction Stop
        if (-not $endpointResult){
            Write-Error -Message "Unable to get service index, result empty." -ErrorAction Stop
            return
        }
        $puburi = $endpointResult.resources | Where-Object '@type' -like PackagePublish* | ForEach-Object '@id'
        if (-not $puburi) {
            Write-Error -Message "Unable to find a Publish endpoint in the Service Index." -TargetObject $puburi -ErrorAction Stop
        }

        $apikey = if (-not $PAT) {
            # use pass as PAT for publish
            $Credential.GetNetworkCredential().Password
        } else {
            $PAT
        }

        $IWRParams = @{
            Uri = $puburi
            Headers = @{'X-NuGet-ApiKey'=$apikey}
            Credential = $cred
            Method = "put"
            Form = @{file=get-item $File}
        }
        $PushResult = Invoke-WebRequest @IWRParams -SkipHttpErrorCheck
        if ($PushResult.StatusCode -in '200','202','201'){
            [PSCustomObject]@{
                Statuscode = $PushResult.StatusCode
                Status = $PushResult.StatusDescription
                Success = $true
            }
        } else {
            $resultData = $PushResult.Content
            try { 
                $resultData = $PushResult.Content | ConvertFrom-Json -ErrorAction Stop
            } catch {
                # error action silentycontinue does not appear to work so
                # have this stupid emtpy catch >:(
            }
            if ($resultData.Message) {
                #VS nuget feed uses message and some extra fields to return errors.
                Write-Error -Message $resultData.Message -TargetObject $file -ErrorId $resultData.typeName -CategoryReason $resultData.typeKey -ErrorAction Stop
            } elseif ($resultData.Error) {
                # github's nuget sends errors in error property.
                Write-Error -Message $resultData.Error -ErrorAction Stop -ErrorId Nuget.PutApiError
            } else {
                [PSCustomObject]@{
                    Statuscode = $PushResult.StatusCode
                    Status = $PushResult.StatusDescription
                    Success = $false
                    Response = $PushResult
                }
            }

        }
    }
}