### Create a ssh key for the ssh server 
```bash   

# FOR PROXMOX VMS
ssh-keygen -t ed25519 -C "cpinto@home.lab"  -f ~/.ssh/proxmox-vms

```

### Add the public key to the server  ()
```bash
ssh carlosp@192.168.1.100
sudo apt install nano
nano .ssh/authorized_keys 

```

### rename template configs if needed

```bash

sudo nano /etc/hostname
sudo nano /etc/hosts

#then go to proxmox pve console
systemctl restart pve-cluster #this will update proxmox name


#Install QEMU guest agent
#Enable it on the VM OPtions in proxmox

sudo apt update && sudo apt install qemu-guest-agent -y
sudo systemctl enable --now qemu-guest-agent
sudo systemctl status qemu-guest-agent.service



#define network interface (enp0s18)
ip a

ip route # gateway
resolvectl status #dns servers
sudo nano /etc/netplan/50-cloud-init.yaml #add new routing config

```

```yaml
network:
  version: 2
  ethernets:
    enp0s18:
      dhcp4: false
      addresses:
        - 192.168.1.103/24
      routes:
        - to: default
          via: 192.168.1.1
      nameservers:
        addresses: [1.1.1.1, 8.8.8.8]
```

```bash
#Apply network changes with 

sudo netplan apply
```

---
### Kubernetes install commands
#### https://www.youtube.com/watch?v=3FiBhTEBPeE

```bash

sudo apt-get update
sudo apt-get install -y apt-transport-https ca-certificates curl gpg

curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.36/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg

echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.36/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list

sudo apt-get update
sudo apt-get install -y kubelet kubeadm kubectl
sudo apt-mark hold kubelet kubeadm kubectl
sudo systemctl enable --now kubelet

```

### Install Kubernetes runtime containerd
```bash
sudo swapoff -a
sudo sed -i '/swap/s/^/#/' /etc/fstab
cat /etc/fstab | grep -i swap

# Load required modules
sudo modprobe br_netfilter
sudo modprobe overlay

# Make them persist across reboots
cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF

# Set required sysctls
cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF

sudo sysctl --system

lsmod | grep br_netfilter
cat /proc/sys/net/bridge/bridge-nf-call-iptables   # should print 1

sudo apt install -y containerd
sudo systemctl enable --now containerd
sudo mkdir -p /etc/containerd
containerd config default | sudo tee /etc/containerd/config.toml
sudo sed -i 's/SystemCgroup =false/SystemCgroup = true/' /etc/containerd/config.toml
sudo systemctl restart containerd
ls /var/run/containerd/containerd.sock
```

### Final config
```bash

ip route show
sudo kubeadm init \
--apiserver-advertise-address="192.168.30.10" \
--pod-network-cidr="10.244.0.0/16"

#Pick the join command to add the worker nodes to this controller

#DONT run these in the worker node
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config
kubectl apply -f https://raw.githubusercontent.com/flannel-io/flannel/master/Documentation/kube-flannel.yml

```

### Now on the master node when the worker nodes were added

```bash

#Label the worker node
kubectl label node k8s-worker1 node-role.kubernetes.io/worker=worker

kubectl get nodes --show-labels

```



# WORKERS
### Now go to the worker node and apply same commands and stop in command  **** (sudo kubeadm init) ****

```bash
#RUN WITH SUDO
kubeadm join 192.168.30.10:6443 --token 0x1vvf.ntvhl508kmgjdp6n \
        --discovery-token-ca-cert-hash sha256:e7fb4ef7564... 

```

### To get the master kube config
```bash

# On master1
sudo cp /etc/kubernetes/admin.conf /home/carlosp/admin.conf
sudo chown carlosp:carlosp /home/carlosp/admin.conf

# On my machine
scp carlosp@192.168.1.100:~/admin.conf ~/.kube/config


#back on master1
rm /home/carlosp/admin.conf

#on my machine
# This file has full cluster-admin credentials, so tighten it up locally:
chmod 600 ~/.kube/config
```


### Reset a k8s node
```bash

sudo kubeadm reset -f

sudo rm -rf /etc/cni/net.d
sudo ip link delete cni0 2>/dev/null
sudo ip link delete flannel.1 2>/dev/null
sudo iptables -F && sudo iptables -t nat -F && sudo iptables -t mangle -F && sudo iptables -X


# if it's master then run the kubeadmin init .... command
# if it's worker then run the join command

``


