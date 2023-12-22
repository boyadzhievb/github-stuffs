#!/usr/bin/env bash

set -o pipefail

app_id=$1 # App ID as first argument
pem=$( cat $2 ) # file path of the private key as second argument

now=$(date +%s)
iat=$((${now} - 60)) # Issues 60 seconds in the past
exp=$((${now} + 600)) # Expires 10 minutes in the future

b64enc() { openssl base64 | tr -d '=' | tr '/+' '_-' | tr -d '\n'; }

header_json='{
    "typ":"JWT",
    "alg":"RS256"
}'
# Header encode
header=$( echo -n "${header_json}" | b64enc )

payload_json='{
    "iat":'"${iat}"',
    "exp":'"${exp}"',
    "iss":'"${app_id}"'
}'
# Payload encode
payload=$( echo -n "${payload_json}" | b64enc )

# Signature
header_payload="${header}"."${payload}"
signature=$(
    openssl dgst -sha256 -sign <(echo -n "${pem}") \
    <(echo -n "${header_payload}") | b64enc
)

# Create JWT
JWT="${header_payload}"."${signature}"
printf '%s\n' "JWT: $JWT"

curl --request GET \
--url "https://api.github.com/app" \
--header "Accept: application/vnd.github+json" \
--header "Authorization: Bearer "$JWT \
--header "X-GitHub-Api-Version: 2022-11-28"

installation_id=$(curl -s -L \
  -H "Accept: application/vnd.github+json" \
  -H "Authorization: Bearer "$JWT \
  -H "X-GitHub-Api-Version: 2022-11-28" \
  https://api.github.com/app/installations | jq  '.[].id')

printf '%s\n' "Installation ID: $installation_id"

git_token=$(curl -s -L \
  -X POST \
  -H "Accept: application/vnd.github+json" \
  -H "Authorization: Bearer "$JWT \
  -H "X-GitHub-Api-Version: 2022-11-28" \
  https://api.github.com/app/installations/$installation_id/access_tokens \
 -d '{"permissions":{"contents":"read"}}' | jq  '.token' | tr -d '"')

printf '%s\n' "git token: $git_token"

echo "Use it like: git clone https://git:$git_token@github.com/reponame.git"
