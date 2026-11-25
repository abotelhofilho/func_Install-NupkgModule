# Install-NupkgModule

A PowerShell function that installs PowerShell modules from `.nupkg` files for **all users**, on the local computer or on remote computers. It does the manual-install steps for you — extract the package, remove the NuGet metadata, unblock the files, and copy them into the correct `Modules\<Name>\<Version>` folder — without needing the NuGet provider, `Install-Module`, or internet access.

## Features

- Installs every `.nupkg` found in a folder, including subfolders
- Reads the module name and version from each package's `.nuspec`, so file names do not matter
- Removes NuGet packaging files (`_rels`, `package`, `[Content_Types].xml`, `.nuspec`)
- Unblocks the files so Windows does not treat them as untrusted downloads
- Installs to `Program Files`, which Windows PowerShell 5.1 and PowerShell 7 both read for every user
- Installs to one or more remote computers through the `C$` admin share — no PowerShell remoting needed
- Extracts each package once, then copies it to every target
- Skips versions that are already installed unless `-Force` is used
- Supports `-WhatIf` and `-Confirm`
- Returns an object for each module installed

## Requirements

- **OS:** Windows
- **PowerShell:** 5.1 or later
- **Privileges:**
  - **Local install:** must be run as **Administrator**
  - **Remote install:** administrator rights on the remote computer, and its `C$` admin share reachable (File and Printer Sharing allowed through the firewall)

## Installation

1. Clone the repository or download the script:
   ```powershell
   git clone https://github.com/abotelhofilho/func_Install-NupkgModule.git
   ```
2. Dot-source the function into your PowerShell session:
   ```powershell
   . .\func_Install-NupkgModule.ps1
   ```

## Parameters

| Parameter      | Required | Default                | Description                                                                                         |
| -------------- | -------- | ---------------------- | --------------------------------------------------------------------------------------------------- |
| `SourcePath`   | **Yes**  | —                      | Folder that contains the `.nupkg` files. Subfolders are searched too.                               |
| `ComputerName` | No       | `$env:COMPUTERNAME`    | One or more target computers. Defaults to the local computer. Accepts pipeline input.               |
| `Force`        | No       | —                      | Overwrite a module version that is already installed.                                               |
| `WhatIf`       | No       | —                      | Show what would be installed without installing anything.                                          |
| `Confirm`      | No       | —                      | Ask for confirmation before each module is installed.                                               |

## Usage

### Basic — install on the local computer

Run PowerShell as Administrator:

```powershell
Install-NupkgModule -SourcePath "$HOME\Downloads\powershellModule"
```

### Install on remote computers

```powershell
Install-NupkgModule -SourcePath "$HOME\Downloads\powershellModule" -ComputerName SERVER01, SERVER02
```

### Computer names from a file

```powershell
Get-Content .\servers.txt | Install-NupkgModule -SourcePath "$HOME\Downloads\powershellModule"
```

### Preview without installing

```powershell
Install-NupkgModule -SourcePath "$HOME\Downloads\powershellModule" -WhatIf
```

### Reinstall versions that are already present

```powershell
Install-NupkgModule -SourcePath "$HOME\Downloads\powershellModule" -Force
```

### Check the install

```powershell
Get-Module -ListAvailable Az.Storage
```

## Output

- Modules are installed to:
  - **Local:** `C:\Program Files\WindowsPowerShell\Modules\<ModuleName>\<Version>\`
  - **Remote:** `\\<computer>\C$\Program Files\WindowsPowerShell\Modules\<ModuleName>\<Version>\`
- For each module installed, an object is returned with `ComputerName`, `Module`, `Version` and `Path`.
- Versions that are already installed are reported in yellow and skipped.
- Errors are reported per computer (not elevated, or `C$` not reachable) and the remaining computers are still processed.

## Notes

- The function does not resolve dependencies. Make sure every module a package needs is in `SourcePath` — for Az modules, always include `Az.Accounts`.
- Prerelease suffixes (for example `-preview`) are removed from the version folder name, because PowerShell expects the folder to match `ModuleVersion` in the `.psd1`.
- Remote installs assume Windows is on the `C:` drive of the target computer.
- Packages are extracted to a temporary folder under `$env:TEMP`, which is deleted when the function finishes.
- If an older copy of a module is installed for your account only (`Documents\WindowsPowerShell\Modules`), it can be loaded instead of the all-users copy. Remove it to avoid version conflicts.
- To download the Az packages, use [`Download-PSModule`](https://github.com/abotelhofilho/func_Download-PSModule-Az).
