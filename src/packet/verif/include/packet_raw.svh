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

class packet_raw extends packet;

    //===================================
    // Properties
    //===================================
    byte __data [];

    //===================================
    // Methods
    //===================================
    // Constructor
    function new(
        input string name = "packet_raw",
        input byte data []
    );
        super.new(name, packet_pkg::PROTOCOL_NONE);
        this.__data = data;
    endfunction

    // Get string representation of packet
    // [[ overrides to_string() method of std_verif_pkg::base extended class ]]
    function string to_string();
        string str = super.to_string();
        str = {str, std_string_pkg::horiz_line()};
        str = {str, std_string_pkg::byte_array_to_string(this.__data)};
        str = {str, std_string_pkg::horiz_line()};
        return str;
    endfunction

    //===================================
    // Virtual Methods
    // (to be implemented by derived class)
    //===================================
    // Get data as byte array
    function automatic byte_array_t to_bytes();
        return this.__data;
    endfunction

    // Header
    function automatic byte_array_t header();
        return {};
    endfunction

    // Payload
    function automatic byte_array_t payload();
        return this.__data;
    endfunction

    // Payload protocol
    function automatic protocol_t payload_protocol();
        return packet_pkg::PROTOCOL_NONE;
    endfunction

endclass : packet_raw

