# Étape 8.B — Scripts de déploiement

## 📦 Fichiers livrés

| Fichier | Rôle |
|---------|------|
| `scripts/bootstrap-vps.ps1` | À exécuter **1 seule fois** pour préparer le VPS |
| `scripts/deploy.ps1` | À exécuter à **chaque mise à jour** |

## ⚙️ Avant de lancer

### 1. Vérifie la config dans `bootstrap-vps.ps1`

Ouvre le fichier et adapte au début si nécessaire :

```powershell
$VpsHost          = '151.80.232.214'
$VpsUser          = 'ubuntu'
$IdentityFile     = "$env:USERPROFILE\.ssh\id_ed25519_gifstudio_nopass"
$Domain           = 'gifstudio.toolspdf.net'
$RepoUrl          = 'https://github.com/jlp4keritec/gifstudio.git'
$LetsEncryptEmail = 'jlp@keritec.fr'   # ⚠️ ADAPTE avec TON email
```

⚠️ **Important** : remplace `$LetsEncryptEmail` par ton vrai email — Let's Encrypt l'utilise pour t'envoyer les alertes d'expiration de certificat.

### 2. Configure le DNS chez ton registrar

Avant de lancer le bootstrap, configure ton sous-domaine :

```
Type : A
Nom  : gifstudio.toolspdf.net  (ou juste "gifstudio" si subdomain de "toolspdf.net")
Valeur : 151.80.232.214
TTL : 3600
```

Vérifie la propagation depuis ton poste :

```cmd
nslookup gifstudio.toolspdf.net
```

Tu dois voir `151.80.232.214` dans la réponse.

⏱️ La propagation DNS prend généralement **5-30 minutes**, parfois jusqu'à 24h.

## 🚀 Première utilisation

### Étape 1 — Bootstrap (5-10 min)

```cmd
cd C:\gifstudio\scripts
powershell -ExecutionPolicy Bypass -File .\bootstrap-vps.ps1
```

Ce que le script va faire :
1. ✅ Vérifier la connexion SSH
2. ✅ Vérifier les prérequis (Docker, Docker Compose, Nginx, Git)
3. ✅ Vérifier le DNS
4. ✅ Créer `/var/www/gifstudio` + storage
5. ✅ Cloner le repo GitHub
6. ✅ Générer un `.env.production` avec **secrets aléatoires sécurisés**
7. ✅ Configurer Nginx pour `gifstudio.toolspdf.net`
8. ✅ Obtenir un certificat SSL Let's Encrypt

À la fin, le script affiche :
- 🔑 **L'email admin** : `admin@gifstudio.toolspdf.net`
- 🔑 **Le mot de passe admin temporaire** (généré aléatoirement)

⚠️ **NOTE-LES IMMÉDIATEMENT** ! Tu en auras besoin pour le premier login (et le mot de passe sera demandé au changement obligatoire à la première connexion).

### Étape 2 — Déploiement (3-5 min)

```cmd
powershell -ExecutionPolicy Bypass -File .\deploy.ps1
```

Ce que le script va faire :
1. ✅ Pull les dernières modifs du code depuis GitHub
2. ✅ Build les images Docker (api + web)
3. ✅ Lance les conteneurs
4. ✅ Vérifie que tout répond
5. ✅ Affiche les logs si erreur

## 🔄 Mises à jour ultérieures

Workflow standard pour déployer une modif :

```cmd
REM 1. Tu fais tes modifs en local et tu commit
cd C:\gifstudio
git add .
git commit -m "Ajout fonctionnalité X"
git push

REM 2. Tu deploies
cd scripts
powershell -ExecutionPolicy Bypass -File .\deploy.ps1
```

Le script `deploy.ps1` :
- Ne touche pas à `.env.production`
- Ne refait pas la config Nginx
- Ne refait pas le SSL
- Pull simplement le dernier code et redeploie les images

## 🎛️ Options avancées

### Mode DryRun (simulation sans modification)

```cmd
powershell -ExecutionPolicy Bypass -File .\bootstrap-vps.ps1 -DryRun
powershell -ExecutionPolicy Bypass -File .\deploy.ps1 -DryRun
```

Affiche **toutes les commandes** qui seraient exécutées, sans rien faire.

### Mode Force (réinitialiser)

```cmd
powershell -ExecutionPolicy Bypass -File .\bootstrap-vps.ps1 -Force
```

Force la réinitialisation : reclone le repo, regénère le `.env.production`, etc.

