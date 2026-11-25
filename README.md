# autodesk-inventor-api

Unofficial multi-version NuGet packages for the Autodesk Inventor and iLogic API reference assemblies.

> **Unofficial.** This project is not affiliated with Autodesk. The assemblies and their XML documentation are
> Autodesk files, the MIT license does not apply to them, and this project grants no rights to them. Read
> [NOTICE.md](https://github.com/tylerwarner33/autodesk-inventor-api/blob/main/NOTICE.md).

## Packages

One package for each assembly. Each ID starts with `TylerWarner.Inventor.Api.`.

| Package | Assembly | Depends on |
| --- | --- | --- |
| `Interop` | `Autodesk.Inventor.Interop` | - |
| `iLogic.Types` | `Autodesk.iLogic.Types` | `Interop` |
| `iLogic.Interfaces` | `Autodesk.iLogic.Interfaces` | `Interop`, `iLogic.Types` |
| `iLogic.Runtime` | `Autodesk.iLogic.Runtime` | `Interop`, `iLogic.Interfaces`, `iLogic.Types` |
| `iLogic.Automation` | `Autodesk.iLogic.Automation` (no XML documentation) | `Interop`, `iLogic.Interfaces` |
| `iLogic.UiBuilderCore` | `Autodesk.iLogic.UiBuilderCore` | - |

- **Compile time only.** The files are under `ref/<framework>/`. A consumer compiles against them, and nothing is
	copied to its output folder, because Inventor supplies these assemblies at run time.
- Dependencies between the packages use the exact version, so releases cannot mix.

## Use a package

Reference the packages that you need. Each package brings its dependencies.

```xml
<ItemGroup>
	<PackageReference Include="TylerWarner.Inventor.Api.Interop" Version="2027.*" />
</ItemGroup>
```

A project that builds for more than one release can use a property, ex. `Version="$(InventorVersion).*"`. With
central package management, a floating version also needs `CentralPackageFloatingVersionsEnabled`.

## Versions

The version is `<product year>.<update>.<patch>`, and each package of a release has the same version. It comes from
the file version of `Autodesk.iLogic.Interfaces.dll` (ex. `29.40.40700` is `2025.4.0`).

| Inventor | Version | Folder in the package | Source of the files |
| --- | --- | --- | --- |
| 2020 | `2020.0.0` | `ref/net47/` | Installer media |
| 2021 | `2021.0.0` | `ref/net48/` | Installer media |
| 2022 | `2022.0.0` | `ref/net48/` | Installer media |
| 2023 | `2023.0.0` | `ref/net48/` | Installer media |
| 2024 | `2024.0.0` | `ref/net48/` | Installer media |
| 2025 | `2025.4.0` | `ref/net8.0/` | Installation |
| 2026 | `2026.4.0` | `ref/net8.0/` | Installation |
| 2027 | `2027.2.0` | `ref/net10.0/` | Installation |

The framework is the one that Inventor hosts. The iLogic assemblies of 2021 and 2022 target .NET Framework 4.7,
but their installer media supplies .NET Framework 4.8.

## Work on this repository

The rest of this page is for people who build or publish the packages.

### Requirements

- Windows.
- [PowerShell 7](https://learn.microsoft.com/powershell/scripting/install/installing-powershell-on-windows).
- The .NET 10 SDK.

### Build the packages

Build the packages from the files in `Source/Content/<version>/` into `artifacts/packages/`:

```powershell
./Tools/Build-Packages.ps1
```

The [pack project](https://github.com/tylerwarner33/autodesk-inventor-api/blob/main/Source/TylerWarner.Inventor.Api.csproj)
maps the source folder to the package folder with one item:

```xml
<Content Include="Content\$(Version)\$(LibraryName).*" PackagePath="ref\$(TargetFramework)\" />
```

To test a package that you built, add the output folder as a package source of the consumer, in its `nuget.config`:

```xml
<configuration>
	<packageSources>
		<add key="inventor-api" value="<path to this repository>\artifacts\packages" />
	</packageSources>
</configuration>
```

**If you build the same version again,** NuGet continues to use the copy in its cache. Delete the folders
`%USERPROFILE%\.nuget\packages\tylerwarner.inventor.api.*` before the next restore.

### Add a release or an update

1. For a new release, add the year and its framework to `releases` in
	[Packages.json](https://github.com/tylerwarner33/autodesk-inventor-api/blob/main/Packages.json).
2. Import the files into `Source/Content/<version>/`. The script accepts Inventor installation folders and installer
	media `.zip` files. It installs nothing, and it accepts only files with a valid Autodesk signature.

	```powershell
	./Tools/Import-InventorApi.ps1 -Source "$env:ProgramFiles\Autodesk\Inventor 2027"
	```

	```powershell
	./Tools/Import-InventorApi.ps1 -Source "$env:USERPROFILE\Downloads\Inventor_2021.zip"
	```

3. Build the packages.

An update of a release gets its own version folder. If the script reads a wrong version, give the correct one with
`-Version`. A `.msp` update patch is not a source. To get the files of an update, install it, and then import from
the installation folder.

### Publish

The [Release](https://github.com/tylerwarner33/autodesk-inventor-api/blob/main/.github/workflows/Release.yml)
workflow publishes to NuGet.org. It starts only by hand: select **Actions**, **Release**, and **Run workflow**, then
give one version in `Source/Content/` (ex. `2027.2.0`), or `all`. It builds the packages, publishes them, and creates
a GitHub release for each version.

- **A published version cannot be replaced.** NuGet.org lets you unlist it, not delete it. The workflow skips a
	version that is already there.
- It signs in with [Trusted Publishing](https://learn.microsoft.com/nuget/nuget-org/trusted-publishing), so the
	repository stores no API key. NuGet.org needs a policy for this repository and the file `Release.yml`, and the
	repository needs the `NUGET_USER` secret.

### Repository layout

| Path | Contents |
| --- | --- |
| `Packages.json` | The packages, their dependencies, and the framework of each release. Their order is the build order. |
| `Tools/` | The import and build scripts |
| `Source/` | The pack project |
| `Source/Content/` | The Autodesk files, one folder for each version |
| `.nuget/` | The icon of the packages |
| `.github/workflows/` | The manual publish workflow |
| `artifacts/` | The built packages. Not in Git. |

## License

[MIT](https://github.com/tylerwarner33/autodesk-inventor-api/blob/main/LICENSE) for the source code, scripts, and
documentation of this repository only. It does not apply to Autodesk files. Read
[NOTICE.md](https://github.com/tylerwarner33/autodesk-inventor-api/blob/main/NOTICE.md).
