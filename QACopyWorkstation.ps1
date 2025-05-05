# Definiši izvor i destinaciju
$sourceFolder = "\\test1\c$\console\PWR"
$destinationFolder = "C$\PWR"

# Spisak radnih stanica
$workstations = @("WS1", "WS2", "WS3")

# Varijabla za praćenje grešaka
$ErrorOccurred = $false

# Petlja kroz radne stanice i kopiranje foldera
foreach ($workstation in $workstations) {
    $destinationPath = "\\$workstation\$destinationFolder"

    try {
        Write-Host "Kopiranje na radnu stanicu $workstation..."

        # Proveri da li postoji izvorni folder
        if (Test-Path -Path $sourceFolder) {
            # Kreiraj destinacijski folder ako ne postoji
            if (-not (Test-Path -Path $destinationPath)) {
                New-Item -ItemType Directory -Path $destinationPath -Force
            }
            Write-Output "Prebacujem artefakte iz $sourceFolder na $destinationPath koristeći robocopy..."
            robocopy $sourceFolder $destinationPath /E /R:3 
            $DeployExitCode = $LASTEXITCODE

            if ($DeployExitCode -lt 8) {
                Write-Output "Deploy robocopy uspešan sa exit kodom $DeployExitCode za $workstation."
            } else {
                Write-Error "Deploy robocopy nije uspešan za $workstation! Exit kod: $DeployExitCode"
                $ErrorOccurred = $true
            }
            Write-Host "Uspešno kopirano na $workstation"
        } else {
            Write-Host "Izvorni folder ne postoji: $sourceFolder"
            $ErrorOccurred = $true
        }
    } 
    catch {
        Write-Host "Greška pri kopiranju na $workstation"
        $ErrorOccurred = $true
    }
}

# Na kraju proveravamo da li je bilo grešaka
if ($ErrorOccurred) {
    exit 1
} else {
    exit 0
}
