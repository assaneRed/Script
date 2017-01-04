#Script d'alerte en cas de problème de synchronisation de SyncThing
#Version 1.0
#Auteur: Nicolas ROBIDEL

cls

#Type d'éxecutioon
Set-ExecutionPolicy Unrestricted

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

#Variables nécessaires, compteur, arrays et string 
$compteurErreurs=0
$compteur=0
$devices = "W2Y7VJS-4BZNCSV-3E5WGJV-HKDU2PQ-LXI2YQL-M6YVQ6K-EDCFI2T-FZR2GQ6", "YB355HA-PW5XWDP-R37EHXH-NQOYKSQ-2G5NCXS-GGGM2H2-AE5MSAP-LFI6SAU", "PGF4U2Z-V7AD7KP-TMUU2P5-3UVG7BH-PD3XPIS-DJ5H54I-NADG2GT-BXZG2QU"
$foldersGit = "gitrepositories", "redmineFiles", "redmineDb", "SharedDisk"
$message = ""
$messageCompletion = ""

#Fonction envoi de mail
function Mail
{
    param($message)
    $smtpServer = "smtp.orange.fr"
    $from = "SyncThing <nrobidel@redtechnologies.fr>"
    $to = "Nicolas ROBIDEL <nrobidel@redtechnologies.fr>"
    $subject = "Test d'envoi de mail"
    $body = "
    <html>
      <head></head>
         <body>
            <p>Bonjour,<br /><br />
               Ceci est un test, no need to panic ! <br />
               '$message'<br />
               <br />
               Cordialement, message systeme. 
            </p>
          </body>
    </html>"

    Send-MailMessage -smtpserver $smtpserver -from $from -to $to -subject $subject -body $body -bodyasHTML -priority High
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

    Invoke-WebRequest -Uri $url -Method Get -Credential $cred | Format-List "content"
    
}

# Fonction permettant de récupérer l'etat de synchronisation d'un dossier provenant d'un device donné en paramètre. Le retour est un nombre représentant le pourcentage compris entre 0 et 100 (.../rest/db/completion)
# Cette fonction prend trois paramètres:
#     - l'ip de la machine
#     - l'ID du device
#     - l'ID du dossier
function getCompletion
{
  param ([string]$ip, [string]$deviceID, [string]$folder)
    $pwd = ConvertTo-SecureString "lsa@2300" -AsPlainText -Force
    $cred = New-Object Management.Automation.PSCredential ('red',$pwd)
    $url = "https://"+$ip+":8384/rest/db/completion?device="+$deviceID+"&folder="+$folder
    echo $ip
    Invoke-WebRequest -Uri $url -Method Get -Credential $cred | Format-List "content"
}

#Variables contenant les résultats de la fonction getConnections pour les serveurs GIT, NAS et OVH
#Out-String transforme le résultat en string
$connecGIT = getConnections "192.168.1.32" | Out-String
$connecNAS = getConnections "192.168.1.2"  | Out-String
$connecOVH = getConnections "37.187.25.79" | Out-String

#Variables contenant le résultat du test de completion

$compGitNas_redmineFiles = getCompletion "192.168.1.32" "YB355HA-PW5XWDP-R37EHXH-NQOYKSQ-2G5NCXS-GGGM2H2-AE5MSAP-LFI6SAU" "redmineFiles" | Out-String
$compGitNas_redmineDb = getCompletion "192.168.1.32" "YB355HA-PW5XWDP-R37EHXH-NQOYKSQ-2G5NCXS-GGGM2H2-AE5MSAP-LFI6SAU" "redmineDb" | Out-String
$compGitNas_gitrepo = getCompletion "192.168.1.32" "YB355HA-PW5XWDP-R37EHXH-NQOYKSQ-2G5NCXS-GGGM2H2-AE5MSAP-LFI6SAU" "gitrepositories" | Out-String
$compNasOvh_gitrepo = getCompletion "192.168.1.2" "PGF4U2Z-V7AD7KP-TMUU2P5-3UVG7BH-PD3XPIS-DJ5H54I-NADG2GT-BXZG2QU" "gitrepositories" | Out-String
$compNasOvh_sharedDisk = getCompletion "192.168.1.2" "PGF4U2Z-V7AD7KP-TMUU2P5-3UVG7BH-PD3XPIS-DJ5H54I-NADG2GT-BXZG2QU" "SharedDisk" | Out-String
$completion = $compGitNas_redmineFiles, $compGitNas_redmineDb, $compGitNas_gitrepo, $compNasOvh_gitrepo, $compNasOvh_sharedDisk

#Compte le nombre d'apparitions du mot "true" dans le résultat de getConnections et le stock dans une variable
#Cela indique si les serveurs sont bien connectés (GIT et OVH doivent valoir 1 et le NAS quand a lui 2)
$countTrueGit =([regex]::Matches($connecGIT, "true" )).count
$countTrueNas =([regex]::Matches($connecNAS, "true" )).count
$countTrueOvh =([regex]::Matches($connecOVH, "true" )).count

if($countTrueGit -ne 1 -or $countTrueNas -ne 2 -or $countTrueOvh -ne 1)
{
    echo "Une ou plusieurs erreurs de connexions rencontrés !"
    if ($countTrueGit -ne 1)
    {
        $compteurErreurs += 1
        $message += "ERREUR ! Il semblerait que le service SyncThing du serveur GIT ne soit pas connecté au serveur NAS.`n"
    }
    if ($countTrueNAS -ne 2)
    {
        if ($countTrueNAS -eq 0)
        {
            $compteurErreurs += 1
            $message += "ERREUR ! Il semblerait que le service SyncThing du serveur NAS ne soit pas connecté au serveur GIT ni au serveur OVH.`n"
        }
        else
        {
            $compteurErreurs += 1
            $message += "ERREUR ! Il semblerait que le service SyncThing du serveur NAS ne soit pas connecté au serveur GIT ou au serveur OVH.`n"
        }   
    }
    if ($countTrueGit -ne 1)
    {
        $compteurErreurs += 1
        $message += "ERREUR ! Il semblerait que le service SyncThing du serveur OVH ne soit pas connecté au serveur NAS.`n"
    }

}
else
{
    $message += "Aucune erreur détecté, tous les services semblent fonctionné normalement !`n"
}

foreach($result in $completion)
{
    if(([regex]::Matches($result, 100 )).count -ne 1)
    {
        $compteurErreurs+=1
        switch($compteur)
        {
            0 {$messageCompletion += "Il semblerait qu'il y ai eu un problème de synchronisation du dossier 'redmineDB' du serveur GIT au serveur NAS"}
            1 {$messageCompletion += "Il semblerait qu'il y ai eu un problème de synchronisation du dossier 'redmineFiles' du serveur GIT au serveur NAS"}
            2 {$messageCompletion += "Il semblerait qu'il y ai eu un problème de synchronisation du dossier 'gitrepositories' du serveur GIT au serveur NAS"}
            3 {$messageCompletion += "Il semblerait qu'il y ai eu un problème de synchronisation du dossier 'gitrepositories' du serveur NAS au serveur OVH"}
            4 {$messageCompletion += "Il semblerait qu'il y ai eu un problème de synchronisation du dossier 'SharedDisk' du serveur NAS au serveur OVH"}
        }

    }
    $compteur +=1
}

#Envoi de mail signalant le nombre d'erreurs rencontrés ainsi que plus de détails concernant les erreurs en question (si elles existent)
#Mail "Nous avons rencontrés $compteurErreurs erreurs.`n$message"

echo "Nous avons rencontrés $compteurErreurs erreurs."
echo $message