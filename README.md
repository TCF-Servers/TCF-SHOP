# TCF Shop - Bot Discord

## Fonctionnement du bot Discord

### Must-have

#### GESTION DES VOTES

##### Step 1:
Créer une instance de Player pour chaque nouvelle connexion sur le serveur.
Quand un joueur régulier se connecte, vérifier l'EOSID dans la base de donnée et patch la valeur du pseudo si celle-ci est différente de la valeur dans la base de donnée.

##### Step 2:
Quand un message est percu par le bot dans le Channel Vote-Topserveur, vérifier si le message est un vote et si oui, vérifier si le joueur a déjà 3 votes dans les 2 dernières heures et si non, ajouter un vote dans la base de donnée et déclencher une commande RCON pour lui envoyer les points. (Montant des points à définir)

##### Step 3:
Pour envoyer les points, on regarde si le joueur est connecté, si oui, on cherche la map sur laquelle il se trouve et on utilise le bon port RCON pour lui délivrer les points.
Sinon, on envoie les points depuis le port part défaut (The Island).

#### CALCULATRICE POUR LA VENTE DES DINOS

### Nice-to-have:

- Un dashboard pour voir les votes, les joueurs connectés
- Executer des commandes sur le site via le dashboard
