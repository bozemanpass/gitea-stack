#!/usr/bin/env bash
# Run this script once after bringing up gitea in docker compose
# TODO: add a check to detect that gitea has not fully initialized yet (no user relation error)

if [[ -n "$STACK_SCRIPT_DEBUG" ]]; then
    set -x
fi

if [[ -f "${STACK_DEPLOYMENT_DIR}/.init_complete" ]]; then
  echo "Initialization complete (if this is wrong, remove ${STACK_DEPLOYMENT_DIR}/.init_complete and restart the stack)."
  exit 0
fi

secure_password() {
    # use openssl as the source, because it behaves similarly on both linux and macos
    # we generate extra bytes so that even if tr deletes some chars we will still have plenty
    openssl rand -base64 32 | tr -d '\/+=' | head -c 10 && echo
}

GITEA_USER=${BPI_GITEA_NEW_ADMIN_USERNAME:-"gitea_admin"}
GITEA_PASSWORD=${BPI_GITEA_SET_NEW_ADMIN_PASSWORD:-"$(secure_password)"}
GITEA_USER_EMAIL=${BPI_GITEA_SET_NEW_ADMIN_EMAIL:-${GITEA_USER}@example.com}
GITEA_NEW_ORGANIZATION=${BPI_GITEA_NEW_ORGANIZATION:-"bpi"}
GITEA_URL_PREFIX=http://gitea.local:3000
BPI_GITEA_TOKEN_NAME=stack-publication-token

if ! [[ -n "$BPI_GITEA_RUNNER_REGISTRATION_TOKEN" ]]; then
    echo "Warning: using insecure default runner registration token"
    BPI_GITEA_RUNNER_REGISTRATION_TOKEN=eMdEwIzSo87nBh0UFWZlbp308j6TNWr3WhWxQqIc
fi

# wait for db
DB_UP="false"
echo -n "Waiting for db to up..."
while [[ "$DB_UP" != "true" ]]; do
  sleep 1
  stack manage --dir ${STACK_DEPLOYMENT_DIR} logs | grep '^db[:-]' | grep 'listening on IPv4 address' >/dev/null 2>&1
  if [[ $? -eq 0 ]]; then
    echo " UP"
    DB_UP="true"
  else
    echo -n "."
  fi
done

# wait for gitea
GITEA_UP="false"
echo -n "Waiting for gitea to be up..."
while [[ "$GITEA_UP" != "true" ]]; do
  sleep 1
  stack manage --dir ${STACK_DEPLOYMENT_DIR} logs | grep '^gitea[:-]' | grep 'ORM engine initialization successful' > /dev/null 2>&1
  if [[ $? -eq 0 ]]; then
    stack manage --dir ${STACK_DEPLOYMENT_DIR} logs | grep '^gitea[:-]' | grep 'Listen: ' > /dev/null 2>&1
    if [[ $? -eq 0 ]]; then
      GITEA_UP="true"
    fi
  fi

  if [[ "$GITEA_UP" == "true" ]]; then
    echo " UP"
  else
    echo -n "."
  fi
done

EXEC_CMD="stack manage --dir ${STACK_DEPLOYMENT_DIR} exec gitea"
EXEC_CMD_DB="stack manage --dir ${STACK_DEPLOYMENT_DIR} exec db"
${EXEC_CMD} "gitea admin user list --admin" | grep -v -e '^ID' | awk '{ print $2 }' | grep ${GITEA_USER} > /dev/null
if [[ $? == 1 ]] ; then
    # Then create if it wasn't found
    ${EXEC_CMD} "gitea admin user create --admin --username ${GITEA_USER} --password ${GITEA_PASSWORD} --email ${GITEA_USER_EMAIL}"
fi

# HACK: sleep a bit because if we don't gitea will return empty responses
sleep 8
# Check if the token already exists
token_response=$(${EXEC_CMD} "curl -s '${GITEA_URL_PREFIX}/api/v1/users/${GITEA_USER}/tokens' -u '${GITEA_USER}:${GITEA_PASSWORD}' -H 'Content-Type: application/json'")
if [[ -n ${token_response} ]] ; then
    # Simple check for re-running this script. Ideally we should behave more elegantly.
    if [[ "${token_response}" == *"password is invalid"* ]]; then
        echo "Note: admin password is invalid, skipping subsqeuent steps"
        exit 0
    fi
    echo ${token_response}  | jq --exit-status -r 'to_entries[] | select(.value.name == "'${BPI_GITEA_TOKEN_NAME}'")'
    if [[ $? == 0 ]] ; then
        token_found=1
    fi
