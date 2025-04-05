#include <linux/bpf.h>
#include <uapi/linux/ptrace.h>
#include <net/sock.h>
#include <bcc/proto.h>
#include <linux/if_ether.h> // ETH_P_IP, ethhdr
#include <linux/ip.h>       // iphdr
#include <linux/tcp.h>      // tcphdr
#include "config.h"

BPF_ARRAY(config_map, struct config, 1);

int xdp_kernel(struct xdp_md *ctx) {
  void *data_end = (void *)(long)ctx->data_end;
  void *data = (void *)(long)ctx->data;
  struct config *cfg;
  int idx = 0;

  cfg = config_map.lookup(&idx);

  struct ethhdr *eth_header;
  struct iphdr *ip_header;
  struct tcphdr *tcp_header;

  eth_header = data;
  if ((void *)eth_header + sizeof(*eth_header) > data_end) {
    return XDP_DROP;
  }

  if (eth_header->h_proto != bpf_htons(ETH_P_IP)) {
    return XDP_PASS;
  }

  ip_header = (void *)eth_header + sizeof(*eth_header);
  if ((void *)ip_header + sizeof(*ip_header) > data_end) {
    return XDP_DROP;
  }

  if (ip_header->protocol == IPPROTO_TCP) {
    tcp_header = (void *)ip_header + sizeof(*ip_header);
    if ((void *)tcp_header + sizeof(*tcp_header) > data_end) {
      return XDP_DROP;
    }

    __u16 source_port = bpf_ntohs(tcp_header->source);
    __u16 dest_port = bpf_ntohs(tcp_header->dest);

    if (source_port == 22 || dest_port == 22) {
      return XDP_PASS;
    }

    if (cfg == NULL) {
      return XDP_ABORTED; 
    }

    if (ip_header->daddr == cfg->local_address) {
      if (ip_header->saddr == cfg->local_address) return XDP_PASS;
      
      if (dest_port == 80 || dest_port == 443) {
        return XDP_PASS;
      }
      else {
        return XDP_DROP;
      }
    }
  }

  return XDP_PASS; // Pass other packets
}
