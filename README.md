# autodesk-inventor-api

Unofficial multi-version NuGet packages for the Autodesk Inventor and iLogic API reference assemblies.

> **This repository holds no Autodesk files, and no package is published.** You supply the files from your own
> Inventor installation or installer media, and you build the packages on your machine. Autodesk's license limits
> the distribution of its files. Get Autodesk's written permission before you publish a package. Read
> [NOTICE.md](NOTICE.md).

## Packages

One package for each assembly. Each ID starts with `TylerWarner33.Inventor.Api.`.

| Package | Assembly | Depends on | Built |
| --- | --- | --- | --- |
| `Interop` | `Autodesk.Inventor.Interop` | - | Always |
| `iLogic.Types` | `Autodesk.iLogic.Types` | `Interop` | Always |
| `iLogic.Interfaces` | `Autodesk.iLogic.Interfaces` | `Interop`, `iLogic.Types` | Always |
| `iLogic.Runtime` | `Autodesk.iLogic.Runtime` | `Interop`, `iLogic.Interfaces`, `iLogic.Types` | Always |
| `iLogic.Automation` | `Autodesk.iLogic.Automation` (no XML documentation) | `Interop`, `iLogic.Interfaces` | `-IncludeOptional` |
| `iLogic.UiBuilderCore` | `Autodesk.iLogic.UiBuilderCore` | - | `-IncludeOptional` |

- The files are under `ref/<framework>/`. A consumer compiles against them, and nothing is copied to its output
	folder, because Inventor supplies these assemblies at run time.
- Dependencies between the packages use the exact version, so releases cannot mix.

## Versions

The version is `<product year>.<update>.<patch>`, and each package of a release has the same version. It comes from
the file version of `Autodesk.iLogic.Interfaces.dll` (ex. `29.40.40700` is `2025.4.0`).

| Inventor | Framework folder | Version of the files used for the first build |
| --- | --- | --- |
| 2020 | `ref/net47/` | `2020.0.0` (installer media) |
| 2021 | `ref/net48/` | `2021.0.0` (installer media) |
| 2022 | `ref/net48/` | `2022.0.0` (installer media) |
| 2023 | `ref/net48/` | `2023.0.0` (installer media) |
| 2024 | `ref/net48/` | `2024.0.0` (installer media) |
| 2025 | `ref/net8.0/` | `2025.4.0` (installation) |
| 2026 | `ref/net8.0/` | `2026.4.0` (installation) |
| 2027 | `ref/net10.0/` | `2027.2.0` (installation) |

The framework is the one that Inventor hosts. The iLogic assemblies of 2021 and 2022 target .NET Framework 4.7,
but their installer media supplies .NET Framework 4.8.

## Requirements

- Windows.
- [PowerShell 7](https://learn.microsoft.com/powershell/scripting/install/installing-powershell-on-windows).
- The .NET 10 SDK.
- An Inventor installation, or the installer media as a `.zip` file, for each release that you want.

## Build the packages

1. Import the files into `Libs/<version>/`. The script accepts installation folders and `.zip` files. It installs
	nothing, and it accepts only files with a valid Autodesk signature.

	```powershell
	./Tools/Import-InventorApi.ps1 -Source "$env:ProgramFiles\Autodesk\Inventor 2027"
	```

	```powershell
	./Tools/Import-InventorApi.ps1 -Source "$env:USERPROFILE\Downloads\Inventor_2021.zip"
	```

2. Build the packages into `artifacts/packages/`.

	```powershell
	./Tools/Build-Packages.ps1
	```

A `.msp` update patch is not a source. To get the files of an update, install it, and then import from the
installation folder.

## Use a package

Add the output folder as a package source of the consumer, in its `nuget.config`:

```xml
<configuration>
	<packageSources>
		<add key="inventor-api" value="<path to this repository>\artifacts\packages" />
	</packageSources>
</configuration>
```

Then reference the packages that you need. `iLogic.Runtime` brings its dependencies.

```xml
<ItemGroup>
	<PackageReference Include="TylerWarner33.Inventor.Api.Interop" Version="2027.*" />
</ItemGroup>
```

A project that builds for more than one release can use a property, ex. `Version="$(InventorVersion).*"`. With
central package management, a floating version also needs `CentralPackageFloatingVersionsEnabled`.

**If you build the same version again,** NuGet continues to use the copy in its cache. Delete the folders
`%USERPROFILE%\.nuget\packages\tylerwarner33.inventor.api.*` before the next restore.

## Add a release or an update

1. For a new release, add the year and its framework to `releases` in [Packages.json](Packages.json).
2. Import the files, and build the packages.

An update of a release gets its own `Libs/<version>/` folder. If the script reads a wrong version, give the correct
one with `-Version`.

## Repository layout

| Path | Contents |
| --- | --- |
| `Packages.json` | The packages, their dependencies, and the framework of each release |
| `Tools/` | The import and build scripts |
| `Source/` | The pack project and the readme inside each package |
| `Libs/` | The imported Autodesk files. Not in Git. |
| `artifacts/` | The built packages. Not in Git. |

## License

[MIT](LICENSE) for the source code, scripts, and documentation of this repository only. It does not apply to
Autodesk files. Read [NOTICE.md](NOTICE.md).
