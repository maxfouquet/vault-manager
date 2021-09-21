#!/bin/sh

vaultCli () {
   vault "$@"
   if [[ $? != 0 ]]
   then
    exit 1
   fi
}

ROOT_NAMESPACE="ERABLE"
export VAULT_ADDR=$1
ROOT_TOKEN=$2
SERVICE=$3
KEYCLOAK_URL=$4
KEYCLOAK_OIDC_CLIENT_ID=$5
KEYCLOAK_OIDC_SECRET_ID=$6

KEYCLOAK_CERT=$7

VAULT_ROLE="$SERVICE"
ADM_ROLE="admin-$SERVICE"
HP_RO_ROLE="hp-ro-$SERVICE"
HP_RW_ROLE="hp-rw-$SERVICE"
PRODUCTION_RO_ROLE="production-ro-$SERVICE"
PRODUCTION_RW_ROLE="production-rw-$SERVICE"

ADM_ROLE_POLICY="admin-$SERVICE"
HP_RO_ROLE_POLICY="hp-ro-$SERVICE"
HP_RW_ROLE_POLICY="hp-rw-$SERVICE"
PRODUCTION_RO_ROLE_POLICY="production-ro-$SERVICE"
PRODUCTION_RW_ROLE_POLICY="production-rw-$SERVICE"

NAMESPACE="PAAS-$SERVICE"

export VAULT_TOKEN=$ROOT_TOKEN
export VAULT_NAMESPACE=$ROOT_NAMESPACE/$NAMESPACE

echo "-------------------------------------"
echo " Enable $ROOT_NAMESPACE/$NAMESPACE oidc "
echo "-------------------------------------"

echo "Activate oidc for $ROOT_NAMESPACE/$NAMESPACE"
vaultCli auth list | grep "oidc" > /dev/null 2>&1
if [[ $? != 0 ]]
then
    vaultCli auth enable oidc
    echo "Success! oidc for $ROOT_NAMESPACE/$NAMESPACE enabled !"
else
    echo "oidc already enabled !"
fi

echo "-----------------------------------------"
echo " Create main role $ROOT_NAMESPACE/$NAMESPACE "
echo "-----------------------------------------"

ENCODED_NAMESPACE=$(echo "/${VAULT_NAMESPACE}" | sed "s/\//%2F/g")
vaultCli list auth/oidc/role | grep "$VAULT_ROLE" > /dev/null 2>&1
if [[ $? != 0 ]]
then
cat > /tmp/oidc_$VAULT_ROLE.json <<EOF
{
    "bound_audiences": "vault",
    "allowed_redirect_uris": [
        "$VAULT_ADDR/ui/vault/auth/oidc/oidc/callback",
        "$VAULT_ADDR/ui/vault/auth/oidc/oidc/callback?namespace=$ENCODED_NAMESPACE"
    ],
    "user_claim": "sub",
    "groups_claim": "roles",
    "bound_claims" : {
        "roles": ["$ADM_ROLE","$HP_RO_ROLE","$HP_RW_ROLE","$PRODUCTION_RO_ROLE","$PRODUCTION_RW_ROLE"]
    }
}
EOF
echo "create oidc role $VAULT_ROLE for $ROOT_NAMESPACE/$NAMESPACE"
vaultCli write auth/oidc/role/$VAULT_ROLE @/tmp/oidc_$VAULT_ROLE.json
fi

curl -s -H "X-Vault-Token: $VAULT_TOKEN" -H "X-Vault-Namespace: $VAULT_NAMESPACE" $VAULT_ADDR/v1/sys/auth | jq -r '.data."oidc/".accessor' > /tmp/accessor.txt
if [[ $? == 0 ]]
then
    echo "Success! .data."oidc/".accessor retrieved and inserted in /tmp/accessor.txt"
else
    exit 1
fi

echo "---------------------------------"
echo " Create alias group $ADM_ROLE   "
echo "---------------------------------"

