/* -*- P4_16 -*- */

// enum bit<32> crc32_polinomials {
//     COEFF1       = 0x04C11DB7,
//     COEFF2       = 0xEDB88320,
//     COEFF3       = 0xDB710641,
//     COEFF4       = 0x82608EDB,
//     COEFF5       = 0x741B8CD7,
//     COEFF6       = 0xEB31D82E,
//     COEFF7       = 0xD663B050,
//     COEFF8       = 0xBA0DC66B
// }

control calc_ipv4_hash(
    in       my_ingress_headers_t   hdr,
    inout    my_ingress_metadata_t  meta)
{
    CRCPolynomial<bit<32>>(
        coeff    = 0x04C11DB7,
        reversed = true,
        msb      = false,
        extended = false,
        init     = 0xFFFFFFFF,
        xor      = 0xFFFFFFFF) poly1;
    Hash<bit<32>>(HashAlgorithm_t.CUSTOM, poly1) hash_algo1;

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

    action do_hash1() {
        meta.index_sketch1 = hash_algo1.get({
                hdr.ipv4.src_addr,
                hdr.ipv4.dst_addr,
                hdr.ipv4.protocol,
                meta.l4_lookup.src_port,
                meta.l4_lookup.dst_port
            });
    }

    action do_hash2() {
        meta.index_sketch2 = hash_algo2.get({
                hdr.ipv4.src_addr,
                hdr.ipv4.dst_addr,
                hdr.ipv4.protocol,
                meta.l4_lookup.src_port,
                meta.l4_lookup.dst_port
            });
    }

    action do_hash3() {
        meta.index_sketch3 = hash_algo3.get({
                hdr.ipv4.src_addr,
                hdr.ipv4.dst_addr,
                hdr.ipv4.protocol,
                meta.l4_lookup.src_port,
                meta.l4_lookup.dst_port
            });
    }

    apply {
        do_hash1();
        do_hash2();
        do_hash3();
    }
}