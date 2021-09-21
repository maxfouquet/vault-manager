
# Setup param HIERA
KC_PASSWORD="$7"
KC_USERNAME="$6"
KC_REALM_NAME="$2"
KC_CLIENT_ID="$4"
KC_CLIENT_NAME="$3"
KC_CLIENT_SECRET="$5"
KC_URL="$1"
IFS=',' read -r -a TEAM_ROLES <<< "$8"

CURL_OPTS="-ks"

function jsonValue() {
        KEY=$1
        num=$2
        awk -F"[,:}]" '{for(i=1;i<=NF;i++){if($i~/'$KEY'\042/){print $(i+1)}}}' | tr -d '"' | sed -n ${num}p
}

function getAccessToken(){
        KC_RESPONSE=$( \
           curl $CURL_OPTS -X POST \
                        -H "Content-Type: application/x-www-form-urlencoded" \
                        -d "username=$KC_USERNAME" \
                        -d "password=$KC_PASSWORD" \
                        -d 'grant_type=password' \
                        -d "client_id=$KC_CLIENT_NAME" \
                        -d "client_secret=$KC_CLIENT_SECRET" \
                        "$KC_URL/auth/realms/$KC_REALM_NAME/protocol/openid-connect/token"
        \
        )

        echo $KC_RESPONSE | grep -i error
        if [[ $? == 0 ]]
        then
            echo "error calling POST $KC_URL/auth/realms/$KC_REALM_NAME/protocol/openid-connect/token, make sure keycloak properties in oidc.properties are correct !"
        fi
        access_token=`echo $KC_RESPONSE | jsonValue access_token`
        echo $access_token
}

function getRolesListForClient(){
        access_token=`getAccessToken`
        KC_RESPONSE=$( \
           curl $CURL_OPTS -X GET \
                        -H "Content-Type: application/json" \
                        -H "Authorization: Bearer $access_token" \
                        -H 'cache-control: no-cache' \
                        -d '{\"clientRole\": true,\"id\": \"$1\",\"name\": \"$1\"}' \
                        "$KC_URL/auth/admin/realms/$KC_REALM_NAME/clients/$KC_CLIENT_ID/roles"
        \
        )

        echo $KC_RESPONSE | grep -i error
        if [[ $? == 0 ]]
        then
            echo "error calling GET $KC_URL/auth/admin/realms/$KC_REALM_NAME/clients/$KC_CLIENT_ID/roles, make sure keycloak properties in oidc.properties are correct !"
        fi
        echo "$KC_RESPONSE"
}

function createRole(){
  roleToCreate=$1
        access_token=`getAccessToken`
        KC_RESPONSE=$( \
           curl $CURL_OPTS -X POST \
                        -H "Content-Type: application/json" \
                        -H "Authorization: Bearer $access_token" \
                        --data "{\"clientRole\": true,\"id\": \"$roleToCreate\",\"name\": \"$roleToCreate\"}" \
                        "$KC_URL/auth/admin/realms/$KC_REALM_NAME/clients/$KC_CLIENT_ID/roles"
        \
        )

        echo $KC_RESPONSE | grep -i error
        if [[ $? == 0 ]]
        then
            echo "error calling POST $KC_URL/auth/admin/realms/$KC_REALM_NAME/clients/$KC_CLIENT_ID/roles, make sure keycloak properties in oidc.properties are correct !"
        fi
        echo "$KC_RESPONSE"
}

keycloakRoleRaw=$(getRolesListForClient)
echo $keycloakRoleRaw | grep -i error > /dev/null
if [[ $? == 0 ]]
then
echo $keycloakRoleRaw
exit 1
fi

keycloakRoles=`echo $keycloakRoleRaw | jsonValue name `
IFS=',' read -r -a array <<< $(echo $keycloakRoles | sed 's/ /,/g')

for roleToCreate in "${TEAM_ROLES[@]}"
 do
  role_exists=false
  for existingRole in "${array[@]}"
  do
     if [[ "$roleToCreate" == "$existingRole" ]]; then
       role_exists=true
     fi
  done
 if [ "$role_exists" = false ] ; then
    echo "add $roleToCreate role in keycloak"
    KC_RESPONSE=$(createRole $roleToCreate)
    echo $KC_RESPONSE | grep -i error > /dev/null
    if [[ $? == 0 ]]
    then
        echo  $KC_RESPONSE
        exit 1

    fi
 fi
done