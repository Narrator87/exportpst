<#
    .SYNOPSIS
    ExportPST
    Version: 0.01 30.12.2015
    
    © Anton Kosenko mail:Anton.Kosenko@gmail.com
    Licensed under the Apache License, Version 2.0

    .DESCRIPTION
    This script create archive users mailboxes to pst file, disable mailboxes, delete users accounts from MS AD.
#>

# requires -version 3

# Declare Variable
$LogFile = "path to file"
$ExchangeServer = "connectionuri"
$SmtpServer = "IP or Domain name"
$UsersList = "path to file"
$ArchiveFolder = "path to folder"

# Start writing log
    Start-Transcript -path $LogFile -append
# Add modules AD and Exchange
    Import-Module ActiveDirectory
    $Session = New-PSSession -ConfigurationName Microsoft.Exchange -ConnectionUri $ExchangeServer
    Import-PSSession $Session -AllowClobber | out-null
# Clear list of current requests in status "Completed"
    Get-MailboxExportRequest -Status Completed | Remove-MailboxExportRequest -Confirm:$False
# Start Export. Read user from csv file and create new export requests
    $UserInformation = Import-Csv $UsersList
    Foreach ($UserLogin in $UserInformation)
        {
            if (($null -eq $UserLogin) -or ($UserLogin -eq "")) { continue }
        New-MailboxExportRequest -Mailbox $UserLogin.LoginName -batchname $($UserLogin.LoginName) -FilePath "$ArchiveFolder\$($UserLogin.LoginName).pst"
        }	
# Wait execution all requests
    do
        {
            write-host -foregroundcolor black -backgroundcolor white  "Wait 60 sec. MoveRequests not completed"
            $AllMoveRequests = Get-MailboxExportRequest
                Foreach ($CurrentExportRequest in $AllMoveRequests)
                {
                    Get-MailboxExportRequestStatistics -identity $CurrentExportRequest.RequestGuid -IncludeReport | Format-List BatchName, PercentComplete | out-string
                }
                write-host "Waiting 60 sec"
                Start-Sleep -seconds 60
                $MoveReq = Get-MailboxExportRequest  | Where-Object {$_.Status -ne "Completed" -and $_.Status -ne "Failed"}
                $requests = ($MoveReq | group-object status).count
        }
    Until (($requests -eq 0) -or ($null -eq $requests)) 
# Disable user mailbox and delete Exchange-properties from user account in MS AD
    $UserInformation = Import-Csv $UsersList
    Foreach ($UserLogin in $UserInformation)
        {  
            if (($null -eq $UserLogin) -or ($UserLogin -eq "")) { continue }
        $CompletedExport = Get-MailboxExportRequest -batchname $($UserLogin.LoginName)
            if ($CompletedExport.Status -ne "Completed") { continue }
        Disable-Mailbox -Identity $($UserLogin.LoginName) -Confirm:$False
        }
# Output info about failed request and clear exports query
    $FailedExportRequest = Get-MailboxExportRequest -Status Failed
    if ($null -eq $FailedExportRequest)
            {
            Foreach ($Request in $FailedExportReques)
            {
            write-host -foregroundcolor black -backgroundcolor white "Export mailbox" $FailedExportReques.BatchName "is not ready"
            }
        }
# Wait replication on MS AD
    write-host "Waiting 60 sec"
    Start-Sleep -seconds 60
# Delete users accounts from MS AD
    $UserInformation = Import-Csv $UsersList
        Foreach ($UserLogin in $UserInformation)
            {  
                if (($null -eq $UserLogin) -or ($UserLogin -eq "")) { continue }
            $CompletedExport=Get-MailboxExportRequest -batchname $($UserLogin.LoginName)
                if ($CompletedExport.Status -ne "Completed") { continue }
                if (Get-ADObject -Filter {ObjectClass -ne "user"} -SearchBase (Get-ADUser $($UserLogin.LoginName)).DistinguishedName) { Remove-ADObject -Identity $($UserLogin.LoginName).DistinguishedName -recursive -Confirm:$False} {continue}
        Remove-aduser -Identity $($UserLogin.LoginName) -Confirm:$False
            }
    Remove-PSSession $session
# Send mail to admin mailbox
    $Message = $AllMoveRequests | Format-List Mailbox | out-string
    $MailTOUser = [Environment]::UserName
    $MailTOUserEmail = get-aduser -identity $MailTOUser -properties mail | Select-Object mail
    $msg = new-object Net.Mail.MailMessage
    $smtp = new-object Net.Mail.SmtpClient($smtpServer)
    $msg.From = "ScriptUser"
    $msg.To.Add($MailTOUserEmail.mail)
    $TodayIS = Get-Date -format "d.M.yyyy HH:mm"
    $msg.Subject = "ScriptUser job at - $TodayIS by $MailTOUser" 
    $msg.Body = $Message
    $smtp.Send($msg)
    Stop-Transcript
    write-host -foregroundcolor black -backgroundcolor white "####################################################"
    write-host -foregroundcolor black -backgroundcolor white "                  Export complete"
    write-host -foregroundcolor black -backgroundcolor white "####################################################"