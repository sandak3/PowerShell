#parametri 
$daysBeforeExpiration = 30
$Today = Get-Date
$expiringSoon = @()

#ucitavanje IIS modula 
Import-Module WebAdministration

#uzmi sve IIS sajtove
$sites = Get-ChildItem IIS:SslBindings


# Get all sites with https bindings
$httpsSites = @()
#Prolazak kroz sve IIS sajtove
Get-ChildItem IIS:\Sites |
ForEach-Object {
   $siteName = $_.Name
   $bindings = $_.Bindings.Collection

   foreach ($binding in $bindings){
       if($binding.protocol -eq "https"){
           $certH = $binding.CertificateHash
           $certS = $binding.CertificateStoreName
           $cert = $null

           If($certH -and $certS){
               try{
                   $cert = Get-Item  "Cert:\LocalMachine\$certS\$certH" -ErrorAction Stop
               } catch{
                   $cert = $null 
               }
           }

           $httpsSites += [PSCustomObject]@{
               SiteName = $siteName
               Protocol = $binding.Protocol
               BindingInfo = $binding.BindingInformation
               Thumbprint = $cert?.Thumbprint
               Subject = $cert?.Subject
               Expires = $cert?.NotAfter
               DaysLeft = if($cert){
                   ($cert.NotAfter - (Get-Date)).days
               }
               else {
                   $null
               }
           }
       }
   }
}
#prikaz u tabeli 
$httpsSites | Sort-Object DaysLeft | Format-Table -AutoSize

foreach ($site in $sites){
   $certHash = $site.Thumbprint
   $certStore = Get-Item "Cert:\LocalMachine\My\$certHash" -ErrorAction SilentlyContinue


if ($certStore){
   $certInfo = [PSCustomObject]@{
       Site = "$($site.IP):$($site.Port)"
       Subject = $certStore.Subject
       Expires = $certStore.NotAfter
       DaysLeft = ($certStore.NorAfter - $Today).days 
       Issuer = $certStore.Issuer
   }
   If($certInfo.DaysLeft -lt $daysBeforeExpiration){
       $expiringSoon += $certInfo
   }
}
}

#prikazi rezultat 
If ($expiringSoon.Count -gt 0){
   Write-Host "Sertifikati koji istiicu u narednih $($daysBeforeExpiration) dana: `n" -ForegroundColor Yellow
   $expiringSoon | Format-Table Site, Subject, Expires, DaysLeft

   #priprema email body-ja 
   $body = $expiringSoon | Out-String

   #slanje mejla
   Send-MailMessage -From "noreplay@test.com -To "sanda.kovacevic@test.com" -Subject "UPOZORENJE: SSL sertifikati uskoro isticu " -Body $body -SmtpServer "smtp.server.com" -UseSsl}
else{
   Write-Host "Nema sertifikata koji uskoro isticu" -ForegroundColor Green
}

 
