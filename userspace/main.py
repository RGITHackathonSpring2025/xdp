#!/usr/bin/env python3
from bcc import BPF
import socket
import struct
import sys
import ctypes
import os.path
import netifaces

def get_ipv4_address(interface_name):
    try:
        addresses = netifaces.ifaddresses(interface_name)
        ipv4_info = addresses.get(netifaces.AF_INET)
        if ipv4_info and len(ipv4_info) > 0:
            return ipv4_info[0]['addr']
    except ValueError:
        print(f"Interface {interface_name} not found.")
    return None

if len(sys.argv) < 2:
    print(f"Usage: {sys.argv[0]} <interface>")
    exit(1)

interface_name = sys.argv[1]

bpf = BPF(src_file="./kernel/xdp_kernel.c", cflags=["-Wno-macro-redefined", f"-I{os.path.realpath('./common')}"])
xdp_function = bpf.load_func("xdp_kernel", BPF.XDP)

local_ip_string = get_ipv4_address(interface_name)
local_ip = struct.unpack("<I", socket.inet_aton(local_ip_string))[0]
print(f"Setting local_address to: {local_ip_string} ({hex(local_ip)})")

class Config(ctypes.Structure):
    _fields_ = [("local_address", ctypes.c_int)]

config_map = bpf["config_map"]
config = Config()
config.local_address = local_ip
config_map[ctypes.c_int(0)] = config

bpf.attach_xdp(interface_name, xdp_function, flags=0)
print(f"XDP program attached on {interface_name}")

try:
    print("Press Ctrl+C to quit")
    bpf.trace_print(fmt="{5}")
except KeyboardInterrupt:
    print("Detaching XDP program...")
    bpf.remove_xdp(interface_name, flags=0)
    print("Done")
