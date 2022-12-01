/* -*- P4_16 -*- */

/*************************************************************************
 **************  I N G R E S S   P R O C E S S I N G   *******************
 *************************************************************************/

    /***********************  P A R S E R  **************************/
parser IngressParser(
    packet_in pkt,
    /* User */    
    out my_ingress_headers_t hdr,
    out my_ingress_metadata_t meta,
    /* Intrinsic */
    out ingress_intrinsic_metadata_t ig_intr_md)
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
        meta.bloomfilter_flag = 0;
        meta.sketch_flag = 0;
        meta.mask = 0x000FFFFF;
        transition parse_bridge;
    }

    state parse_bridge {
        pkt.extract(meta.bridge);
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