#!/usr/bin/env bash

function kcadm() {
  docker compose exec -it keycloak /opt/keycloak/bin/kcadm.sh $@
}

set -e
set -x

kcadm config credentials --server http://localhost:8080 --realm master --user admin --password admin

# kcadm delete realms/test

kcadm create realms \
  -s 'realm=test' \
  -s 'enabled=true'

kcadm update realms/master \
  -s 'sslRequired=NONE'

kcadm update realms/test \
  -s 'sslRequired=NONE'

kcadm create clients \
  -r test \
  -s 'clientId=pantry' \
  -s 'redirectUris=["http://localhost:4200/*"]' \
  -s 'attributes."pkce.code.challenge.method"=S256' \
  -s 'attributes."post.logout.redirect.uris"="http://localhost:4200/*"' \
  -s 'publicClient=true'

kcadm create users \
  -r test \
  -s 'username=test' \
  -s 'email=test@example.com' \
  -s 'emailVerified=true' \
  -s 'firstName=Test' \
  -s 'lastName=Test' \
  -s 'enabled=true'

kcadm set-password -r test --username test --new-password test
