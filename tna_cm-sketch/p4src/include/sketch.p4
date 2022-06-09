/* -*- P4_16 -*- */

/* CM Sketch */
const int SKETCH_BUCKET_LENGTH_WIDTH = 10;
typedef bit<(SKETCH_BUCKET_LENGTH_WIDTH)> SKETCH_BUCKET_LENGTH_t;
const int SKETCH_BUCKET_LENGTH = 1 << (SKETCH_BUCKET_LENGTH_WIDTH);


const int SKETCH_COUNT_BIT_WIDTH = 16;
typedef bit<(SKETCH_COUNT_BIT_WIDTH)> SKETCH_COUNT_BIT_WIDTH_t;

const int SKETCH_DELAY_BIT_WIDTH = 16;
typedef bit<(SKETCH_DELAY_BIT_WIDTH)> SKETCH_DELAY_BIT_WIDTH_t;

const int SKETCH_MAX_DELAY_BIT_WIDTH = 8;
typedef bit<(SKETCH_MAX_DELAY_BIT_WIDTH)> SKETCH_MAX_DELAY_BIT_WIDTH_t;

const int SKETCH_MIN_DELAY_BIT_WIDTH = 8;
typedef bit<(SKETCH_MIN_DELAY_BIT_WIDTH)> SKETCH_MIN_DELAY_BIT_WIDTH_t;

