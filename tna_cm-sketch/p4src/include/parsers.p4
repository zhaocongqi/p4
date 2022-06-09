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
        transition meta_init;
    }

    state meta_init {
        meta.timestamp        = 0;

        meta.l4_lookup        = { 0, 0 };

        meta.index_sketch1    = 0;
        meta.index_sketch2    = 0;
        meta.index_sketch3    = 0;
        meta.index_sketch4    = 0;
        meta.index_sketch5    = 0;
        meta.index_sketch6    = 0;
        meta.index_sketch7    = 0;
        meta.index_sketch8    = 0;

        meta.delay            = 0;

        meta.bloomfilter_flag = 0;

        transition parse_ethernet;
    }

    state parse_ethernet {
        pkt.extract(hdr.ethernet);
        transition select(hdr.ethernet.ether_type) {
            (bit<16>)ether_type_t.MPLS :  parse_mpls;
            (bit<16>)ether_type_t.IPV4 :  parse_ipv4;
            default: accept;
        }
    }

    state parse_mpls {
        pkt.extract(hdr.mpls);
        transition select(pkt.lookahead<bit<4>>()) {
            4: parse_ipv4;
            default: accept;
        }
    }

    state parse_ipv4 {
        pkt.extract(hdr.ipv4);
        meta.l4_lookup = pkt.lookahead<l4_lookup_t>();
        transition select(hdr.ipv4.frag_offset, hdr.ipv4.protocol) {
            ( 0, ip_proto_t.TCP  ) : parse_tcp;
            ( 0, ip_proto_t.UDP  ) : parse_udp;
            default : accept;
        }
    }

    state parse_tcp {
        pkt.extract(hdr.tcp);
        transition accept;
    }
    
    state parse_udp {
        pkt.extract(hdr.udp);
        transition accept;
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
    apply {
        pkt.emit(hdr);
    }
}


/*************************************************************************
 ****************  E G R E S S   P R O C E S S I N G   *******************
 *************************************************************************/

    /***********************  P A R S E R  **************************/

parser EgressParser(packet_in        pkt,
    /* User */
    out my_egress_headers_t          hdr,
    out my_egress_metadata_t         meta,
    /* Intrinsic */
    out egress_intrinsic_metadata_t  eg_intr_md)
{
    /* This is a mandatory state, required by Tofino Architecture */
    state start {
        pkt.extract(eg_intr_md);
        transition accept;
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
    apply {
        pkt.emit(hdr);
    }
}