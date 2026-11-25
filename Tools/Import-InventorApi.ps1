#Requires -Version 7.0

<#
.SYNOPSIS
	Copies the Inventor API files into Source/Content/<version>/.

.DESCRIPTION
	Reads each source, which is an Inventor installation folder or an installer media .zip file.
	Installs nothing, and extracts only the files that Packages.json names. The files stay byte for byte as
	Autodesk supplies them.

	Accepts only the releases that Packages.json names. The package version is <product year>.<update>.<patch>. It comes from the file version of
	Autodesk.iLogic.Interfaces.dll, which follows the product update. The interop version does not always change
	with an update.

.PARAMETER Source
	One or more Inventor installation folders or installer media .zip files.

.PARAMETER Version
	Replaces the version that the script reads from the files. Use it with one source only.

.PARAMETER Force
	Replaces a Source/Content/<version>/ folder that exists.

.EXAMPLE
	./Tools/Import-InventorApi.ps1 -Source "$env:ProgramFiles\Autodesk\Inventor 2027"

.EXAMPLE
	./Tools/Import-InventorApi.ps1 -Source "$env:USERPROFILE\Downloads\Inventor_2021.zip"
#>
[CmdletBinding()]
param(
	[Parameter(Mandatory)]
	[string[]] $Source,

	[ValidatePattern('^\d{4}\.\d+\.\d+$')]
	[string] $Version,

	[switch] $Force
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Add-Type -AssemblyName System.IO.Compression.FileSystem

$repositoryRoot = Split-Path -Parent $PSScriptRoot
$manifest = Get-Content -LiteralPath (Join-Path $repositoryRoot 'Packages.json') -Raw | ConvertFrom-Json

# The files to look for: each DLL, and the XML documentation beside it when there is one.
$wantedFiles = foreach ($package in $manifest.packages) {
	[pscustomobject]@{ Folder = $package.folder; Name = "$($package.assembly).dll"; Required = $true }
	[pscustomobject]@{ Folder = $package.folder; Name = "$($package.assembly).xml"; Required = $package.xml }
}

function Copy-FromInstallation([string] $InstallationFolder, [string] $Destination) {
	foreach ($file in $wantedFiles) {
		$path = Join-Path $InstallationFolder $file.Folder $file.Name
		if (Test-Path -LiteralPath $path -PathType Leaf) {
			Copy-Item -LiteralPath $path -Destination (Join-Path $Destination $file.Name)
		}
	}
}

function Copy-FromMedia([string] $ZipPath, [string] $Destination) {
	$zip = [System.IO.Compression.ZipFile]::OpenRead($ZipPath)
	try {
		foreach ($file in $wantedFiles) {
			# The media holds the installed tree under this path. The full suffix excludes the older interop copies.
			$suffix = "/x64/INV/PF/ADSK/INV/$($file.Folder)/$($file.Name)"
			$found = @($zip.Entries | Where-Object {
					$_.FullName.Replace('\', '/').EndsWith($suffix, [StringComparison]::OrdinalIgnoreCase)
				})

			if ($found.Count -gt 1) {
				throw "'$ZipPath' holds more than one '$($file.Name)'."
			}

			if ($found.Count -eq 1) {
				# The destination name comes from Packages.json, never from the zip entry.
				[System.IO.Compression.ZipFileExtensions]::ExtractToFile($found[0], (Join-Path $Destination $file.Name))
			}
		}
	}
	finally {
		$zip.Dispose()
	}
}

function Assert-AutodeskSignature([string] $Path) {
	$signature = Get-AuthenticodeSignature -LiteralPath $Path
	$isAutodesk = $signature.Status -eq 'Valid' -and $signature.SignerCertificate.Subject -match 'O="Autodesk, Inc\."'

	if (-not $isAutodesk) {
		throw "'$(Split-Path -Leaf $Path)' does not have a valid Autodesk signature (status: $($signature.Status))."
	}
}

function Get-PackageVersion([string] $Folder) {
	$iLogic = (Get-Item -LiteralPath (Join-Path $Folder 'Autodesk.iLogic.Interfaces.dll')).VersionInfo
	$interop = (Get-Item -LiteralPath (Join-Path $Folder 'Autodesk.Inventor.Interop.dll')).VersionInfo

	if ($interop.FileMajorPart -ne $iLogic.FileMajorPart) {
		throw "The interop ($($interop.FileVersion)) and iLogic ($($iLogic.FileVersion)) are from different releases."
	}

	# Software version 24 is Inventor 2020. A minor of 40 is update 4, and an older minor of 1 is update 1.
	$year = $iLogic.FileMajorPart + 1996
	$minor = $iLogic.FileMinorPart
	$update = $minor -ge 10 ? [int][math]::Floor($minor / 10) : $minor
	$patch = $iLogic.FileBuildPart % 100

	return "$year.$update.$patch"
}

if ($Version -and $Source.Count -gt 1) {
	throw 'Use -Version with one source only.'
}

foreach ($item in $Source) {
	$resolved = (Resolve-Path -LiteralPath $item).ProviderPath
	$staging = Join-Path ([System.IO.Path]::GetTempPath()) "inventor-api-$([guid]::NewGuid().ToString('N'))"
	$null = New-Item -ItemType Directory -Path $staging

	try {
		if (Test-Path -LiteralPath $resolved -PathType Container) {
			Copy-FromInstallation $resolved $staging
		}
		elseif ([System.IO.Path]::GetExtension($resolved) -eq '.zip') {
			Copy-FromMedia $resolved $staging
		}
		else {
			throw "'$resolved' is not an installation folder or a .zip file."
		}

		$missing = @($wantedFiles | Where-Object {
				$_.Required -and -not (Test-Path -LiteralPath (Join-Path $staging $_.Name))
			})

		if ($missing.Count -gt 0) {
			throw "'$resolved' does not contain: $($missing.Name -join ', ')."
		}

		Get-ChildItem -LiteralPath $staging -Filter '*.dll' | ForEach-Object { Assert-AutodeskSignature $_.FullName }

		$packageVersion = $Version ? $Version : (Get-PackageVersion $staging)
		$release = $packageVersion.Split('.')[0]

		if ($release -notin $manifest.releases.PSObject.Properties.Name) {
			throw "Inventor $release is not in the releases of Packages.json."
		}

		$target = Join-Path $repositoryRoot 'Source' 'Content' $packageVersion

		if (Test-Path -LiteralPath $target) {
			if (-not $Force) {
				throw "'$target' exists. Use -Force to replace it."
			}

			Remove-Item -LiteralPath $target -Recurse -Force
		}

		$null = New-Item -ItemType Directory -Path $target -Force
		Copy-Item -Path (Join-Path $staging '*') -Destination $target

		[pscustomobject]@{
			Version = $packageVersion
			Files   = @(Get-ChildItem -LiteralPath $target -File).Count
			Source  = Split-Path -Leaf $resolved
		}
	}
	finally {
		Remove-Item -LiteralPath $staging -Recurse -Force -ErrorAction SilentlyContinue
	}
}
