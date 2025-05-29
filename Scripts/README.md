These are the scripts used during the experiment.

## 🔧 Example Commands

Below are sample commands to launch the server, run the client, and fetch logs.  
All default parameters (such as port, algorithms, packet size, and handshake count) are defined within the scripts themselves.

### 🖥️ Start Server

```bash
sudo ./server2.sh 4433 falcon512 hqc128

### 🖥️ Start Client
```bash
sudo ./client2.sh 10.45.0.12 4433 hqc128 falcon512 512 10 50

### 🖥️ Fetch Collected Data during transmission from the host machine (Windows)
```bash
fetch_logs.bat kem_hqc128_sig_falcon512
