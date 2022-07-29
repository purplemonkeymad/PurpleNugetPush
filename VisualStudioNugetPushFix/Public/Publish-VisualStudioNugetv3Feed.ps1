function Publish-VisualStudioNugetv3FeedFile {
    [CmdletBinding(DefaultParameterSetName="URI")]
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
            if (Test-Path -LiteralPath $_ -PathType Leaf) {
                $true
            } else {
                throw "File path not found."
            }
        })]
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
        Invoke-WebRequest @IWRParams  #-ContentType $mp.Headers.ContentType  
    }
}