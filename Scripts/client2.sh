#!/bin/bash

# --- Default Parameters ---
SERVER_IP=${1:-10.45.0.12}
PORT=${2:-4433}
KEM_ALG=${3:-mlkem768}
SIG_ALG=${4:-falcon512}
PACKET_SIZE=${5:-512}
NUM_MESSAGES=${6:-10}
NUM_HANDSHAKES=${7:-5}
CONCURRENCY=${8:-1}
CLIENT_IP="10.45.0.13"   # Adjust as needed

# --- Logging Setup ---
LOG_TIMESTAMP=$(date +"%Y%m%d_%H%M%S")_$(shuf -i 1000-9999 -n 1)
#LOG_TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
LOG_DIR="client_logs/kem_${KEM_ALG}_sig_${SIG_ALG}_concurrency_${CONCURRENCY}_pkt$_{PACKET_SIZE}_${LOG_TIMESTAMP}"
mkdir -p "$LOG_DIR"

HANDSHAKE_LOG="$LOG_DIR/tls_handshake_times.txt"
MESSAGE_LOG="$LOG_DIR/message_latency_throughput.txt"
CPU_LOG="$LOG_DIR/cpu_usage.log"
MEM_LOG="$LOG_DIR/memory_usage.log"
ALL_VALUES="$LOG_DIR/all_values_client.log"
#LOG_FILE="$LOG_DIR/bssl_client_tmux_${KEM_ALG}${SIG_ALG}${LOG_TIMESTAMP}.log"

# PCAP Setup
PCAP_DIR="/home/sanzida/Downloads/boringssl/build/pcaps"
mkdir -p "$PCAP_DIR"
PCAP_FILE="$PCAP_DIR/kem_${KEM_ALG}_sig_${SIG_ALG}_concurrency_${CONCURRENCY}_${LOG_TIMESTAMP}.pcap"
sudo ip route add default dev uesimtun0
# Cleanup function
cleanup() {
    echo "🛑 Cleaning up..."
#    tmux kill-session -t "$SESSION_NAME" 2>/dev/null
    sudo kill "$TCPDUMP_PID" 2>/dev/null
    wait "$TCPDUMP_PID" 2>/dev/null
}
trap cleanup EXIT

echo "=========================="
echo " Starting BoringSSL Client "
echo "=========================="
echo "Server: $SERVER_IP | Port: $PORT"
echo "KEM: $KEM_ALG | SIG: $SIG_ALG"
echo "Packet Size: $PACKET_SIZE"
echo "Messages: $NUM_MESSAGES"
echo "Number of Handshakes: $NUM_HANDSHAKES"
echo "Logs stored in: $LOG_DIR"

# Start tcpdump
echo "📡 Starting tcpdump on interface uesimtun0..."
sudo tcpdump -i uesimtun0 -w "$PCAP_FILE" > /dev/null 2>&1 &
TCPDUMP_PID=$!

# Touch logs
touch "$HANDSHAKE_LOG" "$MESSAGE_LOG" "$CPU_LOG" "$MEM_LOG" "$ALL_VALUES"

# CPU/Memory Monitoring (optional)
# nohup top -b -d 10 | grep "bssl" > "$CPU_LOG" 2>&1 &

# --- TLS Handshake Test ---
TOTAL_HANDSHAKE_TIME=0
for i in $(seq 1 $NUM_HANDSHAKES); do
    START_TIME=$(date +%s%N)
    #echo "QUIT" | tool/bssl client -curves "$KEM_ALG" -sigalgs "$SIG_ALG" -connect "$SERVER_IP:$PORT" -debug >> "$LOG_DIR/handshake_debug.log"
    echo "QUIT" | tool/bssl client -curves "$KEM_ALG" -sigalgs "$SIG_ALG" -connect "$SERVER_IP:$PORT" -debug >> "$LOG_DIR/handshake_debug.log" 2>&1
    END_TIME=$(date +%s%N)
    HANDSHAKE_TIME_MS=$(( (END_TIME - START_TIME) / 1000000 ))
    echo "$i th Handshake"
    echo "$HANDSHAKE_TIME_MS" >> "$HANDSHAKE_LOG"
    TOTAL_HANDSHAKE_TIME=$((TOTAL_HANDSHAKE_TIME + HANDSHAKE_TIME_MS))
    sleep 0.2
done
AVG_HANDSHAKE_TIME=$((TOTAL_HANDSHAKE_TIME / NUM_HANDSHAKES))
echo "✅ Average TLS Handshake Latency: $AVG_HANDSHAKE_TIME ms" | tee -a "$ALL_VALUES"
echo "$AVG_HANDSHAKE_TIME" > "$LOG_DIR/avg_tls_handshake_latency.txt"

# --- Message Transmission Test ---
#TOTAL_LATENCY=0
#TOTAL_BYTES_SENT=0
#echo "Timestamp, Latency (ms), Throughput (KB/s)" > "$MESSAGE_LOG"

# Launch client
#SESSION_NAME="bssl_client_session"
#tmux new-session -d -s "$SESSION_NAME"
#tmux send-keys -t "$SESSION_NAME" "tool/bssl client -curves $KEM_ALG -sigalgs $SIG_ALG -connect $SERVER_IP:$PORT" C-m
#sleep 3

