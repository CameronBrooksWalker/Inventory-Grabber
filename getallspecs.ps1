

#$computers = get-Content '\\c202b\c$\users\sleger\Desktop\hamburgers.txt'

echo "Getting Domain Info..."

$alldomain = get-adcomputer -filter * -property *

$computers = $alldomain.CN

$outfile = 'c:\users\cwalker\desktop\ALLOFTHEMEVER.csv'

$counter = 0

foreach ($computer in $computers) {

$counter++

Write-Progress -Activity 'Gathering and formatting data...' -CurrentOperation $computer -PercentComplete (($counter / $computers.Length) * 100)

if(Test-Connection -ComputerName $computer -count 1 -Quiet)
{
    
try{    

$cpu = Get-WmiObject win32_processor -ComputerName $computer -ErrorAction Stop

$cpu = [string]::Join("/ ",$cpu.Name)

$cpu = $cpu -replace "\(R\)" -replace "\(TM\)" -replace "CPU" -replace " @ [\d.]+GHz"

$gpu = Get-WmiObject win32_videocontroller -ComputerName $computer

$gpu = [string]::Join(" / ",$gpu.Caption)

$gpu = $gpu -replace "\(R\)" -replace "\(TM\)"

$serial = Get-WMIObject Win32_Bios -ComputerName $computer

$info = systeminfo /s $computer /fo csv | ConvertFrom-Csv

$info | Add-Member -NotePropertyName 'Asset Tag' -NotePropertyValue '-'

$info | Add-Member -NotePropertyName 'Status' -NotePropertyValue 'Ready to Deploy'

$info | Add-Member -NotePropertyName 'username' -NotePropertyValue '-'

$info | Add-Member -NotePropertyName Serial -NotePropertyValue $serial.SerialNumber

$info | Add-Member -NotePropertyName CPU -NotePropertyValue $cpu

$info | Add-Member -NotePropertyName GPU -NotePropertyValue $gpu

$info | select 'asset tag', serial, 'host name',status, username, cpu, gpu, 'os name', 'system manufacturer', 'system model', 'bios version', 'total physical memory', 'network card(s)' | Export-Csv $outfile -notypeinformation -Append

}

catch {echo "$computer did not respond to WMIC" >> $outfile}

}

else { echo "$computer did not respond to ping" >> $outfile}

}





