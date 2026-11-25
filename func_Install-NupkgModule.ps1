function Install-NupkgModule {
    <#
    .SYNOPSIS
        Installs PowerShell modules from .nupkg files for all users, locally or on remote computers.
    .PARAMETER SourcePath
        Folder that contains the .nupkg files (subfolders are searched too).
    .PARAMETER ComputerName
        Target computer(s). Defaults to the local computer. Remote targets are reached
        through the admin share (\\computer\C$), so you need admin rights there.
    .PARAMETER Force
        Overwrite a module version that is already installed.
    .EXAMPLE
        Install-NupkgModule -SourcePath "$HOME\Downloads\powershellModule"
    .EXAMPLE
        Install-NupkgModule -SourcePath "$HOME\Downloads\powershellModule" -ComputerName SERVER01, SERVER02
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [ValidateScript({ Test-Path -LiteralPath $_ -PathType Container })]
        [string]$SourcePath,

        [Parameter(ValueFromPipeline)]
        [string[]]$ComputerName = $env:COMPUTERNAME,

        [switch]$Force
    )

    begin {
        Add-Type -AssemblyName System.IO.Compression.FileSystem

        $packages = Get-ChildItem -LiteralPath $SourcePath -Filter *.nupkg -File -Recurse
        if (-not $packages) { throw "No .nupkg files found in '$SourcePath'." }

        # Extract every package once, locally, into a staging folder
        $staging = Join-Path $env:TEMP ("nupkg-" + [guid]::NewGuid())
        New-Item -ItemType Directory -Path $staging -WhatIf:$false | Out-Null

        $modules = foreach ($pkg in $packages) {
            $tmp = Join-Path $staging $pkg.BaseName
            [IO.Compression.ZipFile]::ExtractToDirectory($pkg.FullName, $tmp)

            $specFile = Get-ChildItem -LiteralPath $tmp -Filter *.nuspec | Select-Object -First 1
            if (-not $specFile) { Write-Warning "$($pkg.Name): no .nuspec found, skipping."; continue }

            [xml]$spec = Get-Content -LiteralPath $specFile.FullName
            $name = $spec.package.metadata.id
            $ver  = $spec.package.metadata.version -replace '-.*$', ''   # strip prerelease suffix

            # Remove NuGet packaging metadata
            foreach ($junk in '_rels', 'package', '[Content_Types].xml', $specFile.Name) {
                $p = Join-Path $tmp $junk
                if (Test-Path -LiteralPath $p) { Remove-Item -LiteralPath $p -Recurse -Force -WhatIf:$false }
            }

            # Clear "downloaded from the internet" marks before copying anywhere
            Get-ChildItem -LiteralPath $tmp -Recurse -File | Unblock-File -WhatIf:$false

            [pscustomobject]@{ Name = $name; Version = $ver; Path = $tmp }
        }
    }

    process {
        foreach ($computer in $ComputerName) {
            $isLocal = $computer -in @($env:COMPUTERNAME, 'localhost', '.', '127.0.0.1') -or
                       $computer -like "$env:COMPUTERNAME.*"

            if ($isLocal) {
                $principal = [Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
                if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
                    Write-Error "Installing for all users on $computer requires an elevated (Run as Administrator) PowerShell."
                    continue
                }
                $root = Join-Path $env:ProgramFiles 'WindowsPowerShell\Modules'
            }
            else {
                if (-not (Test-Path -LiteralPath "\\$computer\C$")) {
                    Write-Error "Cannot reach \\$computer\C$ (offline, firewall, or no admin rights)."
                    continue
                }
                $root = "\\$computer\C$\Program Files\WindowsPowerShell\Modules"
            }

            foreach ($m in $modules) {
                $target = Join-Path $root "$($m.Name)\$($m.Version)"

                if ((Test-Path -LiteralPath $target) -and -not $Force) {
                    Write-Host "[$computer] $($m.Name) $($m.Version) already installed, skipping (use -Force to overwrite)." -ForegroundColor Yellow
                    continue
                }

                if ($PSCmdlet.ShouldProcess($computer, "Install $($m.Name) $($m.Version)")) {
                    if (Test-Path -LiteralPath $target) { Remove-Item -LiteralPath $target -Recurse -Force }
                    New-Item -ItemType Directory -Path $target -Force | Out-Null
                    Get-ChildItem -LiteralPath $m.Path | Copy-Item -Destination $target -Recurse -Force

                    [pscustomobject]@{
                        ComputerName = $computer
                        Module       = $m.Name
                        Version      = $m.Version
                        Path         = $target
                    }
                }
            }
        }
    }

    end {
        if ($staging) { Remove-Item -LiteralPath $staging -Recurse -Force -ErrorAction SilentlyContinue -WhatIf:$false }
    }
}
