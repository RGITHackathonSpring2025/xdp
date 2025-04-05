#!/bin/bash

# Get container IP address
CONTAINER_IP=$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' xdp-container)

echo "Container IP: $CONTAINER_IP"
echo "Testing firewall rules from host..."
echo

# Test HTTP on port 80 (should work)
echo "Testing HTTP on port 80 (should work)..."
if curl -s --connect-timeout 2 http://$CONTAINER_IP:80 > /dev/null; then
    echo "SUCCESS: HTTP port 80 is accessible (expected)"
else
    echo "FAIL: HTTP port 80 is not accessible (expected to work)"
fi

# Test SSH on port 22 (should work)
echo "Testing SSH on port 22 (should work)..."
if timeout 2 bash -c "</dev/tcp/$CONTAINER_IP/22" 2>/dev/null; then
    echo "SUCCESS: SSH port 22 is accessible (expected)"
else
    echo "FAIL: SSH port 22 is not accessible (expected to work)"
fi

# Test HTTP on port 8080 (should be blocked)
echo "Testing HTTP on port 8080 (should be blocked)..."
if curl -s --connect-timeout 2 http://$CONTAINER_IP:8080 > /dev/null; then
    echo "FAIL: HTTP port 8080 is accessible (expected to be blocked)"
else
    echo "SUCCESS: HTTP port 8080 is not accessible (expected to be blocked)"
fi

# Test TCP on port 9000 (should be blocked)
echo "Testing TCP on port 9000 (should be blocked)..."
if timeout 2 bash -c "</dev/tcp/$CONTAINER_IP/9000" 2>/dev/null; then
    echo "FAIL: TCP port 9000 is accessible (expected to be blocked)"
else
    echo "SUCCESS: TCP port 9000 is not accessible (expected to be blocked)"
fi

echo
echo "Test completed" 