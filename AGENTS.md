# Autodesk Inventor API packages

Builds unofficial NuGet reference packages from the Autodesk Inventor and iLogic assemblies in `ref/`.
See `README.md` for the packages, the version rule, and the commands.

## Rules

- **`ref/` holds Autodesk files**, which the owner keeps in this public repository. Add them only with
	`Tools/Import-InventorApi.ps1`, which checks the Autodesk signature. Do not edit them, and do not change their
	line endings. Add no other Autodesk files.
- **Do not publish a package** to nuget.org or another shared feed unless the owner tells you to. This includes a
	start of the `Release` workflow. A published version cannot be replaced.
- **Keep the name `.github/workflows/Release.yml`.** The Trusted Publishing policy on NuGet.org names the file. Do
	not add a push or tag trigger.
- **Do not mark a package or an Autodesk file as MIT.** The packages use `NOTICE.md` as their license file.
- **Keep `ref/<framework>/` in each package.** Do not add a `lib/` folder. Consumers must not copy the assemblies.
- **Keep `artifacts/` out of Git.** It holds build output.
- **One version for each release.** All packages of a release have the same version, and depend on each other with
	that exact version.
- **No private data.** Do not write user names, machine names, or absolute user paths. Write a variable
	(ex. `%USERPROFILE%`).

## Check a change

There are no automated tests. After a change to `Packages.json` or a script, run `Tools/Build-Packages.ps1`. Then
build a small project for each framework against `artifacts/packages/`, with an isolated package folder
(`dotnet build --packages <temporary folder>`), so the global cache keeps no test copy.
