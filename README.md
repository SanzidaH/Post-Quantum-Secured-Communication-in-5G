# Post-Quantum-Secured-Communication-in-5G
<!-- This section aims to familiarize the components of 5G and the steps required for the setup.
## Post-Quantum-Secured UE-to-UE Communication
### Background and Steps
### Client and Server Setup
## Experimental Setup
 ### 5G Testbed Setup

#### 5G Testbed Setup from Scratch (Linux):
Steps:
1. Setting Up virt-manager, Open vSwitch, and Bridge Configuration

```bash
# Step 1: Install virt-manager
sudo apt install virt-manager -y   # Install virt-manager   

# Step 2: Install Open vSwitch
sudo apt install openvswitch-switch -y  # Install Open vSwitch  

# Step 3: Create a New Bridge
sudo ovs-vsctl add-br br4  # Create a new bridge named br4  

# Step 4: Install Network Tools
sudo apt install net-tools -y  # Install network tools for managing interfaces  

# Step 5: Assign IP Address to the 

2. Create VMs for UP, CP, gNB, and UEs and set up ip manually
4. 
  --->
#### 5G Testbed Setup from Existing VMs (Windows):
We have a total 5 VMs:
1.	CP: Control Plane using Open5gs
2.	UP: User Plane using Open5gs
3.	Gnb: Base station using UERANSIM
4.	UE1: using UERANSIM - Client
5.	UE2: using UERANSIM – Server (it can be cloned from ue1)

### VMWare Installations:
For Windows, we can use Vmware, which can be downloaded from:
https://softwareupdate.vmware.com/cds/vmw-desktop/ws/17.6.1/24319023/windows/core/

### Network Adapter Setup:
Assuming we have all VMs in vmdk format. Now we need a customized adapter for our setup, export VMs, set the network config, and then set the 5G and pqc config.
In vmware, we need to add a network adapter. For that, go to edit->virtual network editor. In the virtual network editor, add a network, when all vms are powered off. It should be host only and set the ip. For this case, all vms have IP set in 192.168.234.x range, so set the subnet ip as 192.168.234.0 and subnet mask 255.255.255.0. So, now this adapter we will be using for all VM for LAN and the 5Gsetup would transmitting packet over this network. We will also have the VMnet8 NAT adapter so we can connect to the Internet also and ssh the VMs.

### VM export and Add NIC:
To export VM in vmware, VMware workstation pro: go to File -> New Virtual Machine -> custom (advanced) -> in Guest operating system installation, add ubuntu iso -> Name the virtual machine. You can change the vm name here. -> you can decrease the virtual memory. -> for network use host only, this can be changed later as well. -> (ii) In select disk, select existing virtual disk, and export the virtual machine. -> in ready to create VM, click customized hardware and add network adapter that we set before. Also, keep on as NAT. Then click finish to create the vm successfully. For cp, we need three adapters: smf,amf, and NAT. Hardware can be added when VM is turned off.

<!--- ### Open5GS and UERANSIM Setup Guide From Exisitng ---> 

#### (i) Control Plane (CP)

##### Set AMF and SMF Addresses
AMF: 192.168.234.2,
SMF: 192.168.234.3

##### Update Configuration Files
```bash
cd /etc/open5gs
sudo nano amf.yaml
sudo nano smf.yaml
```
##### Add UE Profiles in WebUI
Access WebUI at localhost:9999 and configure:
IMSI: International Mobile Subscriber Identity
IP Address: e.g., 10.45.0.x

##### Check Status of Network Functions and Database
```bash
sudo systemctl status open5gs-smfd
sudo systemctl status open5gs-amfd
sudo systemctl status mongod.service
```

#### (ii) User Plane (UP) 
##### Set UPF IP Address
UPF: 192.168.234.4
```bash
##### Update Configuration and Prepare UP Script
cd /etc/open5gs

# Create the script up.sh with the following content:
echo 'sudo ip link set ogstun up
sudo sysctl -w net.ipv4.ip_forward=1
sudo iptables -I INPUT --source 10.45.0.2/16 -j ACCEPT
sudo iptables -t nat -I POSTROUTING --out-interface eno1 -j MASQUERADE
sudo iptables -I FORWARD --in-interface ogstun --out-interface eno1 -j ACCEPT' > up.sh

# Replace 'eno1' with your actual network interface using 'ip a' command

# Make the script executable
chmod +x up.sh

# Check UPF Status and Run UP Script
sudo systemctl status open5gs-upfd.service
sudo ./up.sh
```

#### (iii) GNB: 
##### Set gNB IP Address
gNB: 192.168.234.6

##### Update Configuration File
```bash
cd UERANSIM/config
sudo nano open5gs-gnb1.yaml
cd ..

# Run gNB
./build/nr-gnb -c config/open5gs-gnb1.yaml
```
#### (iv) UE1: 
##### Update Configuration File
```bash
cd UERANSIM/config
sudo nano open5gs-ue1.yaml
cd ..
```

##### Run UE1
```bash
./build/nr-ue -c config/open5gs-ue1.yaml
```
##### Set Default Route for UE1 Interface
```bash
sudo ip route add default dev uesimtun0
```

#### (v) UE2: 
##### Update Configuration File
```bash
cd UERANSIM/config
sudo nano open5gs-ue2.yaml
# Run UE2
./build/nr-ue -c config/open5gs-ue2.yaml

# Set Default Route for UE2 Interface
sudo ip route add default dev uesimtun0
```

#### Boringssl:  
```bash
# https://github.com/open-quantum-safe/boringssl
 cd Downloads/boringssl/build

 tool/bssl client -curves kyber512 -connect 10.45.0.5:4433 
#(set in webui)
 tool/bssl server -accept 4433 -sig-alg dilithium2 –loop
```
#### Wolfssl:
 ```bash
cd osp/oqs/wolfssl
./examples/client/client -v 4 --pqc KYBER_LEVEL1 -h 10.45.0.3
./examples/server/server -v 4 -l TLS_AES_256_GCM_SHA384 --pqc P521_KYBER_LEVEL5 –b
```

