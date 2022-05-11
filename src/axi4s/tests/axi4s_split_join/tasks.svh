//=======================================================================
// Tasks
//=======================================================================

// Send packets described in PCAP file on AXI-S input interface
task send_pcap(input string pcap_filename, input int num_pkts=0, start_idx=0, twait=0, input bit id=0, dest=0);
    axis_driver.send_from_pcap(pcap_filename, num_pkts, start_idx, twait, id, dest);
endtask


// Compare packets
task compare_pkts(input byte pkt1[$], pkt2[$]);
    automatic int byte_idx = 0;

    if (pkt1.size != pkt2.size()) begin
        $display("pkt1:"); pcap_pkg::print_pkt_data(pkt1);
        $display("pkt2:"); pcap_pkg::print_pkt_data(pkt2);
        `FAIL_IF_LOG(
            pkt1.size() != pkt2.size(),
            $sformatf("FAIL!!! Packet size mismatch. size1=%0d size2=%0d", pkt1.size(), pkt2.size())
        );
    end

    byte_idx = 0;
    while ( byte_idx < pkt1.size() ) begin
       if (pkt1[byte_idx] != pkt2[byte_idx]) begin
          $display("pkt1:"); pcap_pkg::print_pkt_data(pkt1);
          $display("pkt2:"); pcap_pkg::print_pkt_data(pkt2);
	  
          `FAIL_IF_LOG( pkt1[byte_idx] != pkt2[byte_idx],
                        $sformatf("FAIL!!! Packet bytes mismatch at byte_idx: 0x%0h (d:%0d)", byte_idx, byte_idx) )
       end
       byte_idx++;
    end
endtask


task run_pkt_test (input bit dest_port=0, input VERBOSE=1 );
	
   string filename;

   // variabes for reading expected pcap data
   byte                      exp_data[$][$];
   pcap_pkg::pcap_hdr_t      exp_pcap_hdr;
   pcap_pkg::pcaprec_hdr_t   exp_pcap_record_hdr[$];

   // variables for sending packet data
   automatic int          num_pkts  = 0;
   automatic int          start_idx = 0;

   // variables for receiving (monitoring) packet data
   automatic int rx_pkt_cnt = 0;    
   automatic bit rx_done = 0;
   byte          rx_data[$];
   bit           id;
   bit           dest;
   bit           user;

   debug_msg("Reading expected pcap file...", VERBOSE);
   filename = "../../../tests/axi4s_split_join/64B_multiples_10pkts.pcap";
   pcap_pkg::read_pcap(filename, exp_pcap_hdr, exp_pcap_record_hdr, exp_data);

   debug_msg("Starting simulation...", VERBOSE);
   rx_pkt_cnt = 0;
   fork
      begin
          // Send packets
          send_pcap(filename, num_pkts, start_idx);
      end
      begin
      // Monitor output packets
          while (rx_pkt_cnt < exp_pcap_record_hdr.size()) begin
              axis_monitor.receive_raw(.data(rx_data), .id(id), .dest(dest), .user(user), .tpause(0));
              rx_pkt_cnt++;
              debug_msg( $sformatf( "      Receiving packet # %0d (of %0d)...", 
                                    rx_pkt_cnt, exp_pcap_record_hdr.size()), VERBOSE );

              debug_msg("      Comparing rx_pkt to exp_pkt...", VERBOSE);
              compare_pkts(rx_data, exp_data[start_idx+rx_pkt_cnt-1]);
             `FAIL_IF_LOG( dest != dest_port, 
                           $sformatf("FAIL!!! Output tdest mismatch. tdest=%0h (exp:%0h)", dest, dest_port) )
          end
          rx_done = 1;
      end
   join
endtask

task debug_msg(input string msg, input bit VERBOSE=0);
    if (VERBOSE) `INFO(msg);
endtask
   
