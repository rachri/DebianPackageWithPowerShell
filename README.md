# DebianPackageWithPowerShell

Create Debian package with PowerShell scripts on Windows

## Motivation

On Windows tools are hard to find to create Debian packages.
.net core makes it easy to create Command line Applications which target Linux.
When the development platform and build environemnt is Windows and you want to publish an application to Linux as a Debian package there is a need to create the package using Windows tooling.

## Implementation

The Powershell module make _Package.psm1_ implements the `New-DebianPackage` commandlet. The commandlet creates a Debian package out of a given folder structure.

## Limitations

The commandlet is intended for small and simple .net core console applications which get published to a Debian Linux. Consider using proper Debian tooling for doing advanced packages.

Windows out-of-the-box offers only very limited support for creating compressed files in a format acceptable by the Debian package management. Therefore the calling script needs to provide a compression function. The sample uses tar.exe which is available on some Versions of Windows 10.

## Resources

[Basics of the Debian package management system](https://www.debian.org/doc/manuals/debian-faq/pkg-basics.en.html)

[Debian file format](https://en.wikipedia.org/wiki/Deb_(file_format))

[tar commandline options in Windows](https://ss64.com/nt/tar.html)

## Pitfalls when creating packages

- control file and scripts (postinst etc.) must have line endings of LF and not CR/LF which is the default on Windows.
- Shell scripts need to have a line ending on the last line of the file.
