# Note: Run these commands on the workstation instance itself

# Set some environment variables
export PROJECT_ID=$(gcloud config get-value project)
export ZONE=us-central1-a
export SSH_PRIVATE_KEY=/root/.ssh/id_rsa
export LB_CONTROLL_PLANE_NODE=10.200.0.3
export LB_CONTROLL_PLANE_VIP=10.200.0.98

# Create some service account keys and use them to authenticate
gcloud iam service-accounts keys create installer.json \
  --iam-account=bm-owner@$PROJECT_ID.iam.gserviceaccount.com
export GOOGLE_APPLICATION_CREDENTIALS=~/installer.json

# Generate a bmctl config file
bmctl create config -c admin-cluster \
  --enable-apis \
  --create-service-accounts \
  --project-id=$PROJECT_ID

# Modify the generated config file
sed -r -i "s|sshPrivateKeyPath: <path to SSH private key, used for node access>|sshPrivateKeyPath: $(echo $SSH_PRIVATE_KEY)|g" bmctl-workspace/admin-cluster/admin-cluster.yaml
sed -r -i "s|type: hybrid|type: admin|g" bmctl-workspace/admin-cluster/admin-cluster.yaml
sed -r -i "s|- address: <Machine 1 IP>|- address: $(echo $LB_CONTROLL_PLANE_NODE)|g" bmctl-workspace/admin-cluster/admin-cluster.yaml
sed -r -i "s|controlPlaneVIP: 10.0.0.8|controlPlaneVIP: $(echo $LB_CONTROLL_PLANE_VIP)|g" bmctl-workspace/admin-cluster/admin-cluster.yaml

# Delete the NodePool section of the config file
head -n -11 bmctl-workspace/admin-cluster/admin-cluster.yaml > temp_file && mv temp_file bmctl-workspace/admin-cluster/admin-cluster.yaml

# Create the cluster
bmctl create cluster -c admin-cluster

# Configure kubectx for this context
export KUBECONFIG=$KUBECONFIG:~/bmctl-workspace/admin-cluster/admin-cluster-kubeconfig
kubectx admin=.

# Make sure we can see the control plane node
kubectl get nodes

# Create a Kubernetes service account so we can log in from the Cloud Console
kubectl create serviceaccount -n kube-system admin-user
kubectl create clusterrolebinding admin-user-binding \
    --clusterrole cluster-admin --serviceaccount kube-system:admin-user

# Create a token and print it so we can use it to log in
kubectl create token admin-user -n kube-system 
