#!/bin/sh

print_help () {
    echo "Illegal number of parameters"
    echo "USAGE : $0 --namespace=<1>"
    echo "<1>: namespace of the service"
    exit 1
}

vaultCli () {
   vault "$@"
   if [[ $? != 0 ]]
   then
    exit 1
   fi
}

PROPERTY_FILE=/images/hashicorpvault-manager/oidc.properties

function getProperty {
   PROP_KEY=$1
   PROP_VALUE=`cat $PROPERTY_FILE | grep "$PROP_KEY" | cut -d'=' -f2-`
   echo $PROP_VALUE
}

KEYCLOAK_CERT=$(getProperty "keycloak.ca")
if [ -z "$KEYCLOAK_CERT" ]; then
 echo "oidc.properties: ERROR keycloak.ca is empty !"
 exit 1
fi
KEYCLOAK_USER=$(getProperty "keycloak.api.user")
if [ -z "$KEYCLOAK_USER" ]; then
 echo "oidc.properties: ERROR keycloak.api.user is empty !"
 exit 1
fi
KEYCLOAK_PWD=$(getProperty "keycloak.api.pwd")
if [ -z "$KEYCLOAK_PWD" ]; then
 echo "oidc.properties: ERROR keycloak.api.pwd is empty !"
 exit 1
fi
KEYCLOAK_REALM=$(getProperty "keycloak.realm")
if [ -z "$KEYCLOAK_REALM" ]; then
 echo "oidc.properties: ERROR keycloak.realm is empty !"
 exit 1
fi
KEYCLOAK_URL=$(getProperty "keycloak.url")
if [ -z "$KEYCLOAK_URL" ]; then
 echo "oidc.properties: ERROR keycloak.url is empty !"
 exit 1
fi
KEYCLOAK_OIDC_CLIENT_ID=$(getProperty "keycloak.client.id")
if [ -z "$KEYCLOAK_OIDC_CLIENT_ID" ]; then
 echo "oidc.properties: ERROR keycloak.client.id is empty !"
 exit 1
fi
KEYCLOAK_OIDC_CLIENT_UID=$(getProperty "keycloak.client.uuid")
if [ -z "$KEYCLOAK_OIDC_CLIENT_UID" ]; then
 echo "oidc.properties: ERROR keycloak.client.uuid is empty !"
 exit 1
fi
KEYCLOAK_OIDC_SECRET_ID=$(getProperty "keycloak.client.secretid")
if [ -z "$KEYCLOAK_OIDC_SECRET_ID" ]; then
 echo "oidc.properties: ERROR keycloak.client.secretid is empty !"
 exit 1
fi
export VAULT_ADDR=$(getProperty "vault.url")
if [ -z "$VAULT_ADDR" ]; then
 echo "oidc.properties: ERROR vault.url is empty !"
 exit 1
fi
ROOT_NAMESPACE=$(getProperty "vault.rootnamespace.name")
if [ -z "$ROOT_NAMESPACE" ]; then
 echo "oidc.properties: ERROR vault.rootnamespace.name is empty !"
 exit 1
fi
ROLEID=$(getProperty "vault.rootnamespace.roleid")
if [ -z "$ROLEID" ]; then
 echo "oidc.properties: ERROR vault.rootnamespace.roleid is empty !"
 exit 1
fi
SECRETID=$(getProperty "vault.rootnamespace.secretid")
if [ -z "$SECRETID" ]; then
 echo "oidc.properties: ERROR vault.rootnamespace.secretid is empty !"
 exit 1
fi

for i in "$@"
do
case $i in
    --namespace=*)
    SERVICE="${i#*=}"
    shift # past argument=value
    ;;
    -h|--help)
    print_help
    shift # past argument=value
    ;;
    *)
    ;;
esac
done

export VAULT_NAMESPACE=$ROOT_NAMESPACE
RAW_LOGIN_DATA=$(vaultCli write auth/approle/login role_id=$ROLEID secret_id=$SECRETID -format=json)
if [[ $? != 0 ]]
then
    exit 1
