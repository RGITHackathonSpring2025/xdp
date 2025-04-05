# XDP Firewall Docker Test Environment

This Docker container provides a testing environment for the XDP-based firewall. The firewall is configured to:
- Allow SSH traffic (port 22)
- Allow HTTP traffic (port 80)
- Block all other TCP traffic
- Allow non-TCP traffic and loopback traffic

## Building the Docker Image

```bash
docker build -t xdp-firewall-test .
```

## Running the Container

You can run the container using docker-compose (recommended):

```bash
docker-compose up -d
```

Or run with Docker directly:

```bash
docker run --privileged -p 80:80 -p 2222:22 -p 18080:8080 -p 9000:9000 -it xdp-firewall-test
```

The `--privileged` flag is required to allow loading of XDP programs.

## Port Mappings

The container maps the following ports:
- Host port 80 → Container port 80 (HTTP, allowed by XDP)
- Host port 2222 → Container port 22 (SSH, allowed by XDP)
- Host port 18080 → Container port 8080 (HTTP on non-standard port, blocked by XDP)
- Host port 9000 → Container port 9000 (Custom TCP service, blocked by XDP)

## Testing the Firewall

Once inside the container, the services will start automatically and the XDP program will be loaded onto the loopback interface.

### If using docker-compose:

Access the running container:
```bash
docker-compose exec xdp-firewall bash
```

### Testing

You can run the automated test script:

```bash
/app/test_firewall.sh
```

Or test manually with these commands:

1. Test HTTP port 80 (should work):
   ```bash
   curl http://localhost:80
   ```

2. Test SSH port 22 (should work):
   ```bash
   nc localhost 22
   ```

3. Test HTTP port 8080 (should be blocked):
   ```bash
   curl http://localhost:8080
   ```

4. Test TCP port 9000 (should be blocked):
   ```bash
   nc localhost 9000
   ```

## Testing from Outside the Container

You can also test the XDP firewall behavior from your host machine:

1. Test HTTP port 80 (should work):
   ```bash
   curl http://localhost:80
   ```

2. Test SSH port 22 (should work):
   ```bash
   nc localhost 2222
   ```

3. Test HTTP port 8080 (should be blocked):
   ```bash
   curl http://localhost:18080
   ```

4. Test TCP port 9000 (should be blocked):
   ```bash
   nc localhost 9000
   ```

## Understanding the Results

- **Port 80 (HTTP)**: Should be accessible because the XDP firewall allows traffic on this port
- **Port 22 (SSH)**: Should be accessible because the XDP firewall allows SSH traffic
- **Port 8080 (HTTP on non-standard port)**: Should be blocked because it's not on port 80
- **Port 9000 (non-HTTP TCP)**: Should be blocked as it's not SSH or HTTP

## Viewing Firewall Logs

To see the filtering decisions made by the XDP program, you can view the logs:

```bash
cat /app/xdp_logs.txt
```

Or follow the logs in real-time:
```bash
tail -f /app/xdp_logs.txt
```

## Troubleshooting

If you encounter issues with loading the XDP program:

1. Check that the container is running with `--privileged`
2. Verify the loopback interface is available: `ip link show`
3. Check BPF verification logs: `dmesg | grep BPF`
4. Verify that the BPF tools are in the PATH: `which bpftool` 