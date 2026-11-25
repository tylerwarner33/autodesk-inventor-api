#Requires -Version 7.0

<#
.SYNOPSIS
	Builds the NuGet packages from the files in Source/Content/.

.DESCRIPTION
	Packs the project in Source/ one time for each assembly of each Source/Content/<version>/ folder, as
	Packages.json describes. Each package holds the files under ref/<framework>/, so a consumer compiles against
	them and copies nothing. Dependencies between the packages use the exact version.

	A package can be packed only after the packages that it depends on, so the order in Packages.json matters.

	This script publishes nothing. The packages go to artifacts/packages/.

.PARAMETER Version
	The versions in Source/Content/ to build. The default is all of them.

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
$contentFolder = Join-Path $repositoryRoot 'Source' 'Content'
$outputFolder = Join-Path $repositoryRoot 'artifacts' 'packages'
$restoreFolder = Join-Path $repositoryRoot 'artifacts' 'restore'
$project = Join-Path $repositoryRoot 'Source' 'TylerWarner.Inventor.Api.csproj'

$available = @()
if (Test-Path -LiteralPath $contentFolder) {
	$available = @(Get-ChildItem -LiteralPath $contentFolder -Directory |
			Where-Object Name -Match '^\d{4}\.\d+\.\d+$' | Sort-Object Name)
}

if ($available.Count -eq 0) {
	throw 'Source/Content/ holds no version folder. Run Tools/Import-InventorApi.ps1 first.'
}

if ($Version) {
	$unknown = @($Version | Where-Object { $_ -notin $available.Name })
	if ($unknown.Count -gt 0) {
		throw "Source/Content/ does not hold: $($unknown -join ', ')."
	}

	$available = @($available | Where-Object Name -In $Version)
}

# The restore of a dependency uses its own package folder, which starts empty. A package that was built before with
# the same version therefore never comes from the NuGet cache of the user.
if (Test-Path -LiteralPath $restoreFolder) {
	Remove-Item -LiteralPath $restoreFolder -Recurse -Force
}

$null = New-Item -ItemType Directory -Path $outputFolder -Force

foreach ($folder in $available) {
	$release = $folder.Name.Split('.')[0]

	if ($release -notin $manifest.releases.PSObject.Properties.Name) {
		throw "Inventor $release is not in the releases of Packages.json."
	}

	$framework = $manifest.releases.$release

	foreach ($package in $manifest.packages) {
		$id = "$($manifest.idPrefix).$($package.name)"

		$properties = @(
			"-p:Version=$($folder.Name)"
			"-p:InventorFramework=$framework"
			"-p:LibraryName=$($package.assembly)"
			"-p:PackageId=$id"
			"-p:PackageIdPrefix=$($manifest.idPrefix)"
			"-p:PackageDependencies=$($package.dependencies -join '+')"
			"-p:AssemblyDescription=$($package.description) For Inventor $release."
			"-p:RestorePackagesPath=$restoreFolder"
			"-p:RestoreAdditionalProjectSources=$outputFolder"
		)

		& dotnet restore $project --verbosity quiet @properties
		if ($LASTEXITCODE -ne 0) {
			throw "The restore of $id $($folder.Name) failed."
		}

		& dotnet pack $project --no-build --output $outputFolder --verbosity quiet @properties
		if ($LASTEXITCODE -ne 0) {
			throw "The pack of $id $($folder.Name) failed."
		}

		[pscustomobject]@{
			Id        = $id
			Version   = $folder.Name
			Framework = $framework
		}
	}
}
