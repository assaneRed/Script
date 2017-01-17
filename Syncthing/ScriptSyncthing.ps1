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
    #Secure string version of our password
    $pwd = "01000000d08c9ddf0115d1118c7a00c04fc297eb01000000d2eb9e676ebc694d9b0aa80fcb0eb21900000000020000000000106600000001000020000000d7be393ca06462f7b471af964e62244735c108c34d4db61ce4de6eeae150ed40000000000e8000000002000020000000c53786a1685398518f93035201f752e7795776d5911c7ec649264947e5d8b360200000006bb89ab9ab860e75ad9c072c94e6d73b6f5b428c4aed7dbeeb40568c85c46cd940000000be039696446edc976138dddee311545b1c3715455113d757f81ed981c3245691d863074f6582fa4d203c6612d5972f88fc0104b114d801ae71bab82e98748f1e"
    $cred = New-Object Management.Automation.PSCredential ('nrobidel@redtechnologies.fr',($pwd | ConvertTo-SecureString))
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
