/* -*- P4_16 -*- */

#include <core.p4>
#include <tna.p4>

#include "headers.p4"
#include "parsers.p4"
#include "bf_sketch.p4"

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
    action hit(PortId_t port) {
        ig_tm_md.ucast_egress_port = port;
    }
    action miss() {
        ig_dprsr_md.drop_ctl = 0x1; // Drop packet.
    }
    // Simple port-forwarding is used for testing.
    table simple_fwd {
        key = {
            ig_intr_md.ingress_port : exact;
        }
        actions = {
            hit;
            miss;
        }
        const default_action = miss;
        size = 64;
    }
    apply {
        simple_fwd.apply();

        hdr.bridge.setValid();
        hdr.bridge.ingress_mac_tstamp = ig_intr_md.ingress_mac_tstamp;
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
    BF_Sketch() bf_sketch;
    apply {
        bf_sketch.apply(hdr, meta);
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