⚠️ **Attention** : `-Force` regénère le `.env.production` → **les credentials admin changent** !

### Mode SkipSSL (DNS pas encore prêt)

```cmd
powershell -ExecutionPolicy Bypass -File .\bootstrap-vps.ps1 -SkipSSL
```

Lance tout sauf la demande de certificat Let's Encrypt. Utile si tu veux tester avant que le DNS ne soit propagé.

Plus tard, pour ajouter le SSL :

```cmd
ssh ubuntu@151.80.232.214
sudo certbot --nginx -d gifstudio.toolspdf.net --email jlp@keritec.fr --agree-tos --no-eff-email
```

### Mode SkipBuild (juste reload sans rebuild)

```cmd
powershell -ExecutionPolicy Bypass -File .\deploy.ps1 -SkipBuild
```

Utile si tu n'as modifié que le `docker-compose.prod.yml` ou des fichiers de conf, pas le code.

### Mode Tail (suivre les logs après déploiement)

```cmd
powershell -ExecutionPolicy Bypass -File .\deploy.ps1 -Tail
```

Une fois le déploiement terminé, affiche les logs en continu (Ctrl+C pour quitter).

## 🛠️ Commandes utiles sur le VPS

### Voir les logs en temps réel

```cmd
ssh ubuntu@151.80.232.214 "cd /var/www/gifstudio && docker compose -f docker-compose.prod.yml --env-file .env.production logs -f --tail=100"
```

### Redémarrer un conteneur

```cmd
ssh ubuntu@151.80.232.214 "docker restart gifstudio-api"
```

### Voir l'état des conteneurs

```cmd
ssh ubuntu@151.80.232.214 "docker ps --filter name=gifstudio"
```

### Accéder à PostgreSQL

```cmd
ssh ubuntu@151.80.232.214 "docker exec -it gifstudio-postgres psql -U gifstudio -d gifstudio"
```

### Voir le contenu du `.env.production`

```cmd
ssh ubuntu@151.80.232.214 "cat /var/www/gifstudio/.env.production"
```

## 🆘 Troubleshooting

### Le DNS ne pointe pas encore vers le VPS
→ Lance `bootstrap-vps.ps1 -SkipSSL`, configure le DNS, attends, puis exécute la commande certbot manuelle.

### Erreur lors du build Docker
→ Vérifie l'espace disque sur le VPS : `ssh ubuntu@151.80.232.214 "df -h"`. Tu as besoin d'au moins 5 Go libres.

### "Permission denied (publickey)"
→ Vérifie que `id_ed25519_gifstudio_nopass.pub` est bien dans `~/.ssh/authorized_keys` sur le VPS.

### Les conteneurs démarrent mais HTTPS ne marche pas
→ Vérifie le certif : `ssh ubuntu@151.80.232.214 "sudo certbot certificates"`.

### Erreur "port already in use"
→ Quelqu'un d'autre utilise les ports 3002 ou 4002. Vérifie avec : `ssh ubuntu@151.80.232.214 "sudo ss -tlnp | grep -E ':(3002|4002)'"`.

### Pour tout casser et recommencer
```cmd
ssh ubuntu@151.80.232.214 "cd /var/www/gifstudio && docker compose -f docker-compose.prod.yml --env-file .env.production down -v"
ssh ubuntu@151.80.232.214 "sudo rm -rf /var/www/gifstudio"
powershell -ExecutionPolicy Bypass -File .\bootstrap-vps.ps1 -Force
powershell -ExecutionPolicy Bypass -File .\deploy.ps1
```

⚠️ Le `-v` du `down` supprime aussi le volume PostgreSQL → **toutes les données sont perdues**.

## 🎯 Workflow complet récapitulatif

```
1️⃣ Configure DNS (chez registrar) → A : gifstudio.toolspdf.net → 151.80.232.214
2️⃣ Attends 5-30 min, vérifie : nslookup gifstudio.toolspdf.net
3️⃣ Lance : bootstrap-vps.ps1
4️⃣ NOTE l'email + mot de passe admin affichés
5️⃣ Lance : deploy.ps1
6️⃣ Va sur https://gifstudio.toolspdf.net → page de login
7️⃣ Connexion avec admin@gifstudio.toolspdf.net / mot de passe noté
8️⃣ Change le mot de passe (forcé au premier login)
9️⃣ Profite ! 🎉

Pour les futures mises à jour :
- git push (en local)
- deploy.ps1 (depuis scripts/)
```
