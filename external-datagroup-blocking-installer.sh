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

json_curl() {
    local response

    if ! response=$(curl "$@")
    then
        return 1
    fi

    if [[ "${DEBUG:-0}" == "1" ]]
    then
        printf '%s\n' "${response}"
    fi
}

## Create temporary Python converter
cat > "rule-converter.py" << 'EOF'
import sys

filename = sys.argv[1]

with open(filename, "r") as file:
    lines = file.readlines()

escape_chars = {
    '\\': '\\\\',
    '"': '\\"',
    '\n': '\\n',
    '\[': '\\[',
    '\]': '\\]',
    '\.': '\\.',
    '\d': '\\d',
}

one_line = "".join(lines)
for old, new in escape_chars.items():
    one_line = one_line.replace(old, new)

output_filename = filename.split(".")[0] + ".out"
with open(output_filename, "w") as f:
    f.write(one_line)
EOF


## Install external-datagroup-blocking iRule
echo "..Creating the external-datagroup-blocking-rule iRule"
curl -sk "https://raw.githubusercontent.com/gregmpepper/SSLO-Service-Extensions/refs/heads/main/external-datagroup-blocking-rule" -o external-datagroup-blocking-rule.in
python3 rule-converter.py external-datagroup-blocking-rule.in
rule=$(cat external-datagroup-blocking-rule.out)
data=$(RULE="${rule}" python3 - <<'EOF'
import json
import os

print(json.dumps({
    "name": "external-datagroup-blocking-rule",
    "apiAnonymous": os.environ["RULE"],
}))
EOF
)
json_curl -sk \
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
"https://localhost/mgmt/shared/file-transfer/uploads/block-list.txt" -o /dev/null


## Create sys file data-group object
echo "..Registering the external data group source file"
json_curl -sk \
-u "${BIGUSER}" \
-H "Content-Type: application/json" \
-d '{"name":"block-list.txt","sourcePath":"file:/var/config/rest/downloads/block-list.txt"}' \
https://localhost/mgmt/tm/sys/file/data-group


## Create external data group
echo "..Creating the dg_blocklist_by_agency external data group"
json_curl -sk \
-u "${BIGUSER}" \
-H "Content-Type: application/json" \
-d '{"name":"dg_blocklist_by_agency","externalFileName":"block-list.txt"}' \
https://localhost/mgmt/tm/ltm/data-group/external


## Create SSLO External DataGroup Blocking Inspection Service
echo "..Creating the SSLO external-datagroup-blocking inspection service"
json_curl -sk \
-u ${BIGUSER} \
-H "Content-Type: application/json" \
-d "$(curl -sk https://raw.githubusercontent.com/gregmpepper/SSLO-Service-Extensions/refs/heads/main/external-datagroup-blocking)" \
https://localhost/mgmt/shared/iapp/blocks


## Sleep for 15 seconds to allow SSLO inspection service creation to finish
echo "..Sleeping for 15 seconds to allow SSLO inspection service creation to finish"
sleep 15


## Modify SSLO External DataGroup Blocking Isolation Service (remove tenant-restrictions iRule)
echo "..Modifying the SSLO external-datagroup-blocking service"
json_curl -sk \
-u ${BIGUSER} \
-H "Content-Type: application/json" \
-X PATCH \
-d '{"rules":["/Common/external-datagroup-blocking-rule"]}' \
https://localhost/mgmt/tm/ltm/virtual/ssloS_F5_External-DataGroup-Blocking.app~ssloS_F5_External-DataGroup-Blocking-t-4


echo "..Cleaning up temporary files"
rm -f rule-converter.py external-datagroup-blocking-rule.in external-datagroup-blocking-rule.out


echo "..Done"