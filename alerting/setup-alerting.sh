#!/bin/bash

# crea el topico de SNS, las 3 alarmas y el dashboard de CloudWatch
# uso: ./setup-alerting.sh <instance-id> <correo>

set -e

REGION="us-east-1"
INSTANCE_ID="$1"
ALERT_EMAIL="$2"
DIR=$(dirname "$0")

echo "Creando topico de SNS y suscribiendo el correo..."
TOPIC_ARN=$(aws sns create-topic --name todo-alertas --region "$REGION" \
  --query TopicArn --output text)
aws sns subscribe --topic-arn "$TOPIC_ARN" --protocol email \
  --notification-endpoint "$ALERT_EMAIL" --region "$REGION" > /dev/null

export REGION INSTANCE_ID TOPIC_ARN

echo "Creando alarmas..."
envsubst < "$DIR/alarms.json" | jq -c '.[]' | while read -r ALARM; do
  aws cloudwatch put-metric-alarm --region "$REGION" --cli-input-json "$ALARM"
done

echo "Creando dashboard todo-list-api..."
aws cloudwatch put-dashboard --region "$REGION" --dashboard-name todo-list-api \
  --dashboard-body "$(envsubst < "$DIR/cloudwatch-dashboard.json")" > /dev/null

echo "Listo. Confirma la suscripcion en tu correo para recibir las alarmas."
