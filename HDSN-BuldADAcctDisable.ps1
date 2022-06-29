#Check for prerequisites
#Write-host "Testing if RSAT is installed"
$RSAT = if(get-module -list activedirectory){'RSAT found'}
if(-not ($rsat -eq 'RSAT found')){
    read-host 'Rsat is not installed, please enable it and try again'
    exit
    } else {
    'RSAT is installed. Continuing..'
    }


$DomainController = ' ' #YOURDOMAINCONTROLLER DC computer name
$DomainName = ' ' #YOURDOMAINNAME ex. contoso.local
$DisableUsersOU = ' ' #The full Distinguished Name of where you want disabled users to be moved to. ex.'OU=Disabled Accounts,DC=YOURDOMAIN,DC=local' You can find this by running- get-adorganizationalunit -filter 'name -like "THE OU YOU ARE USING" '
$PathtoCSV = '.\ToBeTerminated.csv' #THE PATH TO WHERE THE CSV IS. 

#import CSV and assign it to a variable.
$TermCSV = Import-CSV -Path $pathtocsv


#Connect to the Local DC withthe users local AD admin creds     
$AdminUser = Read-Host "What is your Admin username?"
Invoke-Command -computername $DomainController -credential $DomainName\$adminuser -ArgumentList $TermCSV, $DisableUsersOU -ScriptBlock {

# Collect initials of individual running report and create the new description
$Initials = (Read-Host "Please enter your initials: ").ToUpper()
$DescriptionStamp = "Term $(Get-Date -UFormat %Y%m%d) $Initials"

Write-Host "The Description Stamp will say $DescriptionStamp"

# Import CSV, make sure This CSV has been updated and the path below is correct
#re-assign the termcsv to a variable on the remote machine.
$remoteterm = $using:termcsv

$MatchedUsers = @()
$PrevDisabledUsers = @()
$NotMatchedUsers = @()

foreach ($User in $remoteterm) {

    $FirstName = $($User.Name).Split(' ')[0]
    $LastName = $($User.Name).Split(' ')[1]


    if (Get-ADUser -Filter {(GivenName -eq $FirstName) -and (Surname -eq $LastName) -and (Enabled -eq 'True')}){
        # Write-Host "$FirstName $LastName will be disabled" -ForegroundColor Green
        $MatchedUsers += Get-ADUser -Filter {(GivenName -eq $FirstName) -and (Surname -eq $LastName) -and (Enabled -eq 'True')}

    }elseif(Get-ADUser -Filter {(GivenName -eq $FirstName) -and (Surname -eq $LastName) -and (Enabled -eq 'False')}){
        # Write-Host "$FirstName $LastName has already been disabled." -ForegroundColor Yellow
        $PrevDisabledUsers += Get-ADUser -Filter {(GivenName -eq $FirstName) -and (Surname -eq $LastName) -and (Enabled -eq 'False')}

    }else{
        # Write-Host "No Match found for $FirstName $LastName" -ForegroundColor Red
        $NotMatchedUsers += "$FirstName $LastName"
    }
        
}
Write-Host "`nThe following Users could not be matched with an AD Account:" -ForegroundColor Red
$NotMatchedUsers | ForEach-Object {Write-Host $_ -ForegroundColor Red}

Write-Host "`nThe following users have been matched with an account that is already disabled:" -ForegroundColor Yellow
$PrevDisabledUsers | ForEach-Object {Write-Host $_.Name -ForegroundColor Yellow}

Write-Host "`nThe following users are active and will be disabled should you accept:" -ForegroundColor Green
$MatchedUsers | ForEach-Object {Write-Host $_.Name -ForegroundColor Green}

$UserAgrees = Read-Host "Would you like to consent to disabling these users? (y/n) WARNING: THIS CANNOT BE REVERSED VIA SCRIPT!"

if ($UserAgrees -eq 'y'){
    $MatchedUsers | ForEach-Object {
        foreach ($group in (Get-ADUser $_ -Properties MemberOf).MemberOf){
            Remove-ADGroupMember -Identity $group -Members $_ -Confirm:$False
        }
        Set-ADUser -Identity $_ -Description $DescriptionStamp -Enabled $False
        Move-ADObject -Identity $_ -TargetPath $using:disableUsersOU
        
        write-host "user account $($_.name) disabled and moved" -ForegroundColor black -BackgroundColor green
    }
}
}

Pause
