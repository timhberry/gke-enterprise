# Note: Run these commands on the workstation instance itself

# Set the environment variables we need (just in case we lost them)
export PROJECT_ID=$(gcloud config get-value project)

# Generate a bmctl config file for the user cluster
bmctl create config -c user-cluster \
  --project-id=$PROJECT_ID

# Delete the credentials file references that we don't need
tail -n +11 bmctl-workspace/user-cluster/user-cluster.yaml > temp_file && mv temp_file bmctl-workspace/user-cluster/user-cluster.yaml

# Add the private SSH key to the config
sed -i '1 i\sshPrivateKeyPath: /root/.ssh/id_rsa' bmctl-workspace/user-cluster/user-cluster.yaml

# Change the cluster type to user
sed -r -i "s|type: hybrid|type: user|g" bmctl-workspace/user-cluster/user-cluster.yaml

# Set the IP for the control plane VM node
sed -r -i "s|- address: <Machine 1 IP>|- address: 10.200.0.4|g" bmctl-workspace/user-cluster/user-cluster.yaml

# Set the IP for the control plane API server
sed -r -i "s|controlPlaneVIP: 10.0.0.8|controlPlaneVIP: 10.200.0.99|g" bmctl-workspace/user-cluster/user-cluster.yaml

# Set up the IP for the user cluster's Ingress
sed -r -i "s|# ingressVIP: 10.0.0.2|ingressVIP: 10.200.0.100|g" bmctl-workspace/user-cluster/user-cluster.yaml

# Configure IPs for LoadBalancer services
sed -r -i "s|# addressPools:|addressPools:|g" bmctl-workspace/user-cluster/user-cluster.yaml
sed -r -i "s|# - name: pool1|- name: pool1|g" bmctl-workspace/user-cluster/user-cluster.yaml
sed -r -i "s|#   addresses:|  addresses:|g" bmctl-workspace/user-cluster/user-cluster.yaml
sed -r -i "s|#   - 10.0.0.1-10.0.0.4|  - 10.200.0.100-10.200.0.200|g" bmctl-workspace/user-cluster/user-cluster.yaml

# Enable logging
sed -r -i "s|# disableCloudAuditLogging: false|disableCloudAuditLogging: false|g" bmctl-workspace/user-cluster/user-cluster.yaml
sed -r -i "s|# enableApplication: false|enableApplication: true|g" bmctl-workspace/user-cluster/user-cluster.yaml

# Configure the worker node pool
sed -r -i "s|name: node-pool-1|name: user-cluster-central-pool-1|g" bmctl-workspace/user-cluster/user-cluster.yaml
sed -r -i "s|- address: <Machine 2 IP>|- address: 10.200.0.5|g" bmctl-workspace/user-cluster/user-cluster.yaml
sed -r -i "s|- address: <Machine 3 IP>|# - address: <Machine 3 IP>|g" bmctl-workspace/user-cluster/user-cluster.yaml

# Create the cluster
bmctl create cluster -c user-cluster --kubeconfig bmctl-workspace/admin-cluster/admin-cluster-kubeconfig

# Configure kubectx for this context
export KUBECONFIG=~/bmctl-workspace/user-cluster/user-cluster-kubeconfig
kubectx user=.

# Make sure we can see the cluster nodes
kubectl get nodes

# Create a Kubernetes service account so we can log in from the Cloud Console
kubectl create serviceaccount -n kube-system admin-user
kubectl create clusterrolebinding admin-user-binding \
    --clusterrole cluster-admin --serviceaccount kube-system:admin-user

# Create a token and print it so we can use it to log in
kubectl create token admin-user -n kube-system 
