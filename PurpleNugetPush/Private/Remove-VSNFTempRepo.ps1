function Remove-VSNFTempRepo {
    [CmdletBinding()]
    Param()
    $path = Join-Path $env:ProgramData -ChildPath purplemonkeymad
    $path = Join-Path $path -ChildPath temp_PublishRepo

    $name = '_Temp_VSNFPublishRepo'

    Write-Verbose "Attempting to remove local repository."
    $null = Unregister-PSResourceRepository -Name $name
}