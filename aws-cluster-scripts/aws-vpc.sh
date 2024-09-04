# Create the VPC

aws --region us-east-1 ec2 create-vpc \
    --cidr-block 10.0.0.0/16 \
    --tag-specifications 'ResourceType=vpc, Tags=[{Key=Name,Value=gke-cluster-VPC}]'

# Enable DNS

VPC_ID=$(aws ec2 describe-vpcs \
  --filters 'Name=tag:Name,Values=gke-cluster-VPC' \
  --query "Vpcs[].VpcId" --output text)
aws ec2 modify-vpc-attribute --enable-dns-hostnames --vpc-id $VPC_ID
aws ec2 modify-vpc-attribute --enable-dns-support --vpc-id $VPC_ID

# Create private control plane subnets

aws ec2 create-subnet \
  --availability-zone us-east-1a \
  --vpc-id $VPC_ID \
  --cidr-block 10.0.1.0/24 \
  --tag-specifications 'ResourceType=subnet, Tags=[{Key=Name,Value=gke-cluster-PrivateSubnet1}]'
aws ec2 create-subnet \
  --availability-zone us-east-1b \
  --vpc-id $VPC_ID \
  --cidr-block 10.0.2.0/24 \
  --tag-specifications 'ResourceType=subnet, Tags=[{Key=Name,Value=gke-cluster-PrivateSubnet2}]'
aws ec2 create-subnet \
  --availability-zone us-east-1c \
  --vpc-id $VPC_ID \
  --cidr-block 10.0.3.0/24 \
  --tag-specifications 'ResourceType=subnet, Tags=[{Key=Name,Value=gke-cluster-PrivateSubnet3}]'

# Create public subnets

aws ec2 create-subnet \
  --availability-zone us-east-1a \
  --vpc-id $VPC_ID \
  --cidr-block 10.0.101.0/24 \
  --tag-specifications 'ResourceType=subnet, Tags=[{Key=Name,Value=gke-cluster-PublicSubnet1}]'
aws ec2 create-subnet \
  --availability-zone us-east-1b \
  --vpc-id $VPC_ID \
  --cidr-block 10.0.102.0/24 \
  --tag-specifications 'ResourceType=subnet, Tags=[{Key=Name,Value=gke-cluster-PublicSubnet2}]'
aws ec2 create-subnet \
  --availability-zone us-east-1c \
  --vpc-id $VPC_ID \
  --cidr-block 10.0.103.0/24 \
  --tag-specifications 'ResourceType=subnet, Tags=[{Key=Name,Value=gke-cluster-PublicSubnet3}]'

PUBLIC_SUBNET_ID_1=$(aws ec2 describe-subnets \
  --filters 'Name=tag:Name,Values=gke-cluster-PublicSubnet1' \
  --query "Subnets[].SubnetId" --output text)
PUBLIC_SUBNET_ID_2=$(aws ec2 describe-subnets \
  --filters 'Name=tag:Name,Values=gke-cluster-PublicSubnet2' \
  --query "Subnets[].SubnetId" --output text)
PUBLIC_SUBNET_ID_3=$(aws ec2 describe-subnets \
  --filters 'Name=tag:Name,Values=gke-cluster-PublicSubnet3' \
  --query "Subnets[].SubnetId" --output text)
aws ec2 modify-subnet-attribute \
  --map-public-ip-on-launch \
  --subnet-id $PUBLIC_SUBNET_ID_1
aws ec2 modify-subnet-attribute \
  --map-public-ip-on-launch \
  --subnet-id $PUBLIC_SUBNET_ID_2
aws ec2 modify-subnet-attribute \
  --map-public-ip-on-launch \
  --subnet-id $PUBLIC_SUBNET_ID_3

# Create internet gateway and attach to VPC

aws --region us-east-1  ec2 create-internet-gateway \
  --tag-specifications 'ResourceType=internet-gateway, Tags=[{Key=Name,Value=gke-cluster-InternetGateway}]'
INTERNET_GW_ID=$(aws ec2 describe-internet-gateways \
  --filters 'Name=tag:Name,Values=gke-cluster-InternetGateway' \
  --query "InternetGateways[].InternetGatewayId" --output text)
aws ec2 attach-internet-gateway \
  --internet-gateway-id $INTERNET_GW_ID \
  --vpc-id $VPC_ID

# Configure routing tables for public subnets

