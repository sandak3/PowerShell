Import-Module "C:\Powershell\Modules\SqlServer\21.1.18256\SqlServer.psd1"



$upit = "select IE.environment_id, IE.environment_name, IV.value, f.name
  FROM [SSISDB].[internal].[environments] IE
  join internal.environment_variables IV on IE.environment_id = IV.environment_id
  join catalog.environments IEE on  IEE.environment_id = IE.environment_id
  join catalog.folders F on f.folder_id = ie.folder_id
  where f.name = '$env:SolutionName' and environment_name = '$env:environment'"

$invoke = Invoke-SqlCmd -ServerInstance $(SSIS.SQLServer) -Database "SSISDB" -Query $Upit -Username "AzureDevOpsSql" -Password $env:password

$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$invoke | out-file "\\$(SSIS.SQLServer)\C$\temp\SSIS backup\$env:SolutionName`_$timestamp`_$env:environment.txt"

$json_name = "$(System.DefaultWorkingDirectory)/$(SolutionName)/drop/Configuration$(Release.EnvironmentName).json"
#$sqlServerName = "localhost"
$sqlServerName = "$(SSIS.SQLServer)"

#find folder name
$folder_name = Get-Content -raw -path $json_name | ConvertFrom-Json | select -expand folders | select -ExpandProperty Name

#find env names
$env_names = Get-Content -raw -path $json_name | ConvertFrom-Json | select -expand folders | select -expand environments | select -ExpandProperty Name
Write-host "Environments to be deleted in the folder ${folder_name}:"
$env_names

foreach ($f in $env_names){

    write-host "Deleting environment $f in folder $folder_name"
    $query1 = "EXEC SSISDB.catalog.delete_environment @environment_name=$f, @folder_name=$folder_name"
    sqlcmd -S $sqlServerName -Q $query1 
    write-host "====================="
}