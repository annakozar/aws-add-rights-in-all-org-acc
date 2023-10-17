#!/bin/bash

# Parameter: AWS-Profilname und Username/Email
PROFILE=$1
USERNAME_OR_EMAIL=$2

POLICY_ARN="arn:aws:iam::aws:policy/job-function/AdministratorAccess"
INSTANCE_ARN=$(aws sso-admin list-instances --profile $PROFILE --query Instances[0].InstanceArn --output text)
STORE_ID=$(aws sso-admin list-instances --profile $PROFILE --query Instances[0].IdentityStoreId --output text)

# Überprüfung der Parameter
if [[ -z "$PROFILE" || -z "$USERNAME_OR_EMAIL" ]]; then
	echo "Bitte geben Sie sowohl das AWS-Profil als auch den Benutzernamen/Email an."
	exit 1
fi

# Bekannte Kontonummer des Hauptkontos
Hauptkonto_ID="ROOT_ACCOUNT_NUMBER"

# Hole die aktuelle Kontonummer für das angegebene Profil
Aktuelle_ID=$(aws sts get-caller-identity --profile $PROFILE --query Account --output text)

# Vergleiche die Kontonummern
if [[ "$Aktuelle_ID" != "$Hauptkonto_ID" ]]; then
	echo "Dieses Skript muss vom Hauptkonto aus ausgeführt werden!"
	exit 1
fi
IFS=$'\n'

USER_ID=$(aws identitystore get-user-id --identity-store-id $STORE_ID --alternate-identifier '{"UniqueAttribute":{"AttributePath":"Username","AttributeValue":"'$USERNAME_OR_EMAIL'"}}' --profile $PROFILE --query UserId --output text)

# Get list of accounts from AWS Organizations
ACCOUNTS=$(aws organizations list-accounts --output json --no-cli-pager --profile $PROFILE )

for ACCOUNT in `echo $ACCOUNTS|jq -r '.Accounts[] | select(.Status=="ACTIVE") |"\(.Id) \(.Name)"'`; do 

	ACCOUNT_ID=$(echo $ACCOUNT|cut -d" " -f-1 )
	ACCOUNT_NAME=$(echo $ACCOUNT|cut -d" " -f2- )

	echo "Processing account: $ACCOUNT_NAME ($ACCOUNT_ID)"

	aws sso-admin create-account-assignment --target-id $ACCOUNT_ID --target-type AWS_ACCOUNT --principal-id $USER_ID --principal-type USER --permission-set-arn arn:aws:sso:::permissionSet/ssoins-NUMBER--instance-arn $INSTANCE_ARN --profile $PROFILE
done

unset IFS

echo "Done!"
