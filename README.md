Scripts Powershell para manipulação de .pibx

Em todos os casos é solicitado o login interativamente.

Download de todos os .pibx daquela conta, no diretório indicado.
----------------------------------
.\download-all-from-account.ps1 "C:\PBIX"

Download de todos os .pibx daquele workspace, no diretório indicado.
----------------------------------
.\download-all-from-workspace.ps1 -WorkspaceName "Sales Workspace" -OutDir "C:\PBIX" -OutDir "C:\PBIX"
.\download-all-from-workspace.ps1 -WorkspaceId "00000000-0000-0000-0000-000000000000"

Lista todos os .pibx de um workspace. Se for passado o parâmetro -CSVFile, salva a listagem como .csv
----------------------------------
.\show-workspace-info.ps1 -WorkspaceName "Sales Workspace" 

.\show-workspace-info.ps1 -WorkspaceId "00000000-0000-0000-0000-000000000000"

.\show-workspace-info.ps1 -WorkspaceName "Sales Workspace" -CSVFile "C:\TEMP\X.CSV"


