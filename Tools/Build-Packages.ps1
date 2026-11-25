#Requires -Version 7.0

<#
.SYNOPSIS
	Builds the NuGet packages from the files in Libs/.

.DESCRIPTION
	Makes one package for each assembly of each Libs/<version>/ folder, as Packages.json describes.
	Each package holds the files under ref/<framework>/, so a consumer compiles against them and copies nothing.
	Dependencies between the packages use the exact version.

	This script publishes nothing. The packages go to artifacts/packages/.

.PARAMETER Version
	The Libs/ versions to build. The default is all of them.

.EXAMPLE
	./Tools/Build-Packages.ps1

.EXAMPLE
	./Tools/Build-Packages.ps1 -Version 2027.2.0
#>
[CmdletBinding()]
param(
	[string[]] $Version
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repositoryRoot = Split-Path -Parent $PSScriptRoot
$manifest = Get-Content -LiteralPath (Join-Path $repositoryRoot 'Packages.json') -Raw | ConvertFrom-Json
$libsFolder = Join-Path $repositoryRoot 'Libs'
$nuspecFolder = Join-Path $repositoryRoot 'artifacts' 'nuspec'
$outputFolder = Join-Path $repositoryRoot 'artifacts' 'packages'
$project = Join-Path $repositoryRoot 'Source' 'Package.csproj'

function ConvertTo-XmlText([string] $Text) {
	return [System.Security.SecurityElement]::Escape($Text)
}

function New-Nuspec($Package, [string] $PackageVersion, [string] $Framework, [string] $SourceFolder) {
	$id = "$($manifest.idPrefix).$($Package.name)"
	$release = $PackageVersion.Split('.')[0]

	$dependencies = foreach ($name in $Package.dependencies) {
		"        <dependency id=`"$($manifest.idPrefix).$name`" version=`"[$PackageVersion]`" />"
	}

	$files = foreach ($extension in 'dll', 'xml') {
		$path = Join-Path $SourceFolder "$($Package.assembly).$extension"
		if (Test-Path -LiteralPath $path) {
			"    <file src=`"$(ConvertTo-XmlText $path)`" target=`"ref/$Framework/`" />"
		}
	}

	$notice = ConvertTo-XmlText (Join-Path $repositoryRoot 'NOTICE.md')
	$readme = ConvertTo-XmlText (Join-Path $repositoryRoot 'Source' 'PackageReadme.md')

	$content = @"
<?xml version="1.0" encoding="utf-8"?>
<package xmlns="http://schemas.microsoft.com/packaging/2013/05/nuspec.xsd">
  <metadata>
    <id>$id</id>
    <version>$PackageVersion</version>
    <authors>$($manifest.owner)</authors>
    <description>Unofficial package. $(ConvertTo-XmlText $Package.description) For Inventor $release, compile time only.</description>
    <license type="file">NOTICE.md</license>
    <readme>PackageReadme.md</readme>
    <projectUrl>$($manifest.repositoryUrl)</projectUrl>
    <repository type="git" url="$($manifest.repositoryUrl)" />
    <tags>autodesk inventor ilogic api reference unofficial</tags>
    <dependencies>
      <group targetFramework="$Framework">
$($dependencies -join "`n")
      </group>
    </dependencies>
  </metadata>
  <files>
$($files -join "`n")
    <file src="$notice" target="" />
    <file src="$readme" target="" />
  </files>
</package>
"@

	$path = Join-Path $nuspecFolder $PackageVersion "$id.nuspec"
	$null = New-Item -ItemType Directory -Path (Split-Path -Parent $path) -Force
	Set-Content -LiteralPath $path -Value $content

	return $path
}

$available = @()
if (Test-Path -LiteralPath $libsFolder) {
	$available = @(Get-ChildItem -LiteralPath $libsFolder -Directory | Where-Object Name -Match '^\d{4}\.\d+\.\d+$')
}

if ($available.Count -eq 0) {
	throw 'Libs/ holds no version folder. Run Tools/Import-InventorApi.ps1 first.'
}

if ($Version) {
	$unknown = @($Version | Where-Object { $_ -notin $available.Name })
	if ($unknown.Count -gt 0) {
		throw "Libs/ does not hold: $($unknown -join ', ')."
	}

	$available = @($available | Where-Object Name -In $Version)
}

& dotnet restore $project --verbosity quiet
if ($LASTEXITCODE -ne 0) {
	throw "The restore of '$project' failed."
}

foreach ($folder in $available) {
	$release = $folder.Name.Split('.')[0]
	$framework = $manifest.releases.$release

	foreach ($package in $manifest.packages) {
		$assembly = Join-Path $folder.FullName "$($package.assembly).dll"

		if (-not (Test-Path -LiteralPath $assembly)) {
			throw "$($folder.Name) does not hold $($package.assembly).dll."
		}

		$nuspec = New-Nuspec $package $folder.Name $framework $folder.FullName

		& dotnet pack $project --no-restore --no-build --output $outputFolder --verbosity quiet "-p:NuspecFile=$nuspec"
		if ($LASTEXITCODE -ne 0) {
			throw "The pack of $($package.name) $($folder.Name) failed."
		}

		[pscustomobject]@{
			Id        = "$($manifest.idPrefix).$($package.name)"
			Version   = $folder.Name
			Framework = $framework
		}
	}
}
