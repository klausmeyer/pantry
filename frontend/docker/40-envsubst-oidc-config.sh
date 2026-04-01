#!/bin/sh

cd /usr/share/nginx/html/

envsubst < oidc-config.js.tpl > oidc-config.js
