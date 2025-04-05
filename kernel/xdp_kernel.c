/* 
 * XDP (eXpress Data Path) packet filter program
 * This program inspects and filters network packets at the earliest possible point
 * in the network stack for maximum performance.
 */
#include <linux/bpf.h>
#include <bpf/bpf_helpers.h>
#include <bpf/bpf_endian.h>
#include <linux/if_ether.h> // ETH_P_IP, ethhdr
#include <linux/ip.h>       // iphdr
#include <linux/tcp.h>      // tcphdr
#include <linux/in.h>       // IPPROTO_TCP

// Simplest possible logging to minimize stack usage
#define LOG(msg) bpf_printk(msg)
#define LOG_PORT(msg, port) bpf_printk(msg " %u", port)

/* SEC("xdp") marks this function as an XDP program entry point */
SEC("xdp")
int xdp_kernel(struct xdp_md *ctx)
{
    void *data_end = (void *)(long)ctx->data_end;
    void *data = (void *)(long)ctx->data;
    struct ethhdr *eth = data;
    struct iphdr *iph;
    struct tcphdr *tcph;
    __u16 sport, dport;

    // Boundary check for Ethernet header
    if ((void *)(eth + 1) > data_end) {
        LOG("ETH OOB");
        return XDP_DROP;
    }

    // Only handle IPv4 packets
    if (eth->h_proto != bpf_htons(ETH_P_IP)) {
        return XDP_PASS;
    }

    // Parse IP header
    iph = (struct iphdr *)((void *)eth + sizeof(*eth));
    
    // Boundary check for IP header
    if ((void *)(iph + 1) > data_end) {
        LOG("IP OOB");
        return XDP_DROP;
    }

    // Only handle IPv4
    if (iph->version != 4) {
        return XDP_PASS;
    }

    // Only handle TCP
    if (iph->protocol != IPPROTO_TCP) {
        return XDP_PASS;
    }

    // Parse TCP header
    tcph = (struct tcphdr *)((void *)iph + sizeof(*iph));
    
    // Boundary check for TCP header
    if ((void *)(tcph + 1) > data_end) {
        LOG("TCP OOB");
        return XDP_DROP;
    }

    // Get ports
    sport = bpf_ntohs(tcph->source);
    dport = bpf_ntohs(tcph->dest);

    // For all traffic:
    // Allow any traffic to port SSH (22) or HTTP (80)
    if (dport == 22 || dport == 80) {
        if (dport == 22) {
            LOG("Allow SSH");
        } else {
            LOG("Allow HTTP");
        }
        return XDP_PASS;
    }
    
    // Allow any traffic from port SSH (22) or HTTP (80)
    // This is needed for responses from these services
    if (sport == 22 || sport == 80) {
        if (sport == 22) {
            LOG("Allow SSH response");
        } else {
            LOG("Allow HTTP response");
        }
        return XDP_PASS;
    }

    // Block all other TCP traffic
    LOG_PORT("Block port", dport);
    return XDP_DROP;
}

/* License declaration required for BPF programs */
char _license[] SEC("license") = "GPL";
