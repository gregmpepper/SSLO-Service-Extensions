#!/bin/bash
# Author: Greg Pepper
# Version: 20260910-1
# Installs the External DataGroup Blocking Advanced Blocking Pages Service Extension

if [[ -z "${BIGUSER}" ]]
then
    echo
    echo "The user:pass must be set in an environment variable. Exiting."
    echo "   export BIGUSER='admin:password'"
    echo
    exit 1
fi

## Install external-datagroup-blocking iRule
echo "..Creating the external-datagroup-blocking-rule iRule"
curl -sk "https://raw.githubusercontent.com/gregmpepper/SSLO-Service-Extensions/refs/heads/main/external-datagroup-blocking" -o external-datagroup-blocking-rule.in
data=$(python3 - <<'EOF'
import json
from pathlib import Path

print(json.dumps({
    "name": "external-datagroup-blocking-rule",
    "apiAnonymous": Path("external-datagroup-blocking-rule.in").read_text(),
}))
EOF
)
curl -sk \
-u ${BIGUSER} \
-H "Content-Type: application/json" \
-d "${data}" \
https://localhost/mgmt/tm/ltm/rule


## Upload external data group source file
echo "..Uploading the external data group source file"
if ! curl -skf \
"https://raw.githubusercontent.com/gregmpepper/SSLO-Service-Extensions/refs/heads/main/block-list.txt" \
-o block-list.txt
then
    echo "Unable to download block-list.txt. Exiting."
    exit 1
fi
if [[ ! -f "block-list.txt" ]]
then
    echo "The external data group source file block-list.txt was not found. Exiting."
    exit 1
fi

file_size=$(wc -c < block-list.txt | tr -d ' ')
if [[ "${file_size}" -eq 0 ]]
then
    echo "The external data group source file block-list.txt is empty. Exiting."
    exit 1
fi
last_byte=$((file_size - 1))
curl -sk \
-u "${BIGUSER}" \
-H "Content-Type: application/octet-stream" \
-H "Content-Range: 0-${last_byte}/${file_size}" \
--data-binary @block-list.txt \
"https://localhost/mgmt/shared/file-transfer/uploads/block-list.txt" 


## Create external data group
echo "..Creating the dg_blocklist_by_agency external data group"
curl -sk \
-u "${BIGUSER}" \
-H "Content-Type: application/json" \
-d '{"name":"dg_blocklist_by_agency","externalFileName":"/var/config/rest/downloads/block-list.txt"}' \
https://localhost/mgmt/tm/ltm/data-group/external 

## Create SSLO External DataGroup Blocking Inspection Service
echo "..Creating the SSLO external-datagroup-blocking inspection service"
curl -sk \
-u ${BIGUSER} \
-H "Content-Type: application/json" \
-d "$(curl -sk https://raw.githubusercontent.com/gregmpepper/SSLO-Service-Extensions/refs/heads/main/external-datagroup-blocking)" \
https://localhost/mgmt/shared/iapp/blocks 


## Sleep for 15 seconds to allow SSLO inspection service creation to finish
echo "..Sleeping for 15 seconds to allow SSLO inspection service creation to finish"
sleep 15


## Modify SSLO External DataGroup Blocking Isolation Service (remove tenant-restrictions iRule)
echo "..Modifying the SSLO external-datagroup-blocking service"
curl -sk \
-u ${BIGUSER} \
-H "Content-Type: application/json" \
-X PATCH \
-d '{"rules":["/Common/external-datagroup-blocking-rule"]}' \
https://localhost/mgmt/tm/ltm/virtual/ssloS_F5_External-DataGroup-Blocking-Pages.app~ssloS_F5_External-DataGroup-Blocking-Pages-t-4 -o /dev/null


echo "..Cleaning up temporary files"
rm -f external-datagroup-blocking-rule.in block-list.txt


echo "..Done"