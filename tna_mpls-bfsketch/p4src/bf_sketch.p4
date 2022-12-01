control BF_Sketch(
    in my_egress_headers_t hdr,
    inout my_egress_metadata_t meta)
{

    action getdelay() {
        meta.delay = hdr.mpls.label[7:0];
    }

    CRCPolynomial<bit<32>>(
        coeff    = 0x04C11DB7,
        reversed = true,
        msb      = false,
        extended = false,
        init     = 0xFFFFFFFF,
        xor      = 0xFFFFFFFF) poly;
    Hash<bit<32>>(HashAlgorithm_t.CUSTOM, poly) hash_algo1;

    CRCPolynomial<bit<32>>(
        coeff    = 0x741B8CD7,
        reversed = true,
        msb      = false,
        extended = false,
        init     = 0xFFFFFFFF,
        xor      = 0xFFFFFFFF) poly2;
    Hash<bit<32>>(HashAlgorithm_t.CUSTOM, poly2) hash_algo2;

    CRCPolynomial<bit<32>>(
        coeff    = 0xDB710641,
        reversed = true,
        msb      = false,
        extended = false,
        init     = 0xFFFFFFFF,
        xor      = 0xFFFFFFFF) poly3;
    Hash<bit<32>>(HashAlgorithm_t.CUSTOM, poly3) hash_algo3;

    CRCPolynomial<bit<32>>(
        coeff    = 0xEB31D82E,
        reversed = true,
        msb      = false,
        extended = false,
        init     = 0xFFFFFFFF,
        xor      = 0xFFFFFFFF) poly4;
    Hash<bit<32>>(HashAlgorithm_t.CUSTOM, poly4) hash_algo4;

    CRCPolynomial<bit<32>>(
        coeff    = 0xD663B050,
        reversed = true,
        msb      = false,
        extended = false,
        init     = 0xFFFFFFFF,
        xor      = 0xFFFFFFFF) poly5;
    Hash<bit<32>>(HashAlgorithm_t.CUSTOM, poly5) hash_algo5;

    CRCPolynomial<bit<32>>(
        coeff    = 0xBA0DC66B,
        reversed = true,
        msb      = false,
        extended = false,
        init     = 0xFFFFFFFF,
        xor      = 0xFFFFFFFF) poly6;
    Hash<bit<32>>(HashAlgorithm_t.CUSTOM, poly6) hash_algo6;

    action hash1(){
        meta.index1 = hash_algo1.get({ hdr.ipv4.src_addr,hdr.ipv4.dst_addr,hdr.ipv4.protocol,hdr.ports.src_port,hdr.ports.dst_port });
    }

    action hash2(){
        meta.index2 = hash_algo2.get({ hdr.ipv4.src_addr,hdr.ipv4.dst_addr,hdr.ipv4.protocol,hdr.ports.src_port,hdr.ports.dst_port });
    }

    action hash3(){
        meta.index3 = hash_algo3.get({ hdr.ipv4.src_addr,hdr.ipv4.dst_addr,hdr.ipv4.protocol,hdr.ports.src_port,hdr.ports.dst_port });
    }

    action hash4(){
        meta.index4 = hash_algo4.get({ hdr.ipv4.src_addr,hdr.ipv4.dst_addr,hdr.ipv4.protocol,hdr.ports.src_port,hdr.ports.dst_port });
    }

    action hash5(){
        meta.index5 = hash_algo5.get({ hdr.ipv4.src_addr,hdr.ipv4.dst_addr,hdr.ipv4.protocol,hdr.ports.src_port,hdr.ports.dst_port });
    }

    action hash6(){
        meta.index6 = hash_algo6.get({ hdr.ipv4.src_addr,hdr.ipv4.dst_addr,hdr.ipv4.protocol,hdr.ports.src_port,hdr.ports.dst_port });
    }

    table tbl_hash1{
        actions = {
            hash1;
        }
        const default_action = hash1(); 
        size = 1;
    }

    table tbl_hash2{
        actions = {
            hash2;
        }
        const default_action = hash2(); 
        size = 1;
    }

    table tbl_hash3{
        actions = {
            hash3;
        }
        const default_action = hash3(); 
        size = 1;
    }

    table tbl_hash4{
        actions = {
            hash4;
        }
        const default_action = hash4(); 
        size = 1;
    }

    table tbl_hash5{
        actions = {
            hash5;
        }
        const default_action = hash5(); 
        size = 1;
    }

    table tbl_hash6{
        actions = {
            hash6;
        }
        const default_action = hash6(); 
        size = 1;
    }

    Register<bit<1>, bit<32>>(131072,0) bloomfilter1;
    Register<bit<1>, bit<32>>(131072,0) bloomfilter2;
    Register<bit<1>, bit<32>>(131072,0) bloomfilter3;

    RegisterAction<bit<1>, bit<32>, bit<1>>(bloomfilter1)
    set_data1 = {
        void apply(inout bit<1> value, out bit<1> result) {
            value = 0x1;
            result = value;
        }
    };

    RegisterAction<bit<1>, bit<32>, bit<1>>(bloomfilter1)
    get_data1 = {
        void apply(inout bit<1> value, out bit<1> result) {
            result = value;
        }
    };

    RegisterAction<bit<1>, bit<32>, bit<1>>(bloomfilter2)
    set_data2 = {
        void apply(inout bit<1> value, out bit<1> result) {
            value = 0x1;
            result = value;
        }
    };

    RegisterAction<bit<1>, bit<32>, bit<1>>(bloomfilter2)
    get_data2 = {
        void apply(inout bit<1> value, out bit<1> result) {
            result = value;
        }
    };

    RegisterAction<bit<1>, bit<32>, bit<1>>(bloomfilter3)
    set_data3 = {
        void apply(inout bit<1> value, out bit<1> result) {
            value = 0x1;
            result = value;
        }
    };

    RegisterAction<bit<1>, bit<32>, bit<1>>(bloomfilter3)
    get_data3 = {
        void apply(inout bit<1> value, out bit<1> result) {
            result = value;
        }
    };

    action op_set_hash1(){
        meta.sketch_flag = set_data1.execute((bit<32>)meta.index1[16:0]);
    }
    action op_get_hash1(){
        meta.sketch_flag = get_data1.execute((bit<32>)meta.index1[16:0]);
    }
    action op_set_hash2(){
        meta.sketch_flag = set_data2.execute((bit<32>)meta.index2[16:0]);
    }
    action op_get_hash2(){
        meta.sketch_flag = meta.sketch_flag & get_data2.execute((bit<32>)meta.index2[16:0]);
    }
    action op_set_hash3(){
        meta.sketch_flag = set_data3.execute((bit<32>)meta.index3[16:0]);
    }
    action op_get_hash3(){
        meta.sketch_flag = meta.sketch_flag & get_data3.execute((bit<32>)meta.index3[16:0]);
    }

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

    Register<bit<32>, bit<32>>(131072) sketch1;
    Register<bit<32>, bit<32>>(131072) sketch2;
    Register<bit<32>, bit<32>>(131072) sketch3;

    RegisterAction<bit<32>, bit<32>, bit<1>>(sketch1)
    leave_delay1 = {
        void apply(inout bit<32> delay) {
            delay = delay |+| (bit<32>)meta.delay;
        }
    };

    RegisterAction<bit<32>, bit<32>, bit<1>>(sketch2)
    leave_delay2 = {
        void apply(inout bit<32> delay) {
            delay = delay |+| (bit<32>)meta.delay;
        }
    };

    RegisterAction<bit<32>, bit<32>, bit<1>>(sketch3)
    leave_delay3 = {
        void apply(inout bit<32> delay) {
            delay = delay |+| (bit<32>)meta.delay;
        }
    };

    Register<bit<32>, bit<32>>(131072) count1;
    Register<bit<32>, bit<32>>(131072) count2;
    Register<bit<32>, bit<32>>(131072) count3;

    RegisterAction<bit<32>, bit<32>, bit<1>>(count1)
    leave_count1 = {
        void apply(inout bit<32> count) {
            count = count |+| 1;
        }
    };

    RegisterAction<bit<32>, bit<32>, bit<1>>(count2)
    leave_count2 = {
        void apply(inout bit<32> count) {
            count = count |+| 1;
        }
    };

    RegisterAction<bit<32>, bit<32>, bit<1>>(count3)
    leave_count3 = {
        void apply(inout bit<32> count) {
            count = count |+| 1;
        }
    };

    action get_index(){
        meta.index1 = meta.index1 & meta.mask;
        meta.index2 = meta.index2 & meta.mask;
        meta.index3 = meta.index3 & meta.mask;
    }

    action sketch1_add(){
        leave_delay1.execute(meta.index1);
    }

    action sketch2_add(){
        leave_delay2.execute(meta.index2);
    }

    action sketch3_add(){
        leave_delay3.execute(meta.index3);
    }

    action send(){

    }

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

    action count1_add(){
        leave_count1.execute(meta.index1);
    }

    action count2_add(){
        leave_count2.execute(meta.index2);
    }

    action count3_add(){
        leave_count3.execute(meta.index3);
    }

    table tbl_count1_operation {
        key = {
            meta.sketch_flag : exact;
        }
        actions = {
            count1_add;
            send;
        }
        const entries = {
            (0) : count1_add();
            (1) : send();
        }
        size = 2;
    }

    table tbl_count2_operation {
        key = {
            meta.sketch_flag : exact;
        }
        actions = {
            count2_add;
            send;
        }
        const entries = {
            (0) : count2_add();
            (1) : send();
        }
        size = 2;
    }

    table tbl_count3_operation {
        key = {
            meta.sketch_flag : exact;
        }
        actions = {
            count3_add;
            send;
        }
        const entries = {
            (0) : count3_add();
            (1) : send();
        }
        size = 2;
    }

    apply{
        if(hdr.mpls.isValid() && hdr.ipv4.isValid() && (hdr.tcp.isValid() || hdr.udp.isValid())){
            // Get delay
            getdelay();
            // Hash
            tbl_hash1.apply();
            tbl_hash2.apply();
            tbl_hash3.apply();
            tbl_hash4.apply();
            tbl_hash5.apply();
            tbl_hash6.apply();
            // Set delay threshold
            // tbl_threshold.apply();
            if(meta.delay > 0xFF){
                meta.bloomfilter_flag = 1;
            }
            // Check bloomfilter
            tbl_hash1_operation.apply();
            tbl_hash2_operation.apply();
            tbl_hash3_operation.apply();
            // CM_Sketch
            get_index();
            tbl_sketch1_operation.apply();
            tbl_sketch2_operation.apply();
            tbl_sketch3_operation.apply();
            tbl_count1_operation.apply();
            tbl_count2_operation.apply();
            tbl_count3_operation.apply();
        }
    }

}