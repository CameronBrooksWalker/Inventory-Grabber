# Inventory-Grabber
Dynamically grabs hardware inventory from your Active Directory Domain, and exports it in an import-able .csv, formatted for Snipe-IT


This script will reach out to your DC, grab a list of active computer objects, and then use that list to ask each individual device about it's hardware.

I realize that AD actually stores a fair amount of this information itself, but I worked exceptionally hard to make sure the formatting for the final .csv was perfect, and grabbing the information in the manner below and doing some string manipulation yielded the best results.

Because this script was written largely to help another member of my department, I tried my darndest to make the console output as clean and verbose as possible. This is mostly necessary because unfortunately the systeminfo batch command is HORRIBLY slow, so a more clear representation of what's happening, and a confirmation that things ARE still happening, is helpful.

We start by grabbing a list of ad computers from the domain.


    echo "Getting Domain Info...
    
    $alldomain  =  get-adcomputer  -filter *  -property *
    
    $computers  =  $alldomain.CN

We're also experimenting with PowerShell's "Write-Progress" bar, in the pursuit of maximum nice-looking-ness. This really just uses the $counter variable divided by the number of computers in the list to get a percentage of completion.

    $counter  =  0
    
    foreach ($computer  in  $computers) {
    
    $counter++
    
    Write-Progress  -Activity 'Gathering and formatting data...'  -CurrentOperation $computer  -PercentComplete (($counter  /  $computers.Length) *  100)

Then we get to the meat of the script, in which we have lots of WMI calls, and an unpleasant amount of string manipulation.

Here, we get the CPU name from WMI, because the "systeminfo" batch command actually gives you the family name instead of the actual CPU model name. Then we have to do our first bit of funky manipulation, because there's a very real chance your computer might have more than 1 cpu. Left unaltered, this would return an object instead of a string, and leave you with some completely worthless output in your field. So in one line, we break open the $cpu variable, pull it's pieces out, and then glue them back together in a string format, with " / " separating individual entries. I also clean up the name of the CPU, because you generally get lots of silly marketing mumbo jumbo in your field, and since we KNOW the product is a CPU, and we KNOW that the name "Intel" or "AMD" is trademarked, we can live without putting that in our inventory. Something possessed me to use a bit of regex to make this cleanup easier, and I'm deeply sorry, because regex is awful.

    $cpu  =  Get-WmiObject win32_processor -ComputerName $computer  -ErrorAction Stop
    
    $cpu  = [string]::Join("/ ",$cpu.Name)
    
    $cpu  =  $cpu  -replace  "\(R\)"  -replace  "\(TM\)"  -replace  "CPU"  -replace  " @ [\d.]+GHz"

We run into exactly the same problem with the GPU. It's VERY common to have a dedicated graphics card in addition to an integrated one built into your CPU, so we have to do the same string trickery as before. Stick the GPUs together, remove the marketing junk, return to variable.

    $gpu  =  Get-WmiObject win32_videocontroller -ComputerName $computer
    
    $gpu  = [string]::Join(" / ",$gpu.Caption)
    
    $gpu  =  $gpu  -replace  "\(R\)"  -replace  "\(TM\)"


Here we get the "serial" for the machines. This is stored in the bios, and will look a little different depending on your manufacturer (it'll likely be worthless in a custom built computer). On Dell machines, this is also what you call your "Service Tag".

    $serial  =  Get-WMIObject Win32_Bios -ComputerName $computer

Here the oldschool batch "systeminfo" command does the rest of the information gathering. For it to be as old as it is (it predates PowerShell), it's reasonably advanced, and horribly silly. It has a built in function for remotely pulling specs from a network computer (using the /s flag), which is fantastic. But since it predates PowerShell, it has no semblance of an idea how to do anything constructive with all of its info, much less put it into a PS Object. So to manage that, we use the /fo format flag to tell it to turn the information into a ".csv", and then immediately pipe that raw .csv output into PowerShell's "Convertfrom-csv" tool to turn it into a usable object.

$info becomes where we put everything that will eventually be written to our output.

    $info  = systeminfo /s $computer  /fo csv |  ConvertFrom-Csv

The rest of this is just making new fields for the $info object, giving them names, then throwing earlier variables into it's fields. Note that "Asset Tag", "Status", and "username" aren't being pulled from the network, as their placeholder columns for your Snipe-IT import. You could very easily remove those lines if you're using a different inventory system.

    $info  |  Add-Member  -NotePropertyName 'Asset Tag'  -NotePropertyValue '-'
    
    $info  |  Add-Member  -NotePropertyName 'Status'  -NotePropertyValue 'Ready to Deploy'
    
    $info  |  Add-Member  -NotePropertyName 'username'  -NotePropertyValue '-'
    
    $info  |  Add-Member  -NotePropertyName Serial -NotePropertyValue $serial.SerialNumber
    
    $info  |  Add-Member  -NotePropertyName CPU -NotePropertyValue $cpu
    
    $info  |  Add-Member  -NotePropertyName GPU -NotePropertyValue $gpu

Lastly, we take all of the relevant fields from our $info object and dump them to a .csv. Make sure to use the -Append flag so that you're able to add data to the end of your file from each new computer, otherwise you'll overwrite the file everytime.

    $info  | select 'asset tag', serial,  'host name',status, username, cpu, gpu,  'os name',  'system manufacturer',  'system model',  'bios version',  'total physical memory',  'network card(s)'  |  Export-Csv  $outfile  -notypeinformation -Append
