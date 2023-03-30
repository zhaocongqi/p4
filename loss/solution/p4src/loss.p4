/* -*- P4_16 -*- */

#include <core.p4>
#include <tna.p4>

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
    ethernet_h   ethernet;
    mpls_h       mpls;
    ipv4_h       ipv4;
    l4port_h     ports;
    tcp_h        tcp;
    udp_h        udp;
}

struct my_ingress_metadata_t {
    bit<32> hash;
    bit<16> loss;
}

/* -*- P4_16 -*- */

/*************************************************************************
 **************  I N G R E S S   P R O C E S S I N G   *******************
 *************************************************************************/

    /***********************  P A R S E R  **************************/
parser IngressParser(packet_in        pkt,
    /* User */    
    out my_ingress_headers_t          hdr,
    out my_ingress_metadata_t         meta,
    /* Intrinsic */
    out ingress_intrinsic_metadata_t  ig_intr_md)
{
    /* This is a mandatory state, required by Tofino Architecture */
    state start {
        pkt.extract(ig_intr_md);
        pkt.advance(PORT_METADATA_SIZE);
        transition parse_ethernet;
    }

    state parse_ethernet {
        pkt.extract(hdr.ethernet);
        transition select(hdr.ethernet.ether_type) {
            MPLS :  parse_mpls;
            IPV4 :  parse_ipv4;
            default: reject;
        }
    }

    state parse_mpls {
        pkt.extract(hdr.mpls);
        transition select(pkt.lookahead<bit<4>>()) {
            4: parse_ipv4;
            default: reject;
        }
    }

    state parse_ipv4 {
        pkt.extract(hdr.ipv4);
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
/*************************************************************************
 **************  I N G R E S S   P R O C E S S I N G   *******************
 *************************************************************************/

    /***************** M A T C H - A C T I O N  *********************/

control Ingress(
    /* User */
    inout my_ingress_headers_t hdr,
    inout my_ingress_metadata_t meta,
    /* Intrinsic */
    in ingress_intrinsic_metadata_t ig_intr_md,
    in ingress_intrinsic_metadata_from_parser_t ig_prsr_md,
    inout ingress_intrinsic_metadata_for_deparser_t ig_dprsr_md,
    inout ingress_intrinsic_metadata_for_tm_t ig_tm_md)
{
    action send(PortId_t port) {
        ig_tm_md.ucast_egress_port = port;
    }

    action drop() {
        ig_dprsr_md.drop_ctl = 1;
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

    Register<bit<16>, bit<32>>(16,1) NextSeq;

    RegisterAction<bit<16>, bit<32>, bit<16>>(NextSeq)
    get_seq = {
        void apply(inout bit<16> register_data, out bit<16> result) {
            if(hdr.mpls.label[15:0] < register_data){
                result = 0;
            }else{
                result = register_data;
                register_data = hdr.mpls.label[15:0] + 1;
            }
        }
    };

    Register<bit<16>, bit<32>>(16,0) Loss;

    RegisterAction<bit<16>, bit<32>, bit<16>>(Loss)
    get_loss = {
        void apply(inout bit<16> register_data) {
            register_data = register_data + meta.loss;
        }
    };

    Register<bit<16>, bit<32>>(16,0) Reorder;

    RegisterAction<bit<16>, bit<32>, bit<16>>(Reorder)
    get_reorder = {
        void apply(inout bit<16> register_data) {
            register_data = register_data + 1;
        }
    };

    apply {
        if (hdr.ipv4.isValid()) {
            simple_fwd.apply();
        }else{
            drop();
        }
        
        hash();
        bit<16> flag = get_seq.execute(0);
        if(flag == 0x00){
            get_reorder.execute(0);
        }else{
            meta.loss = hdr.mpls.label[15:0] - flag;
            get_loss.execute(0);
        }
    }
}

    /*********************  D E P A R S E R  ************************/

control IngressDeparser(
    packet_out pkt,
    /* User */
    inout my_ingress_headers_t hdr,
    in my_ingress_metadata_t meta,
    /* Intrinsic */
    in ingress_intrinsic_metadata_for_deparser_t ig_dprsr_md)
{
    apply {
        pkt.emit(hdr);
    }
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
}

/*************************************************************************
 ****************  E G R E S S   P R O C E S S I N G   *******************
 *************************************************************************/

    /***********************  P A R S E R  **************************/

parser EgressParser(
    packet_in pkt,
    /* User */
    out my_egress_headers_t hdr,
    out my_egress_metadata_t meta,
    /* Intrinsic */
    out egress_intrinsic_metadata_t eg_intr_md)
{
    /* This is a mandatory state, required by Tofino Architecture */
    state start {
        pkt.extract(eg_intr_md);
        transition meta_init;
    }

    state meta_init {
        transition parse_ethernet;
    }

    state parse_ethernet {
        pkt.extract(hdr.ethernet);
        transition select(hdr.ethernet.ether_type) {
            MPLS :  parse_mpls;
            IPV4 :  parse_ipv4;
            default: reject;
        }
    }

    state parse_mpls {
        pkt.extract(hdr.mpls);
        transition select(pkt.lookahead<bit<4>>()) {
            4: parse_ipv4;
            default: reject;
        }
    }

    state parse_ipv4 {
        pkt.extract(hdr.ipv4);
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

/*************************************************************************
 ****************  E G R E S S   P R O C E S S I N G   *******************
 *************************************************************************/

    /***************** M A T C H - A C T I O N  *********************/

control Egress(
    /* User */
    inout my_egress_headers_t hdr,
    inout my_egress_metadata_t meta,
    /* Intrinsic */    
    in egress_intrinsic_metadata_t eg_intr_md,
    in egress_intrinsic_metadata_from_parser_t eg_prsr_md,
    inout egress_intrinsic_metadata_for_deparser_t eg_dprsr_md,
    inout egress_intrinsic_metadata_for_output_port_t eg_oport_md)
{
    action drop() {
        eg_dprsr_md.drop_ctl = 1;
    }



    apply {

    }
}


    /*********************  D E P A R S E R  ************************/

control EgressDeparser(
    packet_out pkt,
    /* User */
    inout my_egress_headers_t hdr,
    in my_egress_metadata_t meta,
    /* Intrinsic */
    in egress_intrinsic_metadata_for_deparser_t eg_dprsr_md)
{
    apply {
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