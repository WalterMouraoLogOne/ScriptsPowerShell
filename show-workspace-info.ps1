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

function Install-RequiredModule {
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
        Write-Host "Nenhum relatório no workspace."
        return
    }
    Write-Host "Relatórios no workspace:"
    $reports | ForEach-Object {
        Write-CSV-Line -Value "`"$WorkspaceName`",`"$WorkspaceId`",`"$($_.Name)`",`"$($_.Id)`""
        Write-Host ("- {0} (ID: {1})" -f $($_.Name), $($_.Id))
    }
}

function Get-DatasetSizeViaAPI {
    param($WorkspaceId, $DatasetId)
    
    try {
        $url = "groups/$WorkspaceId/datasets/$DatasetId"
        $response = Invoke-PowerBIRestMethod -Url $url -Method Get | ConvertFrom-Json
        
        if ($response -and $response.contentSize) {
            $sizeMB = $response.contentSize / 1MB
            $sizeGB = $response.contentSize / 1GB
            
            if ($sizeGB -ge 1) {
                return "{0:F2} GB" -f $sizeGB
            } else {
                return "{0:F2} MB" -f $sizeMB
            }
        }
    } catch {
        # Size info unavailable
    }
    return "N/A"
}

function Show-datasets {
    param($WorkspaceId, $WorkspaceName)
    Write-Host "Datasets no workspace:"
    $datasets = Get-PowerBIDataset -WorkspaceId $WorkspaceId
    
    $days = @()
    $times = @()

    foreach ($dataset in $datasets) {

        Write-Host "Processando dataset: $dataset"
        $datasetSize = Get-DatasetSizeViaAPI -WorkspaceId $WorkspaceId -DatasetId $dataset.Id

        # Apenas tenta buscar agendamento se o dataset for atualizável
        if ($dataset.IsRefreshable -eq $true) {
            
            try {
                $url = "groups/$($WorkspaceId)/datasets/$($dataset.Id)/refreshSchedule"
                $response = Invoke-PowerBIRestMethod -Url $url -Method Get | ConvertFrom-Json
                
                # Se houver agendamento configurado
                if ($response -and $response.days) {
                    $days = $response.days
                    $times = $response.times
                    $enabled = if($response.enabled -eq 'True'){"Sim"} else {"Não"}
                } else {
                    $days = "N/A"
                    $times = "N/A"
                    $enabled = "Não"
                }
            } catch {
                # Trata erros de permissão ou datasets sem API de schedule disponível
                $days = "Erro/Sem Acesso"
                $times = "Erro/Sem Acesso"
                $enabled = "Unknown"
            }
        }
        $joinedDays = $days -join ", "
        $joinedTimes = $times -join ", "
        Write-Host ("- {0} (ID: {1} - Tamanho: {2} - Dias: {3} - Horas: {4} - Ativo: {5})" -f $dataset.Name, $dataset.Id, $datasetSize, $joinedDays, $joinedTimes, $enabled)

        $days | ForEach-Object {
            $day = "$_";
            $times | ForEach-Object {
                Write-CSV-Line -Value "`"$WorkspaceName`",`"$WorkspaceId`",`"$($dataset.Name)`",`"$($dataset.Id)`", $datasetSize, `"$day`", `"$_`", `"$enabled`""
            }
        }    
    }
}
# Ensure modules
Install-RequiredModule -Name MicrosoftPowerBIMgmt

# Connect (interactive). For service principal flows, replace with appropriate Connect-PowerBIServiceAccount params.
Write-Host "Conectando ao Power BI..."
Connect-PowerBIServiceAccount -ErrorAction Stop

if($CSVFile){
    Remove-Item -Path $CSVFile -ErrorAction SilentlyContinue
}

# Resolve workspace
if (-not $WorkspaceName -and -not $WorkspaceId) {
    Write-Host "Não foi especificado Workspace, listando todos:"
    $wsList = Get-PowerBIWorkspace -All
    if (-not $wsList) { throw "Não há Workspaces nessa conta." }
    Write-CSV-Line -Value "`"WorkspaceName`",`"WorkspaceId`",`"ReportName`",`"ReportId`""
    $wsList | ForEach-Object { 
        Write-Host ("`nWorkspace: {1} [{0}]" -f $_.Id, $_.Name) 
        Show-reports -WorkspaceId $_.Id -WorkspaceName $_.Name
    }
    Write-CSV-Line -Value ""
    Write-CSV-Line -Value "`"WorkspaceName`",`"WorkspaceId`",`"DatasetName`",`"DatasetId`",`"Size`",`"Day`",`"Hour`",'`"Enabled`""
    $wsList | ForEach-Object { 
        Write-Host ("`nWorkspace: {1} [{0}]" -f $_.Id, $_.Name) 
        Show-datasets -WorkspaceId $_.Id -WorkspaceName $_.Name
    }
} else {
    if ($WorkspaceId) {
        $workspace = Get-PowerBIWorkspace -Id $WorkspaceId -ErrorAction SilentlyContinue
    } else {
        $workspace = Get-PowerBIWorkspace -Name $WorkspaceName -ErrorAction SilentlyContinue | Select-Object -First 1
    }

    if (-not $workspace) { throw "Workspace não encontrado." }

    Write-CSV-Line -Value "`"WorkspaceName`",`"WorkspaceId`",`"ReportName`",`"ReportId`""
    Show-reports -WorkspaceId $workspace.Id -WorkspaceName $workspace.Name
    Write-CSV-Line -Value ""
    Write-CSV-Line -Value "`"WorkspaceName`",`"WorkspaceId`",`"DatasetName`",`"DatasetId`",`"Size`",`"Day`",`"Hour`,'`"Enabled`""
    Show-datasets -WorkspaceId $workspace.Id -WorkspaceName $workspace.Name
}

Write-Host "Finished."