fi
ROOT_TOKEN=$(echo $RAW_LOGIN_DATA | jq -r '.auth.client_token')
COMPONENTS=$(jq -r '.components[]' ./components.json)
LAST_ENVIRONMENTS=("recette" "production")
ENVIRONMENTS=("hp" "production")
ERABLE_ADMIN_POLICY="erable_adm"
NAMESPACE="PAAS-${SERVICE}"

export VAULT_TOKEN=$ROOT_TOKEN

! test -d ./tmp && mkdir ./tmp

for component in ${COMPONENTS[@]}; do
for env in ${ENVIRONMENTS[@]}; do
cat >> ./tmp/policy-adm.hlc <<EOF
path "/$env-$component/*" {
    capabilities = ["create", "read", "update", "delete", "list", "sudo"]
}
EOF
cat >> ./tmp/policy-ro-${env}.hlc <<EOF
path "/$env-$component/*" {
    capabilities = ["read", "list"]
}
EOF
cat >> ./tmp/policy-rw-${component}.hlc <<EOF
path "/$NAMESPACE/$env-$component/*" {
    capabilities = ["create", "read", "update", "delete", "list", "sudo"]
}
EOF
cat >> ./tmp/policy-rw-${env}.hlc <<EOF
path "/$env-$component/*" {
    capabilities = ["create", "read", "update", "delete", "list", "sudo"]
}
EOF
done
done

for env in ${ENVIRONMENTS[@]}; do
cat >> ./tmp/policy-ro-${env}.hlc <<EOF
path "/secrets-$env/*" {
    capabilities = ["read", "list"]
}
EOF
cat >> ./tmp/policy-rw-${env}.hlc <<EOF
path "/secrets-$env/*" {
    capabilities = ["create", "read", "update", "delete", "list", "sudo"]
}
EOF
done

echo "---------------------------------"
echo " $ROOT_NAMESPACE"
echo "---------------------------------"

echo "get $ERABLE_ADMIN_POLICY policy"
vaultCli policy read erable_adm > ./tmp/erable_adm.hlc
# remove all policy of the namespace
sed -i -e "/\"$NAMESPACE/,/}/d" ./tmp/erable_adm.hlc

# create namespace for SERVICE
echo "[1]- create namespace $ROOT_NAMESPACE/$NAMESPACE"
vault namespace lookup $NAMESPACE >/dev/null 2>&1
if [[ $? != 0 ]]
then
    vaultCli namespace create $NAMESPACE
else
    echo "namespace already exists !"
fi

cp -rf templates/erable_adm.hlc ./tmp/erable_${SERVICE}.hlc
sed -i -e "s#<ns>#${NAMESPACE}#g" ./tmp/erable_${SERVICE}.hlc
cat ./tmp/erable_adm.hlc ./tmp/erable_${SERVICE}.hlc > ./tmp/new_erable_adm.hlc

echo "[2]- update $ERABLE_ADMIN_POLICY policy"
vaultCli policy write $ERABLE_ADMIN_POLICY ./tmp/new_erable_adm.hlc

for component in ${COMPONENTS[@]}
do    
    echo "[3]- Create a global policy for ${component}"
    vaultCli policy read policy-${component} > ./tmp/policy-${component}.hlc
    sed -i -e "/$NAMESPACE/,/}/d" ./tmp/policy-${component}.hlc
    cat ./tmp/policy-rw-${component}.hlc >> ./tmp/policy-${component}.hlc
    vaultCli policy write policy-${component} ./tmp/policy-${component}.hlc

    vaultCli auth list | grep "approle-${component}" > /dev/null 2>&1
    if [[ $? != 0 ]]
    then
        echo "[4]- Activate approle for $ROOT_NAMESPACE, ${component}"
        vaultCli auth enable -path approle-${component} approle
    fi

    vaultCli list auth/approle-${component}/role | grep "${component}-rw" > /dev/null 2>&1
    if [[ $? != 0 ]]
    then
        echo "[5]- Create rolename ${component}-rw $ROOT_NAMESPACE/${NAMESPACE}"
        vaultCli write auth/approle-${component}/role/${component}-rw policies="policy-${component}" token_ttl=1h
    fi
done

export VAULT_NAMESPACE=$ROOT_NAMESPACE/${NAMESPACE}

