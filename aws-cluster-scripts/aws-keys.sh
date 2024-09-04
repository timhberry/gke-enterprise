# Create the KMS key

KMS_KEY_ARN=$(aws --region us-east-1 kms create-key \
    --description "gke-key" \
    --output json| jq -r '.KeyMetadata.Arn')

# Create the EC2 key pair

ssh-keygen -t rsa -m PEM -b 4096 -C "GKE key pair" \
      -f gke-key -N "" 1>/dev/null
aws ec2 import-key-pair --key-name gke-key \
      --public-key-material fileb://gke-key.pub
