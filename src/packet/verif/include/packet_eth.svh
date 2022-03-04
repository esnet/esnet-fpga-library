// =============================================================================
//  NOTICE: This computer software was prepared by The Regents of the
//  University of California through Lawrence Berkeley National Laboratory
//  and Jonathan Sewter hereinafter the Contractor, under Contract No.
//  DE-AC02-05CH11231 with the Department of Energy (DOE). All rights in the
//  computer software are reserved by DOE on behalf of the United States
//  Government and the Contractor as provided in the Contract. You are
//  authorized to use this computer software for Governmental purposes but it
//  is not to be released or distributed to the public.
//
//  NEITHER THE GOVERNMENT NOR THE CONTRACTOR MAKES ANY WARRANTY, EXPRESS OR
//  IMPLIED, OR ASSUMES ANY LIABILITY FOR THE USE OF THIS SOFTWARE.
//
//  This notice including this sentence must appear on any copies of this
//  computer software.
// =============================================================================

class packet_eth extends packet;
    //===================================
    // Parameters
    //===================================
    localparam packet_pkg::protocol_t PROTOCOL = packet_pkg::PROTOCOL_ETHERNET;

    //===================================
    // Properties
    //===================================
    packet_eth_pkg::hdr_t __hdr;
    packet __payload;

    //===================================
    // Methods
    //===================================
    // Constructor
    function new(
            input string name = "packet",
            input packet_eth_pkg::hdr_t hdr,
            input packet payload
        );
        super.new(name, PROTOCOL);
        this.__hdr = hdr;
        this.__payload = payload;
    endfunction
 
    // Get string representation of packet
    function automatic string to_string();
        string str = super.to_string();
        str = {str, std_string_pkg::horiz_line()};
        str = {str, std_string_pkg::byte_array_to_string(this.to_bytes())};
        str = {str, std_string_pkg::horiz_line()};
        return str;
    endfunction

    function automatic byte_array_t to_bytes();
        return {header(), payload()};
    endfunction

    function automatic byte_array_t header();
        return {>>byte{this.__hdr}};
    endfunction
 
    function automatic byte_array_t payload();
        return this.__payload.to_bytes();
    endfunction

    function automatic protocol_t payload_protocol();
        return this.__payload.protocol();
    endfunction

endclass
