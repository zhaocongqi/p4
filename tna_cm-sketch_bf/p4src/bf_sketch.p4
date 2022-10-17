struct pair {
    bit<32> delay;
    bit<32> count;
}

control BF_Sketch(
    in my_egress_headers_t hdr,
    inout my_egress_metadata_t meta)
{
    CRCPolynomial<bit<32>>(
        coeff    = 0x04C11DB7,
        reversed = true,
        msb      = false,
        extended = false,
        init     = 0xFFFFFFFF,
        xor      = 0xFFFFFFFF) poly;
    Hash<bit<32>>(HashAlgorithm_t.CUSTOM, poly) hash_unit;

    action hash(){
        meta.key = hash_unit.get({ hdr.ipv4.src_addr,hdr.ipv4.dst_addr,hdr.ipv4.protocol,hdr.ports.src_port,hdr.ports.dst_port });
    }

    @pragma stage 0
    table tbl_hash{
        actions = {
            hash;
        }
        const default_action = hash(); 
        size = 1;
    }

    // action no_action(){}

    // action delay_threshold(bit<18> threshold){
    //     meta.default_threshold = threshold;
    // }

    // @pragma stage 0
    // table tbl_threshold{
    //     actions = {
    //         no_action;
    //         delay_threshold;
    //     }
    //     const default_action = no_action(); 
    //     size = 1;
    // }

    Register<bit<1>, bit<16>>(32,0) bloomfilter1;
    Register<bit<1>, bit<16>>(32,0) bloomfilter2;
    Register<bit<1>, bit<16>>(32,0) bloomfilter3;

    RegisterAction<bit<1>, bit<16>, bit<1>>(bloomfilter1)
    set_data1 = {
        void apply(inout bit<1> value, out bit<1> result) {
            value = 0x1;
            result = value;
        }
    };

    RegisterAction<bit<1>, bit<16>, bit<1>>(bloomfilter1)
    get_data1 = {
        void apply(inout bit<1> value, out bit<1> result) {
            result = value;
        }
    };

    RegisterAction<bit<1>, bit<16>, bit<1>>(bloomfilter2)
    set_data2 = {
        void apply(inout bit<1> value, out bit<1> result) {
            value = 0x1;
            result = value;
        }
    };

    RegisterAction<bit<1>, bit<16>, bit<1>>(bloomfilter2)
    get_data2 = {
        void apply(inout bit<1> value, out bit<1> result) {
            result = value;
        }
    };

    RegisterAction<bit<1>, bit<16>, bit<1>>(bloomfilter3)
    set_data3 = {
        void apply(inout bit<1> value, out bit<1> result) {
            value = 0x1;
            result = value;
        }
    };

    RegisterAction<bit<1>, bit<16>, bit<1>>(bloomfilter3)
    get_data3 = {
        void apply(inout bit<1> value, out bit<1> result) {
            result = value;
        }
    };

    action op_set_hash1(){
        meta.sketch_flag = set_data1.execute((bit<16>)meta.key[4:0]);
    }
    action op_get_hash1(){
        meta.sketch_flag = get_data1.execute((bit<16>)meta.key[4:0]);
    }
    action op_set_hash2(){
        meta.sketch_flag = set_data2.execute((bit<16>)meta.key[12:8]);
    }
    action op_get_hash2(){
        meta.sketch_flag = meta.sketch_flag & get_data2.execute((bit<16>)meta.key[12:8]);
    }
    action op_set_hash3(){
        meta.sketch_flag = set_data3.execute((bit<16>)meta.key[20:16]);
    }
    action op_get_hash3(){
        meta.sketch_flag = meta.sketch_flag & get_data3.execute((bit<16>)meta.key[20:16]);
    }

    @pragma stage 1
    table tbl_hash1_operation {
        key = {
            meta.bloomfilter_flag : exact;
        }
        actions = {
            op_set_hash1;
            op_get_hash1;
        }
        const entries = {
            (0) : op_get_hash1();
            (1) : op_set_hash1();
        }
        size = 2;
    }

    @pragma stage 1
    table tbl_hash2_operation {
        key = {
            meta.bloomfilter_flag : exact;
        }
        actions = {
            op_set_hash2;
            op_get_hash2;
        }
        const entries = {
            (0) : op_get_hash2();
            (1) : op_set_hash2();
        }
        size = 2;
    }

    @pragma stage 1
    table tbl_hash3_operation {
        key = {
            meta.bloomfilter_flag : exact;
        }
        actions = {
            op_set_hash3;
            op_get_hash3;
        }
        const entries = {
            (0) : op_get_hash3();
            (1) : op_set_hash3();
        }
        size = 2;
    }

    Register<pair, bit<16>>(32) sketch1;
    Register<pair, bit<16>>(32) sketch2;
    Register<pair, bit<16>>(32) sketch3;

    RegisterAction<pair, bit<16>, bit<1>>(sketch1)
    leave_pair1 = {
        void apply(inout pair value) {
            value.delay = value.delay |+| (bit<32>)meta.deq_timedelta[15:0];
            value.count = value.count |+| 1;
        }
    };

    RegisterAction<pair, bit<16>, bit<1>>(sketch2)
    leave_pair2 = {
        void apply(inout pair value) {
            value.delay = value.delay |+| (bit<32>)meta.deq_timedelta[15:0];
            value.count = value.count |+| 1;
        }
    };

    RegisterAction<pair, bit<16>, bit<1>>(sketch3)
    leave_pair3 = {
        void apply(inout pair value) {
            value.delay = value.delay |+| (bit<32>)meta.deq_timedelta[15:0];
            value.count = value.count |+| 1;
        }
    };

    action sketch1_add(){
        leave_pair1.execute((bit<16>)meta.key[4:0]);
    }

    action sketch2_add(){
        leave_pair2.execute((bit<16>)meta.key[12:8]);
    }

    action sketch3_add(){
        leave_pair3.execute((bit<16>)meta.key[20:16]);
    }

    action send(){

    }

    @pragma stage 2
    table tbl_sketch1_operation {
        key = {
            meta.sketch_flag : exact;
        }
        actions = {
            sketch1_add;
            send;
        }
        const entries = {
            (0) : sketch1_add();
            (1) : send();
        }
        size = 2;
    }

    @pragma stage 2
    table tbl_sketch2_operation {
        key = {
            meta.sketch_flag : exact;
        }
        actions = {
            sketch2_add;
            send;
        }
        const entries = {
            (0) : sketch2_add();
            (1) : send();
        }
        size = 2;
    }

    @pragma stage 2
    table tbl_sketch3_operation {
        key = {
            meta.sketch_flag : exact;
        }
        actions = {
            sketch3_add;
            send;
        }
        const entries = {
            (0) : sketch3_add();
            (1) : send();
        }
        size = 2;
    }

    apply{
        if(hdr.mpls.isValid() && hdr.ipv4.isValid() && (hdr.tcp.isValid() || hdr.udp.isValid())){
            // Hash
            tbl_hash.apply();
            // Set delay threshold
            // tbl_threshold.apply();
            if(meta.deq_timedelta > 0xFFFF){
                meta.bloomfilter_flag = 1;
            }
            // Check bloomfilter
            tbl_hash1_operation.apply();
            tbl_hash2_operation.apply();
            tbl_hash3_operation.apply();
            // CM_Sketch
            tbl_sketch1_operation.apply();
            tbl_sketch2_operation.apply();
            tbl_sketch3_operation.apply();
        }
    }

}