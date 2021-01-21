function ConfirmResetADPassword {
    Write-Host "Please Confirm password reset for $global:confirmedemail"
    $confirmpasswordreset = Read-Host "Is this the correct user? (Yes or No)"
    while("yes","no" -notcontains $confirmpasswordreset)
    {
        $confirmpasswordreset = Read-Host "You did not enter a valid answer(Yes or No). Confirm password reset for $script:confirmedemail"
    }
    switch($confirmpasswordreset)
    {
        yes{ResetADPassword};
        no{Write-Host "Going back to start" | Import-Module $PSScriptRoot\UserBase.psm1}
    }
}
function ResetADPassword {
    Write-Host "Resetting password for SAM - $global:confirmedSAM"
    $NewPassword = (Read-Host "Provide New PAssword" -AsSecureString)
    Set-ADAccountPassword -Identity $global:confirmedSAM -NewPassword $NewPassword -Reset
    PasswordResetComplete
}
function PasswordResetComplete {
    Write-Host "Password has successfully been reset!"
    $IsFinished = Read-Host "Would you like to restart the script"
    while("yes","no" -notcontains $IsFinished)
    {
        $IsFinished = Read-Host "You did not enter a valid answer(Yes or No). Would you like to restart the script"
    }
    switch($IsFinished)
    {
        no{exit};
        yes{Write-Host "Going back to start" | Import-Module $PSScriptRoot\UserBase.psm1}
    }
}
ConfirmResetADPassword