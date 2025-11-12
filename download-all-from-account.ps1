<#
.SYNOPSIS
Download all downloadable .pbix files from a Power BI account.

.NOTES
- Requires MicrosoftPowerBIMgmt PowerShell modules.
- Authenticates interactively by default (Connect-PowerBIServiceAccount).
- Usage examples:
    .\download-all-from-account.ps1 -WorkspaceName -OutDir "C:\PBIX"
#>

param(
    [string]$OutDir
)

function Ensure-Module {
    param($Name)
    if (-not (Get-Module -ListAvailable -Name $Name)) {
        Write-Host "Installing module $Name..."
        Install-Module -Name $Name -Scope CurrentUser -Force -ErrorAction Stop
    }
    Import-Module $Name -ErrorAction Stop
}

function Sanitize-FileName {
    param([string]$Name)
    $invalid = [System.IO.Path]::GetInvalidFileNameChars()
    foreach ($c in $invalid) { $Name = $Name -replace [regex]::Escape($c), '_' }
    $Name.Trim()
}

if (-not $OutDir) { throw "Faltou o parâmetro OutDir." }

# Prepare output folder
$OutDir = Resolve-Path -Path $OutDir -ErrorAction SilentlyContinue 2>$null
if (-not $OutDir) { New-Item -Path $PSBoundParameters['OutDir'] -ItemType Directory -Force | Out-Null; $OutDir = Resolve-Path -Path $PSBoundParameters['OutDir'] }

# Ensure modules
Ensure-Module -Name MicrosoftPowerBIMgmt

# Connect (interactive). For service principal flows, replace with appropriate Connect-PowerBIServiceAccount params.
Write-Host "Connecting to Power BI..."
Connect-PowerBIServiceAccount -ErrorAction Stop

$wsList = Get-PowerBIWorkspace -All
if (-not $wsList) { throw "No workspaces available for the account." }

$wsList | ForEach-Object { 
    Write-Host ("[{0}] {1}" -f $_.Id, $_.Name) 

    # Get reports
    $reports = Get-PowerBIReport -WorkspaceId $_.id -ErrorAction Stop

    if (-not $reports) {
        Write-Host "No reports found in workspace."
    } else { 
        $safeDirName = Sanitize-FileName "$($_.Name)"
        $safeDirName = Join-Path $OutDir $safeDirName
        $dirName = Resolve-Path -Path $safeDirName -ErrorAction SilentlyContinue 2>$null
        if (-not $dirName) { New-Item -Path $safeDirName -ItemType Directory -Force | Out-Null; $safeDirName = Resolve-Path -Path $safeDirName }

        foreach ($r in $reports) {
            $safeName = Sanitize-FileName "$($r.Name)"
            $outFile = Join-Path $safeDirName ("$safeName - $($r.Id).pbix")
            Write-Host "Exporting report: $($r.Name) -> $outFile"
            try {
                # Export-PowerBIReport is part of the Power BI management module set.
                Export-PowerBIReport -Id $r.Id -WorkspaceId $_.Id -OutFile $outFile -ErrorAction Stop
                Write-Host "Saved: $outFile"
            } catch {
                Write-Warning "Failed to export '$($r.Name)'. It may not be downloadable or you lack permissions. Error: $($_.Exception.Message)"
            }
        }
    }
}


Write-Host "Finished."