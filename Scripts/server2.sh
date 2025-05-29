#!/bin/bash

# Default parameters
PORT=${1:-4433}
SIG_ALG=${2:-"falcon512"}   # Default Signature Algorithm
KEM_ALG=${3:-"mlkem768"}    # Default Key Exchange Algorithm (KEM)
#SIG_ALG=${2:-" "}   # Default Signature Algorithm
#KEM_ALG=${3:-" "}    # Default Key Exchange Algorithm (KEM)
# Set up logging directory
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
LOG_DIR="server_logs/kem_${KEM_ALG}_sig_${SIG_ALG}_${TIMESTAMP}/"
INTERFACE="uesimtun0"  # Change if needed

# Ensure logging directory exists
mkdir -p "$LOG_DIR"

LOG_FILE="$LOG_DIR/server_log.txt"
CPU_MEM_LOG="$LOG_DIR/cpu_memory_usage.txt"
THROUGHPUT_LOG="$LOG_DIR/network_usage.txt"
CLIENT_ALGO_LOG="$LOG_DIR/client_algorithms.txt"
TMP_CPU_LOG="$LOG_DIR/tmp_cpu_usage.txt"
TMP_MEM_LOG="$LOG_DIR/tmp_mem_usage.txt"
MAX_CPU_LOG="$LOG_DIR/max_cpu_usage.txt"
MAX_MEM_LOG="$LOG_DIR/max_memory_usage.txt"
AVG_THROUGHPUT_LOG="$LOG_DIR/avg_throughput.txt"
ALL_VALUES_LOG="$LOG_DIR/all_values_server.txt"
# Ensure log files exist
# touch "$CLIENT_ALGO_LOG" 
touch "$TMP_CPU_LOG" "$TMP_MEM_LOG" "$MAX_CPU_LOG" "$MAX_MEM_LOG" "$AVG_THROUGHPUT_LOG" "$THROUGHPUT_LOG" "$ALL_VALUES_LOG"

# Function to handle cleanup on Ctrl+C
cleanup() {
    echo -e "\n🚨 Stopping server..."
    pkill -f "tool/bssl server"
    pkill -P $$  # Kill all background processes

    # Compute max CPU and memory usage
    MAX_CPU=$(awk 'BEGIN {max=0} {if ($1+0 > max) max=$1} END {print max}' "$TMP_CPU_LOG")
    MAX_MEM=$(awk 'BEGIN {max=0} {if ($1+0 > max) max=$1} END {print max}' "$TMP_MEM_LOG")

    # Compute average throughput
    AVG_THROUGHPUT=$(awk 'BEGIN {sum=0; count=0} {sum+=$2; count+=1} END {if (count > 0) print sum/count; else print "0"}' "$THROUGHPUT_LOG")
    echo "$LOG_DIR" >> "$ALL_VALUES_LOG"
    echo "Max CPU Usage During Transmission: $MAX_CPU%" | tee -a "$MAX_CPU_LOG" >> "$ALL_VALUES_LOG"
    echo "Max Memory Usage During Transmission: $MAX_MEM KB" | tee -a "$MAX_MEM_LOG"  >> "$ALL_VALUES_LOG"
    echo "Average Throughput: $AVG_THROUGHPUT KB/s" | tee -a "$AVG_THROUGHPUT_LOG"  >> "$ALL_VALUES_LOG"

    echo "✅ Server stopped successfully."
    exit 0
}

# Trap SIGINT (CTRL+C) to call cleanup function
trap cleanup SIGINT

echo "=========================="
echo " 🟢 Starting BoringSSL Server "
echo "=========================="
echo "🔹 Port: $PORT"
echo "🔹 Signature Algorithm: $SIG_ALG"
echo "🔹 Key Exchange Mechanism (KEM): $KEM_ALG"
echo "🔹 Logs stored in: $LOG_DIR"
echo "==================================="

# Kill any existing process using the port before starting
if sudo lsof -i :$PORT; then
    echo "⚠️  Port $PORT is in use. Killing existing process..."
    sudo fuser -k ${PORT}/tcp
    sleep 2
fi

# Capture initial network statistics
RX_BYTES_BEFORE=$(cat /sys/class/net/$INTERFACE/statistics/rx_bytes)
TX_BYTES_BEFORE=$(cat /sys/class/net/$INTERFACE/statistics/tx_bytes)

CPU_USAGE=$(ps au | grep "[b]ssl" | awk "{print \$3}")
MEM_USAGE=$(ps au | grep "[b]ssl" | awk "{print \$4}")

# 📌 **Save CPU & Memory Usage for Analysis**
echo "$CPU_USAGE" >> "$TMP_CPU_LOG"
echo "$MEM_USAGE" >> "$TMP_MEM_LOG"