aws ec2 create-route-table --vpc-id $VPC_ID \
  --tag-specifications 'ResourceType=route-table, Tags=[{Key=Name,Value=gke-cluster-PublicRouteTbl1}]'
aws ec2 create-route-table --vpc-id $VPC_ID \
  --tag-specifications 'ResourceType=route-table, Tags=[{Key=Name,Value=gke-cluster-PublicRouteTbl2}]'
aws ec2 create-route-table --vpc-id $VPC_ID \
  --tag-specifications 'ResourceType=route-table, Tags=[{Key=Name,Value=gke-cluster-PublicRouteTbl3}]'

# Associate public routes with public subnets

PUBLIC_ROUTE_TABLE_ID_1=$(aws ec2 describe-route-tables \
    --filters 'Name=tag:Name,Values=gke-cluster-PublicRouteTbl1' \
    --query "RouteTables[].RouteTableId" --output text)
PUBLIC_ROUTE_TABLE_ID_2=$(aws ec2 describe-route-tables \
    --filters 'Name=tag:Name,Values=gke-cluster-PublicRouteTbl2' \
    --query "RouteTables[].RouteTableId" --output text)
PUBLIC_ROUTE_TABLE_ID_3=$(aws ec2 describe-route-tables \
    --filters 'Name=tag:Name,Values=gke-cluster-PublicRouteTbl3' \
    --query "RouteTables[].RouteTableId" --output text)
aws ec2 associate-route-table \
  --route-table-id $PUBLIC_ROUTE_TABLE_ID_1 \
  --subnet-id $PUBLIC_SUBNET_ID_1
aws ec2 associate-route-table \
  --route-table-id $PUBLIC_ROUTE_TABLE_ID_2 \
  --subnet-id $PUBLIC_SUBNET_ID_2
aws ec2 associate-route-table \
  --route-table-id $PUBLIC_ROUTE_TABLE_ID_3 \
  --subnet-id $PUBLIC_SUBNET_ID_3

# Create default routes for the internet gateway

aws ec2 create-route --route-table-id $PUBLIC_ROUTE_TABLE_ID_1 \
  --destination-cidr-block 0.0.0.0/0 --gateway-id $INTERNET_GW_ID
aws ec2 create-route --route-table-id $PUBLIC_ROUTE_TABLE_ID_2 \
  --destination-cidr-block 0.0.0.0/0 --gateway-id $INTERNET_GW_ID
aws ec2 create-route --route-table-id $PUBLIC_ROUTE_TABLE_ID_3 \
  --destination-cidr-block 0.0.0.0/0 --gateway-id $INTERNET_GW_ID

# Allocate an elastic IP for each NAT gateway

aws ec2 allocate-address \
  --tag-specifications 'ResourceType=elastic-ip, Tags=[{Key=Name,Value=gke-cluster-NatEip1}]'
aws ec2 allocate-address \
  --tag-specifications 'ResourceType=elastic-ip, Tags=[{Key=Name,Value=gke-cluster-NatEip2}]'
aws ec2 allocate-address \
  --tag-specifications 'ResourceType=elastic-ip, Tags=[{Key=Name,Value=gke-cluster-NatEip3}]'

# Create NAT gateways

NAT_EIP_ALLOCATION_ID_1=$(aws ec2 describe-addresses \
  --filters 'Name=tag:Name,Values=gke-cluster-NatEip1' \
  --query "Addresses[].AllocationId" --output text)
NAT_EIP_ALLOCATION_ID_2=$(aws ec2 describe-addresses \
  --filters 'Name=tag:Name,Values=gke-cluster-NatEip2' \
  --query "Addresses[].AllocationId" --output text)
NAT_EIP_ALLOCATION_ID_3=$(aws ec2 describe-addresses \
  --filters 'Name=tag:Name,Values=gke-cluster-NatEip3' \
  --query "Addresses[].AllocationId" --output text)
aws ec2 create-nat-gateway \
  --allocation-id $NAT_EIP_ALLOCATION_ID_1 \
  --subnet-id $PUBLIC_SUBNET_ID_1 \
  --tag-specifications 'ResourceType=natgateway, Tags=[{Key=Name,Value=gke-cluster-NatGateway1}]'
aws ec2 create-nat-gateway \
  --allocation-id $NAT_EIP_ALLOCATION_ID_2 \
  --subnet-id $PUBLIC_SUBNET_ID_2 \
  --tag-specifications 'ResourceType=natgateway, Tags=[{Key=Name,Value=gke-cluster-NatGateway2}]'
