# Definišite putanje izvornog i odredišnog foldera
$sourceFolder = "C:\MyDir"
$backupFolder = "C:\backup"

# Uzmi trenutni datum u formatu godineMesecDan (npr. 20250120)
$currentDate = Get-Date -Format "yyyyMMdd"

#broj pokusaja
$attempt = 1

# Kreiramo ime foldera za backup (datum + broj pokušaja)
$backupFolderName = "$currentDate.$attempt"

#provera da li postoji folder sa tim imenom, ako postoji uvecati attempt broj 
while (Test-Path (Join-Path $backupFolder $backupFolderName )){
$attempt++
$backupFolderName = "$currentDate.$attempt"
}

# Kreiranje putanje za backup
$backupFolderPath = Join-Path $backupFolder $backupFolderName
New-Item -ItemType Directory -Force -Path $backupFolderPath

# Kopiraj svih fajlova i foldera
Copy-Item -Path $sourceFolder\* -Destination $backupFolderPath -Recurse -Force

Write-Host "Backup završen: $backupFolderPath"

# Proveri koliko backup foldera postoji
$existingBackupFolders = Get-ChildItem -Path $backupFolder -Directory | Sort-Object LastWriteTime

# Ako postoji više od 3 foldera obriši najstariji
if ($existingBackupFolders.Count -gt 3) {
    $oldestFolder = $existingBackupFolders | Select-Object -First 1
    Write-Host "Brisanje najstarijeg foldera: $($oldestFolder.FullName)"
    Remove-Item -Path $oldestFolder.FullName -Recurse -Force
}

Write-Host "Obrisan je najstariji folder: $oldestFolder"