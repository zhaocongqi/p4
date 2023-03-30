/* -*- P4_16 -*- */

#include <core.p4>
#include <tna.p4>

/*************************************************************************
 ************* C O N S T A N T S    A N D   T Y P E S  *******************
**************************************************************************/
#define IPV4        0x0800 // ETHERTYPE_IPV4
#define TCP         0x06   // PROTO_TCP
#define UDP         0x11   // PROTO_UDP
typedef bit<48>     mac_addr_t;
typedef bit<32>     ipv4_addr_t;
typedef bit<16>     l4_port_t;
typedef bit<32>     pkt_num_t;

/*************************************************************************
 ***********************  H E A D E R S  *********************************
 *************************************************************************/

/*  Define all the headers the program will recognize             */
/*  The actual sets of headers processed by each gress can differ */

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

/*** Internal Headers ***/

typedef bit<4> header_type_t; 
typedef bit<4> header_info_t; 

const header_type_t HEADER_TYPE_BRIDGE         = 0xB;
const header_type_t HEADER_TYPE_MIRROR_INGRESS = 0xC;
const header_type_t HEADER_TYPE_MIRROR_EGRESS  = 0xD;
const header_type_t HEADER_TYPE_RESUBMIT       = 0xA;

/* 
 * This is a common "preamble" header that must be present in all internal
 * headers. The only time you do not need it is when you know that you are
 * not going to have more than one internal header type ever
 */

#define INTERNAL_HEADER         \
    header_type_t header_type;  \
    header_info_t header_info


header inthdr_h {
    INTERNAL_HEADER;
}

/* Bridged metadata */
header bridge_h {
    INTERNAL_HEADER;
    
#ifdef FLEXIBLE_HEADERS
    @flexible    PortId_t  ingress_port;
#else
    bit<7> pad0; PortId_t ingress_port;
#endif
}

/* Ingress mirroring information */
const bit<3> ING_PORT_MIRROR = 0;  /* Choose between different mirror types */

header ing_port_mirror_h {
    INTERNAL_HEADER;
    
#ifdef FLEXIBLE_HEADERS    
    @flexible     PortId_t    ingress_port;
    @flexible     MirrorId_t  mirror_session;
    @flexible     bit<48>     ingress_mac_tstamp;
    @flexible     bit<48>     ingress_global_tstamp;
#else
    bit<7> pad0;  PortId_t    ingress_port;
    bit<6> pad1;  MirrorId_t  mirror_session;
                  bit<48>     ingress_mac_tstamp;
                  bit<48>     ingress_global_tstamp;    
#endif
}

/* 
 * Custom to-cpu header. This is not an internal header, but it contains 
 * the same information, because it is useful to the control plane
 * Note, that we cannot use @flexible annotation here, since these packets
 * do appear on the wire and thus must have deterministic header format
 */
header to_cpu_h {
    INTERNAL_HEADER;
    bit<6>    pad0; MirrorId_t  mirror_session;
    bit<7>    pad1; PortId_t    ingress_port;
                    bit<48>     ingress_mac_tstamp;
                    bit<48>     ingress_global_tstamp;
                    bit<48>     egress_global_tstamp;
                    bit<16>     pkt_length;
}

header mirror_ack_h {
    bit<48>     tstamp;
}

/*************************************************************************
 **************  I N G R E S S   P R O C E S S I N G   *******************
 *************************************************************************/
 
    /***********************  H E A D E R S  ************************/

struct my_ingress_headers_t {
    bridge_h           bridge;
    ethernet_h         ethernet;
    ipv4_h             ipv4;
    l4port_h           ports;
    tcp_h              tcp;
    udp_h              udp;  
}

    /******  G L O B A L   I N G R E S S   M E T A D A T A  *********/

struct my_ingress_metadata_t {
    header_type_t  mirror_header_type;
    header_info_t  mirror_header_info;
    PortId_t       ingress_port;
    MirrorId_t     mirror_session;
    bit<48>        ingress_mac_tstamp;
    bit<48>        ingress_global_tstamp;
    bit<1>         ipv4_csum_err;
    bit<16>            pkt_len;
    bit<32>            data_len;
    bit<32>            hash;
    bit<32>            nextseq;
    bit<8>             flag;
    bit<8>             next;
}

    /***********************  P A R S E R  **************************/
