
Import-Module "C:\Powershell\Modules\SqlServer\21.1.18256\SqlServer.psd1"



$upit = "select IE.env_id, IE.env_name, IV.value, f.name
  FROM [SSISPackage].[internal].[env] IE
  join internal.env_var IV on IE.env_id = IV.env_id
  join catalog.env IEE on  IEE.env_id = IE.env_id
  join catalog.folders F on f.folder_id = ie.folder_id
  where f.name = '$env:SolutionName' and environment_name = '$env:environment'"

$invoke = Invoke-SqlCmd -ServerInstance $(SSISPackage.SQL) -Database "SSISPackage" -Query $Upit -Username "user1" -Password $env:password

$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$invoke | out-file "\\$(SSIS.SQL)\C$\SSIS backup\$env:SolutionName`_$timestamp`_$env:environment.txt"

$json_name = "$(System.DefaultWorkingDirectory)/$(SolutionName)/drop/Configuration$(Release.EnvironmentName).json"
#$sqlServerName = "localhost"
$sqlServerName = "$(SSIS.SQL)"

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
