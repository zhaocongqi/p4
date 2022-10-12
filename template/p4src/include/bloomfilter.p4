/* -*- P4_16 -*- */

/* Bloom Filter */
const int BLOOM_FILTER_BIT_WIDTH = 1;
const int BLOOM_FILTER_ENTRIES_WIDTH = 12;

const int BLOOM_FILTER_ENTRIES = 1 << (BLOOM_FILTER_ENTRIES_WIDTH);

typedef bit<(BLOOM_FILTER_ENTRIES_WIDTH)> BLOOM_FILTER_ENTRIES_t;
typedef bit<(BLOOM_FILTER_BIT_WIDTH)> BLOOM_FILTER_BIT_WIDTH_t;

control BloomFilter(
    inout my_ingress_metadata_t   meta,
    in bit<1>                     search)
{

    Register<BLOOM_FILTER_BIT_WIDTH_t, BLOOM_FILTER_ENTRIES_t>(BLOOM_FILTER_ENTRIES,0) bloomfilter1;
    
    RegisterAction<BLOOM_FILTER_BIT_WIDTH_t, BLOOM_FILTER_ENTRIES_t, BLOOM_FILTER_BIT_WIDTH_t>(bloomfilter1)
    set_data1 = {
        void apply(inout BLOOM_FILTER_BIT_WIDTH_t register_data) {
            register_data = 0x1;
        }
    };

    RegisterAction<BLOOM_FILTER_BIT_WIDTH_t, BLOOM_FILTER_ENTRIES_t, BLOOM_FILTER_BIT_WIDTH_t>(bloomfilter1)
    get_data1 = {
        void apply(inout BLOOM_FILTER_BIT_WIDTH_t register_data, out BLOOM_FILTER_BIT_WIDTH_t result) {
            result = register_data;
        }
    };

    Register<BLOOM_FILTER_BIT_WIDTH_t, BLOOM_FILTER_ENTRIES_t>(BLOOM_FILTER_ENTRIES,0) bloomfilter2;
    
    RegisterAction<BLOOM_FILTER_BIT_WIDTH_t, BLOOM_FILTER_ENTRIES_t, BLOOM_FILTER_BIT_WIDTH_t>(bloomfilter2)
    set_data2 = {
        void apply(inout BLOOM_FILTER_BIT_WIDTH_t register_data) {
            register_data = 0x1;
        }
    };

    RegisterAction<BLOOM_FILTER_BIT_WIDTH_t, BLOOM_FILTER_ENTRIES_t, BLOOM_FILTER_BIT_WIDTH_t>(bloomfilter2)
    get_data2 = {
        void apply(inout BLOOM_FILTER_BIT_WIDTH_t register_data, out BLOOM_FILTER_BIT_WIDTH_t result) {
            result = register_data;
        }
    };

    Register<BLOOM_FILTER_BIT_WIDTH_t, BLOOM_FILTER_ENTRIES_t>(BLOOM_FILTER_ENTRIES,0) bloomfilter3;
    
    RegisterAction<BLOOM_FILTER_BIT_WIDTH_t, BLOOM_FILTER_ENTRIES_t, BLOOM_FILTER_BIT_WIDTH_t>(bloomfilter3)
    set_data3 = {
        void apply(inout BLOOM_FILTER_BIT_WIDTH_t register_data) {
            register_data = 0x1;
        }
    };

    RegisterAction<BLOOM_FILTER_BIT_WIDTH_t, BLOOM_FILTER_ENTRIES_t, BLOOM_FILTER_BIT_WIDTH_t>(bloomfilter3)
    get_data3 = {
        void apply(inout BLOOM_FILTER_BIT_WIDTH_t register_data, out BLOOM_FILTER_BIT_WIDTH_t result) {
            result = register_data;
        }
    };

    action check1(bit<1> flag1){
        meta.bloomfilter_flag = flag1;
    }

    action check2(bit<1> flag2){
        meta.bloomfilter_flag = meta.bloomfilter_flag & flag2;
    }

    action check3(bit<1> flag3){
        meta.bloomfilter_flag = meta.bloomfilter_flag & flag3;
    }

    apply {
        if(search == 1){
            bit<1> flag1 = get_data1.execute(meta.index_sketch1[(BLOOM_FILTER_ENTRIES_WIDTH -1):0]);
            bit<1> flag2 = get_data2.execute(meta.index_sketch2[(BLOOM_FILTER_ENTRIES_WIDTH -1):0]);
            bit<1> flag3 = get_data3.execute(meta.index_sketch3[(BLOOM_FILTER_ENTRIES_WIDTH -1):0]);
            check1(flag1);
            check2(flag2);
            check3(flag3);
        }else{
            set_data1.execute(meta.index_sketch1[(BLOOM_FILTER_ENTRIES_WIDTH -1):0]);
            set_data2.execute(meta.index_sketch2[(BLOOM_FILTER_ENTRIES_WIDTH -1):0]);
            set_data3.execute(meta.index_sketch3[(BLOOM_FILTER_ENTRIES_WIDTH -1):0]);
        }
    }
}