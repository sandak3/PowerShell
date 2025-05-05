    # Importovanje potrebnih PowerShell modula   
    Import-Module "C:\Powershell\Modules\sdi.psd1" 
    Import-Module "C:\Powershell\Modules\SqlServer.psd1" 
    
    # Putanja do fajla sa listom servera
    $stage = $env:Okruzenje
    if($stage -eq 'Test'){
    $serverListPath = "C:\Powershell\OpenTran\ServerListTest.txt"
    }
    if($stage -eq 'Test2'){
    $serverListPath = "C:\Powershell\OpenTran\ServerListTest2.txt"
    }
    
    
    # HTML šablon za izgled tabele
    $htmlTemplate = @"
    <!DOCTYPE html>
    <html>
    <head>
        <style>
            table {
                border-collapse: collapse;
                width: 100%;
            }
    
            th {
                background-color: #f2f2f2;
            }
    
            th, td {
                border: 1px solid black;
                padding: 8px;
                text-align: left;
            }
    
            
        </style>
    </head>
    <body>
    
    <h2>Upozorenja o transakcijama koje traju du&#x17E;e od 10 minuta na $stage</h2>
    <table>
        <tr>
            <th>Redni broj</th>
            <th>Server</th>
            <th>TRANSACTION BEGIN TIME</th>
            <th>TRANSACTION DURATION (min)</th>  
            <th>SESSION ID</th>
            <th>HOST NAME</th>
            <th>Login NAME</th>
            <th>PROGRAM NAME</th>
            <th>TRANSACTION ID</th>
            <th>TRANSACTION NAME</th>
            <th>DATABASE ID</th>
            <th>DATABASE NAME</th>
            
        </tr>
        <!--DATA-->
    </table>
    
    </body>
    </html>
"@
    
    
    # Parametri za konektovanje na SQL Server
    $invokeParam = @{
        username = "userA"
        password = "***"
    }
    
    # Učitavanje liste servera iz fajla
    $servers = Get-Content -Path $serverListPath
    
    # SQL upit za dobijanje podataka o aktivnim transakcijama
    $sqlQuery = @"
        SELECT
        at.session_id AS [SESSION ID],
        at.host_name AS [HOST NAME],
        login_name AS [LOGIN NAME],
        program_name AS [PROGRAM NAME],
        trans.transaction_id AS [TRANSACTION ID],
        at.name AS [TRANSACTION NAME],
        at.transaction_begin_time AS [TRANSACTION BEGIN TIME],
        tds.database_id AS [DATABASE ID],
        DBs.name AS [DATABASE NAME]
        FROM sys.dm_tran_active_transactions at
        JOIN sys.dm_tran_session_transactions trans ON (trans.transaction_id = at.transaction_id)
        LEFT OUTER JOIN sys.dm_tran_database_transactions tds ON (at.transaction_id = tds.transaction_id )
        LEFT OUTER JOIN sys.databases AS DBs ON tds.database_id = DBs.database_id
        LEFT OUTER JOIN sys.dm_exec_sessions AS at ON trans.session_id = at.session_id
        WHERE at.session_id IS NOT NULL
        ORDER BY [TRANSACTION BEGIN TIME] ASC
