#!/bin/sh -l

echo "Environment:"
env

if release=$(git log --format=%B -n 1 | sed -n '/^[Rr]elease:/s/^[Rr]elease: *//p'); then
    # strip off any trailing CRs or NLs
    release=$(echo "$release" | tr -d '\r\n')
    echo "Release requested is: >$release<"
else
    echo "No release request"
    exit 0
fi

# Ensure that the GITHUB_TOKEN secret is included
if [[ -z "$GITHUB_TOKEN" ]]; then
  echo "Set the GITHUB_TOKEN env variable."
  exit 1
fi

json="{
  \"tag_name\": \"v$release\",
  \"target_commitish\": \"$GITHUB_SHA\",
  \"name\": \"Release $release\",
  \"body\": \"DAOS release $release\",
  \"draft\": false,
  \"prerelease\": false
}"

echo "Creating release $release with:"
echo "$json"

curl --request POST \
  --url https://api.github.com/repos/${GITHUB_REPOSITORY}/releases \
  --header "Authorization: Bearer $GITHUB_TOKEN" \
  --header 'Content-Type: application/json' \
  --data "$json"
