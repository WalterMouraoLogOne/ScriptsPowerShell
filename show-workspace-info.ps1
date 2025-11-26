<#
.SYNOPSIS
Show all downloadable .pbix files from a Power BI workspace.

.NOTES
- Requires MicrosoftPowerBIMgmt PowerShell modules.
- Authenticates interactively by default (Connect-PowerBIServiceAccount).
- Usage examples:
    .\show-workspace-info.ps1 -WorkspaceName "Sales Workspace" 
    .\show-workspace-info.ps1 -WorkspaceId "00000000-0000-0000-0000-000000000000"
#>

param(
    [string]$WorkspaceName,
    [string]$WorkspaceId,
    [string]$CSVFile
)

Function Write-CSV-Line {
    param($Value)

    if($CSVFile){
        "$Value" | Out-File -FilePath $CSVFile -Append
    }
}

function Ensure-Module {
    param($Name)
    if (-not (Get-Module -ListAvailable -Name $Name)) {
        Write-Host "Installing module $Name..."
        Install-Module -Name $Name -Scope CurrentUser -Force -ErrorAction Stop
    }
    Import-Module $Name -ErrorAction Stop
}

function Show-reports {
    param($WorkspaceId, $WorkspaceName)
    $reports = Get-PowerBIReport -WorkspaceId $WorkspaceId -ErrorAction Stop
    if (-not $reports) {
        Write-Host "No reports found in workspace."
        return
    }
    Write-Host "Reports in workspace:"
    $reports | ForEach-Object {
        Write-CSV-Line -Value "`"$WorkspaceName`",`"$WorkspaceId`",`"$($_.Name)`",`"$($_.Id)`""
        Write-Host ("- {0} (ID: {1})" -f $($_.Name), $($_.Id))
    }
}

if($CSVFile){
    Remove-Item -Path $CSVFile -ErrorAction SilentlyContinue
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
    Write-CSV-Line -Value "`"WorkspaceName`",`"WorkspaceId`",`"ReportName`",`"ReportId`""
    $wsList | ForEach-Object { 
        Write-Host ("[{0}] {1}\n" -f $_.Id, $_.Name) 
        Show-reports -WorkspaceId $_.Id -WorkspaceName $_.Name
    }
} else {
    if ($WorkspaceId) {
        $workspace = Get-PowerBIWorkspace -Id $WorkspaceId -ErrorAction SilentlyContinue
    } else {
        $workspace = Get-PowerBIWorkspace -Name $WorkspaceName -ErrorAction SilentlyContinue | Select-Object -First 1
    }

    if (-not $workspace) { throw "Workspace not found." }

    Write-CSV-Line -Value "`"WorkspaceName`",`"WorkspaceId`",`"ReportName`",`"ReportId`""
    Show-reports -WorkspaceId $workspace.Id -WorkspaceName $workspace.Name
}

Write-Host "Finished."