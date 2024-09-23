# Note: Use the IAP command below to pass through the SSH identity
# then run the rest of the commands on the workstation instance itself

eval `ssh-agent`
ssh-add ~/.ssh/google_compute_engine
gcloud compute ssh --ssh-flag="-A" root@admin-workstation \
  --zone us-central1-a \
  --tunnel-through-iap

# Install the gcloud SDK (accept the defaults when prompted)
snap remove google-cloud-cli
curl https://sdk.cloud.google.com | bash
exec -l $SHELL

# Install kubectl
gcloud components install kubectl

# Download and install the bmctl tool
gsutil cp gs://anthos-baremetal-release/bmctl/1.16.0/linux-amd64/bmctl .
chmod a+x bmctl
mv bmctl /usr/local/sbin/
bmctl version

# Download and install Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sh get-docker.sh
docker version

# Create SSH keys (accept the defaults and do not specify a passphrase)
ssh-keygen -t rsa

# Create a bash array containing our server names
declare -a VMs=("admin-control" "user-control" "user-worker")

# Copy our SSH public key to enable password-less access
for vm in "${VMs[@]}"
do
    ssh-copy-id -o StrictHostKeyChecking=no -i ~/.ssh/id_rsa.pub root@$vm
done

# Install kubectx
git clone https://github.com/ahmetb/kubectx /opt/kubectx
ln -s /opt/kubectx/kubectx /usr/local/bin/kubectx
ln -s /opt/kubectx/kubens /usr/local/bin/kubens
