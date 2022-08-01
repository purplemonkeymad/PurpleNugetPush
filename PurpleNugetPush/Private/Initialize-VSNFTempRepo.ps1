function Initialize-VSNFTempRepo {
    [CmdletBinding()]
    Param()
    $path = Join-Path $env:ProgramData -ChildPath purplemonkeymad
    $path = Join-Path $path -ChildPath temp_PublishRepo

    $null = New-Item -Path $path -Force -ErrorAction Stop -ItemType Directory

    $name = '_Temp_VSNFPublishRepo'

    Write-Verbose "Attempting to create a new local repository."
    $null = Register-PSResourceRepository -Name $name -Uri $path -Priority 50
}