# Documentation de configuration : sécurité, Ubuntu et poste de travail

Rédigée le 2026-10-18 à partir des actions faites au fil de la session. Chaque section indique ce qui est **fait** et ce qui reste **à faire**.

---

## 1. Sécurité des comptes (piratage de la boîte mail Free)

### Diagnostic
- Trois piratages en quelques années, dont un le 16/10/2026.
- Malwarebytes « Digital Footprint » : 17 fuites de données, 13 mots de passe exposés, surtout dans des *combolists* Telegram (mai à octobre 2026), plus d'anciennes fuites (DailyMotion 2017, Deezer 2023, Fareye 2024, ColisPrive juin 2026).
- Un des mots de passe exposés est encore valide, et tous ont la même racine.
- **Cause la plus probable : réutilisation d'un schéma de mot de passe (credential stuffing)**, plus l'absence de 2FA sur la messagerie Free. Aucun infostealer n'a été trouvé sur le PC.

### Règles à retenir
- Une racine commune compromet tous les comptes qui en dérivent : changer un chiffre ne sert à rien.
- Un mot de passe **aléatoire et unique par compte**, généré par un gestionnaire (Bitwarden / 1Password).
- Mot de passe maître : phrase de 5 à 6 mots au hasard. 2FA sur le gestionnaire.
- 2FA par **application** (pas par SMS) sur la messagerie, la banque, Google/Microsoft/Apple.
- Ne jamais enregistrer les mots de passe dans le navigateur ; ne jamais rappeler un numéro reçu par SMS ou appel inconnu.

### Ordre de rotation des mots de passe (depuis le téléphone)
1. Messagerie (et la nouvelle boîte)
2. Banque, PayPal, impôts, Ameli
3. Comptes Google / Microsoft / Apple
4. Comptes pro, Amazon
5. Le reste (le gestionnaire signale les faibles/réutilisés)

Puis : déconnecter les sessions actives de chaque compte, et changer le mot de passe du PC (différent de la racine).

### À faire
- [ ] Rotation complète des mots de passe
- [ ] Migrer vers une boîte avec 2FA / clés d'accès (Proton, Gmail, Fastmail) et garder l'adresse Free en secondaire avec redirection
- [ ] Vérifier les règles de redirection et filtres de la boîte Free

---

## 2. Nettoyage du PC Windows

### Fait
- Malwarebytes (analyse des menaces + analyse approfondie) : 13 PUP en quarantaine (Conduit, BitTorrent, BundleInstaller) ; `GID.RAR` (crack de 2006, heuristique) et `i686-w64-mingw32-lto-dump.exe` (Cygwin, faux positif probable).
- Analyse **Microsoft Defender hors ligne** : 0 détection.
- Dossier `%APPDATA%\BitTorrent` supprimé.

### À faire
- [ ] Désinstaller le client BitTorrent dans Paramètres > Applications
- [ ] Supprimer `D:\BERTDOCS\GID.RAR`
- [ ] Relancer Malwarebytes avec l'option « Rechercher les rootkits » activée (Paramètres > Sécurité)

### Windows 10
- Build 19045.6456 : correctif d'octobre 2025, donc **pas d'ESU**. Le programme ESU grand public a pris fin le **13/10/2026**.
- i7-7700H (ASUS UX550) : non officiellement compatible Windows 11. Contournements possibles (Rufus, clé `AllowUpgradesWithUnsupportedTPMOrCPU`) mais non supportés, à faire en installation propre uniquement. **Choix retenu : transition vers Linux.**

---

## 3. Dual boot Ubuntu 26.04 + Windows

### Situation trouvée
Disque NVMe 953,87 Gio, ancien Ubuntu **18.04** (noyau 4.15, en fin de vie) sur `p7`, GRUB cassé.

| Partition | Type | Taille | Usage |
|---|---|---|---|
| p1 | FAT32 | 260 Mo | EFI (partagée Windows/Linux) |
| p2 | MSR | 16 Mo | réservée Microsoft |
| p3 | NTFS | 214,7 Go | Windows (OS), 176 Go utilisés |
| p5 | NTFS | 708 Go | Data, 689 Go utilisés |
| p6 | swap | 10 Go | inutilisée (aucune ligne swap dans `/etc/fstab`, swap à 0) |
| p7 | ext4 | 20 Go | Ubuntu (racine `/`) |
| p4 | NTFS | 800 Mo | Recovery Windows (WinRE) |

### Fait
- Ubuntu 26.04 LTS installé sur `p7`, avec l'EFI `p1` partagée.
- Pas de NuttX ni de données à conserver sur l'ancien Ubuntu.

