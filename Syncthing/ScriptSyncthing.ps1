# Script to alert admins in case of issues with Syncthing's backup
# Version 1.1
# Autor: Nicolas ROBIDEL

# Ignore SSL certificate
Add-Type @"
    using System;
    using System.Net;
    using System.Net.Security;
    using System.Security.Cryptography.X509Certificates;
    public class ServerCertificateValidationCallback
    {
        public static void Ignore()
        {
            ServicePointManager.ServerCertificateValidationCallback += 
                delegate
                (
                    Object obj, 
                    X509Certificate certificate, 
                    X509Chain chain, 
                    SslPolicyErrors errors
                )
                {
                    return true;
                };
        }
    }
"@

[ServerCertificateValidationCallback]::Ignore();

#Declaration of variables
$messageMail=""

# Parameters for getConnection function (Objects with 3 properties : Server's IP, API Key and name)
$connGIT = New-Object PSObject -Property @{IP="192.168.1.32"; API = "FoQZE5DLTPDlrdRuLxjIH0kd48h808Su"; Server= "GIT"}
$connNAS = New-Object PSObject -Property @{IP="192.168.1.2"; API = "4mb4eJi3nTh-T6Zb2gvx-6qgzS-nKmd6"; Server= "NAS"}
$connOVH = New-Object PSObject -Property @{IP="37.187.25.79"; API = "QJ5w7HBjlvvdtpISyo0k760evKiGWjb2"; Server= "OVH"}
$connections = $connGIT, $connNAS, $connOVH

# Parameters for getCompletion function (Objects with 6 properties : source server's IP and API Key, destination server's ID, array of folder's ID, source server's name and destination server's name) 
$compGitNas = New-Object PSObject -Property @{IP="192.168.1.32"; API = "FoQZE5DLTPDlrdRuLxjIH0kd48h808Su"; DeviceID="YB355HA-PW5XWDP-R37EHXH-NQOYKSQ-2G5NCXS-GGGM2H2-AE5MSAP-LFI6SAU"; Folder="redmineFiles","redmineDb","gitrepositories"; serverSource= "GIT"; serverDestination= "NAS"}
$compNasOvh = New-Object PSObject -Property @{IP="192.168.1.2"; API = "4mb4eJi3nTh-T6Zb2gvx-6qgzS-nKmd6"; DeviceID="PGF4U2Z-V7AD7KP-TMUU2P5-3UVG7BH-PD3XPIS-DJ5H54I-NADG2GT-BXZG2QU"; Folder="gitrepositories","SharedDisk"; serverSource= "NAS"; serverDestination= "OVH"}
$completion = $compGitNas, $compNasOvh

# Function used to send mails, takes 2 string parameters: subject and body of the mail
function mail
{
    param($subject, $messageMail)
    $smtpServer = "ssl0.ovh.net"
    # Password encrypted from Jenkins
    $pwd = "01000000d08c9ddf0115d1118c7a00c04fc297eb0100000019d930eb8aff6c499967aabbfb4628780000000002000000000003660000c0000000100000009433563cf588ff67ee94349b014a65ba0000000004800000a000000010000000a62f89ebce463cc330e07ef0c214e03c180000005e02ca2a5f84d4d6882966655b178323bf8f8ddb24192cdd14000000d1c2c0386da20f637d6a8c8500b6411434310001"
    # Password encrypted from my computer
    #$pwd = '01000000d08c9ddf0115d1118c7a00c04fc297eb01000000d2eb9e676ebc694d9b0aa80fcb0eb2190000000002000000000010660000000100002000000043bc341dfa9cd33fe588a50d61fa39432267e7f6738a931888608991f7c10c6d000000000e8000000002000020000000c2d6c18f4df36c1df508d401c9b1d3f1306872f4018ca20a170e09a8c1caaa662000000051e861f51298250d4d3e470c3a37d6f040a512f91104444ab7e3020676752c8340000000d00d5943defd9d849032673f97b7428eeefa0037505f62002a64d17c58b7c243272a726166de7efd999d02153d2b1b2eebf3761f0c853e4a6ca35c521891fac4'
    echo $pwd
    echo $pwd | ConvertTo-SecureString
    $cred = New-Object System.Management.Automation.PsCredential 'nrobidel@redtechnologies.fr',(ConvertTo-SecureString -String $pwd)
    $from = "Syncthing <nrobidel@redtechnologies.fr>"
    $to = @("Nicolas ROBIDEL <nrobidel@redtechnologies.fr>")
    $body = "Hi,`n`n$messageMail `n`nRegards, System message."
    Send-MailMessage -smtpserver $smtpserver -from $from -to $to -subject $subject -body $body -Credential $cred -priority High
}

