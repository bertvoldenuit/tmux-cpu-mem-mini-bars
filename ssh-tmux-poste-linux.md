# Remplacer MobaXterm sous Linux : SSH, tmux et monitoring

Rédigée le 2026-10-18. À suivre pour reconfigurer un poste Linux (réinstallation ou nouvelle machine) afin de retrouver : sessions SSH en un mot, monitoring CPU/RAM sur une ligne, navigation et transfert de fichiers.

Les exemples utilisent le serveur `192.168.0.73` et l'utilisateur `bert` : à adapter.

---

## 0. Prérequis

Sur le poste (PC) :
```bash
sudo apt install openssh-client
```

Sur le serveur :
```bash
sudo apt install tmux openssh-server
mkdir -p ~/bin
```

---

## 1. Clé SSH et fichier de configuration (sur le PC)

```bash
ssh-keygen -t ed25519
ssh-copy-id bert@192.168.0.73
```

`~/.ssh/config` :
```
# Terminal : ouvre directement la session tmux "main"
Host cerebro-bert
    HostName 192.168.0.73
    User bert
    RequestTTY yes
    RemoteCommand tmux new -A -s main
    ServerAliveInterval 30

# Fichiers (scp, rsync, sftp, sshfs) : sans RemoteCommand
Host cerebro-bert-fichiers
    HostName 192.168.0.73
    User bert

# Deuxième utilisateur
Host cerebro-autre
    HostName 192.168.0.73
    User <deuxième_utilisateur>
```
- `ssh cerebro-bert` ouvre directement la session tmux `main` (créée si absente, rattachée sinon). Elle survit aux coupures de connexion.
- **`RemoteCommand` casse `scp`, `sftp` et `sshfs`** : utiliser le bloc `cerebro-bert-fichiers` pour les transferts.
- Ajouter `IdentityFile ~/.ssh/<clé>` dans un bloc si l'utilisateur a sa propre clé.

### Sécurité du serveur (à faire)
- [ ] Désactiver l'authentification par mot de passe SSH (`PasswordAuthentication no`, `PermitRootLogin no` dans `/etc/ssh/sshd_config`, puis `sudo systemctl restart ssh`) **après avoir testé une deuxième connexion**
- [ ] Installer `fail2ban` si le port 22 est exposé à Internet
- [ ] Vérifier `last -a`, `/var/log/auth.log`, `~/.ssh/authorized_keys` et les crontabs

---

## 2. Monitoring sur une ligne (barre d'état tmux, sur le serveur)

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

Le chemin dans `status-right` doit être **absolu** (`/home/<utilisateur>/bin/tmux-stats.sh`) : `~` et `$HOME` posent des problèmes de guillemets dans tmux.

### Vérification rapide
```bash
~/bin/tmux-stats.sh                # affiche une ligne avec des codes #[fg=...] (normal hors tmux)
tmux kill-server && tmux           # la barre doit afficher CPU/RAM en bas à droite
```

### Pièges rencontrés
| Symptôme | Cause | Solution |
|---|---|---|
| Barre sans CPU/RAM | texte vert sur la barre verte par défaut | `status-style 'bg=colour235,fg=colour250'` |
| La barre disparaît en relançant tmux | réglages faits avec `tmux set -g` (temporaires) | les mettre dans `~/.tmux.conf` |
| Barre vide, `#()` sans effet | chemin faux (`/home/bin/…` au lieu de `/home/bert/bin/…`) | chemin absolu correct |
| Config ignorée | un serveur tmux déjà lancé ne relit pas le fichier | `tmux kill-server` puis `tmux`, ou `tmux source-file ~/.tmux.conf` |
| CPU toujours faux | `top -bn1` donne la moyenne depuis le démarrage | lecture de `/proc/stat` par différence |

Pour diagnostiquer si tmux exécute bien le script, rediriger sa sortie dans des fichiers :
```bash
tmux set -g status-right '#(/home/bert/bin/tmux-stats.sh 2>/tmp/stats.err | tee /tmp/stats.out) | %H:%M'
sleep 5; cat /tmp/stats.out; cat /tmp/stats.err
```

---

## 3. Navigation et transfert de fichiers

- Gestionnaire de fichiers d'Ubuntu : `Ctrl+L`, puis `sftp://bert@192.168.0.73/home/bert`. `Ctrl+D` ajoute un signet (un par utilisateur ; clic droit pour renommer). Un double-clic ouvre le fichier dans l'éditeur local, et l'enregistrement le renvoie sur le serveur.
- En ligne de commande (utiliser le bloc sans `RemoteCommand`) :
  ```bash
  scp fichier cerebro-bert-fichiers:/chemin/
  rsync -avP dossier/ cerebro-bert-fichiers:/chemin/
  sshfs cerebro-bert-fichiers:/home/bert ~/cerebro -o reconnect,ServerAliveInterval=15   # sudo apt install sshfs
  fusermount -u ~/cerebro                                                                # démonter
  ```
- Terminal : `mc` (Midnight Commander), `yazi` ou `ranger`, `micro` comme éditeur simple.
- Édition de projets : VS Code « Remote - SSH » ou Zed.
- Sessions qui survivent aux coupures : `tmux new -A -s main` (ou `tmux attach`).
- Lanceur de bureau, au besoin : `~/.local/share/applications/cerebro-bert.desktop`
  ```
  [Desktop Entry]
  Type=Application
  Name=Cerebro (bert)
  Exec=nautilus sftp://bert@192.168.0.73/home/bert
  Icon=folder-remote
  ```

---

## 4. Liste de contrôle pour une nouvelle installation

- [ ] Installer `openssh-client` (PC) ; `tmux` et `openssh-server` (serveur)
- [ ] Générer la clé (`ssh-keygen`) et la copier (`ssh-copy-id`)
- [ ] Recréer `~/.ssh/config`
- [ ] Recréer `~/.tmux.conf` et `~/bin/tmux-stats.sh` sur le serveur (ne pas oublier `chmod +x`)
- [ ] `tmux kill-server`, puis se reconnecter : la barre CPU/RAM doit apparaître
- [ ] Ajouter les signets `sftp://` dans le gestionnaire de fichiers
- [ ] Durcir SSH sur le serveur (clés uniquement, `fail2ban`)