# 📌 **Start BoringSSL Server & Monitoring Together**
stdbuf -oL tool/bssl server -accept $PORT -sig-alg $SIG_ALG -curves $KEM_ALG -loop -www -debug 2>&1 | tee "$LOG_FILE" | while read -r line; do
     echo "🔹 [Server Output]: $line"

    # 📌 **Detect ECDHE Group (KEM Algorithm)**
    # if echo "$line" | grep -q "ECDHE group"; then
    #    CLIENT_ALGO=$(echo "$line" | awk '{print $NF}')
    #    echo "$(date +"%Y-%m-%d %H:%M:%S"), $CLIENT_ALGO" | tee -a "$CLIENT_ALGO_LOG"
    #    echo "✅ Detected ECDHE Group (KEM): $CLIENT_ALGO"
    # fi

    # 📌 **Get BSSL Process ID & Capture CPU, Memory Usage**
    BSSL_PID=$(pgrep -af "bssl" | awk "NR==1 {print \$1}")
    while [[ -n "$BSSL_PID" && "$BSSL_PID" =~ ^[0-9]+$ ]]; do
        CPU_USAGE=$(ps au | grep "[b]ssl" | awk "{print \$3}")
        #MEM_USAGE=$(ps au | grep "[b]ssl" | awk "{print \$4}")
	MEM_USAGE=$(smem -r -K K -P bssl | awk '/^[0-9]+/ {if ($5+0 > max) max=$5} END {print max}')
	[[ -z "$MEM_USAGE" ]] && MEM_USAGE="0"
        # If CPU or Memory usage is empty, set to 0
        if [[ -z "$CPU_USAGE" ]]; then
            CPU_USAGE="0.00"
            MEM_USAGE="0"
        fi

        # 📌 **Save CPU & Memory Usage for Analysis**
        echo "$CPU_USAGE" >> "$TMP_CPU_LOG"
        echo "$MEM_USAGE" >> "$TMP_MEM_LOG"
        echo "🔹 [Server Output]: $line"
        # 📌 **Capture Network Throughput**
        RX_BYTES_AFTER=$(cat /sys/class/net/$INTERFACE/statistics/rx_bytes)
        TX_BYTES_AFTER=$(cat /sys/class/net/$INTERFACE/statistics/tx_bytes)

        RX_DIFF=$(( (RX_BYTES_AFTER - RX_BYTES_BEFORE) / 1024 ))
        TX_DIFF=$(( (TX_BYTES_AFTER - TX_BYTES_BEFORE) / 1024 ))

        # 📌 **Display Real-Time CPU, Memory, and Network Data**
        echo "$(date +"%Y-%m-%d %H:%M:%S"), RX: $RX_DIFF KB, TX: $TX_DIFF KB, Active Algorithm: $CLIENT_ALGO, CPU: $CPU_USAGE%, MEM: $MEM_USAGE KB" | tee -a "$THROUGHPUT_LOG"

        # Update values
        RX_BYTES_BEFORE=$RX_BYTES_AFTER
        TX_BYTES_BEFORE=$TX_BYTES_AFTER

        # Wait for the next update
        sleep 1
    done
done &
#    if [[ -n "$BSSL_PID" && "$BSSL_PID" =~ ^[0-9]+$ ]]; then
        # CPU_USAGE=$(ps -p "$BSSL_PID" -o %cpu --no-headers 2>/dev/null | awk '{printf "%.4f", $1}')
        # MEM_USAGE=$(ps -p "$BSSL_PID" -o rss --no-headers 2>/dev/null | awk '{printf "%.4f", $1}')
#        CPU_USAGE=$(ps au | grep "[b]ssl" | awk "{print \$3}")
#        MEM_USAGE=$(ps au | grep "[b]ssl" | awk "{print \$4}")
#    else
#        CPU_USAGE="0.0"
#        MEM_USAGE="0"
#    fi

    # 📌 **Save CPU & Memory Usage for Analysis**
#    echo "$CPU_USAGE" >> "$TMP_CPU_LOG"
#    echo "$MEM_USAGE" >> "$TMP_MEM_LOG"

    # 📌 **Capture Network Throughput**
#    RX_BYTES_AFTER=$(cat /sys/class/net/$INTERFACE/statistics/rx_bytes)
#    TX_BYTES_AFTER=$(cat /sys/class/net/$INTERFACE/statistics/tx_bytes)

#    RX_DIFF=$(( (RX_BYTES_AFTER - RX_BYTES_BEFORE) / 1024 ))
#    TX_DIFF=$(( (TX_BYTES_AFTER - TX_BYTES_BEFORE) / 1024 ))

#    echo "$(date +"%Y-%m-%d %H:%M:%S"), $RX_DIFF, $TX_DIFF, $CLIENT_ALGO, $CPU_USAGE, $MEM_USAGE" | tee -a "$THROUGHPUT_LOG"

#    RX_BYTES_BEFORE=$RX_BYTES_AFTER
#    TX_BYTES_BEFORE=$TX_BYTES_AFTER
#done &

SERVER_PID=$!
echo "✅ Server started successfully with PID: $SERVER_PID"

wait $SERVER_PID

