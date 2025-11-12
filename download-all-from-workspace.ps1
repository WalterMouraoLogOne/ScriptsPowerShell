<#
.SYNOPSIS
Download all downloadable .pbix files from a Power BI workspace.

.NOTES
- Requires MicrosoftPowerBIMgmt PowerShell modules.
- Authenticates interactively by default (Connect-PowerBIServiceAccount).
- Usage examples:
    .\download-all-from-workspace.ps1 -WorkspaceName "Sales Workspace" -OutDir "C:\PBIX" -OutDir "C:\PBIX"
    .\download-all-from-workspace.ps1 -WorkspaceId "00000000-0000-0000-0000-000000000000"
#>

param(
    [string]$WorkspaceName,
    [string]$WorkspaceId,
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

# Ensure modules
Ensure-Module -Name MicrosoftPowerBIMgmt

# Connect (interactive). For service principal flows, replace with appropriate Connect-PowerBIServiceAccount params.
Write-Host "Connecting to Power BI..."
Connect-PowerBIServiceAccount -ErrorAction Stop

# Resolve workspace
if (-not $WorkspaceName -and -not $WorkspaceId) {
    Write-Host "No workspace specified. Listing available workspaces..."
    $wsList = Get-PowerBIWorkspace -All
    if (-not $wsList) { throw "No workspaces available for the account." }
    $wsList | ForEach-Object { Write-Host ("[{0}] {1}" -f $_.Id, $_.Name) }
    $input = Read-Host "Enter WorkspaceId from the list above"
    $WorkspaceId = $input.Trim()
}

if ($WorkspaceId) {
    $workspace = Get-PowerBIWorkspace -Id $WorkspaceId -ErrorAction SilentlyContinue
} else {
    $workspace = Get-PowerBIWorkspace -Name $WorkspaceName -ErrorAction SilentlyContinue | Select-Object -First 1
}

if (-not $workspace) { throw "Workspace not found." }

Write-Host "Using workspace: $($workspace.Name) [$($workspace.Id)]"

if (-not $OutDir) { throw "Faltou o parâmetro OutDir." }

# Prepare output folder
$OutDir = Resolve-Path -Path $OutDir -ErrorAction SilentlyContinue 2>$null
if (-not $OutDir) { New-Item -Path $PSBoundParameters['OutDir'] -ItemType Directory -Force | Out-Null; $OutDir = Resolve-Path -Path $PSBoundParameters['OutDir'] }

# Get reports
$reports = Get-PowerBIReport -WorkspaceId $workspace.Id -ErrorAction Stop

if (-not $reports) {
    Write-Host "No reports found in workspace."
    exit 0
}

foreach ($r in $reports) {
    $safeName = Sanitize-FileName "$($r.Name)"
    $outFile = Join-Path $OutDir ("$safeName - $($r.Id).pbix")
    Write-Host "Exporting report: $($r.Name) -> $outFile"
    try {
        # Export-PowerBIReport is part of the Power BI management module set.
        Export-PowerBIReport -Id $r.Id -WorkspaceId $workspace.Id -OutFile $outFile -ErrorAction Stop
        Write-Host "Saved: $outFile"
    } catch {
        Write-Warning "Failed to export '$($r.Name)'. It may not be downloadable or you lack permissions. Error: $($_.Exception.Message)"
    }
}

Write-Host "Finished."