control Sketch(
    in  my_ingress_metadata_t   meta)
{

    Register<SKETCH_COUNT_BIT_WIDTH_t, SKETCH_BUCKET_LENGTH_t>(SKETCH_BUCKET_LENGTH,0) sketch_count1;
    Register<SKETCH_DELAY_BIT_WIDTH_t, SKETCH_BUCKET_LENGTH_t>(SKETCH_BUCKET_LENGTH,0) sketch_delay1;
    Register<SKETCH_MAX_DELAY_BIT_WIDTH_t, SKETCH_BUCKET_LENGTH_t>(SKETCH_BUCKET_LENGTH,0) sketch_max_delay1;
    Register<SKETCH_MIN_DELAY_BIT_WIDTH_t, SKETCH_BUCKET_LENGTH_t>(SKETCH_BUCKET_LENGTH,0xFF) sketch_min_delay1;

    RegisterAction<SKETCH_COUNT_BIT_WIDTH_t, SKETCH_BUCKET_LENGTH_t, SKETCH_COUNT_BIT_WIDTH_t>(sketch_count1)
    leave_count1 = {
        void apply(inout SKETCH_COUNT_BIT_WIDTH_t register_data) {
            register_data = register_data + 1;
        }
    };

    RegisterAction<SKETCH_DELAY_BIT_WIDTH_t, SKETCH_BUCKET_LENGTH_t, SKETCH_DELAY_BIT_WIDTH_t>(sketch_delay1)
    leave_delay1 = {
        void apply(inout SKETCH_DELAY_BIT_WIDTH_t register_data) {
            register_data = register_data + (bit<16>)meta.delay;
        }
    };

    RegisterAction<SKETCH_MAX_DELAY_BIT_WIDTH_t, SKETCH_BUCKET_LENGTH_t, SKETCH_MAX_DELAY_BIT_WIDTH_t>(sketch_max_delay1)
    leave_max_delay1 = {
        void apply(inout SKETCH_MAX_DELAY_BIT_WIDTH_t register_data) {
            if(meta.delay > register_data){
                register_data = meta.delay;
            }
        }
    };

    RegisterAction<SKETCH_MIN_DELAY_BIT_WIDTH_t, SKETCH_BUCKET_LENGTH_t, SKETCH_MIN_DELAY_BIT_WIDTH_t>(sketch_min_delay1)
    leave_min_delay1 = {
        void apply(inout SKETCH_MIN_DELAY_BIT_WIDTH_t register_data) {
            if(meta.delay < register_data){
                register_data = meta.delay;
            }
        }
    };

    Register<SKETCH_COUNT_BIT_WIDTH_t, SKETCH_BUCKET_LENGTH_t>(SKETCH_BUCKET_LENGTH,0) sketch_count2;
    Register<SKETCH_DELAY_BIT_WIDTH_t, SKETCH_BUCKET_LENGTH_t>(SKETCH_BUCKET_LENGTH,0) sketch_delay2;
    Register<SKETCH_MAX_DELAY_BIT_WIDTH_t, SKETCH_BUCKET_LENGTH_t>(SKETCH_BUCKET_LENGTH,0) sketch_max_delay2;
    Register<SKETCH_MIN_DELAY_BIT_WIDTH_t, SKETCH_BUCKET_LENGTH_t>(SKETCH_BUCKET_LENGTH,0xFF) sketch_min_delay2;

    RegisterAction<SKETCH_COUNT_BIT_WIDTH_t, SKETCH_BUCKET_LENGTH_t, SKETCH_COUNT_BIT_WIDTH_t>(sketch_count2)
    leave_count2 = {
        void apply(inout SKETCH_COUNT_BIT_WIDTH_t register_data) {
            register_data = register_data + 1;
        }
    };

    RegisterAction<SKETCH_DELAY_BIT_WIDTH_t, SKETCH_BUCKET_LENGTH_t, SKETCH_DELAY_BIT_WIDTH_t>(sketch_delay2)
    leave_delay2 = {
        void apply(inout SKETCH_DELAY_BIT_WIDTH_t register_data) {
            register_data = register_data + (bit<16>)meta.delay;
        }
    };

    RegisterAction<SKETCH_MAX_DELAY_BIT_WIDTH_t, SKETCH_BUCKET_LENGTH_t, SKETCH_MAX_DELAY_BIT_WIDTH_t>(sketch_max_delay2)
    leave_max_delay2 = {
        void apply(inout SKETCH_MAX_DELAY_BIT_WIDTH_t register_data) {
            if(meta.delay > register_data){
                register_data = meta.delay;
            }
        }
    };

    RegisterAction<SKETCH_MIN_DELAY_BIT_WIDTH_t, SKETCH_BUCKET_LENGTH_t, SKETCH_MIN_DELAY_BIT_WIDTH_t>(sketch_min_delay2)
    leave_min_delay2 = {
        void apply(inout SKETCH_MIN_DELAY_BIT_WIDTH_t register_data) {
            if(meta.delay < register_data){
                register_data = meta.delay;
            }
        }
    };
    
    Register<SKETCH_COUNT_BIT_WIDTH_t, SKETCH_BUCKET_LENGTH_t>(SKETCH_BUCKET_LENGTH,0) sketch_count3;
    Register<SKETCH_DELAY_BIT_WIDTH_t, SKETCH_BUCKET_LENGTH_t>(SKETCH_BUCKET_LENGTH,0) sketch_delay3;
    Register<SKETCH_MAX_DELAY_BIT_WIDTH_t, SKETCH_BUCKET_LENGTH_t>(SKETCH_BUCKET_LENGTH,0) sketch_max_delay3;
    Register<SKETCH_MIN_DELAY_BIT_WIDTH_t, SKETCH_BUCKET_LENGTH_t>(SKETCH_BUCKET_LENGTH,0xFF) sketch_min_delay3;

    RegisterAction<SKETCH_COUNT_BIT_WIDTH_t, SKETCH_BUCKET_LENGTH_t, SKETCH_COUNT_BIT_WIDTH_t>(sketch_count3)
    leave_count3 = {
        void apply(inout SKETCH_COUNT_BIT_WIDTH_t register_data) {
            register_data = register_data + 1;
        }
    };

    RegisterAction<SKETCH_DELAY_BIT_WIDTH_t, SKETCH_BUCKET_LENGTH_t, SKETCH_DELAY_BIT_WIDTH_t>(sketch_delay3)
    leave_delay3 = {
        void apply(inout SKETCH_DELAY_BIT_WIDTH_t register_data) {
            register_data = register_data + (bit<16>)meta.delay;
        }
    };

    RegisterAction<SKETCH_MAX_DELAY_BIT_WIDTH_t, SKETCH_BUCKET_LENGTH_t, SKETCH_MAX_DELAY_BIT_WIDTH_t>(sketch_max_delay3)
    leave_max_delay3 = {
        void apply(inout SKETCH_MAX_DELAY_BIT_WIDTH_t register_data) {
            if(meta.delay > register_data){
                register_data = meta.delay;
            }
        }
    };

    RegisterAction<SKETCH_MIN_DELAY_BIT_WIDTH_t, SKETCH_BUCKET_LENGTH_t, SKETCH_MIN_DELAY_BIT_WIDTH_t>(sketch_min_delay3)
    leave_min_delay3 = {
        void apply(inout SKETCH_MIN_DELAY_BIT_WIDTH_t register_data) {
            if(meta.delay < register_data){
                register_data = meta.delay;
            }
        }
    };

    apply {
        leave_count1.execute(meta.index_sketch1[(SKETCH_BUCKET_LENGTH_WIDTH - 1):0]);
        leave_count2.execute(meta.index_sketch2[(SKETCH_BUCKET_LENGTH_WIDTH - 1):0]);
        leave_count3.execute(meta.index_sketch3[(SKETCH_BUCKET_LENGTH_WIDTH - 1):0]);

        leave_delay1.execute(meta.index_sketch1[(SKETCH_BUCKET_LENGTH_WIDTH - 1):0]);
        leave_delay2.execute(meta.index_sketch2[(SKETCH_BUCKET_LENGTH_WIDTH - 1):0]);
        leave_delay3.execute(meta.index_sketch3[(SKETCH_BUCKET_LENGTH_WIDTH - 1):0]);

        leave_max_delay1.execute(meta.index_sketch1[(SKETCH_BUCKET_LENGTH_WIDTH - 1):0]);
        leave_max_delay2.execute(meta.index_sketch2[(SKETCH_BUCKET_LENGTH_WIDTH - 1):0]);
        leave_max_delay3.execute(meta.index_sketch3[(SKETCH_BUCKET_LENGTH_WIDTH - 1):0]);

        leave_min_delay1.execute(meta.index_sketch1[(SKETCH_BUCKET_LENGTH_WIDTH - 1):0]);
        leave_min_delay2.execute(meta.index_sketch2[(SKETCH_BUCKET_LENGTH_WIDTH - 1):0]);
        leave_min_delay3.execute(meta.index_sketch3[(SKETCH_BUCKET_LENGTH_WIDTH - 1):0]);
    }
}