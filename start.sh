#!/bin/bash
# Mount debug filesystem for BPF logging
mount -t debugfs debugfs /sys/kernel/debug 2>/dev/null || true

echo "Starting services..."
python3 /app/services/http_80.py & 
python3 /app/services/http_8080.py & 
python3 /app/services/tcp_9000.py & 
python3 /app/services/ssh_22.py & 
echo "Services started"

echo "Loading XDP program..."
# Ensure bpftool is in PATH
export PATH=$PATH:/usr/lib/linux-tools/$(uname -r)

# Apply XDP to loopback interface
ip link set dev lo xdp obj xdp_kernel sec xdp
echo "XDP program loaded on loopback interface"

# Apply XDP to container's network interface (eth0)
ip link set dev eth0 xdp obj xdp_kernel sec xdp
echo "XDP program loaded on external interface"

# Start log capture in background
echo "Starting log capture..."
mkdir -p /sys/kernel/debug/tracing 2>/dev/null || true
cat /sys/kernel/debug/tracing/trace_pipe > /app/xdp_logs.txt 2>/dev/null & 
LOG_PID=$!

echo "Test commands:"
echo "- curl http://localhost:80 (should work - allowed HTTP port)"
echo "- nc localhost 22 (should work - allowed SSH port)"
echo "- curl http://localhost:8080 (should be blocked)"
echo "- nc localhost 9000 (should be blocked)"
echo "
View logs: cat /app/xdp_logs.txt"
echo "Run tests: /app/test_firewall.sh"

# Keep container running
tail -f /dev/null 