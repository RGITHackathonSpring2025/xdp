IFACE ?= wlan0

all: xdp_kernel

xdp_kernel: kernel/*.c
	clang -c -target bpf -D__TARGET_ARCH_x86_64 -Wall -o xdp_kernel ./kernel/xdp_kernel.c

load:
	sudo ip link set dev $(IFACE) xdp obj xdp_kernel sec xdp

unload:
	sudo xdp-loader unload -a $(IFACE)