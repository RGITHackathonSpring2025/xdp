#include <linux/bpf.h>
#include <bpf/bpf_helpers.h>
#include <bpf/bpf_endian.h>
#include <linux/if_ether.h> // ETH_P_IP, ethhdr
#include <linux/ip.h>       // iphdr
#include <linux/tcp.h>      // tcphdr
#include <arpa/inet.h>      // Needed for htons if bpf_htons is not available

SEC("xdp")
int xdp_kernel(struct xdp_md *ctx)
{
    void *data_end = (void *)(long)ctx->data_end;
    void *data = (void *)(long)ctx->data;

    struct ethhdr *eth;
    struct iphdr *iph;
    __u32 ip_version;

    eth = data;
    if ((void *)eth + sizeof(*eth) > data_end)
    {
        return XDP_DROP;
    }

    if (eth->h_proto != bpf_htons(ETH_P_IP))
    {
        return XDP_PASS;
    }

    iph = (void *)eth + sizeof(*eth);
    if ((void *)iph + sizeof(*iph) > data_end)
    {
        return XDP_DROP;
    }

    ip_version = iph->version;

    if (ip_version != 4)
    {
        return XDP_PASS;
    }

    if (iph->protocol == IPPROTO_TCP)
    {
        struct tcphdr *tcph;
        tcph = (void *)iph + sizeof(*iph);
        if ((void *)tcph + sizeof(*tcph) > data_end)
        {
            return XDP_DROP;
        }

        __u16 port = bpf_ntohs(tcph->dest);

        if (port == 6942) {
            return XDP_DROP;
        }
        else {
            return XDP_PASS;
        }
    }

    return XDP_PASS;
}

char _license[] SEC("license") = "GPL";
