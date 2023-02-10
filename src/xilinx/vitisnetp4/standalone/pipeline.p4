#include <core.p4>
#include <xsa.p4>

// ****************************************************************************** //
// *************************** H E A D E R S  *********************************** //
// ****************************************************************************** //

header ethernet_t {
    bit<48> dstAddr;
    bit<48> srcAddr;
    bit<16> etherType;
}

// ****************************************************************************** //
// ************************* S T R U C T U R E S  ******************************* //
// ****************************************************************************** //

// header structure
struct headers {
    ethernet_t ethernet;
}

struct metadata {
    bit<3>  ingress_port;    // 3b ingress port
    bit<3>  egress_port;     // 3b egress port
}

// ****************************************************************************** //
// *************************** P A R S E R  ************************************* //
// ****************************************************************************** //

parser ParserImpl( packet_in packet,
                   out headers hdr,
                   inout metadata meta,
                   inout standard_metadata_t smeta) {
    state start {
        transition parse_ethernet;
    }

    state parse_ethernet {
        packet.extract(hdr.ethernet);
        transition accept;
    }
}

// ****************************************************************************** //
// **************************  P R O C E S S I N G   **************************** //
// ****************************************************************************** //

control MatchActionImpl( inout headers hdr,
                         inout metadata meta,
                         inout standard_metadata_t smeta) {

    UserExtern<bit<3>,bit<1>>(4) counter;

    action forwardPacket(bit<3> dest_port) {
        meta.egress_port = dest_port;
    }

    action dropPacket() {
        smeta.drop = 1;
    }

    table forward {
        key     = { hdr.ethernet.dstAddr : lpm; }
        actions = { forwardPacket;
                    dropPacket;
                    NoAction; }
        size    = 128;
        num_masks = 8;
        default_action = NoAction;
    }

    bit<1> process_enable;

    apply {

        if (smeta.parser_error != error.NoError) {
            dropPacket();
            return;
        }

        counter.apply(meta.ingress_port, process_enable);

        if ((process_enable == 1) && hdr.ethernet.isValid())
            forward.apply();
        else
            dropPacket();
    }
}

// ****************************************************************************** //
// ***************************  D E P A R S E R  ******************************** //
// ****************************************************************************** //

control DeparserImpl( packet_out packet,
                      in headers hdr,
                      inout metadata meta,
                      inout standard_metadata_t smeta) {
    apply {
        packet.emit(hdr.ethernet);
    }
}

// ****************************************************************************** //
// *******************************  M A I N  ************************************ //
// ****************************************************************************** //

XilinxPipeline(
    ParserImpl(),
    MatchActionImpl(),
    DeparserImpl()
) main;
