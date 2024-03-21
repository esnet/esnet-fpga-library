package pcap_pkg;

    //===================================
    // Parameters
    //===================================
    // PCAP magic number
    localparam int MAGIC_NUMBER    = 32'ha1b2c3d4; // ms resolution
    localparam int MAGIC_NUMBER_NS = 32'ha1b23c4d; // ns resolution

    //===================================
    // Typedefs
    //===================================
    // Global header
    typedef struct packed {
        int unsigned magic_number;
        shortint unsigned version_major;
        shortint unsigned version_minor;
        int signed thiszone;
        int unsigned sigfigs;
        int unsigned snaplen;
        int unsigned network;
    } pcap_hdr_t;

    localparam int PCAP_HDR_BYTES = $bits(pcap_hdr_t)/8;

    typedef enum {
        PCAP_TIME_RESOLUTION_US,
        PCAP_TIME_RESOLUTION_NS
    } pcap_time_resolution_t;

    typedef enum {
        PCAP_ENDIAN_MAINTAIN, // PCAP file written with same endianness; no change required.
        PCAP_ENDIAN_SWAP      // PCAP file written with different endianness; swap required.
    } pcap_endian_t;

    typedef struct packed {
        logic valid;
        pcap_time_resolution_t resolution;
        pcap_endian_t endianness;
    } pcap_meta_t;

    // Record (packet) header
    typedef struct packed {
        int unsigned ts_sec;
        int unsigned ts_usec;
        int unsigned incl_len;
        int unsigned orig_len;
    } pcap_record_hdr_t;

    localparam int PCAP_RECORD_HDR_BYTES = $bits(pcap_record_hdr_t)/8;

    // PCAP record type
    typedef struct {
        pcap_record_hdr_t hdr;
        byte pkt_data [$];
    } pcap_record_t;

    // PCAP data type
    typedef struct {
        pcap_hdr_t    hdr;
        pcap_record_t records[$];
    } pcap_t;

    //===================================
    // Functions
    //===================================
    function automatic void read_to_bytes(input string filename, output byte data[$]);
        bit [8:0] c;
        int fd = $fopen(filename, "r");
        if (fd) begin
            c = $fgetc(fd);
            while (c != 'h1ff) begin
                data.push_back(c);
                c = $fgetc(fd);
            end
            $fclose(fd);
        end else begin
            $error("[pcap_pkg::read_to_bytes] Invalid PCAP file specified.");
            $finish;
        end
    endfunction

    function automatic pcap_t read_pcap(input string filename);
        byte data [$];
        pcap_t pcap;
        read_to_bytes(filename, data);
        return parse(data);
    endfunction

    function automatic pcap_hdr_t pop_hdr(ref byte data[$]);
        pcap_hdr_t hdr;
        {>>{hdr}} = data;
        // Check that header can be popped from buffer
        assert(data.size() >= PCAP_HDR_BYTES) else
            $fatal(1, $sformatf("[pcap_pkg::pop_hdr] Insufficient bytes to pop PCAP header. %d bytes required, %d bytes available in buffer.", PCAP_HDR_BYTES, data.size()));
        // Build header from buffer
        for (int i = 0; i < PCAP_HDR_BYTES; i++) data.pop_front();
        return hdr;
    endfunction

    function automatic pcap_record_hdr_t pop_record_hdr(ref byte data[$]);
        pcap_record_hdr_t record_hdr;
        {>>{record_hdr}} = data;
        // Check that header can be popped from buffer
        assert(data.size() >= PCAP_RECORD_HDR_BYTES) else
            $fatal(1, $sformatf("[pcap_pkg::pop_record_hdr] Insufficient bytes to pop PCAP record header. %d bytes required, %d bytes available in buffer.", PCAP_RECORD_HDR_BYTES, data.size()));
        // Build header from buffer
        for (int i = 0; i < PCAP_RECORD_HDR_BYTES; i++) data.pop_front();
        return record_hdr;
    endfunction

    function automatic pcap_meta_t parse_hdr(input pcap_hdr_t hdr);
        pcap_meta_t pcap_meta;
        int MAGIC_NUMBER_SWAPPED    = {<<byte{MAGIC_NUMBER}};
        int MAGIC_NUMBER_NS_SWAPPED = {<<byte{MAGIC_NUMBER_NS}};
        if      (hdr.magic_number == MAGIC_NUMBER)            pcap_meta = '{valid: 1'b1, resolution: PCAP_TIME_RESOLUTION_US, endianness: PCAP_ENDIAN_MAINTAIN};
        else if (hdr.magic_number == MAGIC_NUMBER_NS)         pcap_meta = '{valid: 1'b1, resolution: PCAP_TIME_RESOLUTION_NS, endianness: PCAP_ENDIAN_MAINTAIN};
        else if (hdr.magic_number == MAGIC_NUMBER_SWAPPED)    pcap_meta = '{valid: 1'b1, resolution: PCAP_TIME_RESOLUTION_US, endianness: PCAP_ENDIAN_SWAP};
        else if (hdr.magic_number == MAGIC_NUMBER_NS_SWAPPED) pcap_meta = '{valid: 1'b1, resolution: PCAP_TIME_RESOLUTION_NS, endianness: PCAP_ENDIAN_SWAP};
        else                                                  pcap_meta = '{valid: 1'b0, resolution: PCAP_TIME_RESOLUTION_US, endianness: PCAP_ENDIAN_MAINTAIN};
        return pcap_meta;
    endfunction

    function automatic void swap_hdr_endianness(ref pcap_hdr_t hdr);
        {<<byte{hdr.magic_number}} = hdr.magic_number;
        {<<byte{hdr.version_major}} = hdr.version_major;
        {<<byte{hdr.version_minor}} = hdr.version_minor;
        {<<byte{hdr.thiszone}} = hdr.thiszone;
        {<<byte{hdr.sigfigs}} = hdr.sigfigs;
        {<<byte{hdr.snaplen}} = hdr.snaplen;
        {<<byte{hdr.network}} = hdr.network;
    endfunction

    function automatic void swap_record_hdr_endianness(ref pcap_record_hdr_t record_hdr);
        {<<byte{record_hdr.ts_sec}} = record_hdr.ts_sec;
        {<<byte{record_hdr.ts_usec}} = record_hdr.ts_usec;
        {<<byte{record_hdr.incl_len}} = record_hdr.incl_len;
        {<<byte{record_hdr.orig_len}} = record_hdr.orig_len;
    endfunction

    function automatic pcap_t parse(input byte data[$]);
        int pkt_bytes;
        pcap_t pcap;
        pcap_meta_t meta;

        // Parse global header
        pcap.hdr = pop_hdr(data);
        meta = parse_hdr(pcap.hdr);

        // Validate header
        if (!meta.valid)
            $fatal(1, $sformatf("[pcap_pkg::parse] Invalid PCAP header (magic number = 0x%x).", pcap.hdr.magic_number));

        // Swap endianness as required
        if (meta.endianness == PCAP_ENDIAN_SWAP) swap_hdr_endianness(pcap.hdr);

        // Parse packet records
        while (data.size() > 0) begin
            int pkt_bytes;
            pcap_record_t __record;

            // Parse packet header
            __record.hdr = pop_record_hdr(data);

            // Swap endianness as required
            if (meta.endianness == PCAP_ENDIAN_SWAP) swap_record_hdr_endianness(__record.hdr);

            // Process packet data
            __record.pkt_data = {};
            pkt_bytes = __record.hdr.incl_len;

            // Check that packet data can be popped from buffer
            assert(data.size() >= pkt_bytes) else
            $fatal(1, $sformatf("[pcap_pkg::parse] Insufficient bytes in buffer to pop packet data. %d bytes required, %d bytes available in buffer.", pkt_bytes, data.size()));
            for (int i = 0; i < pkt_bytes; i++) begin
                __record.pkt_data.push_back(data.pop_front());
            end

            // Add assembled record
            pcap.records.push_back(__record);
        end

        return pcap;

    endfunction

    function automatic void print_raw(input byte data[]);
        foreach (data[i]) begin
            $display("%x", data[i]);
        end
    endfunction

    function automatic void print_hdr(input pcap_hdr_t hdr);
        $display("magic number: 0x%x", hdr.magic_number);
        $display("major version: 0x%x", hdr.version_major);
        $display("minor version: 0x%x", hdr.version_minor);
        $display("GMT to local correction: 0x%x", hdr.thiszone);
        $display("timestamp accuracy: 0x%x", hdr.sigfigs);
        $display("max length of packets: %0d", hdr.snaplen);
        $display("data link type: 0x%x", hdr.network);
    endfunction

    function automatic void print_record_hdr(input pcap_record_hdr_t record_hdr, input bit ns_resolution=1'b0);
        $display("timestamp seconds: %0d", record_hdr.ts_sec);
        if (ns_resolution)
            $display("timestamp nanoseconds: %0d", record_hdr.ts_usec);
        else
            $display("timestamp microseconds: %0d", record_hdr.ts_usec);
        $display("packet length (captured): %0d", record_hdr.incl_len);
        $display("packet length (original): %0d", record_hdr.orig_len);
    endfunction

    function automatic void print_pkt_data(input byte pkt_data [$]);
        string pkt_string = string_pkg::byte_array_to_string(pkt_data);
        $display(pkt_string);
    endfunction

    function automatic void print_pcap(input pcap_t pcap);
        int num_pkts = pcap.records.size();
        pcap_meta_t meta;
        bit ns_resolution;

        // Determine record timestamp resolution
        meta = parse_hdr(pcap.hdr);
        ns_resolution = (meta.resolution == PCAP_TIME_RESOLUTION_NS);

        $display("========================================");
        $display("Global Header");
        $display("========================================");
        print_hdr(pcap.hdr);
        $display("========================================");
        $display("Packets: %0d", num_pkts);
        $display("========================================");
        for (int i = 0; i < num_pkts; i++) begin
            $display("Packet %0d (of %0d)", i+1, num_pkts);
            $display("========================================");
            print_record_hdr(pcap.records[i].hdr, ns_resolution);
            $display();
            print_pkt_data(pcap.records[i].pkt_data);
            $display("========================================");
        end
    endfunction

endpackage : pcap_pkg
