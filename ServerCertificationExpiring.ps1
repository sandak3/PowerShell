# Importovanje potrebnih PowerShell modula   
Import-Module "C:\Powershell\Modules\CMD\CMD.psd1" 
Import-Module WebAdministration

$FarmServers = $env:FarmServers -split ","  # We define the servers from the Azure variable (eg "ArrWeb1MNT, ArrWeb2MNT")
$stageName = $env:RELEASE_ENVIRONMENTNAME # we define the name of the stage from azure in order to enter the HTML as such
$daysBeforeExpiration = 30
$outputPath = "\\fsi\ORG\ICT\DevOps\IstekCert$stageName.html"
$outputPathRmReporting = "\\fsi\ORG\ICT\DevOps\RM_Reporting\CertKojiIsticu_$stageName.html"

   # HTML template for table layout
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
   
   <h2>Sertifikati koji isticu u narednih $daysBeforeExpiration dana</h2>
   <table>
       <tr>
           <th>Subject</th>
           <th>NotAfter</th>
           <th>Thumbprint</th>
       </tr>
       <!--DATA-->
   </table>
   
   </body>
   </html>
"@
# A script block to be executed on each remote server
$ScriptBlock = {
#parameters
$daysBeforeExpiration = 30 
$Today = Get-Date
#Loading Cert from Personal Store (Local Machine)
$certs = Get-ChildItem -Path Cert:\LocalMachine\My

#Filtering out those expiring in the next 30 days
$expiringCerts = $certs | Where-Object{$_.NotAfter -lt $Today.AddDays($daysBeforeExpiration)} | Select-Object Subject, NotAfter, Thumbprint
return $expiringCerts
}

#Collecting results from all servers
foreach($server in $FarmServers){
   Write-Host "Proveravam server: $($server)"
   try{
       $result = Invoke-Command -ComputerName $server -ScriptBlock $ScriptBlock -ArgumentList $daysBeforeExpiration
       if($result.Count -gt 0){
           $htmlBody += "<h3>Server:$server</h3>"
           $htmlBody += "<table><tr>
           <th>Subject</th>
           <th>NotAfter</th>
           <th>Thumbprint</th></tr>"
           foreach ($cert in $result){
               $subject = $cert.Subject
               $NotAfter = $cert.NotAfter.ToString("yyyy-MM-dd")
               $thumbprint = $cert.Thumbprint
               $htmlBody += "<tr>
               <td>$subject</td>
               <td>$NotAfter</td>
               <td>$thumbprint</td></tr>"
           }
           $htmlBody += "</table><br/ >"
       }
       else{
           $htmlBody += "<h3>Server:$server</h3><p style='color:green;'> Nema isticucih sertifikata </p>"
       }
   }
   catch{
       $htmlBody += "<h3>Server:$server</h3><p style='color:red;'> Greska $_</p>"
   }
}

#save html file
$htmlReport = $htmlTemplate -replace '!--DATA-->', $htmlBody
$htmlReport | Out-File -FilePath $outputPathRmReporting -Encoding utf8

Write-Output "`nHTML izvestaj je sacuvan na $($outputPathRmReporting)"

# HTML-a
try {
   $htmlReport | Out-File -FilePath $outputPath -Encoding UTF8
   $htmlReport | Out-File -FilePath $outputPathRmReporting -Encoding UTF8 -Force
   Write-Output "HTML izveštaj kreiran"
}
catch {
   Write-Error "Greška pri kreiranju HTML fajla: $_"
}

 


#Display of results

 


#if ($expiringCerts.Count -gt 0){
#   Write-Host "Sertifikati koji isticu u narednih $($daysBeforeExpiration) dana: `n"
#   $expiringCerts | Format-Table -AutoSize
#export to csv

 


#$csvPath = "C:\Temp\ExpiringCert.csv"
#$expiringCerts | Export-Csv -Path $csvPath -NoTypeInformation
#Write-Host "`nPodaci su sacuvani u: $($csvPath)"

#}
#else{
###   Write-Host "Nema sertifikata koji isticu u narednih $($daysBeforeExpiration)"
#


  
# Lista za sve rezultate


#$expiringCerts = @()