### Réparation du démarrage (si GRUB casse à nouveau)
Depuis une session live Ubuntu :
```bash
R=/run/media/ubuntu/<UUID de la partition racine>
sudo mount /dev/nvme0n1p1 $R/boot/efi
for i in /dev /dev/pts /proc /sys /sys/firmware/efi/efivars /run; do sudo mount --bind $i $R$i; done
sudo chroot $R
grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=ubuntu
update-grub
exit
```
Si besoin : désactiver temporairement Secure Boot ; ajouter `nomodeset` au noyau en cas d'écran noir.

### Stratégie d'espace (à faire)
- [ ] **Supprimer la partition swap `p6`** puis déplacer/agrandir `p7` vers la gauche avec GParted (live USB, secteur branché) : `/` passe à environ 30 Go. Pas de modification de `fstab` nécessaire.
- [ ] Ajouter un swap compressé : `sudo apt install systemd-zram-generator`
- [ ] Acheter un **disque externe** (1 à 2 To) : y déplacer les gros volumes de `Data` et y faire la sauvegarde
- [ ] Réduire `Data` (`p5`) de 150 à 300 Go avec GParted (avant : démarrage rapide de Windows désactivé, `powercfg /h off`, `chkdsk /f`)
- [ ] Créer une partition **ext4 pour `/home`** dans l'espace libéré, copier `/home` dessus, la monter dans `/etc/fstab`
- [ ] Ne pas supprimer `p4` (Recovery) ni toucher à `p1` tant que Windows est utilisé

### Conseils de coexistence
- `Data` (NTFS) partagée pour les fichiers ; les projets de code restent sur ext4.
- Désactiver le démarrage rapide de Windows (sinon `Data` en lecture seule sous Linux).
- Heure : `timedatectl set-local-rtc 1` côté Linux.

### Le jour où Windows est retiré
Pas besoin de déplacer Linux. Supprimer `p3` (et `p2`, `p4`), **garder `p1` (EFI)**, créer une partition ext4 dans l'espace libéré (par exemple pour `/home` ou `/data`), puis `sudo update-grub`.

---

## 4. Remplacer MobaXterm sous Linux

### Clé SSH et fichier de configuration (sur le PC)
```bash
ssh-keygen -t ed25519
ssh-copy-id utilisateur@192.168.0.73
```

`~/.ssh/config` :
```
Host cerebro-bert
    HostName 192.168.0.73
    User bert
    RequestTTY yes
    RemoteCommand tmux new -A -s main
    ServerAliveInterval 30

Host cerebro-autre
    HostName 192.168.0.73
    User <deuxième_utilisateur>
```
Puis `ssh cerebro-bert` ouvre directement la session tmux `main`. Pour un navigateur de fichiers, retirer `RemoteCommand` ou utiliser un bloc `Host` séparé.

### Sécurité du serveur (à faire)
- [ ] Désactiver l'authentification par mot de passe SSH (`PasswordAuthentication no`, `PermitRootLogin no` dans `/etc/ssh/sshd_config`, puis `sudo systemctl restart ssh`) **après avoir testé une deuxième connexion**
- [ ] Installer `fail2ban` si le port 22 est exposé à Internet
- [ ] Vérifier `last -a`, `/var/log/auth.log`, `~/.ssh/authorized_keys` et les crontabs

### Monitoring sur une ligne (barre d'état tmux, sur le serveur)

`~/.tmux.conf` :
```
set -g status on
set -g status-interval 2
set -g status-style 'bg=colour235,fg=colour250'
set -g status-right-length 100
set -g status-right '#(/home/bert/bin/tmux-stats.sh) #[default]| %H:%M'
```

`~/bin/tmux-stats.sh` (puis `chmod +x ~/bin/tmux-stats.sh`) :
```sh
#!/bin/sh
# CPU (écart depuis le dernier appel) + RAM utilisée/totale, en mini-barres colorées
f=/tmp/.tmux-cpu-$(id -u)
read -r _ u n s i w q sq st _ < /proc/stat
total=$((u+n+s+i+w+q+sq+st)); idle=$((i+w))
if [ -f "$f" ]; then read -r pt pi < "$f"; else pt=$total; pi=$idle; fi
echo "$total $idle" > "$f"
dt=$((total-pt)); di=$((idle-pi))
if [ "$dt" -gt 0 ]; then cpu=$((100*(dt-di)/dt)); else cpu=0; fi

set -- $(LC_ALL=C awk '/MemTotal/{t=$2} /MemAvailable/{a=$2} END{printf "%d %.1f %.1f", (t-a)*100/t, (t-a)/1048576, t/1048576}' /proc/meminfo)
mem=$1; used=$2; tot=$3

bar() { n=$(($1*8/100)); k=0; o=""
  while [ $k -lt 8 ]; do
    if [ $k -lt $n ]; then o="$o█"; else o="$o░"; fi; k=$((k+1)); done
  printf "%s" "$o"; }
col() { if [ "$1" -ge 80 ]; then printf '#[fg=red]'
  elif [ "$1" -ge 50 ]; then printf '#[fg=yellow]'
  else printf '#[fg=green]'; fi; }

printf "%sCPU %s %3d%%#[default]  %sRAM %s %s/%s Go#[default]" \
  "$(col $cpu)" "$(bar $cpu)" "$cpu" "$(col $mem)" "$(bar $mem)" "$used" "$tot"
```
Couleurs : vert < 50 %, jaune de 50 à 80 %, rouge au-delà. Fonctionne aussi depuis le terminal Android.