parser IngressParser(packet_in        pkt,
    /* User */    
    out my_ingress_headers_t          hdr,
    out my_ingress_metadata_t         meta,
    /* Intrinsic */
    out ingress_intrinsic_metadata_t  ig_intr_md)
{
    Checksum() ipv4_checksum;
    
    /* This is a mandatory state, required by Tofino Architecture */
    state start {
        pkt.extract(ig_intr_md);
        pkt.advance(PORT_METADATA_SIZE);
        transition init_meta;
    }

    state init_meta {
        meta = { 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 };

        hdr.bridge.setValid();
        hdr.bridge.header_type  = HEADER_TYPE_BRIDGE;
        hdr.bridge.header_info  = 0;

#ifndef FLEXIBLE_HEADERS
        hdr.bridge.pad0 = 0;
#endif
        hdr.bridge.ingress_port = ig_intr_md.ingress_port; 
        
        transition parse_ethernet;
    }
    
    state parse_ethernet {
        pkt.extract(hdr.ethernet);
        transition select(hdr.ethernet.ether_type) {
            IPV4 :  parse_ipv4;
            default: reject;
        }
    }

    state parse_ipv4 {
        pkt.extract(hdr.ipv4);
        ipv4_checksum.add(hdr.ipv4);
        meta.ipv4_csum_err = (bit<1>)ipv4_checksum.verify();
        meta.pkt_len = hdr.ipv4.total_len;
        transition select(hdr.ipv4.frag_offset, hdr.ipv4.protocol) {
            ( 0, TCP  ) : parse_tcp;
            ( 0, UDP  ) : parse_udp;
            default : reject;
        }
    }

    state parse_tcp {
        pkt.extract(hdr.ports);
        pkt.extract(hdr.tcp);
        transition accept;
    }
    
    state parse_udp {
        pkt.extract(hdr.ports);
        pkt.extract(hdr.udp);
        transition accept;
    }

}

    /***************** M A T C H - A C T I O N  *********************/