# Function used to execute the web requests. It is used in both getConnection and getCompletion
# Takes 2 parameters : URL and device's API Key
function webRequest
{
    param($url, $api)
    Invoke-WebRequest -Uri $url -Method Get -Headers @{"X-API-Key" = "$api"} -UseBasicParsing | Format-List "content"
}

# Function used to get a list of connections with the dates (.../rest/system/connections)
# Takes 2 parameters: Device's IP & API Key
function getConnections
{
    param ([string] $ip, [string] $api)
    $url = "http://"+$ip+":8384/rest/system/connections"
    webRequest $url $api
    
}

# Fuction used to get the state of synchronisation for a given folder on a device given in parameter. It returns a number reprensenting the % of completion (.../rest/db/completion)
# This function takes 2 parameters: Completion object and Folder's ID
function getCompletion
{
    param ($param, $folder)
    $url = "http://"+$param.IP+":8384/rest/db/completion?device="+$param.DeviceID+"&folder="+$folder
    webRequest $url $param.API
}

# Function taking an array of connection objects as parameter and uses getConnection function to test connection to different servers 
# Indicates if servers are connected (GIT & OVH must return 1 while NAS must return 2)
function testConnection
{
    param($connexion)
    $script:compteurErreursConnexions=0
    $message = ""
    foreach($element in $connexion)
    {
        $result = getConnections $element.IP $element.API | Out-String
        switch($element.IP)
        {
            #Specific case for 192.168.1.2 because it's the only server connected to 2 servers, other are only connected to 1.
            "192.168.1.2" 
            {
                switch(([regex]::Matches($result, "true" )).count)
                {
                    2 {}
                    default
                    {
                       $script:compteurErreursConnexions += 1
                       $message += " - Connection problem of Syncthing on server "+$element.Server+".`n" 
                    }
                }
            }
            default
            {
                if(([regex]::Matches($result, "true" )).count -ne 1)
                {
                    $script:compteurErreursConnexions += 1
                    $message += " - Connection problem of Syncthing on server "+$element.Server+".`n"
                }
            }
        }
    }

    if($compteurErreursConnexions -eq 0)
    {
        $script:messageMail += "No connection error encountered during the tests, everything seems OK.`n"
    }
    else
    { 
        $script:messageMail += "ERROR, $compteurErreursConnexions error(s) encountered during connection tests.`n"
    }
    $script:messageMail += $message
    }

# Function taking an array of completion objects as parameter and checks synchronisation status using the getCompletion function
function testCompletion
{
    param($completion)
    $script:compteurErreursCompletion=0
    $messageCompletion = ""
    foreach($element in $completion)
    {
        foreach($folder in $element.Folder)
        {
            $result = getCompletion $element $folder| Out-String
            if(([regex]::Matches($result,100)).count -ne 1)
            {
                $script:compteurErreursCompletion+=1
                $messageCompletion += " - Synchronisation problem of folder "+$folder+" from server "+$element.serverSource+" to server "+$element.serverDestination+".`n"
        
            }
        }    
    }
    if($compteurErreursCompletion -eq 0)
    {
        $script:messageMail += "No synchronisation error encountered during the tests, everything seems OK.`n"
    }
    else
    {
        $script:messageMail += "ERROR, $compteurErreursCompletion error(s) encountered during synchronisation tests.`n"
    }
    $script:messageMail += $messageCompletion
}

#Function executing tests and sending mail to keep the admin updated (using mail, testConnection & testCompletion functions)
function main
{
    testConnection $connections
    testCompletion $completion
    if ($compteurErreursConnexions -ne 0 -or $compteurErreursCompletion -ne 0)
    {
        mail "ERROR ! Syncthing Report" $messageMail
    }
    else
    {
        mail "OK ! Syncthing Report" $messageMail
    }
    echo $messageMail
}

main
