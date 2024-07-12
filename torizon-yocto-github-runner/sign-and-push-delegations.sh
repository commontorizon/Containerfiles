#/usr/bin/env bash
set -euxo pipefail
shopt -s nullglob
for d in *.unsigned.json; do
	delegation=${d%.unsigned.json}
	uptane-sign sign-json -k "${SIGNING_PRIVKEY}" -p "${SIGNING_PUBKEY}" -i "${delegation}.unsigned.json" > "${delegation}.json"
	aws s3 cp "${delegation}.json" s3://commontorizon.dev/delegations/
	echo "Delegation ${delegation} uploaded."
done

for i in add-*.json; do
	info=${i}
        aws s3 cp "${info}" s3://commontorizon.dev/delegations/
	echo "Delegation-info ${info} uploaded."
done