### Pièges rencontrés
| Symptôme | Cause | Solution |
|---|---|---|
| Barre sans CPU/RAM | texte vert sur la barre verte par défaut | `status-style 'bg=colour235,fg=colour250'` |
| La barre disparaît en relançant tmux | réglages faits avec `tmux set -g` (temporaires) | les mettre dans `~/.tmux.conf` |
| Barre vide, `#()` sans effet | chemin faux (`/home/bin/…` au lieu de `/home/bert/bin/…`) | chemin absolu correct |
| Config ignorée | un serveur tmux déjà lancé ne relit pas le fichier | `tmux kill-server` puis `tmux`, ou `tmux source-file ~/.tmux.conf` |
| CPU toujours faux | `top -bn1` donne la moyenne depuis le démarrage | lecture de `/proc/stat` par différence |

### Navigation et transfert de fichiers
- Gestionnaire de fichiers d'Ubuntu : `Ctrl+L`, puis `sftp://bert@192.168.0.73/home/bert`. `Ctrl+D` ajoute un signet (un par utilisateur). Un double-clic ouvre le fichier dans l'éditeur local, et l'enregistrement le renvoie sur le serveur.
- En ligne de commande : `scp`, `rsync -avP`, `sshfs cerebro:/home/bert ~/cerebro -o reconnect,ServerAliveInterval=15` (démonter : `fusermount -u ~/cerebro`).
- Terminal : `mc` (Midnight Commander), `yazi` ou `ranger`, `micro` comme éditeur simple.
- Édition de projets : VS Code « Remote - SSH » ou Zed.
- Sessions qui survivent aux coupures : `tmux new -A -s main` (ou `tmux attach`).

---

## 5. Réseau au bureau (hub USB + carte RJ45)

- Hub USB-C avec Realtek **RTL8153 Gigabit** détecté sur le bus USB 3.0 (`lsusb`).
- Interface : `enx00e04c3d0d40`, IP `192.168.0.80`. Wi-Fi coupé (`nmcli radio wifi off`, réactivation : `nmcli radio wifi on`).
- Vérifications : `ip -br link`, `nmcli device status`, `sudo ethtool enx00e04c3d0d40 | grep -E 'Speed|Link detected'` (attendu : 1000 Mb/s), `ip route` (route filaire de métrique plus basse que le Wi-Fi).
- Mesure de débit : `iperf3 -s` sur le serveur, `iperf3 -c 192.168.0.73` sur le PC.

---

## 6. Appels indésirables (téléphone perso et pro)

- Les services de suppression de données (type Incogni) sont peu utiles en France, surtout pour la ligne pro dont le numéro est public (annuaires, Sirene, Google).
- **Bloctel** (ligne perso uniquement) ; signalement sur signal.conso.gouv.fr.
- **Filtrage** plutôt que blocage : filtre d'appels du téléphone (Google Téléphone / iOS), répondeur avec message clair (les robots ne laissent pas de message), appli d'identification (Hiya, Truecaller) sur la ligne pro.
- Ne pas décrocher puis rappeler un numéro inconnu. Se méfier du phishing par SMS et du vishing (le numéro est exposé dans les fuites, dont ColisPrive).

---

## 7. Liste de tâches restantes

- [ ] Rotation des mots de passe + gestionnaire + 2FA
- [ ] Nouvelle messagerie avec 2FA
- [ ] Désinstaller BitTorrent, supprimer `GID.RAR`, scan Malwarebytes avec rootkits
- [ ] Supprimer la swap `p6`, agrandir `p7`, ajouter zram
- [ ] Disque externe, tri de `Data`, partition `/home` séparée
- [ ] Clés SSH uniquement sur le serveur, `fail2ban`
- [ ] Désactiver le démarrage rapide de Windows
- [ ] Filtrage d'appels sur les deux téléphones