echo "-------------------------------------"
echo " ERABLE/${NAMESPACE}"
echo "-------------------------------------"

vaultCli auth list | grep "approle" > /dev/null 2>&1
if [[ $? != 0 ]]
then
    echo "[6]- Activate approle for $ROOT_NAMESPACE/${NAMESPACE}"
    vaultCli auth enable approle
fi

echo "[7]- Create admin policy for $ROOT_NAMESPACE/${NAMESPACE}"
cp -rf ./templates/services/child_namespace_adm.hlc ./tmp/child_namespace_adm.hlc
cat ./tmp/policy-adm.hlc >> ./tmp/child_namespace_adm.hlc
vaultCli policy write admin-${SERVICE} ./tmp/child_namespace_adm.hlc

for env in ${ENVIRONMENTS[@]}
do
    vaultCli secrets list | grep "secrets-${env}" > /dev/null 2>&1
    if [[ $? != 0 ]]
    then
            echo "[8]- Create a secret engine kv-v2 in path secrets-${env}"
            vaultCli secrets enable -path=secrets-${env} kv-v2
    fi
done

for env in ${ENVIRONMENTS[@]}
do 
    echo "-------------------------------------"
    echo " ERABLE/${NAMESPACE}, ${env}  "
    echo "-------------------------------------"

    vaultCli list auth/approle/role | grep "${env}-ro-${SERVICE}" > /dev/null 2>&1
    if [[ $? != 0 ]]
    then
            echo "[6]- Create rolename ${env}-ro  $ROOT_NAMESPACE/$NAMESPACE"
            vaultCli write auth/approle/role/${env}-ro-${SERVICE} policies="${env}-ro-${SERVICE}" token_ttl=1h
    fi

    vaultCli list auth/approle/role | grep "${env}-rw-${SERVICE}" > /dev/null 2>&1
    if [[ $? != 0 ]]
    then
            echo "[7]- Create rolename ${env}-rw  $ROOT_NAMESPACE/$NAMESPACE"
            vaultCli write auth/approle/role/${env}-rw-${SERVICE} policies="${env}-rw-${SERVICE}" token_ttl=3600
    fi

    vaultCli secrets list | grep "secrets-${env}" > /dev/null 2>&1
    if [[ $? != 0 ]]
    then
            echo "[8]- Create a secret engine kv-v2 in path secrets-${env}"
            vaultCli secrets enable -path=secrets-${env} kv-v2
    fi

    for component in ${COMPONENTS[@]}
    do 
        vaultCli secrets list | grep "${env}-${component}" > /dev/null 2>&1
        if [[ $? != 0 ]]
        then
            echo "[9]- Create a secret engine kv-v2 in path ${env}-${component}"
            vaultCli secrets enable -path=${env}-${component} kv-v2
        fi
    done

    echo "[10]- Create a read data policy for $ROOT_NAMESPACE/${NAMESPACE}"
    vaultCli policy write ${env}-ro-${SERVICE} ./tmp/policy-ro-${env}.hlc
    
    echo "[11]- Create a write data policy for $ROOT_NAMESPACE/${NAMESPACE}"
    vaultCli policy write ${env}-rw-${SERVICE} ./tmp/policy-rw-${env}.hlc
done

. ./manage_oidc.sh $VAULT_ADDR $VAULT_TOKEN $SERVICE $KEYCLOAK_URL $KEYCLOAK_OIDC_CLIENT_ID $KEYCLOAK_OIDC_SECRET_ID "$KEYCLOAK_CERT"
if [[ $? != 0 ]]
then
    rm -rf ./tmp
    exit 1
fi
. ./keycloak_client.sh $KEYCLOAK_URL $KEYCLOAK_REALM $KEYCLOAK_OIDC_CLIENT_ID $KEYCLOAK_OIDC_CLIENT_UID $KEYCLOAK_OIDC_SECRET_ID $KEYCLOAK_USER $KEYCLOAK_PWD "admin-${SERVICE},production-rw-${SERVICE},production-ro-${SERVICE},hp-rw-${SERVICE},hp-ro-${SERVICE}"
if [[ $? != 0 ]]
then
    rm -rf ./tmp
    exit 1
fi
rm -rf ./tmp
