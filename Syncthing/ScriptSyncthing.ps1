#Script d'alerte en cas de problème de synchronisation de SyncThing
#Version 1.0
#Auteur: Nicolas ROBIDEL

#Ignore le certificat SSL
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

#Déclaration de variables
$compteurErreursConnexions=0
$compteurErreursCompletion=0
$message = ""
$messageCompletion = ""
$messageMail=""
$IPs = "192.168.1.32", "192.168.1.2", "37.187.25.79"

#Paramètres pour getCompletion (Objets à 3 propriétés : ip du serveur de d'origine, id du serveur de destination, id du folder) 
$compGitNas_redmineFiles = New-Object PSObject -Property @{IP="192.168.1.32"; DeviceID="YB355HA-PW5XWDP-R37EHXH-NQOYKSQ-2G5NCXS-GGGM2H2-AE5MSAP-LFI6SAU"; Folder="redmineFiles"}
$compGitNas_redmineDb = New-Object PSObject -Property @{IP="192.168.1.32"; DeviceID="YB355HA-PW5XWDP-R37EHXH-NQOYKSQ-2G5NCXS-GGGM2H2-AE5MSAP-LFI6SAU"; Folder="redmineDb"}
$compGitNas_gitrepo = New-Object PSObject -Property @{IP="192.168.1.32"; DeviceID="YB355HA-PW5XWDP-R37EHXH-NQOYKSQ-2G5NCXS-GGGM2H2-AE5MSAP-LFI6SAU"; Folder="gitrepositories"}
$compNasOvh_gitrepo = New-Object PSObject -Property @{IP="192.168.1.2"; DeviceID="PGF4U2Z-V7AD7KP-TMUU2P5-3UVG7BH-PD3XPIS-DJ5H54I-NADG2GT-BXZG2QU"; Folder="gitrepositories"}
$compNasOvh_sharedDisk = New-Object PSObject -Property @{IP="192.168.1.2"; DeviceID="PGF4U2Z-V7AD7KP-TMUU2P5-3UVG7BH-PD3XPIS-DJ5H54I-NADG2GT-BXZG2QU"; Folder="SharedDisk"}
$completion = $compGitNas_redmineFiles, $compGitNas_redmineDb, $compGitNas_gitrepo, $compNasOvh_gitrepo, $compNasOvh_sharedDisk

#Fonction envoi de mail prend 2 paramètres (string) le sujet du mail et le message
function mail
{
    param($subject, $messageMail)
    $smtpServer = "ssl0.ovh.net"
    $pwd = ConvertTo-SecureString "newlsa2300" -AsPlainText -Force
    $cred = New-Object Management.Automation.PSCredential ('nrobidel@redtechnologies.fr',$pwd)
    $from = "Syncthing <nrobidel@redtechnologies.fr>"
    $to = @("Nicolas ROBIDEL <nrobidel@redtechnologies.fr>","Paul LEREBOURG <plerebourg@redtechnologies.fr>")
    $body = "Bonjour,`n`n$messageMail `n`nCordialement, message systeme."
    Send-MailMessage -smtpserver $smtpserver -from $from -to $to -subject $subject -body $body -Credential $cred -priority High
}

# Fonction permettant de récupérer la liste des connections et la date des connections (.../rest/system/connections)
# Cette fonction prend un paramètre:
#     - l'ip de la machine
function getConnections
{
    param ([string]$ip)
    $pwd = ConvertTo-SecureString "lsa@2300" -AsPlainText -Force
    $cred = New-Object Management.Automation.PSCredential ('red',$pwd)
    $url = "https://"+$ip+":8384/rest/system/connections"
    Invoke-WebRequest -Uri $url -Method Get -Credential $cred -UseBasicParsing | Format-List "content"
    
}

# Fonction permettant de récupérer l'etat de synchronisation d'un dossier provenant d'un device donné en paramètre. Le retour est un nombre représentant le pourcentage compris entre 0 et 100 (.../rest/db/completion)
# Cette fonction prend trois paramètres:
#     - l'ip de la machine
#     - l'ID du device
#     - l'ID du dossier
function getCompletion
{
    param ($param)
    $pwd = ConvertTo-SecureString "lsa@2300" -AsPlainText -Force
    $cred = New-Object Management.Automation.PSCredential ('red',$pwd)
    $url = "https://"+$param.IP+":8384/rest/db/completion?device="+$param.DeviceID+"&folder="+$param.Folder
    Invoke-WebRequest -Uri $url -Method Get -Credential $cred -UseBasicParsing | Format-List "content"
}

