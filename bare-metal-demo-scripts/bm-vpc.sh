# Create the VPC to simulate our bare metal network

gcloud compute networks create baremetal \
  --subnet-mode=custom \
  --mtu=1460 \
  --bgp-routing-mode=regional

# Create the subnet in our VPC

gcloud compute networks subnets create us-central1-subnet \
  --range=10.1.0.0/24 \
  --stack-type=IPV4_ONLY \
  --network=baremetal \
  --region=us-central1

# Create firewall rules for inbound SSH and VXLAN traffic

gcloud compute firewall-rules create iap \
  --direction=INGRESS \
  --priority=1000 \
  --network=baremetal \
  --action=ALLOW \
  --rules=tcp:22 \
  --source-ranges=35.235.240.0/20

gcloud compute firewall-rules create vxlan \
  --direction=INGRESS \
  --priority=1000 \
  --network=baremetal \
  --action=ALLOW \
  --rules=udp:4789 \
  --source-tags=vxlan

# Please note! Due to changes in the VXLAN package and Google's cloud SDN
# these rules may not be sufficient. If you get stuck, you can create an
# ALLOW ALL rule for your "bare metal" VPC. This is not a secure solution,
# but this is for demonstration purposes only.

# Set up a service account to use later
PROJECT_ID=$(gcloud config get-value project)
gcloud iam service-accounts create bm-owner
gcloud projects add-iam-policy-binding ${PROJECT_ID} \
  --member=serviceAccount:bm-owner@${PROJECT_ID}.iam.gserviceaccount.com \
  --role=roles/owner

