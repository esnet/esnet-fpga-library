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

class packet_transaction extends std_verif_pkg::transaction;
    //===================================
    // Typedefs
    //===================================
    typedef byte byte_array_t [];

    //===================================
    // Properties
    //===================================
    local const packet __packet;

    //===================================
    // Methods
    //===================================
    // Constructor
    function new(
            input string name="packet_transaction",
            input packet packet
        );
        super.new(name);
        this.__packet = packet;
    endfunction

    // Return packet
    function automatic packet get_packet();
        return this.__packet;
    endfunction

    // Return packet data as array of bytes
    function automatic byte_array_t to_bytes();
        return get_packet().to_bytes();
    endfunction

    // Get size of packet in bytes
    function automatic int size();
        return get_packet().size();
    endfunction

    // Get string representation of transaction
    // [[ implements to_string virtual method of std_verif_pkg::transaction ]]
    function automatic string to_string();
        string str;
        str = $sformatf("Packet transaction '%s' (%0d bytes):\n", get_name(), size());
        str = {str, this.__packet.to_string()};
        return str;
    endfunction

    // Compare transaction against another
    // [[ implements compare virtual method of std_verif_pkg::transaction ]]
    function automatic bit compare(input packet_transaction b, output string msg);
        return this.__packet.compare(b.get_packet(), msg);
    endfunction

endclass
