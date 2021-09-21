# vault-manager

## Description

Scripts permettant l'automatisation du processus de création d'un namespace au sein d'une instance vault.
le script "create_service_namespace.sh" permet de créer:
- un namespace et les policies associés
- un approle et les policies associés par composant paas
- un rolename en read-only et un rolename en read-write par composant paas et par environnement (hp, prod)

La liste des composants paas est définie dans le fichier components.json:
```json
{
    "components": ["bddmanager","kafka","nexus"]
}
```

il permet aussi d'activer l'authentification oidc via keycloak et d'y créer les rôles admin, hp-ro, hp-rw, production-ro, production-rw

## Pré-requis

- Le binaire du client vault doit avoir été installé sur la VM
- Le secretId et roleId d'un compte administrateur


## Utilisation

### Création du namespace

- Se déplacer dans le dossier vault-manager
- Créez le fichier de configuration oidc.properties dans le dossier /images/hashicorpvault-manager 
```
keycloak.ca=***********
keycloak.api.user=vaultuser
keycloak.api.pwd=************
keycloak.realm=erable
keycloak.url=<url de keycloak>
keycloak.client.id=vault
keycloak.client.uuid=****************************************
keycloak.client.secretid=************************************
vault.url=<url de vault>
vault.rootnamespace.name=ERABLE
vault.rootnamespace.roleid=**************************************
vault.rootnamespace.secretid=************************************
```
- Executer le script: ./create_service_namespace.sh --namespace=<TEAM>

```
[osadmin@dverbrun01 hashicorpvault-manager]$ ./create_service_namespace.sh --namespace=testapp6
---------------------------------
 ERABLE
---------------------------------
get erable_adm policy
[1]- create namespace ERABLE/PAAS-testapp6
Key     Value
---     -----
id      oUvSd
path    ERABLE/PAAS-testapp6/
[2]- update erable_adm policy
Success! Uploaded policy: erable_adm
[3]- Create a global policy for bddmanager
Success! Uploaded policy: policy-bddmanager
[3]- Create a global policy for kafka
Success! Uploaded policy: policy-kafka
[3]- Create a global policy for nexus
Success! Uploaded policy: policy-nexus
-------------------------------------
 ERABLE/PAAS-testapp6
-------------------------------------
[6]- Activate approle for ERABLE/PAAS-testapp6
Success! Enabled approle auth method at: approle/
[7]- Create admin policy for ERABLE/PAAS-testapp6
Success! Uploaded policy: admin-testapp6
-------------------------------------
 ERABLE/PAAS-testapp6, hp  
-------------------------------------
[8]- Create a secret engine kv-v2 in path hp-bddmanager
Success! Enabled the kv-v2 secrets engine at: hp-bddmanager/
[8]- Create a secret engine kv-v2 in path hp-kafka
Success! Enabled the kv-v2 secrets engine at: hp-kafka/
[8]- Create a secret engine kv-v2 in path hp-nexus
Success! Enabled the kv-v2 secrets engine at: hp-nexus/
[9]- Create a read data policy for ERABLE/PAAS-testapp6
Success! Uploaded policy: hp-ro-testapp6
[10]- Create a write data policy for ERABLE/PAAS-testapp6
Success! Uploaded policy: hp-rw-testapp6
-------------------------------------
 ERABLE/PAAS-testapp6, production  
-------------------------------------
[8]- Create a secret engine kv-v2 in path production-bddmanager
Success! Enabled the kv-v2 secrets engine at: production-bddmanager/
[8]- Create a secret engine kv-v2 in path production-kafka
Success! Enabled the kv-v2 secrets engine at: production-kafka/
[8]- Create a secret engine kv-v2 in path production-nexus
Success! Enabled the kv-v2 secrets engine at: production-nexus/
[9]- Create a read data policy for ERABLE/PAAS-testapp6
Success! Uploaded policy: production-ro-testapp6
[10]- Create a write data policy for ERABLE/PAAS-testapp6
Success! Uploaded policy: production-rw-testapp6
-------------------------------------
 Enable ERABLE/PAAS-testapp6 oidc 
-------------------------------------
Activate oidc for ERABLE/PAAS-testapp6
Success! Enabled oidc auth method at: oidc/
Success! oidc for ERABLE/PAAS-testapp6 enabled !
-----------------------------------------
 Create main role ERABLE/PAAS-testapp6 
-----------------------------------------
No value found at auth/oidc/role/
create oidc role testapp6 for ERABLE/PAAS-testapp6
Success! .data.oidc/.accessor retrieved and inserted in /tmp/accessor.txt
---------------------------------
 Create alias group admin-testapp6   
---------------------------------
Success! identity group has been created
Success! identity group alias has been created
---------------------------------
 Create alias group hp-ro-testapp6 
---------------------------------
Success! identity group has been created
Success! identity group alias has been created
---------------------------------
 Create alias group hp-rw-testapp6 
---------------------------------
Success! identity group has been created
Success! identity group alias has been created
---------------------------------
 Create alias group production-ro-testapp6 
---------------------------------
Success! identity group has been created
Success! identity group alias has been created
---------------------------------
 Create alias group production-rw-testapp6 
---------------------------------
Success! identity group has been created
Success! identity group alias has been created
---------------------------------
 Configure oidc auth for ERABLE/PAAS-testapp6 
---------------------------------
config oidc auth for ERABLE/PAAS-testapp6
Success! oidc auth has been configured
add admin-testapp6 role in keycloak
add production-rw-testapp6 role in keycloak
add production-ro-testapp6 role in keycloak
add hp-rw-testapp6 role in keycloak
add hp-ro-testapp6 role in keycloak
