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
#include <arpa/inet.h>      // Needed for bpf_htons if bpf_htons is not available

/* SEC("xdp") marks this function as an XDP program entry point */
SEC("xdp")
int xdp_kernel(struct xdp_md *ctx)
{
    bpf_printk("XDP program started - processing new packet");
    
    /* Access the packet data and boundaries */
    void *data_end = (void *)(long)ctx->data_end;
    void *data = (void *)(long)ctx->data;

    struct ethhdr *eth;
    struct iphdr *iph;
    __u32 ip_version;

    /* Parse Ethernet header */
    eth = (struct ethhdr *)data;
    /* Boundary check for Ethernet header */
    if ((void *)eth + sizeof(*eth) > data_end)
    {
        /* Malformed packet, drop it */
        bpf_printk("Malformed packet: Ethernet header out of bounds");
        return XDP_DROP;
    }

    bpf_printk("Ethernet header parsed: src_mac=%pM dst_mac=%pM eth_type=0x%x", 
               eth->h_source, eth->h_dest, bpf_ntohs(eth->h_proto));

    /* Only handle IPv4 packets, pass everything else */
    if (eth->h_proto != bpf_htons(ETH_P_IP))
    {
        bpf_printk("Non-IPv4 packet detected (protocol=0x%x), passing", bpf_ntohs(eth->h_proto));
        return XDP_PASS;
    }

    /* Parse IP header */
    iph = (struct iphdr *)((void *)eth + sizeof(*eth));
    /* Boundary check for IP header */
    if ((void *)iph + sizeof(*iph) > data_end)
    {
        /* Malformed packet, drop it */
        bpf_printk("Malformed packet: IP header out of bounds");
        return XDP_DROP;
    }

    /* Extract IP version */
    ip_version = iph->version;

    /* Ensure we're dealing with IPv4 */
    if (ip_version != 4)
    {
        bpf_printk("Non-IPv4 packet detected (version=%d), passing", ip_version);
        return XDP_PASS;
    }

    bpf_printk("IPv4 packet: src=%u dst=%u proto=%d ttl=%d", 
               iph->saddr, iph->daddr, iph->protocol, iph->ttl);

    /* Handle TCP packets */
    if (iph->protocol == IPPROTO_TCP)
    {
        bpf_printk("TCP packet detected");
        struct tcphdr *tcph;
        /* Parse TCP header */
        tcph = (struct tcphdr *)((void *)iph + sizeof(*iph));
        /* Boundary check for TCP header */
        if ((void *)tcph + sizeof(*tcph) > data_end)
        {
            /* Malformed packet, drop it */
            bpf_printk("Malformed packet: TCP header out of bounds");
            return XDP_DROP;
        }

        /* Extract source and destination ports */
        __u16 sport = bpf_ntohs(tcph->source);
        __u16 port = bpf_ntohs(tcph->dest);
        
        bpf_printk("TCP header: src_port=%d dst_port=%d seq=%u ack=%u flags=%x",
                   sport, port, bpf_ntohl(tcph->seq), bpf_ntohl(tcph->ack_seq),
                   (tcph->fin | (tcph->syn << 1) | (tcph->rst << 2) | 
                   (tcph->psh << 3) | (tcph->ack << 4) | (tcph->urg << 5)));
        
        /* Access the TCP payload */
        char *payload = (char *)((void *)tcph + tcph->doff * 4);
        /* Boundary check for payload pointer */
        if (payload > (char *)data_end)
        {
            /* Log error and drop the packet if payload pointer is out of bounds */
            bpf_printk("Payload pointer is beyond data_end: %p > %p", payload, data_end);
            return XDP_DROP;
        }

        /* Calculate payload size */
        __u32 payload_size = (char *)data_end - payload;
        bpf_printk("TCP payload size: %d bytes", payload_size);
        
        /* Allow loopback traffic (same source and destination IP) */
        if (iph->saddr == iph->daddr)
        {
            bpf_printk("Allowing loopback traffic %u:%d -> %u:%d", 
                      iph->saddr, sport, iph->daddr, port);
            return XDP_PASS;
        }
        
        /* Always allow SSH traffic (port 22) */
        if (port == 22) {
            bpf_printk("Allowing SSH traffic (port 22)");
            return XDP_PASS;
        }

        /* Log information about packets with payload */
        if (payload_size > 0)
        {
            bpf_printk("Packet with payload: %u:%d -> %u:%d size=%d", 
                      iph->saddr, sport, iph->daddr, port, payload_size);
        }

        /* Traffic filtering based on destination port:
         * - Allow port 80 (HTTP)
         * - Block all other ports
         */
        if (port != 80)
        {
            bpf_printk("Blocking traffic to port %d (not HTTP)", port);
            return XDP_DROP;
        }
        else
        {
            bpf_printk("Allowing HTTP traffic (port 80)");
            return XDP_PASS;
        }
    }

    /* Pass all non-TCP packets */
    bpf_printk("Non-TCP packet (protocol=%d), passing", iph->protocol);
    return XDP_PASS;
}

/* License declaration required for BPF programs */
char _license[] SEC("license") = "GPL";