"@
    
    # Inicijalizacija StringBuilder-a za izgradnju HTML-a
    $htmlBuilder = New-Object -TypeName System.Text.StringBuilder
    
    # Inicijalizacija rednog broja za svaki red
    $redniBroj = 1
    #$zastava je varijbla za proveru da li treba da se šalje mail
    $zastava = 0
    
    # Na početku skripte, nakon učitavanja servera
    Write-Output "Učitano servera: $($servers.Count)"
    Write-Output "Stage: $stage"
    Write-Output "Server list path: $serverListPath"
    
    # Iteracija kroz sve servere
    foreach ($server in $servers) {
        Write-Output "Proveravam server: $server"
        try {
            # Izvršavanje SQL upita na trenutnom serveru
            Write-Output "Izvršavam SQL upit na serveru $server"
            $result = Invoke-Sqlcmd @invokeParam -query $sqlQuery -ServerInstance $server
            # Provera da li ima rezultata
            if ($null -eq $result) {
                Write-Output "Nema rezultata na serveru $server"
                continue
            }
            else {
                Write-Output "Pronađeno $($result.Count) transakcija na serveru $server"
                # Iteracija kroz rezultate upita
                foreach ($tran in $result) {
                    # Računanje trajanja transakcije u minutima
                    $trenutnoVreme = Get-Date
                    $pocetakTransakcije = $tran."TRANSACTION BEGIN TIME"
                    $razlika = ($trenutnoVreme - $pocetakTransakcije).TotalMinutes
    
                    # Provera da li je trajanje veće od 10 minuta
                    if ($razlika -gt 10) {
                        Write-Host "##vso[task.logissue type=warning]Pronađena transakcija duža od 10 minuta: $($tran.'HOST NAME') - $razlika minuta"
                        # Provera da li login počinje sa 'SDI, usa, fni' i ubijanje sesije ako je true
                        $isKilled = $false
                        if ($tran.'HOST NAME' -match "^SDI|^usa|^fni") {
                            try {
                                Write-Host "##vso[task.logissue type=warning]Ubijanje sesije za SDI, usa, fni korisnika: $($tran.'HOST NAME') na serveru $server"
                                $killQuery = "KILL $($tran.'SESSION ID')"
                                Invoke-Sqlcmd @invokeParam -Query $killQuery -ServerInstance $server
                                Write-Host "##vso[task.logissue type=warning]Sesija uspešno ubijena"
                                $isKilled = $true
                            }
                            catch {
                                Write-Host "Greška pri ubijanju sesije: $_"
                            }
                        }
    
                        # Računanje trajanja transakcije u satima, minutima i danima
                        $razlikaSati = [math]::Floor($razlika / 60)
                        $ostatakMinuta = $razlika % 60
    
                        # Zaokruživanje minuta na ceo broj
                        $ostatakMinutaZaokruzeno = [math]::Round($ostatakMinuta)
    
                        $razlikaDana = [math]::Floor($razlikaSati / 24)
                        $ostatakSati = $razlikaSati % 24
    
                        # Formatiranje trajanja
                        $trajanje = if ($razlikaDana -gt 0) {
                            "$razlikaDana dan/a, $ostatakSati sat/a, $ostatakMinutaZaokruzeno minuta"
                        } elseif ($razlikaSati -gt 0) {
                            "$ostatakSati sat/a, $ostatakMinutaZaokruzeno minuta"
                        } else {
                            "$ostatakMinutaZaokruzeno minuta"
                        }
    
                        # Dodavanje HTML reda u StringBuilder sa crvenom bojom za ubijene sesije
                        $serverCell = [System.Web.HttpUtility]::HtmlEncode($server)
                        $rowStyle = if ($isKilled) { ' style="color: red;"' } else { '' }
                        $htmlRow = @"
                        <tr$rowStyle>
                            <td>$redniBroj</td>
                            <td>$serverCell</td>
                            <td>$($tran.'TRANSACTION BEGIN TIME')</td>
                            <td>$trajanje</td>
                            <td>$($tran.'SESSION ID')</td>
                            <td>$($tran.'HOST NAME')</td>
                            <td>$($tran.'LOGIN NAME')</td>
                            <td>$($tran.'PROGRAM NAME')</td>
                            <td>$($tran.'TRANSACTION ID')</td>
                            <td>$($tran.'TRANSACTION NAME')</td>
                            <td>$($tran.'DATABASE ID')</td>
                            <td>$($tran.'DATABASE NAME')</td>
                        </tr>
"@
                        # Dodavanje HTML reda u StringBuilder
                        [void]$htmlBuilder.AppendLine($htmlRow)
                        # Povećavamo redni broj za sledeću transakciju
                        $redniBroj++
                        # Postavi zastavu na 1 jer smo pronašli transakciju
                        $zastava = 1
                    }
                }
            }
        }
        catch {
            Write-Output "Greška pri povezivanju na server $server : $_"
        }
    }
    
    $outputPathRmReporting = "\\share\Powershell\OpenTran_$stage.html"
    
    # Provera i kreiranje direktorijuma ako ne postoji
    $outputDirectory = Split-Path $outputPathRmReporting -Parent
    if (-not (Test-Path $outputDirectory)) {
        try {
            New-Item -ItemType Directory -Path $outputDirectory -Force | Out-Null
            Write-Output "Kreiran direktorijum: $outputDirectory"
        }
        catch {
            Write-Error "Nije moguće kreirati direktorijum $outputDirectory : $_"
            # Pokušaj kreiranje kroz cmd ako PowerShell ne uspe
            cmd /c mkdir "$outputDirectory" 2>$null
        }
    }
    
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
    
    # Provera da li treba poslati email
    if ($zastava -eq 1) {
        # Završavanje izgradnje HTML-a
        $htmlResult = $htmlTemplate -replace "<!--DATA-->", "$htmlBuilder"
    
        # Sačuvaj HTML na putanji
        $htmlResult | Out-File -FilePath $outputPathRmReporting -Encoding UTF8
        Write-Host "HTML sačuvan na putanji: $($outputPathRmReporting)"
    
        $PipNaziv = $env:Naziv
        $PipAgent = $env:Agent
    
        # Šaljemo email
     <#   Send-Email -mailParam @{
            From       = "$PipelineAgent@$PipelineAgent.rs"
            To         = 'DevOps@test.rs'
            Subject    = 'Otvorene Transakcije[Test, Test2]'
            Body       = "\\share\DEV\EmailS\transaction.html"
            SmtpServer = 'smtpq'
        }
     #>
    }
    
    # Pre kreiranja HTML fajla
    Write-Output "Zastava status: $zastava"
    Write-Output "Broj pronađenih transakcija: $($redniBroj - 1)"