control Ingress(
    /* User */
    inout my_ingress_headers_t                       hdr,
    inout my_ingress_metadata_t                      meta,
    /* Intrinsic */
    in    ingress_intrinsic_metadata_t               ig_intr_md,
    in    ingress_intrinsic_metadata_from_parser_t   ig_prsr_md,
    inout ingress_intrinsic_metadata_for_deparser_t  ig_dprsr_md,
    inout ingress_intrinsic_metadata_for_tm_t        ig_tm_md)
{
    bit<8>          ttl_dec = 0;

    /*********** NEXTHOP ************/
    action send(PortId_t port) {
        ig_tm_md.ucast_egress_port = port;
    }

    action drop() {
        ig_dprsr_md.drop_ctl = 1;
    }

    action l3_switch(PortId_t port, bit<48> new_mac_da, bit<48> new_mac_sa) {
        hdr.ethernet.dst_addr = new_mac_da;
        hdr.ethernet.src_addr = new_mac_sa;
        ttl_dec = 1;
        send(port); 
    }

    table simple_fwd {
        key = {
            ig_intr_md.ingress_port : exact;
        }
        actions = {
            send; drop; NoAction;
        }
        const default_action = NoAction();
        size = 64;
    }

    /********* MIRRORING ************/
    action acl_mirror(MirrorId_t mirror_session) {
        ig_dprsr_md.mirror_type = ING_PORT_MIRROR;

        meta.mirror_header_type = HEADER_TYPE_MIRROR_INGRESS;
        meta.mirror_header_info = (header_info_t)ING_PORT_MIRROR;

        meta.ingress_port   = ig_intr_md.ingress_port;
        meta.mirror_session = mirror_session;
        
        meta.ingress_mac_tstamp    = ig_intr_md.ingress_mac_tstamp;
        meta.ingress_global_tstamp = ig_prsr_md.global_tstamp;
    }

    action acl_drop_and_mirror(MirrorId_t mirror_session) {
        acl_mirror(mirror_session);
        drop();
    }

    action get_nextSeq(){
        meta.nextseq = meta.data_len + hdr.tcp.seq_no;
    }
    
    table port_acl {
        key = {
            ig_intr_md.ingress_port : ternary;
        }
        actions = {
            acl_mirror; acl_drop_and_mirror; drop; NoAction;
        }
        size = 512;
        default_action = NoAction();
    }

    CRCPolynomial<bit<32>>(
        coeff    = 0x04C11DB7,
        reversed = true,
        msb      = false,
        extended = false,
        init     = 0xFFFFFFFF,
        xor      = 0xFFFFFFFF) poly;
    Hash<bit<32>>(HashAlgorithm_t.CUSTOM, poly) hash_algo;

    action hash(){
        meta.hash = hash_algo.get({ hdr.ipv4.src_addr,hdr.ipv4.dst_addr,hdr.ipv4.protocol,hdr.ports.src_port,hdr.ports.dst_port });
    }

    Register<bit<32>, bit<32>>(16,0) NextSeq;

    RegisterAction<bit<32>, bit<32>, bit<1>>(NextSeq)
    get_seq = {
        void apply(inout bit<32> register_data, out bit<1> result) {
            if(register_data != hdr.tcp.seq_no){
                if(meta.nextseq > register_data){
                    register_data = meta.nextseq;
                }
                result = 0x1;
            }else{
                register_data = meta.nextseq;
                result = 0x0;
            }
        }
    };

    Register<bit<8>, bit<32>>(16) Flag;

    RegisterAction<bit<8>, bit<32>, bit<1>>(Flag)
    get_flag1 = {
        void apply(inout bit<8> register_data, out bit<1> result) {
            if(register_data == 0xFE){
                register_data = 0xFE;
                result = 0x1;
            }else{
                register_data = 0xFD;
                result = 0x0;
            }
        }
    };

    RegisterAction<bit<8>, bit<32>, bit<1>>(Flag)
    get_flag2 = {
        void apply(inout bit<8> register_data, out bit<1> result) {
            if(register_data == 0x0){
                register_data = 0xFD;
                result = 0x0;
            }else{
                register_data = register_data |+| 0x01;
                result = 0x1;
            }
        }
    };


    Register<bit<8>, bit<32>>(16) flag;

    RegisterAction<bit<8>, bit<32>, bit<1>>(flag)
    get_flag3 = {
        void apply(inout bit<8> register_data, out bit<1> result) {
            register_data = meta.flag;
        }
    };

    Register<bit<8>, bit<32>>(16,0) nextseq;

    RegisterAction<bit<8>, bit<32>, bit<1>>(nextseq)
    get_seq1 = {
        void apply(inout bit<8> register_data, out bit<1> result) {
            register_data = meta.next;
        }
    };
    
    apply {
        /* Mirroring */
        port_acl.apply();

        if (ig_prsr_md.parser_err == 0) {
            if (hdr.ipv4.isValid() && hdr.tcp.isValid()) {
                if (meta.ipv4_csum_err == 0 && hdr.ipv4.ttl > 1) {
                    simple_fwd.apply();
                }

                hash();
                meta.data_len = (bit<32>)meta.pkt_len - 0x45000028;
                get_nextSeq();
                bit<1> flag1 = get_seq.execute(0);
                bit<1> flag2 = 0;
                if(flag1 == 0){
                    flag2 = get_flag1.execute(0);
                }else{
                    flag2 = get_flag2.execute(0);
                }
                meta.next = (bit<8>)flag1;
                meta.flag = (bit<8>)flag2;

                get_seq1.execute(0);
                get_flag3.execute(0);
                if(flag2 == 0){
                    ig_dprsr_md.mirror_type = 1;
                }
                
            }else{
                drop();
            }
        }else{
            drop();
        }

    }
    
}

    /*********************  D E P A R S E R  ************************/