aws ec2 create-nat-gateway \
  --allocation-id $NAT_EIP_ALLOCATION_ID_3 \
  --subnet-id $PUBLIC_SUBNET_ID_3 \
  --tag-specifications 'ResourceType=natgateway, Tags=[{Key=Name,Value=gke-cluster-NatGateway3}]'

# Configure private route tables

aws ec2 create-route-table --vpc-id $VPC_ID \
  --tag-specifications 'ResourceType=route-table, Tags=[{Key=Name,Value=gke-cluster-PrivateRouteTbl1}]'
aws ec2 create-route-table --vpc-id $VPC_ID \
  --tag-specifications 'ResourceType=route-table, Tags=[{Key=Name,Value=gke-cluster-PrivateRouteTbl2}]'
aws ec2 create-route-table --vpc-id $VPC_ID \
  --tag-specifications 'ResourceType=route-table, Tags=[{Key=Name,Value=gke-cluster-PrivateRouteTbl3}]'

# Associate private routes with private subnets

PRIVATE_SUBNET_ID_1=$(aws ec2 describe-subnets \
  --filters 'Name=tag:Name,Values=gke-cluster-PrivateSubnet1' \
  --query "Subnets[].SubnetId" --output text)
PRIVATE_SUBNET_ID_2=$(aws ec2 describe-subnets \
  --filters 'Name=tag:Name,Values=gke-cluster-PrivateSubnet2' \
  --query "Subnets[].SubnetId" --output text)
PRIVATE_SUBNET_ID_3=$(aws ec2 describe-subnets \
  --filters 'Name=tag:Name,Values=gke-cluster-PrivateSubnet3' \
  --query "Subnets[].SubnetId" --output text)
PRIVATE_ROUTE_TABLE_ID_1=$(aws ec2 describe-route-tables \
  --filters 'Name=tag:Name,Values=gke-cluster-PrivateRouteTbl1' \
  --query "RouteTables[].RouteTableId" --output text)
PRIVATE_ROUTE_TABLE_ID_2=$(aws ec2 describe-route-tables \
  --filters 'Name=tag:Name,Values=gke-cluster-PrivateRouteTbl2' \
  --query "RouteTables[].RouteTableId" --output text)
PRIVATE_ROUTE_TABLE_ID_3=$(aws ec2 describe-route-tables \
  --filters 'Name=tag:Name,Values=gke-cluster-PrivateRouteTbl3' \
  --query "RouteTables[].RouteTableId" --output text)
aws ec2 associate-route-table --route-table-id $PRIVATE_ROUTE_TABLE_ID_1 \
  --subnet-id $PRIVATE_SUBNET_ID_1
aws ec2 associate-route-table --route-table-id $PRIVATE_ROUTE_TABLE_ID_2 \
  --subnet-id $PRIVATE_SUBNET_ID_2
aws ec2 associate-route-table --route-table-id $PRIVATE_ROUTE_TABLE_ID_3 \
  --subnet-id $PRIVATE_SUBNET_ID_3

# Create default routes to NAT gateways

NAT_GW_ID_1=$(aws ec2 describe-nat-gateways \
 --filter 'Name=tag:Name,Values=gke-cluster-NatGateway1' \
 --query "NatGateways[].NatGatewayId" --output text)
NAT_GW_ID_2=$(aws ec2 describe-nat-gateways \
 --filter 'Name=tag:Name,Values=gke-cluster-NatGateway2' \
 --query "NatGateways[].NatGatewayId" --output text)
NAT_GW_ID_3=$(aws ec2 describe-nat-gateways \
 --filter 'Name=tag:Name,Values=gke-cluster-NatGateway3' \
 --query "NatGateways[].NatGatewayId" --output text)
aws ec2 create-route --route-table-id $PRIVATE_ROUTE_TABLE_ID_1  \
  --destination-cidr-block 0.0.0.0/0 --gateway-id $NAT_GW_ID_1
aws ec2 create-route --route-table-id $PRIVATE_ROUTE_TABLE_ID_2  \
  --destination-cidr-block 0.0.0.0/0 --gateway-id $NAT_GW_ID_2
aws ec2 create-route --route-table-id $PRIVATE_ROUTE_TABLE_ID_3 \
  --destination-cidr-block 0.0.0.0/0 --gateway-id $NAT_GW_ID_3