cat > /tmp/$ADM_ROLE.json <<EOF
{
  "name": "$ADM_ROLE",
  "policies": ["$ADM_ROLE_POLICY"],
  "type": "external",
  "metadata": {
    "responsibility": "Manage $SERVICE Namespace"
  }
}
EOF

GROUP_ID=$(curl -s -H "X-Vault-Token: $VAULT_TOKEN" -H "X-Vault-Namespace: $VAULT_NAMESPACE" --request POST --data @/tmp/$ADM_ROLE.json $VAULT_ADDR/v1/identity/group | jq -r '.data.id')
if [[ $? == 0 ]]
then
    echo "Success! identity group has been created"
else
    exit 1
fi

cat > /tmp/${ADM_ROLE}_alias.json <<EOF
{
  "canonical_id": "$GROUP_ID",
  "mount_accessor": "$(cat /tmp/accessor.txt)",
  "name": "$ADM_ROLE"
}
EOF
curl -s -H "X-Vault-Token: $VAULT_TOKEN" -H "X-Vault-Namespace: $VAULT_NAMESPACE" --request POST -s --data @/tmp/${ADM_ROLE}_alias.json $VAULT_ADDR/v1/identity/group-alias > /dev/null
if [[ $? == 0 ]]
then
    echo "Success! identity group alias has been created"
else
    exit 1
fi

echo "---------------------------------"
echo " Create alias group $HP_RO_ROLE "
echo "---------------------------------"

cat > /tmp/$HP_RO_ROLE.json <<EOF
{
  "name": "$HP_RO_ROLE",
  "policies": ["$HP_RO_ROLE_POLICY"],
  "type": "external"
}
EOF
GROUP_ID=$(curl -s -H "X-Vault-Token: $VAULT_TOKEN" -H "X-Vault-Namespace: $VAULT_NAMESPACE" --request POST --data @/tmp/$HP_RO_ROLE.json $VAULT_ADDR/v1/identity/group | jq -r '.data.id')
if [[ $? == 0 ]]
then
    echo "Success! identity group has been created"
else
    exit 1
fi

cat > /tmp/${HP_RO_ROLE}_alias.json <<EOF
{
  "canonical_id": "$GROUP_ID",
  "mount_accessor": "$(cat /tmp/accessor.txt)",
  "name": "$HP_RO_ROLE"
}
EOF
curl -s -H "X-Vault-Token: $VAULT_TOKEN" -H "X-Vault-Namespace: $VAULT_NAMESPACE" --request POST -s --data @/tmp/${HP_RO_ROLE}_alias.json $VAULT_ADDR/v1/identity/group-alias > /dev/null
if [[ $? == 0 ]]
then
    echo "Success! identity group alias has been created"
else
    exit 1
fi

echo "---------------------------------"
echo " Create alias group $HP_RW_ROLE "
echo "---------------------------------"

cat > /tmp/$HP_RW_ROLE.json <<EOF
{
  "name": "$HP_RW_ROLE",
  "policies": ["$HP_RW_ROLE_POLICY"],
  "type": "external"
}
EOF
GROUP_ID=$(curl -s -H "X-Vault-Token: $VAULT_TOKEN" -H "X-Vault-Namespace: $VAULT_NAMESPACE" --request POST --data @/tmp/$HP_RW_ROLE.json $VAULT_ADDR/v1/identity/group | jq -r '.data.id')
if [[ $? == 0 ]]
then
    echo "Success! identity group has been created"
else
    exit 1
fi

cat > /tmp/${HP_RW_ROLE}_alias.json <<EOF
{
  "canonical_id": "$GROUP_ID",
  "mount_accessor": "$(cat /tmp/accessor.txt)",
  "name": "$HP_RW_ROLE"
}
EOF
curl -s -H "X-Vault-Token: $VAULT_TOKEN" -H "X-Vault-Namespace: $VAULT_NAMESPACE" --request POST -s --data @/tmp/${HP_RW_ROLE}_alias.json $VAULT_ADDR/v1/identity/group-alias > /dev/null
if [[ $? == 0 ]]
then
    echo "Success! identity group alias has been created"
else
    exit 1
fi

