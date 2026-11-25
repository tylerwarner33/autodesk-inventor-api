# Autodesk Inventor API packages

Builds unofficial NuGet reference packages from Autodesk Inventor and iLogic assemblies that the user supplies.
See `README.md` for the packages, the version rule, and the commands.

## Rules

- **No Autodesk files in Git.** This includes DLL files, XML documentation, and built packages, in each branch and
	pull request. `Libs/` and `artifacts/` stay ignored. Git history keeps a file after a later commit deletes it.
- **Do not publish a package** to nuget.org or another shared feed. That needs Autodesk's written permission and the
	owner's instruction. Do not add a publish script or a publish workflow before then.
- **Do not mark a package as MIT.** The packages use `NOTICE.md` as their license file.
- **Keep `ref/<framework>/`.** Do not add a `lib/` folder. Consumers must not copy the assemblies.
- **One version for each release.** All packages of a release have the same version, and depend on each other with
	that exact version.
- **No private data.** Do not write user names, machine names, or absolute user paths. Write a variable
	(ex. `%USERPROFILE%`).

## Check a change

There are no automated tests. After a change to `Packages.json` or a script, run `Tools/Build-Packages.ps1
-IncludeOptional`. Then build a small project for each framework against `artifacts/packages/`, with an isolated
package folder (`dotnet build --packages <temporary folder>`), so the global cache keeps no test copy.
