#!/bin/sh

zip -r deploy.zip public

if ! test  -n "$FBRS_DEPLOY_TOKEN"
then
    echo "no FBRS_DEPLOY_TOKEN env var"
    exit 1
fi

curl -H "Content-Type: application/zip" \
     -H "Authorization: Bearer $FBRS_DEPLOY_TOKEN" \
     --data-binary "@deploy.zip" \
     https://api.netlify.com/api/v1/sites/58ced026-c837-4d6b-9750-56c54bba3e19/deploys

rm deploy.zip
