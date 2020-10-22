$ErrorActionPreference = "Stop"
Set-StrictMode -Version 3
Import-Module "$PSScriptRoot/../Source/packDeb.psm1"

# compress the directory provided and create the destination file
function Compress([string] $srcDirPath, [string] $destFilePath)
{
    Write-Information "compressing $srcDirPath into $destFilePath"

    # if tar is not available use another compression tool
    # https://ss64.com/nt/tar.html
    tar -czf `
        $destFilePath `
        -C $srcDirPath `
        "."
}

# build HelloVersion application
dotnet publish `
    "$PSScriptRoot/HelloVersion/HelloVersion.csproj" `
    -c Release `
    /p:PublishProfile="$PSScriptRoot/HelloVersion/Properties/PublishProfiles/LinuxArm.pubxml"

# create and clean directories
New-Item -ItemType Directory -Path "$PSScriptRoot/DebianPackage/data/opt/HelloVersion" -Force > $null 
Remove-Item "$PSScriptRoot/DebianPackage/data/opt/HelloVersion/*" -Recurse -Force

# copy HelloVersion application into the uncompressed package structure
Copy-Item  `
    -Path "$PSScriptRoot/HelloVersion/bin/Release/netcoreapp3.1/publish/linuxArm/*" `
    -Destination "$PSScriptRoot/DebianPackage/data/opt/HelloVersion"  `
    -Recurse

New-DebianPackage  `
    -ControlDirPath "$PSScriptRoot/DebianPackage/control" `
    -DataDirPath "$PSScriptRoot/DebianPackage/data" `
    -OutDirPath "$PSScriptRoot/out" `
    -TempDirPath "$PSScriptRoot/out/temp" `
    -VersionAssemblyPath "$PSScriptRoot/DebianPackage/data/opt/HelloVersion/HelloVersion.dll" `
    -PackageRevision "001" `
    -CompressFunction $function:Compress
    