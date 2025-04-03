import-module "C:\selenium-powershell-master\Output\Selenium\Selenium.psd1"
import-module "C:\selenium-powershell-master\Output\Selenium\Selenium.psm1" -Force
#pokreni Chrome browser
$driver = Start-SeChromeDriver

#otvori On Call stranicu 
$driver.Navigate().GoToUrl("http://arrwebnlb:7777/on-call")
#Wait-SeElement -Driver $driver -ByTagName -Value "td" -Timeout 15
##### dajemo Angularu vremena da sve ucita
Start-Sleep -Seconds 10

##### dodata funkcija u selenium psm1 function Wait-Until {
#	param(
#	 [Parameter(Mandatory = $true)]
#    [ScriptBlock]$Condition,
#
#	 [int]$TimeoutInSeconds = 20
#	)
#	
#	$elapsed = 0
#	while ($elapsed -lt $TimeoutInSeconds){
#		$result = & $Condition
#		if ($result){
#			return $true
#		}
#		Start-Sleep -Seconds 1
#		$elapsed++
#	}
#	return $false
	
	
####pozivam svoju Wait-Until funkciju kojom proveravam da li ima bar jedan <tr> red u <tbody> tabele,
####ako ne postoji odmah, funkcija ceka i ponavlja proveru dok ne istekne timeout 
Wait-Until {
$driver.FindElements([OpenQA.Selenium.By]::CssSelector("table tbody tr")).Count -gt 0} 

$script = @" 
var output = [];
var table = document.querySelector("table");
if (!table) return ["Tabela nije pronadjena"];

// --- Zaglavlja ---
var headerCells = table.querySelectorAll("thead tr th");
var headers = [];
Array.from(headerCells).forEach(function(th){
headers.push(th.innerText.trim());
});
output.push(headers.join(";"));

// --- Redovi ---
var rows = table.querySelectorAll("tbody tr");
Array.from(rows).forEach(function(row){
    var cols = row.querySelectorAll("td");
    var rowData = [];

Array.from(cols).forEach(function(col){
    var input = col.querySelector("input");
    if(input && input.value){
    rowData.push(input.value.trim());
    }
    else {
    rowData.push(col.innerText.trim());
    }
    
});
// Proveri da li prvi element u redu sadrzi Sanda

    if(rowData.length > 0 && rowData[0].includes("Sanda")){
        output.push(rowData.join(";"));
    }
});
return output;
"@

####izvrsi JavaScript
$result = $driver.ExecuteScript($script)
#$result |  Out-File -Append -FilePath "C:\Temp\javalog.txt" -Encoding utf8

$kolone = $result[0] -split ";"
$sanda = $result[1] -split ";"

####kreiranje Excel fajla
$excel = New-Object -ComObject Excel.Application 
$excel.Visible = $false
$workbook = $excel.Workbooks.Add()
$sheet = $workbook.Sheets.Item(1)

####upis zaglavlja
for ($i = 0; $i -lt $kolone.Count; $i++){
    $sheet.Cells.Item(1, $i + 1) = $kolone[$i]
}

####upis Sanda podataka
for ($i = 0; $i -lt $sanda.Count; $i++){
    $sheet.Cells.Item(2, $i + 1) = $sanda[$i]
}
####cuvanje
$putanja = "C:\Temp\SandaKovacevic.xlsx"
if (Test-Path $putanja) { Remove-Item $putanja -Force }
$workbook.SaveAs($putanja)
$excel.Quit()

Write-Host "Excel sacuvan na: $($putanja)"

Start-Sleep -Seconds 10
$driver.Quit()


$projekti = @{
    "PROD" = "PROD implementacija" 
    "FC2" = "FC2 implementacija i grеške"
    "MNT" = "MNT implementacija"
    "MNT bagovi" = "MNT grеške"
}

####Ucitavanje podataka iz excela
$excel = New-Object -ComObject Excel.Application
$workbook = $excel.Workbooks.Open("C:\Temp\SandaKovacevic.xlsx")
$sheet = $workbook.Sheets.Item(1)
$headeri = @()
$vrednosti = @()
for($i = 1; $i -le 6; $i++) {
    $headeri += $sheet.Cells.Item(1,$i).Text
    $vrednosti += $sheet.Cells.Item(2, $i).Text
    }
$excel.Quit()

foreach ($i in 1..($headeri.Count - 1)){
    $datum = $headeri[$i]
    $dezurstvo = $vrednosti[$i]

    if($projekti.ContainsKey($dezurstvo)){
        $projekat = $projekti[$dezurstvo]
    }
    }



$driver = Start-SeChromeDriver

#otvori WorkingHour stranicu 
$driver.Navigate().GoToUrl("http://arrwebmntnlb/WorkHours-app/calendar")
Start-Sleep -Seconds 10

Wait-Until { $driver.FindElementsByCssSelector("div.dx-popup").Count -gt 0}

$slotovi = $driver.FindElementsByCssSelector("div.dx-scheduler-date-table-cell")
# DEBUG: ispisi sve tekstove iz lotova 
$slotovi | ForEach-Object {Write-Host $_.Text}

$culture = [System.Globalization.CultureInfo]::GetCultureInfo("en-US")
$dayOfWeek = (Get-Date $datum).DayOfWeek.value__
#$dan = (Get-Date $datum).ToString("ddd", $culture).ToLower()
#$danBroj = [int](Get-Date $datum).Day

####pronadji prvi red u tabeli 
$redovi = $driver.FindElementByCssSelector("tr.dx-scheduler-date-table-row")
$prviRed = $redovi[0]
####izvuci sve celije iz tog reda, to su dani 
$tds = $prviRed.FindElements([OpenQA.Selenium.By]::CssSelector("td.dx-scheduler-date-table-cell"))
$slot = $tds[$dayOfWeek]

####scroll do slota
$driver.ExecuteScript("arguments[0].scrollIntoView(true);", $slot)
Start-Sleep -Seconds 1

#$slot.Click()

####dvoklik na slot
$action = New-Object OpenQA.Selenium.Interactions.Actions($driver)
$action.MoveToElement($slot).DoubleClick().Perform()
Start-Sleep -Seconds 1
####sacekaj da overlay nestane
Wait-Until{
($driver.FindElementsByCssSelector("div.dx-overlay-wrapper") | Where-Object { $_.Displayed }).Count -eq 0}
##nadji i klikni na Project select polje
$SelectPolje = $driver.FindElementsCssSelector("input[placeholder=Select...]")[0]
$driver.ExecuteScript("arguments[0].scrollIntoView(true);", $SelectPolje)
Start-Sleep -millisecond 500
$actions = New-Object OpenQA.Selenium.Interactions.Actions($driver)
$actions.MoveToElement($SelectPolje).Click().Perform()
##sacekaj da se opcije pojave
Wait-Until{($driver.FindElementsByCssSelector("div.dx-item-content") | Where-Object { $_.Text }) -eq $projekat}

If($target.Count -gt 0){
$target[0].Click()
Write-Host "Izabran je projekat: $($projekat)"
}
else{
Write-Host "Nema opcije sa tekstom: $($projekat) "
continue}

##Naslov
$titleInput = $driver.FindElementsByCssSelector("input[placeholder='Title']")
$titleInput.Clear()
$titleInput.SendKeys($projekat)

##klik na izvrseno
$izvrseno = $driver.FindElementsByXPath("//div[contains(@class, 'dx-button')]//span[text()='Izvršeno']")
$izvrseno.Click()
Start-Sleep -Seconds 2



$driver.Quit()