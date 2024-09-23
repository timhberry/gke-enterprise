# Create a bash array containing our "bare metal" server names
declare -a VMs=("admin-workstation" "admin-control" "user-control" "user-worker")

# Create an empty array to store IP addresses in from our VMs
declare -a IPs=()

# Create a VM instance for each server in the array
for vm in "${VMs[@]}"
 do
     gcloud compute instances create $vm \
         --image-family=ubuntu-2004-lts \
         --image-project=ubuntu-os-cloud \
         --zone=us-central1-a \
         --boot-disk-size 128G \
         --boot-disk-type pd-standard \
         --can-ip-forward \
         --network baremetal \
         --subnet us-central1-subnet \
         --scopes cloud-platform \
         --machine-type e2-standard-4 \
         --metadata=os-login=FALSE \
         --verbosity=error
     IP=$(gcloud compute instances describe $vm --zone us-central1-a \
         --format='get(networkInterfaces[0].networkIP)')
     IPs+=("$IP")
done

# Add the appropriate network tags
gcloud compute instances add-tags admin-control \
  --zone us-central1-a \
  --tags="cp,admin,lb,vxlan"
gcloud compute instances add-tags user-control \
  --zone us-central1-a \
  --tags="cp,user,lb,vxlan"
gcloud compute instances add-tags user-worker \
  --zone us-central1-a \
  --tags="worker,user,vxlan"

# Disable the Ubuntu fireall on each VM
for vm in "${VMs[@]}"
do
    echo "Disabling UFW on $vm"
    gcloud compute ssh root@$vm --zone us-central1-a --tunnel-through-iap  << EOF
        sudo ufw disable
EOF
done

# Set up VXLAN on each server
i=2
for vm in "${VMs[@]}"
do
    gcloud compute ssh root@$vm --zone us-central1-a --tunnel-through-iap << EOF
        # update package list on VM
        apt-get -qq update > /dev/null
        apt-get -qq install -y jq > /dev/null

        # print executed commands to terminal
        set -x

        # create new vxlan configuration
        ip link add vxlan0 type vxlan id 42 dev ens4 dstport 4789
        current_ip=\$(ip --json a show dev ens4 | jq '.[0].addr_info[0].local' -r)
        echo "VM IP address is: \$current_ip"
        for ip in ${IPs[@]}; do
            if [ "\$ip" != "\$current_ip" ]; then
                bridge fdb append to 00:00:00:00:00:00 dst \$ip dev vxlan0
            fi
        done
        ip addr add 10.200.0.$i/24 dev vxlan0
        ip link set up dev vxlan0
EOF
    i=$((i+1))
done

# Check that VXLAN IPs are working
i=2
for vm in "${VMs[@]}";
do
    echo $vm;
    gcloud compute ssh root@$vm --zone us-central1-a --tunnel-through-iap --command="hostname -I"; 
    i=$((i+1));
done

# Add firewall rule to allow traffic to the control plane
gcloud compute firewall-rules create bm-allow-cp \
    --network="baremetal" \
    --allow="UDP:6081,TCP:22,TCP:6444,TCP:2379-2380,TCP:10250-10252,TCP:4240" \
    --source-ranges="10.0.0.0/8" \
    --target-tags="cp"

# Add firewal rule to allow inbound traffic to worker nodes
gcloud compute firewall-rules create bm-allow-worker \
    --network="baremetal" \
    --allow="UDP:6081,TCP:22,TCP:10250,TCP:30000-32767,TCP:4240" \
    --source-ranges="10.0.0.0/8" \
    --target-tags="worker"

# Add firewall rule to allow inbound traffic to load balancer nodes
gcloud compute firewall-rules create bm-allow-lb \
    --network="baremetal" \
    --allow="UDP:6081,TCP:22,TCP:443,TCP:7946,UDP:7496,TCP:4240" \
    --source-ranges="10.0.0.0/8" \
    --target-tags="lb"

gcloud compute firewall-rules create allow-gfe-to-lb \
    --network="baremetal" \
    --allow="TCP:443" \
    --source-ranges="10.0.0.0/8,130.211.0.0/22,35.191.0.0/16" \
    --target-tags="lb"

# Add firewall rule to allow traffic between admin and user clusters
gcloud compute firewall-rules create bm-allow-multi \
    --network="baremetal" \
    --allow="TCP:22,TCP:443" \
    --source-tags="admin" \
    --target-tags="user"
