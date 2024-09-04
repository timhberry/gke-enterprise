# Create the cluster

gcloud container aws clusters create aws-cluster \
  --cluster-version 1.26.2-gke.1001 \
  --aws-region us-east-1 \
  --location us-east4 \
  --fleet-project $PROJECT_ID \
  --vpc-id $VPC_ID \
  --subnet-ids $PRIVATE_SUBNET_ID_1,$PRIVATE_SUBNET_ID_2,$PRIVATE_SUBNET_ID_3 \
  --pod-address-cidr-blocks 10.2.0.0/16 \
  --service-address-cidr-blocks 10.1.0.0/16 \
  --role-arn $API_ROLE_ARN \
  --iam-instance-profile $CONTROL_PLANE_PROFILE \
  --database-encryption-kms-key-arn $KMS_KEY_ARN \
  --config-encryption-kms-key-arn $KMS_KEY_ARN \
  --tags google:gkemulticloud:cluster=aws-cluster

# Create a node pool

gcloud container aws node-pools create pool-0 \
  --location us-east4 \
  --cluster aws-cluster \
  --node-version 1.26.2-gke.1001 \
  --min-nodes 1 \
  --max-nodes 5 \
  --max-pods-per-node 110 \
  --root-volume-size 50 \
  --subnet-id $PRIVATE_SUBNET_ID_1 \
  --iam-instance-profile $NODE_POOL_PROFILE \
  --config-encryption-kms-key-arn $KMS_KEY_ARN \
  --ssh-ec2-key-pair gke-key \
  --tags google:gkemulticloud:cluster=aws-cluster
