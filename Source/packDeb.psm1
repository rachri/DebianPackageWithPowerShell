<#
 .Synopsis
  Creates a Debian package out of the provided folder structure.

 .Description
  Create a Debian installer package (.deb) from the folder structure provided.
  For a documentation of the file structure see
  https://en.wikipedia.org/wiki/Deb_(file_format)#/media/File:Deb_File_Structure.svg
  The file mainly contains two compressed files: control and data.
  The control file is modified by the script with the current version and packet size
  PowerShell has no built-in functionality to create archives understandable by the
  Debian package manager. The calling script must provide a function for creating
  these archives. Starting from Windows 10 (1903) build 17063 this can be achieved
  using the tar command.

 .Parameter ControlDirPath
  Path to the folder which contains the content for the control archive.

  .Parameter DataDirPath
  Path to the folder which contains the content for the data archive.

  .Parameter OutDirPath
  Path to the directory where the Debian file is created.
  The filename is created according to
  https://www.debian.org/doc/manuals/debian-faq/pkg-basics.en.html#pkgname

  .Parameter TempDirPath
  Path to a folder where temporary files will be stored during creation.
  The content of the path is deleted by the commandlet before use.

  .Parameter VersionAssemblyPath
  Path to a .net Assembly from which the version of the application can be determined.

  .Parameter PackageRevision
  A string containing the revision number of the package

  .Parameter CompressFunction
  A function defined by the caller which compresses a directory into a single file
  first argument: path to the existing source directory
  second argument: path to the resulting file (the archive)

 .Example
   # Create a new Debian package
   New-DebianPackage  `
    -ControlDirPath "./DebianPackage/control" `
    -DataDirPath "./DebianPackage/data" `
    -OutDirPath "./out" `
    -TempDirPath "./out/temp" `
    -VersionAssemblyPath "./DebianPackage/data/usr/bin/HelloWorld/HelloWorld.dll" `
    -PackageRevision "001" `
    -CompressFunction $function:Compress
#>

Set-StrictMode -Version 3
$ErrorActionPreference = "Stop"

function New-DebianPackage {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)] [string] $ControlDirPath,
        [Parameter(Mandatory=$true)] [string] $DataDirPath,
        [Parameter(Mandatory=$true)] [string] $OutDirPath,
        [Parameter(Mandatory=$true)] [string] $TempDirPath,
        [Parameter(Mandatory=$true)] [string] $VersionAssemblyPath,
        [Parameter(Mandatory=$true)] [string] $PackageRevision,
        [Parameter(Mandatory=$true)] [scriptblock] $CompressFunction
    )

    $version = ReadAssemblyVersion $VersionAssemblyPath
    $packageName = ReadProperty "Package" "$ControlDirPath/control"
    $architecture = ReadProperty "Architecture" "$ControlDirPath/control"
    $installedSize = FolderSizeKb $DataDirPath

    SetProperty "Version" $version "$ControlDirPath/control"
    SetProperty "Installed-Size" $installedSize "$ControlDirPath/control"

    $OutFilePath = "$OutDirPath/${packageName}_$version-${PackageRevision}_$architecture.deb"

    # cleanup temp directory
    PurgeOrCreateDir($TempDirPath)

    # prepare the files
    CreateDebianBinaryFile "$TempDirPath/debian-binary"

    # invoke the provided compression function
    $CompressFunction.Invoke($ControlDirPath, "$TempDirPath/control.tar.gz")
    $CompressFunction.Invoke($DataDirPath, "$TempDirPath/data.tar.gz")

    # create deb package file and write the archive file signature
    New-Item -Path $OutFilePath -ItemType File -Force > $null
    Add-Content -Path $OutFilePath -Value "!<arch>`n" -Encoding ascii -NoNewline

    # add the small package section
    $content = CreateFileEntry "$TempDirPath/debian-binary"
    AppendBytes $OutFilePath $content

    # add the control section
    $content = CreateFileEntry "$TempDirPath/control.tar.gz"
    AppendBytes $OutFilePath $content

    # add the data section
    $content = CreateFileEntry "$TempDirPath/data.tar.gz"
    AppendBytes $OutFilePath $content

    Write-Information "finished creating $OutFilePath"
}

