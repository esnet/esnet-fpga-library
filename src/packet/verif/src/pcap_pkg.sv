package pcap_pkg;

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

    // Record (packet) header
    typedef struct packed {
        int unsigned ts_sec;
        int unsigned ts_usec;
        int unsigned incl_len;
        int unsigned orig_len;
    } pcaprec_hdr_t;

    localparam int PCAPREC_HDR_BYTES = $bits(pcaprec_hdr_t)/8;

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

    function automatic void read_pcap(
            input string filename,
            output pcap_hdr_t hdr,
            output pcaprec_hdr_t record_hdr[$],
            output byte pkt_data[$][$]
        );
        byte data [$];
        read_to_bytes(filename, data);
        parse(data, hdr, record_hdr, pkt_data);
    endfunction

    function automatic pcap_hdr_t pop_hdr(ref byte data[$]);
        pcap_hdr_t hdr;
        {>>{hdr}} = data;
        for (int i = 0; i < PCAP_HDR_BYTES; i++) data.pop_front();
        return hdr;
    endfunction

    function automatic pcaprec_hdr_t pop_record_hdr(ref byte data[$], input bit swap_endian=0);
        pcaprec_hdr_t record_hdr;
        {>>{record_hdr}} = data;
        for (int i = 0; i < PCAPREC_HDR_BYTES; i++) data.pop_front();
        if (swap_endian) swap_record_hdr_endianness(record_hdr);
        return record_hdr;
    endfunction

    function automatic bit check_endianness(input pcap_hdr_t hdr);
       bit   little_endian = 0;
       
       if (hdr.magic_number == 32'h4d3cb2a1) little_endian = 1;
       if (hdr.magic_number == 32'hd4c3b2a1) little_endian = 1;
       
       return little_endian;
       
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

    function automatic void swap_record_hdr_endianness(ref pcaprec_hdr_t record_hdr);
        {<<byte{record_hdr.ts_sec}} = record_hdr.ts_sec;
        {<<byte{record_hdr.ts_usec}} = record_hdr.ts_usec;
        {<<byte{record_hdr.incl_len}} = record_hdr.incl_len;
        {<<byte{record_hdr.orig_len}} = record_hdr.orig_len;
    endfunction

    function automatic void parse(
            input byte data[$],
            output pcap_hdr_t hdr,
            output pcaprec_hdr_t record_hdr [$],
            output byte pkt_data [$][$]
        );
        int pkt_bytes;
        bit swap_endian;

        // Parse global header
        hdr = pop_hdr(data);

        // Determine endianness and swap if necessary
        swap_endian = check_endianness(hdr);
        if (swap_endian) swap_hdr_endianness(hdr);

        // Parse packet records
        while (data.size() > 0) begin
            pcaprec_hdr_t __record_hdr;
            automatic byte __pkt_data[$] = {};
            // Process packet header
            __record_hdr = pop_record_hdr(data, swap_endian);
            // Process packet data
            pkt_bytes = __record_hdr.incl_len;
            for (int i = 0; i < pkt_bytes; i++) begin
                __pkt_data.push_back(data.pop_front());
            end
            // Assemble output data
            record_hdr.push_back(__record_hdr);
            pkt_data.push_back(__pkt_data);
        end

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

    function automatic void print_record_hdr(input pcaprec_hdr_t record_hdr);
        $display("timestamp seconds: 0x%x", record_hdr.ts_sec);
        $display("timestamp microseconds: 0x%x", record_hdr.ts_usec);
        $display("packet length (captured): %0d", record_hdr.incl_len);
        $display("packet length (original): %0d", record_hdr.orig_len);
    endfunction

    function automatic void print_pkt_data(input byte pkt_data [$]);
        string pkt_string = std_string_pkg::byte_array_to_string(pkt_data);
        $display(pkt_string);
    endfunction

    function automatic void print_pcap(
            input pcap_hdr_t hdr,
            input pcaprec_hdr_t record_hdr [$],
            input byte pkt_data [$][$]
        );
        int num_pkts = record_hdr.size();
        $display("========================================");
        $display("Global Header");
        $display("========================================");
        print_hdr(hdr);
        $display("========================================");
        $display("Packets: %0d", num_pkts);
        $display("========================================");
        for (int i = 0; i < num_pkts; i++) begin
            $display("Packet %0d (of %0d)", i+1, num_pkts);
            $display("========================================");
            print_record_hdr(record_hdr[i]);
            $display();
            print_pkt_data(pkt_data[i]);
            $display("========================================");
        end
    endfunction

endpackage : pcap_pkg
