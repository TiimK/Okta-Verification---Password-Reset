function GetUserInfo 
{
#Get email address from tech
$typeemail = Read-Host "Enter the user's email address"
#Lookup email address as UserPrincipalName aka User Logon
$UserLookup = Get-ADUser -Filter "UserPrincipalName -eq '$typeemail'" | Format-Table GivenName,Surname,SamAccountName,UserPrincipalName | Out-String
Write-Host $UserLookup
#Confirm if correct user. Force yes or no answer. If No loopback if Yes continue
$confirmuser = Read-Host "Is this the correct user? (Yes or No)"
    while("yes","no" -notcontains $confirmuser)
    {
        $confirmuser = Read-Host "You did not enter a valid answer(Yes or No). Is this the correct user?"
    }
    switch($confirmuser)
    {
        yes{SaveConfirmedInfo};
        no{GetUserInfo};
    }
}
function SaveConfirmedInfo
{
    #Save scriptwide SAM ID and confirmed Email address for later use. 
    $global:confirmedSAM = Get-ADuser -Filter "UserPrincipalName -eq '$typeemail'" | Select-Object -Expand SamAccountName
    $global:confirmedemail = Get-ADuser -Filter "UserPrincipalName -eq '$typeemail'" | Select-Object -Expand UserPrincipalName
    Import-Module $PSScriptRoot\Okta.psm1
}
GetUserInfo

