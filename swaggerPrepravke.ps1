# Importovanje potrebnih PowerShell modula     
Import-Module "C:\Powershell\Modules\CMD\CMD.psd1"
 
$stage = $env:RELEASE_ENVIRONMENTNAME
# Definisanje liste servera za proveru
if ($env:RELEASE_ENVIRONMENTNAME -eq 'MNT') {
    $servers = @{
        ComputerName = 'appcontent1mnt', 'appcontent2mnt', 'appcontent3mnt', 'mntcorecontent1', 'mntcorecontent2', 'mntsnecontent1', 'mntsnecontent2'
    }
    $SufiksZaMail = 'MNT' # Definisanje sufiksa naslova maila radi lakseg filtriranja za RULE 
}
elseif ($env:RELEASE_ENVIRONMENTNAME -eq 'FC2') {
    $servers = @{
        ComputerName =  'fc2corecontent1', 'fc2ssdev1f-05'
    }
    $SufiksZaMail = 'FC2' # Definisanje sufiksa naslova maila radi lakseg filtriranja za RULE
}
elseif ($env:RELEASE_ENVIRONMENTNAME -eq 'PROD') {
    Write-Host "Ne radimo i dalje prod"
}
else {
    Write-Host "Nesto nije u redu"
}

$fileContent = Get-Content "C:\Powershell\Releases\Task Schedulers\SwaggerProvera\Exceptions\Exceptions.txt"
# Definisanje ScriptBlock-a koji će se izvršiti na udaljenim serverima
$SB = {    
    param ($content)
    $exceptions = @{}
    $content | ForEach-Object{
    $parts = $_ -split "\s+"
    if($parts.Count -eq 2){
    $exceptions[$parts[0]]=[int]$parts[1]} 
    }
   

    Import-Module WebAdministration

    # Funkcija koja dobija IIS API servise
    function Get-IISAPIServices {
        $apiServices = @()

        # Dobijanje svih sajtova u IIS-u
        $sites = Get-Website
        foreach ($site in $sites) {
            $siteName = $site.Name
            $bindings = $site.Bindings.Collection

            # Iteracija kroz sve bindinge sajta
            foreach ($binding in $bindings) {
                if ($binding.protocol -eq "http" -or $binding.protocol -eq "https") {
                    $bindingInfo = $binding.bindingInformation
                    $parts = $bindingInfo -split ':'
                    $port = $parts[1]
                    $apps = Get-WebApplication -Site $siteName

                    # Iteracija kroz sve aplikacije sajta
                    foreach ($app in $apps) {
                        $appName = $app.Path -replace '/', ''
                        if ($appName -match "api") {
                            if ($appName) {
                                $apiServices += [PSCustomObject]@{
                                    SiteName    = $siteName
                                    Application = $appName
                                    Protocol    = $binding.protocol
                                    Port        = $port
                                }
                            }
                        }
                    }
                }
            }
        }
        return $apiServices
    }

    function Test-CheckMethods {
        param (
            [string] $siteName,
            [string] $application,
            [string] $protocol,
            [int] $port
        )
                $failedResults = @()

    # Definisanje izuzetih kombinacija servera i servisa (server, servis)
    $excludedServiceCombinations = @(
        @{ Server = "appcontent1mnt"; Service = "TiCatWebApi", "DBA.IpsRateApi", "ITShop.Api", "BFD.api", "PaymentGatewayAdministrationToolAPI","ExternalSalesPartners.Api", "DocumentXpert.Api" },
        @{ Server = "appcontent2mnt"; Service = "SwiftMsg.Api", "DBA.IpsRateApi", "TiCatWebApi", "ITShop.Api", "BFD.api", "PaymentGatewayAdministrationToolAPI","ExternalSalesPartners.Api", "DocumentXpert.Api" },
        @{ Server = "appcontent3mnt"; Service = "SwiftMsg.Api", "DBA.IpsRateApi", "TiCatWebApi", "ITShop.Api","BFD.api", "PaymentGatewayAdministrationToolAPI","ExternalSalesPartners.Api", "DocumentXpert.Api" }
        @{ Server = "fc2ssdev1f-05"; Service = "DBA.IpsRateApi","TiCatWebApi", "ITShop.Api","BFD.api", "PaymentGatewayAdministrationToolAPI","ExternalSalesPartners.Api", "DocumentXpert.Api" }
        @{ Server = "fc2corecontent1"; Service = "Nemanja.Api" }
    )

    # Provera da li je trenutni server i servis u listi izuzetih kombinacija
    $currentServer = $env:COMPUTERNAME
    $currentService = $application

    $isExcluded = $excludedServiceCombinations | Where-Object {
        $_.Server -eq $currentServer -and $_.Service -eq $currentService
    }

    if ($isExcluded) {
        Write-Host "Preskacem servis: $currentService na serveru: $currentServer jer je na listi izuzetih servisa"
        return $failedResults  # Ako je servis izuzet, preskoči ga i ne dodaj u rezultate
    }

        $swaggerUri = "${protocol}://localhost:${port}/${application}/swagger/v1/swagger.json"

        try {
            $swaggerAll = Invoke-RestMethod -Uri $swaggerUri -Method Get -UseDefaultCredentials 
        }
        catch {
        Write-Host "Usao u catch"
        $application
        $swaggerUri
        $statusCode = "N/A"
        $statusDescription = "N/A"
        if ($_.Exception.Response) {
            $statusCode = $_.Exception.Response.StatusCode.value__
            $statusDescription = $_.Exception.Response.StatusDescription
            Write-Host "Status KOD : $statusCode"
        }

        $serverName = $env:COMPUTERNAME
        $fullSwaggerUrl = "${protocol}://${serverName}:${port}/${application}/swagger"
        # Dodavanje u failedResults
        $failedResults += [PSCustomObject]@{
            SiteName    = $siteName
            Application = $application
            Method      = "N/A"  # Ovde dodajemo 'N/A' jer nije bilo poziva
            StatusCode  = $statusCode
            Description = $statusDescription
            SwaggerUrl  = $fullSwaggerUrl
        }
    }
        $methodPaths = $swaggerAll.paths
        $methodList = $methodPaths.PSObject.Properties.Name | Where-Object { $_ -like '*/check' }



        foreach ($method in $methodList) {
            $swaggerUrl = "${protocol}://localhost:${port}/${application}${method}"
            Write-Host "$swaggerUrl"
            $headers = @{
                "ClientID" = "5711443f-2abb-4c94-8007-82318ebb36fc"
            }
            try {
                $response = Invoke-WebRequest -Uri $swaggerUrl -Method Get -UseDefaultCredentials -ContentType "application/json" -Headers $headers -UseBasicParsing

                if ($response.StatusCode -ne 200 -and !($exceptions[$method] -and $exceptions[$method] -eq $response.StatusCode)) {
                    $serverName = $env:COMPUTERNAME
                    $fullSwaggerUrl = "${protocol}://${serverName}:${port}/${application}/swagger"
                    $failedResults += [PSCustomObject]@{
                        SiteName    = $siteName
                        Application = $application
                        Method      = $method
                        StatusCode  = $response.StatusCode
                        Description = $response.StatusDescription
                        SwaggerUrl  = $fullSwaggerUrl
                    }
                }
            }
            catch {
                Write-Host "Greška tokom poziva metode: ${method} servis: ${application} sajt: ${siteName}: $_"
                $statusCode = "N/A"
                $statusDescription = "N/A"
                if ($_.Exception.Response) {
                    $statusCode = $_.Exception.Response.StatusCode.value__
                    $statusDescription = $_.Exception.Response.StatusDescription
                }
                    if (!($exceptions[$method] -and $exceptions[$method] -eq $statusCode)) {
                    $serverName = $env:COMPUTERNAME
                    $fullSwaggerUrl = "${protocol}://${serverName}:${port}/${application}/swagger"
                    $failedResults += [PSCustomObject]@{
                        SiteName    = $siteName
                        Application = $application
                        Method      = $method
                        StatusCode  = $statusCode
                        Description = $statusDescription
                        SwaggerUrl  = $fullSwaggerUrl
                    }
                }
            }
        }
    # Ispisivanje svih podataka u failedResults
    Write-Host "Failed Results:"
    $failedResults | ForEach-Object { Write-Host ($_ | ConvertTo-Json -Depth 3) }
        return $failedResults
    }
    # Glavna funkcija koja poziva prethodne funkcije i kombinuje rezultate
    function Main {
        $apiServices = Get-IISAPIServices

        $allFailedResults = @()

        foreach ($service in $apiServices) {
            Write-Host "Testiranje servisa na sajtu: $($service.SiteName), servis: $($service.Application), protokol: $($service.Protocol), port: $($service.Port)"
            $failedResults = Test-CheckMethods -siteName $service.SiteName -application $service.Application -protocol $service.Protocol -port $service.Port
            $allFailedResults += $failedResults
        }

        return @{
            Server        = $env:COMPUTERNAME
            FailedResults = $allFailedResults
        }
    }
    
    Main
}