control IngressDeparser(packet_out pkt,
    /* User */
    inout my_ingress_headers_t                       hdr,
    in    my_ingress_metadata_t                      meta,
    /* Intrinsic */
    in    ingress_intrinsic_metadata_for_deparser_t  ig_dprsr_md)
{
    Checksum() ipv4_checksum; 
    Mirror()   ing_port_mirror;

    apply {
        /* 
         * If there is a mirror request, create a clone. 
         * Note: Mirror() externs emits the provided header, but also
         * appends the ORIGINAL ingress packet after those
         */
        if (ig_dprsr_md.mirror_type == ING_PORT_MIRROR) {
            ing_port_mirror.emit<ing_port_mirror_h>(
                meta.mirror_session,
                {
                    meta.mirror_header_type, meta.mirror_header_info,
#ifndef FLEXIBLE_HEADERS
                    0, /* pad0 */
#endif
                    meta.ingress_port,
#ifndef FLEXIBLE_HEADERS
                    0, /* pad1 */
#endif
                    meta.mirror_session,
                    meta.ingress_mac_tstamp, meta.ingress_global_tstamp
                });
        }

        /* Update the IPv4 checksum first. Why not in the egress deparser? */
        hdr.ipv4.hdr_checksum = ipv4_checksum.update({
                hdr.ipv4.version,
                hdr.ipv4.ihl,
                hdr.ipv4.diffserv,
                hdr.ipv4.total_len,
                hdr.ipv4.identification,
                hdr.ipv4.flags,
                hdr.ipv4.frag_offset,
                hdr.ipv4.ttl,
                hdr.ipv4.protocol,
                hdr.ipv4.src_addr,
                hdr.ipv4.dst_addr
            });
        /* Deparse the regular packet with bridge metadata header prepended */
        pkt.emit(hdr);
    }
}


/*************************************************************************
 ****************  E G R E S S   P R O C E S S I N G   *******************
 *************************************************************************/

    /***********************  H E A D E R S  ************************/

struct my_egress_headers_t {
    ethernet_h   cpu_ethernet;
    to_cpu_h     to_cpu;
    ethernet_h   ethernet;
    ipv4_h       ipv4;
    l4port_h     ports;
    tcp_h        tcp;
    udp_h        udp;
    mirror_ack_h mirror_ack;
}

    /********  G L O B A L   E G R E S S   M E T A D A T A  *********/

struct my_egress_metadata_t {
    bridge_h           bridge;
    ing_port_mirror_h  ing_port_mirror;
    bit<16>            pkt_len;
    bit<32>            data_len;
    bit<32>            hash;
    bit<32>            nextseq;
    bit<8>             flag;
    bit<8>             next;
}

    /***********************  P A R S E R  **************************/

parser EgressParser(packet_in        pkt,
    /* User */
    out my_egress_headers_t          hdr,
    out my_egress_metadata_t         meta,
    /* Intrinsic */
    out egress_intrinsic_metadata_t  eg_intr_md)
{
    inthdr_h inthdr;
    
    /* This is a mandatory state, required by Tofino Architecture */
    state start {
        pkt.extract(eg_intr_md);
        inthdr = pkt.lookahead<inthdr_h>();
           
        transition select(inthdr.header_type, inthdr.header_info) {
            ( HEADER_TYPE_BRIDGE,         _ ) :
                           parse_bridge;
            ( HEADER_TYPE_MIRROR_INGRESS, (header_info_t)ING_PORT_MIRROR ):
                           parse_ing_port_mirror;
            default : reject;
        }
    }

    state parse_bridge {
        pkt.extract(meta.bridge);
        transition parse_ethernet;
    }

    state parse_ing_port_mirror {
        pkt.extract(meta.ing_port_mirror);
        transition parse_ethernet;
    }

    state parse_ethernet {
        pkt.extract(hdr.ethernet);
        transition select(hdr.ethernet.ether_type) {
            IPV4 :  parse_ipv4;
            default: reject;
        }
    }

    state parse_ipv4 {
        pkt.extract(hdr.ipv4);
        meta.pkt_len = hdr.ipv4.total_len;
        transition select(hdr.ipv4.frag_offset, hdr.ipv4.protocol) {
            ( 0, TCP  ) : parse_tcp;
            ( 0, UDP  ) : parse_udp;
            default : reject;
        }
    }

    state parse_tcp {
        pkt.extract(hdr.ports);
        pkt.extract(hdr.tcp);
        transition accept;
    }
    
    state parse_udp {
        pkt.extract(hdr.ports);
        pkt.extract(hdr.udp);
        transition accept;
    }
}

    /***************** M A T C H - A C T I O N  *********************/