#Prend en paramètre l'ID d'un device et retourne un string contenant le nom du device
function getdeviceNameFromId
{
    param($id)
    switch($id)
    {
        "W2Y7VJS-4BZNCSV-3E5WGJV-HKDU2PQ-LXI2YQL-M6YVQ6K-EDCFI2T-FZR2GQ6"{return "GIT"}
        "YB355HA-PW5XWDP-R37EHXH-NQOYKSQ-2G5NCXS-GGGM2H2-AE5MSAP-LFI6SAU"{return "NAS"}
        "PGF4U2Z-V7AD7KP-TMUU2P5-3UVG7BH-PD3XPIS-DJ5H54I-NADG2GT-BXZG2QU"{return "OVH"}
        default{"Aucune correspondance trouvée"}
    }
}

#Prend en paramètre l'IP d'un device et retourne un string contenant le nom du device
function getDeviceNameFromIp
{
    param($ip)
    switch($ip)
    {
        "192.168.1.32"{return "GIT"}
        "192.168.1.2"{return "NAS"}
        "37.187.25.79"{return "OVH"}
        default{"Aucune correspondance trouvée"}
    }
}

#Fonction prenant en paramètre un array d'adresses IP et utilise la fonction getConnection pour tester les connexions des éléments du tableau
#Cela indique si les serveurs sont bien connectés (GIT et OVH doivent valoir 1 et le NAS quand a lui 2)
function testConnexion
{
    param($connexion)
    foreach($element in $connexion)
    {
        $result = getConnections $element | Out-String
        $serveur = getDeviceNameFromIp $element
        switch($element)
        {
            "192.168.1.2"
            {
                switch(([regex]::Matches($result, "true" )).count)
                {
                    2 {}
                    default
                    {
                       $script:compteurErreursConnexions += 1
                       $message += " - Probleme de connexion de SyncThing sur le serveur "+$serveur+".`n" 
                    }
                }
            }
            default
            {
                if(([regex]::Matches($result, "true" )).count -ne 1)
                {
                    $script:compteurErreursConnexions += 1
                    $message += " - Probleme de connexion de SyncThing sur le serveur "+$serveur+".`n"
                }
            }
        }
    }

    if($compteurErreursConnexions -eq 0)
    {
        $script:messageMail += "Aucune erreur de connexion rencontree lors des tests, tout semble OK.`n"
    }
    else
    { 
        $script:messageMail += "ERREUR, $compteurErreursConnexions erreur(s) rencontree(s) lors des tests de connexions.`n"
    }
    $script:messageMail += $message
    }

#Fonction prenant en paramètre un array contenant des objets paramètres ("ip","device id", "folder id") et vérifie l'etat de la synchronisation
function testCompletion
{
    param($completion)
    foreach($element in $completion)
    {
        $result = getCompletion $element | Out-String
        $source = getDeviceNameFromIp $element.IP
        $destination = getDeviceNameFromId $element.DeviceID
        if(([regex]::Matches($result,100 )).count -ne 1)
        {
            $script:compteurErreursCompletion+=1
            $messageCompletion += " - Probleme de synchronisation du dossier "+$element.Folder+" du serveur "+$source+" vers le serveur "+$destination+".`n"
        
        }
    }
    if($compteurErreursCompletion -eq 0)
    {
        $script:messageMail += "Aucune erreur de synchronisation rencontree lors des tests, tout semble OK.`n"
    }
    else
    {
        $script:messageMail += "ERREUR, $compteurErreursCompletion erreur(s) rencontree(s) lors des tests de synchronisation.`n"
    }
    $script:messageMail += $messageCompletion
}

#Fonctions lançant les différents tests et envoyant le mail de rapport a l'admin en utilisant les fonctions mail, testConnexion et testCompletion
function main
{
    testConnexion $IPs
    testCompletion $completion
    if ($compteurErreursConnexions -ne 0 -or $compteurErreursCompletion -ne 0)
    {
        mail "ERREUR ! Rapport Syncthing" $messageMail
    }
    else
    {
        mail "OK ! Rapport Syncthing" $messageMail
    }
    echo $messageMail
}

main