#for i in $(seq 1 $NUM_MESSAGES); do
#    MSG=$(head -c $PACKET_SIZE </dev/urandom | base64 | tr -d '\n')
#    START_TIME=$(date +%s%N)
#    tmux send-keys -t "$SESSION_NAME" "$MSG" C-m
#    END_TIME=$(date +%s%N)
#    LATENCY_MS=$(( (END_TIME - START_TIME) / 1000000 ))
#    TOTAL_LATENCY=$((TOTAL_LATENCY + LATENCY_MS))
#    TOTAL_BYTES_SENT=$((TOTAL_BYTES_SENT + PACKET_SIZE))
#    THROUGHPUT=$((TOTAL_BYTES_SENT / 1024))
#    echo "$(date +"%Y-%m-%d %H:%M:%S"), $LATENCY_MS, $THROUGHPUT KB/s" >> "$MESSAGE_LOG"
#    sleep 1
#done

# --- Analyze PCAP for Bandwidth and TLS Info ---
if [ -f "$PCAP_FILE" ]; then
    echo "📈 Analyzing PCAP..." | tee -a "$ALL_VALUES"

    FIRST=$(tshark -r "$PCAP_FILE" -T fields -e frame.time_relative | head -n 1)
    LAST=$(tshark -r "$PCAP_FILE" -T fields -e frame.time_relative | tail -n 1)
    DURATION=$(echo "$LAST - $FIRST" | bc)

    if (( $(echo "$DURATION > 0" | bc -l) )); then
        TX_BYTES=$(tshark -r "$PCAP_FILE" -Y "ip.src == $CLIENT_IP && ip.dst == $SERVER_IP" -T fields -e frame.len | awk '{sum+=$1} END {print sum}')
        RX_BYTES=$(tshark -r "$PCAP_FILE" -Y "ip.src == $SERVER_IP && ip.dst == $CLIENT_IP" -T fields -e frame.len | awk '{sum+=$1} END {print sum}')
        TOTAL_BYTES=$((TX_BYTES + RX_BYTES))

        AVG_TX_KBPS=$(echo "scale=2; $TX_BYTES / $DURATION / 1024" | bc)
        AVG_RX_KBPS=$(echo "scale=2; $RX_BYTES / $DURATION / 1024" | bc)
        AVG_TOTAL_KBPS=$(echo "scale=2; $TOTAL_BYTES / $DURATION / 1024" | bc)

        echo "📊 Bandwidth:" | tee -a "$ALL_VALUES"
        echo "    TX: $AVG_TX_KBPS KB/s, RX: $AVG_RX_KBPS KB/s, Total: $AVG_TOTAL_KBPS KB/s" | tee -a "$ALL_VALUES"

        # RTT
        RTT_STATS=$(tshark -r "$PCAP_FILE" -Y "tcp.analysis.ack_rtt" -T fields -e tcp.analysis.ack_rtt | awk '
            BEGIN {min=99999; max=0; sum=0; count=0}
            {rtt=$1+0; sum+=rtt; count++; if(rtt>max) max=rtt; if(rtt<min) min=rtt}
            END {
                if (count>0) {
                    print "RTT Min: " min "s, Max: " max "s, Avg: " sum/count "s"
                } else {
                    print "RTT not available"
                }
            }')
        echo "📌 $RTT_STATS" | tee -a "$ALL_VALUES"

        # TLS handshake duration
        HANDSHAKE_START=$(tshark -r "$PCAP_FILE" -Y "tls.handshake.type == 1" -T fields -e frame.time_relative | head -n1)
        HANDSHAKE_END=$(tshark -r "$PCAP_FILE" -Y "tls.handshake.type == 20" -T fields -e frame.time_relative | head -n1)
        if [[ -n "$HANDSHAKE_START" && -n "$HANDSHAKE_END" ]]; then
            HANDSHAKE_DURATION=$(echo "$HANDSHAKE_END - $HANDSHAKE_START" | bc)
            echo "📌 TLS Handshake Duration (from PCAP): ${HANDSHAKE_DURATION}s" | tee -a "$ALL_VALUES"
        fi

        # Total packets
        TOTAL_PACKETS=$(tshark -r "$PCAP_FILE" | wc -l)
        echo "📦 Total Packets: $TOTAL_PACKETS" | tee -a "$ALL_VALUES"

        # Packet size distribution
        echo "📦 Packet Size Distribution (Top 5):" | tee -a "$ALL_VALUES"
        tshark -r "$PCAP_FILE" -T fields -e frame.len | sort -n | uniq -c | sort -nr | head -5 | tee -a "$ALL_VALUES"

        # Errors and TLS info
        RETRANSMISSIONS=$(tshark -r "$PCAP_FILE" -Y "tcp.analysis.retransmission" | wc -l)
        TLS_ERRORS=$(tshark -r "$PCAP_FILE" -Y "tls.record.content_type == 255" | wc -l)
        echo "🔁 Retransmissions: $RETRANSMISSIONS" | tee -a "$ALL_VALUES"
        echo "🚨 TLS Errors: $TLS_ERRORS" | tee -a "$ALL_VALUES"

        echo "🔐 TLS Versions & Ciphers Observed:" | tee -a "$ALL_VALUES"
        tshark -r "$PCAP_FILE" -Y "tls.handshake.ciphersuite" -T fields -e tls.record.version -e tls.handshake.ciphersuite | sort | uniq | tee -a "$ALL_VALUES"
    fi
else
    echo "❌ PCAP not found." | tee -a "$ALL_VALUES"
fi