echo "---------------------------------"
echo " Create alias group $PRODUCTION_RO_ROLE "
echo "---------------------------------"

cat > /tmp/$PRODUCTION_RO_ROLE.json <<EOF
{
  "name": "$PRODUCTION_RO_ROLE",
  "policies": ["$PRODUCTION_RO_ROLE_POLICY"],
  "type": "external"
}
EOF
GROUP_ID=$(curl -s -H "X-Vault-Token: $VAULT_TOKEN" -H "X-Vault-Namespace: $VAULT_NAMESPACE" --request POST --data @/tmp/$PRODUCTION_RO_ROLE.json $VAULT_ADDR/v1/identity/group | jq -r '.data.id')
if [[ $? == 0 ]]
then
    echo "Success! identity group has been created"
else
    exit 1
fi

cat > /tmp/${PRODUCTION_RO_ROLE}_alias.json <<EOF
{
  "canonical_id": "$GROUP_ID",
  "mount_accessor": "$(cat /tmp/accessor.txt)",
  "name": "$PRODUCTION_RO_ROLE"
}
EOF
curl -s -H "X-Vault-Token: $VAULT_TOKEN" -H "X-Vault-Namespace: $VAULT_NAMESPACE" --request POST -s --data @/tmp/${PRODUCTION_RO_ROLE}_alias.json $VAULT_ADDR/v1/identity/group-alias > /dev/null
if [[ $? == 0 ]]
then
    echo "Success! identity group alias has been created"
else
    exit 1
fi

echo "---------------------------------"
echo " Create alias group $PRODUCTION_RW_ROLE "
echo "---------------------------------"

cat > /tmp/$PRODUCTION_RW_ROLE.json <<EOF
{
  "name": "$PRODUCTION_RW_ROLE",
  "policies": ["$PRODUCTION_RW_ROLE_POLICY"],
  "type": "external"
}
EOF
GROUP_ID=$(curl -s -H "X-Vault-Token: $VAULT_TOKEN" -H "X-Vault-Namespace: $VAULT_NAMESPACE" --request POST --data @/tmp/$PRODUCTION_RW_ROLE.json $VAULT_ADDR/v1/identity/group | jq -r '.data.id')
if [[ $? == 0 ]]
then
    echo "Success! identity group has been created"
else
    exit 1
fi

cat > /tmp/${PRODUCTION_RW_ROLE}_alias.json <<EOF
{
  "canonical_id": "$GROUP_ID",
  "mount_accessor": "$(cat /tmp/accessor.txt)",
  "name": "$PRODUCTION_RW_ROLE"
}
EOF
curl -s -H "X-Vault-Token: $VAULT_TOKEN" -H "X-Vault-Namespace: $VAULT_NAMESPACE" --request POST -s --data @/tmp/${PRODUCTION_RW_ROLE}_alias.json $VAULT_ADDR/v1/identity/group-alias > /dev/null
if [[ $? == 0 ]]
then
    echo "Success! identity group alias has been created"
else
    exit 1
fi

echo "---------------------------------"
echo " Configure oidc auth for $ROOT_NAMESPACE/$NAMESPACE "
echo "---------------------------------"

cat > /tmp/oidc_config.json <<EOF
{
  "oidc_discovery_url": "$KEYCLOAK_URL/auth/realms/erable",
  "oidc_discovery_ca_pem": "$KEYCLOAK_CERT",
  "oidc_client_id": "$KEYCLOAK_OIDC_CLIENT_ID",
  "oidc_client_secret": "$KEYCLOAK_OIDC_SECRET_ID",
  "default_role": "$VAULT_ROLE"
}
EOF

echo "config oidc auth for $ROOT_NAMESPACE/$NAMESPACE"
curl -s --fail --show-error  -H "X-Vault-Token: $VAULT_TOKEN" -H "X-Vault-Namespace: $VAULT_NAMESPACE" --request POST --data @/tmp/oidc_config.json  $VAULT_ADDR/v1/auth/oidc/config
if [[ $? == 0 ]]
then
    echo "Success! oidc auth has been configured"
else
    exit 1
fi