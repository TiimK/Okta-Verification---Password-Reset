$baseURL = ""
$token = ""
$headers = @{"Authorization" = "SSWS $token"; "Accept" = "application/json"; "Content-Type" = "application/json"}

function GetOktaID{
    #Perform Okta User Lookup
    $api = "/api/v1/users/"
    $uri = $baseURL + $api + $confirmedemail
    $IDGET = Invoke-RestMethod -Uri $uri -Method GET -Headers $headers
    #Save Okta ID to scriptwide variable
    $script:OktaUserID = $IDGET.id
    VerifyMethods
}
function VerifyMethods{
    #Perform Okta User MFA Lookup
    $api = "/api/v1/users/$OktaUserID/factors"
    $uri = $baseURL + $api
    $AuthGET = Invoke-RestMethod -Uri $uri -Method GET -Headers $headers
    #Forceful way to get MFA methods
    $AuthGET | Where-Object factorType -eq 'sms' | Select-Object -ExpandProperty id -OutVariable smstrue | Out-Null
    $AuthGET | Where-Object factorType -eq 'push' | Select-Object -ExpandProperty id -OutVariable pushtrue | Out-Null
    #$AuthGET | Where-Object factorType -eq 'token:software:totp' | Select-Object -ExpandProperty id -OutVariable tokentrue | Out-Null
    #Forceful if statement to save what MFA is available
    if($smstrue){$availableauth += "--Option 1 SMS--"}
    if($pushtrue){$availableauth += "--Option 2 Push--"}
    #if($tokentrue){$availableauth += "--Okta Token--"}
    #Write to host which MFA is available and request answer
    Write-Host "Available Authentication Methods"
    Write-Host $availableauth
    $AuthInput = Read-Host "Pick an Authentication Method. Only enter the Option Number"
    while("1","2","3" -notcontains $AuthInput)
    {
        $AuthInput = Read-Host "You did not enter a valid answer. Please enter an MFA Option Number"
    }
    switch($AuthInput){
        1{$AuthGet | Where-Object factorType -eq 'sms' | Select-Object -ExpandProperty id -outvariable script:AuthID | SendVerifySMS}
        2{$AuthGet | Where-Object factorType -eq 'push' | Select-Object -ExpandProperty id -outvariable script:AuthID | SendPush}
        3{$AuthGet | Where-Object factorType -eq 'token:software:totp' | Select-Object -ExpandProperty id -outvariable script:AuthID}
    }
}
function SendVerifySMS{
    $api = "/api/v1/users/$OktaUserID/factors/$AuthID/verify"
    $uri = $baseURL + $api
    try{
        Invoke-RestMethod -Uri $uri -Method POST -Headers $headers
    }
    catch 
    {
        switch ($_.Exception.Response.StatusCode.Value__)
    {
        200 {
            Write-Host "Success"
            }
        403 {
            Write-Host "Incorrect Code"
            }
        404 { 
            Write-Host "404 Not Found"
            }
        429 {
            #If 429(rate limit) sleep for 30 seconds and resend code
            Write-Host "Too Many Requests. Trying to send code again in 30 seconds. Ctrl + C to exit script"
            Start-Sleep -Seconds 30
            SendVerifySMS
            }
    }
}
    VerifySMS
}
function VerifySMS{
    $api = "/api/v1/users/$OktaUserID/factors/$AuthID/verify"
    $uri = $baseURL + $api
    $typecode = Read-Host "Enter Code"
    $code = @{"passCode" = "$typecode"}
    $json = $code | ConvertTo-Json;
    try{
        $VerifySMSRequest = Invoke-RestMethod -Uri $uri -Method POST -Headers $headers -body $json
    }
    catch 
    {
        switch ($_.Exception.Response.StatusCode.Value__)
    {
        200 {
            Write-Host "Success"
            }
        403 {
            Write-Host "Incorrect Code. Please retry."
            VerifySMS
            }
        404 { 
            Write-Host "404 Not Found"
            }
        429 {
            Write-Host "Too Many Requests. Restarting Script"
            GetOktaID
            }
    }
}
if ($VerifySMSRequest) {
    Write-Host "Success"
    Import-Module $PSScriptRoot\ADReset.psm1
    }
}
function SendPush{
    $api = "/api/v1/users/$OktaUserID/factors/$AuthID/verify"
    $uri = $baseURL + $api
    $PushSend = Invoke-RestMethod -Uri $uri -Method POST -Headers $headers
    $script:PushPoll = $PushSend._links.poll.href
    $script:PushReturn = Invoke-RestMethod -Uri $script:PushPoll -Method GET -Headers $headers
    $script:PushReturn = $Pscript:ushReturn.factorResult

    $scroll = "/-\|/-\|"
    $idx = 0

    $origpos = $host.UI.RawUI.CursorPosition
    $origpos.Y += 1

    do{
        $script:PushReturn = Invoke-RestMethod -Uri $script:PushPoll -Method GET -Headers $headers
        $script:PushReturn = $script:PushReturn.factorResult
        if($script:PushReturn -eq 'WAITING'){
        $host.UI.RawUI.CursorPosition = $origpos
        Write-Host "Waiting..." $scroll[$idx] -NoNewline
        $idx++
        if ($idx -ge $scroll.Length)
            {
                $idx = 0
            }
            Start-Sleep -Seconds 1
            }
    }while($script:PushReturn -eq 'WAITING') 

    switch($script:PushReturn){
        SUCCESS {
        Write-Host "`nVerified"
        Import-Module $PSScriptRoot\ADReset.psm1
        }
        REJECTED {
        Write-Host "`nPush was Rejected"
        GetOktaID
        }
        TIMEOUT {
        Write-Host "`nPush timed out"
        GetOktaID
        }
    }
}
GetOktaID