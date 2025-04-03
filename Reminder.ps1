[console]::Beep(800, 200) 
[console]::Beep(1000, 200) 
#[console]::Beep(1200, 500) 
#[console]::Beep(1000, 200) 
#[console]::Beep(800, 400) 
# frekvencija 1000 Hz, trajanje 50 ms


"Reminder script STARTED at" | Out-File -FilePath "$env:USERPROFILE\Desktop\reminder_log.txt" -Append


try{
Add-Type -AssemblyName  System.Windows.Forms
[System.Windows.Forms.MessageBox]::Show("Podsetnik: Popuni WorkingHours!", "Podsetnik", "OKCancel", "Information")
}
catch{
    "Greska: $($_.Exception.Message)" | Out-File "$env:USERPROFILE\Desktop\reminder_log.txt" -Append 

}
Start-Sleep -Seconds 10
#Read-Host "Pritisni Enter da zatvoris prozor"