# Make sure that the provided directory exists and is empty
function PurgeOrCreateDir([string] $dirPath)
{
    if (Test-Path -PathType Container $dirPath)
    {
        Remove-Item "$dirPath/*" -Force -Recurse
    }
    else
    {
        New-Item -ItemType Directory -Path $dirPath  -Force > $null
    }
}

# Create content of the debian-binary file and write it to the provided path
function CreateDebianBinaryFile([string] $destFilePath)
{
    New-Item -Path $destFilePath -ItemType File -Force > $null
    Add-Content -Path $destFilePath -Value "2.0`n" -Encoding ascii -NoNewline
}

function CreateFileEntry([string] $filePath)
{
    [OutputType([byte[]])]

    $file = Get-Item($filePath)

    # for structure see https://en.wikipedia.org/wiki/Deb_(file_format)#/media/File:Deb_File_Structure.svg
    $name = "{0,-16}" -f $file.Name
    $unixtime = Get-Date $file.LastWriteTimeUtc -UFormat %s
    $timeStamp = "{0,-12}" -f [Math]::Round($unixtime)
    $ownerId = "{0,-6}" -f 0
    $groupId = "{0,-6}" -f 0
    $fileMode = "{0,-8}" -f 100644
    $fileContent = ReadAllBytes $file
    $fileSize = "{0,-10}" -f $fileContent.Length    

    Write-Information "$name      $fileSize"
    $header = $name + $timeStamp + $ownerId + $groupId + $fileMode + $fileSize + "```n"
    $bytes = [System.Text.Encoding]::ASCII.GetBytes($header) + $fileContent

    # from https://en.wikipedia.org/wiki/Ar_(Unix)#File_header
    # Each archive file member begins on an even byte boundary; 
    # a newline is inserted between files if necessary. 
    # Nevertheless, the size given reflects the actual size of the 
    # file exclusive of padding.
    if ($bytes.Length % 2 -eq 1)
    {
        $bytes = $bytes + [System.Text.Encoding]::ASCII.GetBytes("`n")
    }

    # depending on the size of the data file this byte[] can become big!
    return $bytes
}

function ReadAssemblyVersion([string] $filePath)
{
    return (Get-Item -Path $filePath).VersionInfo.ProductVersion
}

function ReadProperty([string] $property, [string] $controlFilePath)
{
    $content = Get-Content $controlFilePath

    foreach($c in $content)
    {
        if ($c.StartsWith($property + ":"))
        {
            $pl = $property.Length + 2
            $value = $c.Substring($property.Length + 1, $c.Length - $pl +1).Trim()
            return $value
        }
    }

    return ""
}

function SetProperty([string] $property, [string] $value, [string] $controlFilePath)
{
    $content = Get-Content -Path $controlFilePath

    $i = 0
    foreach($c in $content)
    {
        if ($c.StartsWith($property + ":"))
        {
            $content[$i] = $property + ": " + $value
        }

        # make sure that we have a LF line end
        $content[$i] = $content[$i] + "`n"

        $i++
    }

    # added LF line end before!
    Set-Content -Path $controlFilePath -Value $content -NoNewline
}

function FolderSizeKb([string] $dirPath)
{
    $sizeKb = ((Get-ChildItem $dirPath -Recurse | Measure-Object -Property Length -Sum ).Sum / 1Kb)
    return [Math]::Round($sizeKb, 0)
}

function ReadAllBytes([string] $filePath)
{
    [OutputType([byte[]])]

    # Get-Content -AsByteStream is not available in Powershell 5.1 
    # nor is Get-Content -Enconding byte available in 7.1
    # -> do it with .net so that packag runs with 5.1 and 7.1
    $bytes = [System.IO.File]::ReadAllBytes($filePath)

    return $bytes
}

function AppendBytes([string] $filePath, [byte[]] $bytes)
{
    # Add-Content -AsByteStream is not available in Powershell 5.1 
    # -> do it with .net so that packag runs with 5.1 and 7.1

    $stream = [System.IO.File]::OpenWrite($filePath)
    # append at end of file
    $stream.Position = $stream.Length

    $writer = [System.IO.BinaryWriter]::new($stream)
    $writer.Write($bytes)
    $writer.Close()
}

Export-ModuleMember -Function New-DebianPackage
