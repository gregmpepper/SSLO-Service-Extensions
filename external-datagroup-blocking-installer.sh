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
curl -sk "https://raw.githubusercontent.com/gregmpepper/SSLO-Service-Extensions/refs/heads/main/external-datagroup-blocking" -o external-datagroup-blocking-rule.in
python3 rule-converter.py external-datagroup-blocking-rule.in
rule=$(cat external-datagroup-blocking-rule.out)
data="{\"name\":\"external-datagroup-blocking-rule\",\"apiAnonymous\":\"${rule}\"}"
curl -sk \
-u ${BIGUSER} \
-H "Content-Type: application/json" \
-d "${data}" \
https://localhost/mgmt/tm/ltm/rule -o /dev/null


## Create SSLO External DataGroup Blocking Inspection Service
echo "..Creating the SSLO external-datagroup-blocking inspection service"
curl -sk \
-u ${BIGUSER} \
-H "Content-Type: application/json" \
-d "$(curl -sk https://raw.githubusercontent.com/gregmpepper/SSLO-Service-Extensions/refs/heads/main/external-datagroup-blocking)" \
https://localhost/mgmt/shared/iapp/blocks -o /dev/null


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
https://localhost/mgmt/tm/ltm/virtual/ssloS_F5_External-DataGroup-Blocking.app~ssloS_F5_External-DataGroup-Blocking-t-4 -o /dev/null


echo "..Cleaning up temporary files"
rm -f rule-converter.py external-datagroup-blocking-rule.in external-datagroup-blocking-rule.out


echo "..Done"