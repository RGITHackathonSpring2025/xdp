FROM ubuntu:22.04

# Install dependencies
RUN apt-get update && apt-get install -y \
    build-essential \
    clang \
    llvm \
    libelf-dev \
    gcc-multilib \
    linux-headers-generic \
    pkg-config \
    libbpf-dev \
    iproute2 \
    curl \
    python3 \
    nodejs \
    npm \
    netcat \
    iputils-ping \
    tcpdump \
    git \
    linux-tools-generic

# Set up working directory
WORKDIR /app

# Copy XDP program and build tools
COPY kernel/ ./kernel/
COPY Makefile ./

# Verify the XDP program before building
RUN clang -O2 -target bpf -c kernel/xdp_kernel.c -o xdp_kernel_test.o || true
RUN llvm-objdump -S xdp_kernel_test.o || true

# Build the XDP program
RUN make

# Set up test services
RUN mkdir -p /app/services

# HTTP service on port 80
RUN echo '#!/usr/bin/env python3\nimport http.server\nimport socketserver\n\nHandler = http.server.SimpleHTTPRequestHandler\nwith socketserver.TCPServer(("", 80), Handler) as httpd:\n    print("HTTP server running on port 80")\n    httpd.serve_forever()' > /app/services/http_80.py
RUN chmod +x /app/services/http_80.py

# HTTP service on port 8080
RUN echo '#!/usr/bin/env python3\nimport http.server\nimport socketserver\n\nHandler = http.server.SimpleHTTPRequestHandler\nwith socketserver.TCPServer(("", 8080), Handler) as httpd:\n    print("HTTP server running on port 8080")\n    httpd.serve_forever()' > /app/services/http_8080.py
RUN chmod +x /app/services/http_8080.py

# Simple TCP service on port 9000
RUN echo '#!/usr/bin/env python3\nimport socket\n\ns = socket.socket(socket.AF_INET, socket.SOCK_STREAM)\ns.bind(("", 9000))\ns.listen(5)\nprint("TCP service running on port 9000")\nwhile True:\n    conn, addr = s.accept()\n    print(f"Connection from {addr}")\n    conn.send(b"Hello from TCP 9000\\n")\n    conn.close()' > /app/services/tcp_9000.py
RUN chmod +x /app/services/tcp_9000.py

# SSH service simulation on port 22
RUN echo '#!/usr/bin/env python3\nimport socket\n\ns = socket.socket(socket.AF_INET, socket.SOCK_STREAM)\ns.bind(("", 22))\ns.listen(5)\nprint("SSH service simulation running on port 22")\nwhile True:\n    conn, addr = s.accept()\n    print(f"SSH connection from {addr}")\n    conn.send(b"SSH server\\n")\n    conn.close()' > /app/services/ssh_22.py
RUN chmod +x /app/services/ssh_22.py

# Create test script
COPY test.sh /app/
RUN chmod +x /app/test.sh

# Create startup script
COPY start.sh /app/
RUN chmod +x /app/start.sh

# Create a test client script
RUN echo '#!/bin/bash\n\
\n\
# Test HTTP on port 80 (should work)\n\
echo "Testing HTTP on port 80 (should work)..."\n\
if curl -s --connect-timeout 2 http://localhost:80 > /dev/null; then\n\
    echo "SUCCESS: HTTP port 80 is accessible (expected)"\n\
else\n\
    echo "FAIL: HTTP port 80 is not accessible (expected to work)"\n\
fi\n\
\n\
# Test SSH on port 22 (should work)\n\
echo "Testing SSH on port 22 (should work)..."\n\
if echo "" | nc -w 2 localhost 22 > /dev/null; then\n\
    echo "SUCCESS: SSH port 22 is accessible (expected)"\n\
else\n\
    echo "FAIL: SSH port 22 is not accessible (expected to work)"\n\
fi\n\
\n\
# Test HTTP on port 8080 (should be blocked)\n\
echo "Testing HTTP on port 8080 (should be blocked)..."\n\
if curl -s --connect-timeout 2 http://localhost:8080 > /dev/null; then\n\
    echo "FAIL: HTTP port 8080 is accessible (expected to be blocked)"\n\
else\n\
    echo "SUCCESS: HTTP port 8080 is not accessible (expected to be blocked)"\n\
fi\n\
\n\
# Test TCP on port 9000 (should be blocked)\n\
echo "Testing TCP on port 9000 (should be blocked)..."\n\
if echo "" | nc -w 2 localhost 9000 > /dev/null; then\n\
    echo "FAIL: TCP port 9000 is accessible (expected to be blocked)"\n\
else\n\
    echo "SUCCESS: TCP port 9000 is not accessible (expected to be blocked)"\n\
fi\n\
\n\
# Print recent XDP logs\n\
echo "\nRecent XDP logs:"\n\
tail -n 20 /app/xdp_logs.txt 2>/dev/null || echo "No logs available"\n\
\n' > /app/test_firewall.sh
RUN chmod +x /app/test_firewall.sh

ENTRYPOINT ["/app/start.sh"] 