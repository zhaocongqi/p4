/* -*- P4_16 -*- */

#include <core.p4>
#include <tna.p4>

#include "include/headers.p4"
#include "include/parsers.p4"
#include "include/hash.p4"
#include "include/sketch.p4"
#include "include/bloomfilter.p4"

/*************************************************************************
 **************  I N G R E S S   P R O C E S S I N G   *******************
 *************************************************************************/

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

    action send(PortId_t port) {
        ig_tm_md.ucast_egress_port = port;
    }

    action drop() {
        ig_dprsr_md.drop_ctl = 1;
    }

    action gettimestamp() {
        meta.timestamp = ig_intr_md.ingress_mac_tstamp;
    }

    action getdelay() {
        meta.delay = hdr.mpls.label[7:0];
    }

    action mpls_encap() {
        hdr.mpls.setValid();
        hdr.ethernet.ether_type = ether_type_t.MPLS;
        hdr.mpls.label = meta.timestamp[47:28];
        hdr.mpls.exp = 0;
        hdr.mpls.bos = 1;
        hdr.mpls.ttl = 255;
    }

    // table ipv4_host {
    //     key = { hdr.ipv4.dst_addr : exact; }
    //     actions = {
    //         send; drop;
    //         @defaultonly NoAction;
    //     }
    //     const default_action = NoAction();
    //     size = IPV4_HOST_SIZE;
    // }
 
    // table ipv4_lpm {
    //     key     = { hdr.ipv4.dst_addr : lpm; }
    //     actions = { 
    //         send; drop; 
    //         @defaultonly NoAction;
    //     }
        
    //     const default_action = NoAction();
    //     size = IPV4_LPM_SIZE;
    // }

    table send_to_ovs {
        actions = {
            send;
            NoAction;
        }
        default_action = NoAction;
        size = SEND_TO_OVS_SIZE;
    }

    table port_match {
        key = {
            ig_intr_md.ingress_port: exact;
        }
        actions = {
            send;
        }
        size = PORT_MATCH_SIZE;
    }

    BloomFilter() bloomfilter;
    Sketch() sketch;
    calc_ipv4_hash() hash;

    apply {
        //获取当前收到数据包的时间戳
        gettimestamp();
        if(!hdr.mpls.isValid()) {
            //若不是MPLS,则添加MPLS协议字段
            mpls_encap();
            port_match.apply();            
        }else{
            //若是MPLS且为tcp/udp
            if(hdr.ipv4.isValid() && (hdr.tcp.isValid() || hdr.udp.isValid())){
                //计算时延值
                getdelay();
                //计算hash值
                hash.apply(hdr,meta);

                //若时延值过大,设置bloomfilter,并且交给软件处理
                if(meta.delay > 0x0a){
                    bloomfilter.apply(meta,0);
                    //设置软件交换机转发端口
                    send_to_ovs.apply();
                }else{
                    //时延较小,先查询bloomfilter,判断是否要软件处理
                    bloomfilter.apply(meta,1);
                    if(meta.bloomfilter_flag == 0x1){
                        //设置软件交换机转发端口
                        send_to_ovs.apply();
                    }else{
                        sketch.apply(meta);
                        port_match.apply(); 
                    }
                }
            }
        }
    }
}


/*************************************************************************
 ****************  E G R E S S   P R O C E S S I N G   *******************
 *************************************************************************/

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
    apply {
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