# Kreiranje ScriptBlock-a i postavki sesije
$Blok = [scriptblock]::Create($SB)
$so = New-PSSessionOption -IncludePortInSPN

# Pokretanje ScriptBlock-a na udaljenim serverima i kombinovanje rezultata
$allResults = Invoke-Command -SessionOption $so -ComputerName $servers.ComputerName -ScriptBlock $Blok -ArgumentList (,$fileContent)
$exceptions | Format-Table -AutoSize
# Kombinovanje rezultata sa svih servera
$allResultsByServer = @{}
foreach ($result in $allResults) {
    $server = $result.Server
    if ($result.FailedResults) {
        $allResultsByServer[$server] = $result.FailedResults
    }
    else {
        $allResultsByServer[$server] = @()
    }
}

# Funkcija za generisanje HTML izveštaja
function GenerateHTMLReport {
    param (
        [hashtable] $allResultsByServer
    )

    # Provera da li ima bilo kakvih rezultata
    $hasAnyResults = $false
    foreach ($server in $allResultsByServer.Keys) {
        $validResults = $allResultsByServer[$server] | Where-Object{ $_.siteName -ne $null -and $_.StatusCode -ne $null }
        if ($validResults.Count -gt 0) {
            $hasAnyResults = $true
            break
        }
    }

    # Ako nema rezultata, vrati prazan string
    if (-not $hasAnyResults) {
        return ""
    }

    $html = @"
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <style>
        table {
            width: 100%;
            border-collapse: collapse;
        }
        th, td {
            border: 1px solid black;
            padding: 8px;
            text-align: left;
        }
        th {
            background-color: #f2f2f2;
        }
    </style>
    <title>Swagger check metode izveštaj</title>
</head>
<body>
<h2> Izvestaj check metoda na $stage </h2>
"@

 foreach ($server in $allResultsByServer.Keys) {
    $validResults = $allResultsByServer[$server] | Where-Object{ $_.siteName -ne $null -and $_.StatusCode -ne $null }
    if ($validResults.Count -gt 0){
    $html += "<h2>Izve&#353;taj za server: $server</h2>"
    $html += @"
    <table>
        <tr>
            <th>Site Name</th>
            <th>Application</th>
            <th>Method</th>
            <th>Status Code</th>
            <th>Description</th>
            <th>Swagger URL</th>
        </tr>
"@
    foreach ($result in $allResultsByServer[$server]) {
        # Proveri da li su svi potrebni podaci validni
        if ($result -and $result.SiteName -ne $null -and $result.StatusCode -ne $null) {
            $html += "<tr>"
            $html += "<td>$($result.SiteName.ToString().Trim())</td>"
            $html += "<td>$($result.Application -ne $null ? $result.Application.ToString().Trim() : '')</td>"
            $html += "<td>$($result.Method -ne $null ? $result.Method.ToString().Trim() : '')</td>"
            $html += "<td>$($result.StatusCode.ToString().Trim())</td>"
            $html += "<td>$($result.Description -ne $null ? $result.Description.ToString().Trim() : '')</td>"
            $html += "<td><a href='$($result.SwaggerUrl -ne $null ? $result.SwaggerUrl.ToString().Trim() : '')'>Swagger</a></td>"
            $html += "</tr>"
        }
    }
}
    $html += "</table>"
}
$html += "</body></html>"
return $html
}
$outputPathRmReporting = "\\fsi\ORG\ICT\DevOps\RM_Reporting\SwaggerProvera_$stage.html"
    # Provera i brisanje postojećih fajlova pre kreiranja novih
    if (Test-Path $outputPathRmReporting) {
        try {
            Write-Output "Pokušavam brisanje starog fajla: $outputPathRmReporting"
            Remove-Item -Path $outputPathRmReporting -Force -ErrorAction Stop
            Write-Output "Uspešno obrisan stari fajl"
        }
        catch {
            Write-Error "Greška pri brisanju fajla $outputPathRmReporting : $_"
            # Brišem kroz cmd komandu, ako ne uspem kroz ps1
            cmd /c del "$outputPathRmReporting" /f /q
        }
    }
    else {
        Write-Output "Fajl ne postoji na putanji: $outputPathRmReporting"
    }
# Generisanje i čuvanje HTML izveštaja, slanje email-a
if ($allResultsByServer.Count -gt 0) {
    $htmlReport = GenerateHTMLReport -allResultsByServer $allResultsByServer
    if ($htmlReport -ne "") {
        $htmlReport | Out-File -FilePath $outputPathRmReporting -Encoding UTF8
        Write-Host "Izveštaj sačuvan na sledeću lokaciju: $outputPathRmReporting" 

    } else {
        Write-Host "Nema neuspelih rezultata za prikaz"
    }
}
else {
    Write-Host "Nema neuspelih rezultata, ne saljemo mail"
}
