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

#Add-Type -AssemblyName System.Core
#$wait = New-Object OpenQA.Selenium.Support.UI.WebDriverWait($driver, [System.TimeSpan]::FromSeconds(20))
#$wait.Until({$driver.FindElement([OpenQa.Selenium.By]::TagName("table")).Count -gt 0})
#$scriptBlock ={
#param($d)
#$d.FindElements([OpenQA.Selenium.By]::CssSelector("table tbody tr")).Count -gt 0}
#$wait.Until($scriptBlock)

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
$workbook.SaveAs($putanja)
$excel.Quit()

Write-Host "Excel sacuvan na: $($putanja)"

#$driver.GetScreenshot().SaveAsFile("C:\Temp\screenshot.png", [OpenQA.Selenium.ScreenshotImageFormat]::Png)

Start-Sleep -Seconds 10
$driver.Quit()

$projekti = @{
    "PROD" = "PROD Implementacija" 
    "FC2" = "FC2 implementacija i grеške"
    "MNT" = "MNT implementacija"
    "MNT bagovi" = "MNT grеške"
}

####Ucitavanje podataka iz excela
$excel = New-Object -ComObject Excel.Application
$workbook = $excel.Workbooks.Open("C:\Temp\SandaKovacevic.xlsx")
$sheet = $workbook.Sheets.Ithem(1)
$headeri = @()
$vrednosti = @()
for($i = 1; $i -le 6; $i++) {
    $headeri += $sheet.Cells.Item(1,$i).Text
    $vrednosti += $sheet.Cells.Item(2, $i).Text
    }
$excel.Quit()

foreach ($i in 1..(headeri.Count - 1)){
    $datum = $headeri[$i]
    $dezurstvo = $vrednosti[$i]

    if($projekti.ContainsKey($dezurstvo)){
        $projekat = $projekti[$dezurstvo]
    }
    }