Scripts Powershell para manipulação de .pibx

Em todos os casos é solicitado o login interativamente.

Download de todos os .pibx daquele workspace, no diretório indicado. Se não passar o workspace, faz o download de todos os .pibx da conta.
----------------------------------
.\download-all-from-account.ps1 -WorkspaceName -OutDir "C:\PBIX"

Download de .pibx específico, para o diretório indicado.
----------------------------------
.\download-all-from-workspace.ps1 -WorkspaceName "Sales Workspace" -OutDir "C:\PBIX"

.\download-all-from-workspace.ps1 -WorkspaceId "00000000-0000-0000-0000-000000000000" -OutDir "C:\PBIX"

Lista todos os .pibx de um workspace. Se for passado o parâmetro -CSVFile, salva a listagem como .csv
----------------------------------
.\show-workspace-info.ps1 -WorkspaceName "Sales Workspace" 

.\show-workspace-info.ps1 -WorkspaceId "00000000-0000-0000-0000-000000000000"

.\show-workspace-info.ps1 -WorkspaceName "Sales Workspace" -CSVFile "C:\TEMP\X.CSV"