fi
if [[ ${token_found} != 1 ]] ; then
    # Create access token if not found
    # Note that we either create the token here, or we needed to be passed 
    # the token by the caller. This is because gitea won't release the token
    # plaintext post-creation.
    new_gitea_token_response=$( $EXEC_CMD "curl -s '${GITEA_URL_PREFIX}/api/v1/users/${GITEA_USER}/tokens' -u '${GITEA_USER}:${GITEA_PASSWORD}' -H  'accept: application/json' -H 'Content-Type: application/json' -d '{\"name\":\"'${BPI_GITEA_TOKEN_NAME}'\", \"scopes\": [ \"read:admin\", \"write:admin\", \"read:organization\", \"write:organization\", \"read:repository\", \"write:repository\", \"read:package\", \"write:package\" ] }'" )
    new_gitea_token=$(echo $new_gitea_token_response | jq -r '.["sha1"]')
    echo "NOTE: This is your gitea access token: ${new_gitea_token}. Keep it safe and secure, it can not be fetched again from gitea."
    echo "NOTE: To use with stack set this environment variable: export BPI_NPM_AUTH_TOKEN=${new_gitea_token}"
    BPI_GITEA_AUTH_TOKEN=${new_gitea_token}
else
    # If the token exists, then we must have been passed its value.
    # If we were not, then we fail hard here.
    if [[ -z ${BPI_GITEA_AUTH_TOKEN} ]] ; then
        echo "FATAL error: gitea auth token \"${BPI_GITEA_TOKEN_NAME}\" already exists but no BPI_GITEA_AUTH_TOKEN was provided"
        exit 1
    fi
fi
# Now that we're sure the token exists and is set in BPI_GITEA_AUTH_TOKEN,
# we can proceed with token-authenticated API requests below
# Create org
# First check if it already exists
${EXEC_CMD} "curl -s '${GITEA_URL_PREFIX}/api/v1/admin/users/${GITEA_USER}/orgs' -H 'Authorization: token ${BPI_GITEA_AUTH_TOKEN}' -H 'Content-Type: application/json' -H  'accept: application/json'" | jq --exit-status -r 'to_entries[] | select(.value.name == "'${GITEA_NEW_ORGANIZATION}'")' > /dev/null
if [[ $? != 0 ]]; then
    # If it doesn't exist, create it
    # See: https://discourse.gitea.io/t/create-remove-organization-through-api/478
    ${EXEC_CMD} "curl -s -X POST '${GITEA_URL_PREFIX}/api/v1/admin/users/${GITEA_USER}/orgs' -H 'Authorization: token ${BPI_GITEA_AUTH_TOKEN}' -H 'Content-Type: application/json' -H  'accept: application/json' -d '{\"username\": \"${GITEA_NEW_ORGANIZATION}\"}'" > /dev/null && echo "Created the organization ${GITEA_NEW_ORGANIZATION}" || echo "Error creating organization ${GITEA_NEW_ORGANIZATION}"
fi

# Seed a token for act_runner registration.
${EXEC_CMD_DB} "psql -U gitea -d gitea -c \"INSERT INTO public.action_runner_token(token, owner_id, repo_id, is_active, created, updated, deleted) VALUES('${BPI_GITEA_RUNNER_REGISTRATION_TOKEN}', 0, 0, 't', 1679000000, 1679000000, NULL);\"" >/dev/null

echo "NOTE: Gitea was configured to use host name: gitea.local, ensure that this resolves to localhost, e.g. with sudo vi /etc/hosts"
if ! [[ -n "$BPI_GITEA_SET_NEW_ADMIN_PASSWORD" ]]; then
    echo "NOTE: Gitea was configured with admin user and password: ${GITEA_USER}, ${GITEA_PASSWORD}"
    echo "NOTE: Please make a secure note of the password in order to log in as the admin user"
fi
echo "Success, gitea is properly initialized"

touch "${STACK_DEPLOYMENT_DIR}/.init_complete"