control Egress(
    /* User */
    inout my_egress_headers_t                          hdr,
    inout my_egress_metadata_t                         meta,
    /* Intrinsic */    
    in    egress_intrinsic_metadata_t                  eg_intr_md,
    in    egress_intrinsic_metadata_from_parser_t      eg_prsr_md,
    inout egress_intrinsic_metadata_for_deparser_t     eg_dprsr_md,
    inout egress_intrinsic_metadata_for_output_port_t  eg_oport_md)
{
    action drop() {
        eg_dprsr_md.drop_ctl = 1;
    }

    action just_send() {
        mac_addr_t  tmp_mac  = hdr.ethernet.src_addr;
        ipv4_addr_t tmp_ipv4 = hdr.ipv4.src_addr;
        l4_port_t tmp_port = hdr.ports.src_port;

        hdr.ethernet.src_addr = hdr.ethernet.dst_addr;
        hdr.ethernet.dst_addr = tmp_mac;

        hdr.ipv4.src_addr = hdr.ipv4.dst_addr;
        hdr.ipv4.dst_addr = tmp_ipv4;

        hdr.ports.src_port = hdr.ports.dst_port;
        hdr.ports.dst_port = tmp_port;

        hdr.mirror_ack.setValid();
        hdr.mirror_ack.tstamp = meta.ing_port_mirror.ingress_global_tstamp;

        // IP Header 
        hdr.ipv4.total_len = 0x002E;
        hdr.ipv4.diffserv = 0xFF;

        pkt_num_t tmp_num = hdr.tcp.seq_no;
        hdr.tcp.seq_no = hdr.tcp.ack_no;
        hdr.tcp.ack_no = meta.data_len + tmp_num;
        hdr.tcp.flags = 0x10;
    }

    action send_to_cpu() {
        hdr.cpu_ethernet.setValid();
        hdr.cpu_ethernet.dst_addr   = 0xFFFFFFFFFFFF;
        hdr.cpu_ethernet.src_addr   = 0xAAAAAAAAAAAA;
        hdr.cpu_ethernet.ether_type = 0xBF01;

        hdr.to_cpu.setValid();
        hdr.to_cpu.header_type = meta.ing_port_mirror.header_type;
        hdr.to_cpu.header_info = meta.ing_port_mirror.header_info;
        hdr.to_cpu.pad0 = 0;
        hdr.to_cpu.pad1 = 0;
        hdr.to_cpu.mirror_session  = meta.ing_port_mirror.mirror_session;
        hdr.to_cpu.ingress_port    = meta.ing_port_mirror.ingress_port;

        /* Packet length adjustement since it had headers prepended */
        hdr.to_cpu.pkt_length      = eg_intr_md.pkt_length -
                                   (bit<16>)sizeInBytes(meta.ing_port_mirror);

        /* Timestamps */
        hdr.to_cpu.ingress_mac_tstamp    = meta.ing_port_mirror.ingress_mac_tstamp;
        hdr.to_cpu.ingress_global_tstamp = meta.ing_port_mirror.ingress_global_tstamp;
        hdr.to_cpu.egress_global_tstamp  = eg_prsr_md.global_tstamp; 
    }

    table mirror_dest {
        key = {
            meta.ing_port_mirror.mirror_session : exact;
        }
        
        actions = {
            just_send;
            drop;
            send_to_cpu;
        }
        size = 32;
        default_action = drop();
    }

    action get_nextSeq(){
        meta.nextseq = meta.data_len + hdr.tcp.seq_no;
    }

    apply {
        get_nextSeq();
        if (meta.ing_port_mirror.isValid()) {
            mirror_dest.apply();
        }
    }
}

    /*********************  D E P A R S E R  ************************/

control EgressDeparser(packet_out pkt,
    /* User */
    inout my_egress_headers_t                       hdr,
    in    my_egress_metadata_t                      meta,
    /* Intrinsic */
    in    egress_intrinsic_metadata_for_deparser_t  eg_dprsr_md)
{
    Checksum() ipv4_checksum;

    apply {
        if (meta.ing_port_mirror.isValid()) {
            hdr.ipv4.hdr_checksum = ipv4_checksum.update({
                    hdr.ipv4.version,
                    hdr.ipv4.ihl,
                    hdr.ipv4.diffserv,
                    hdr.ipv4.total_len,
                    hdr.ipv4.identification,
                    hdr.ipv4.flags,
                    hdr.ipv4.frag_offset,
                    hdr.ipv4.ttl,
                    hdr.ipv4.protocol,
                    hdr.ipv4.src_addr,
                    hdr.ipv4.dst_addr
                });
        }
        pkt.emit(hdr);
    }
}


/************ F I N A L   P A C K A G E ******************************/
Pipeline(
    IngressParser(),
    Ingress(),
    IngressDeparser(),
    EgressParser(),
    Egress(),
    EgressDeparser()
) pipe;

Switch(pipe) main;