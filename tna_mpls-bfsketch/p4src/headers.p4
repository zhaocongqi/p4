/* -*- P4_16 -*- */

/*************************************************************************
 ************* C O N S T A N T S    A N D   T Y P E S  *******************
**************************************************************************/

#define IPV4        0x0800 // ETHERTYPE_IPV4
#define MPLS        0x8847// ETHERTYPE_IPV4
#define UDP         0x11  // PROTO_UDP
#define TCP         0x06  // PROTO_TCP

/*************************************************************************
 ***********************  H E A D E R S  *********************************
 *************************************************************************/

/*  Define all the headers the program will recognize             */
/*  The actual sets of headers processed by each gress can differ */

header bridge_h {
    bit<48> ingress_mac_tstamp;
}

/* Standard ethernet header */
header ethernet_h {
    bit<48>   dst_addr;
    bit<48>   src_addr;
    bit<16>   ether_type;
}

header ipv4_h {
    bit<4>   version;
    bit<4>   ihl;
    bit<8>   diffserv;
    bit<16>  total_len;
    bit<16>  identification;
    bit<3>   flags;
    bit<13>  frag_offset;
    bit<8>   ttl;
    bit<8>   protocol;
    bit<16>  hdr_checksum;
    bit<32>  src_addr;
    bit<32>  dst_addr;
}

header mpls_h {
    bit<20> label;
    bit<3> exp;
    bit<1> bos;
    bit<8> ttl;
}

header l4port_h {
    bit<16> src_port;
    bit<16> dst_port;
}

header tcp_h {
    bit<32>  seq_no;
    bit<32>  ack_no;
    bit<4>   data_offset;
    bit<4>   res;
    bit<8>   flags;
    bit<16>  window;
    bit<16>  checksum;
    bit<16>  urgent_ptr;
}

header udp_h {
    bit<16>  len;
    bit<16>  checksum;
}

struct my_ingress_headers_t {
    bridge_h     bridge;
    ethernet_h   ethernet;
    mpls_h       mpls;
    ipv4_h       ipv4;
    l4port_h     ports;
    tcp_h        tcp;
    udp_h        udp;
}

struct my_ingress_metadata_t {
}

struct my_egress_headers_t {
    ethernet_h   ethernet;
    mpls_h       mpls;
    ipv4_h       ipv4;
    l4port_h     ports;
    tcp_h        tcp;
    udp_h        udp;
}

struct my_egress_metadata_t {
    bridge_h bridge;
    bit<32> key;
    bit<20> delay;
    bit<1> bloomfilter_flag;
    bit<1> sketch_flag;
}