module packet_q_core
#(
    parameter int  NUM_INPUT_IFS = 1,
    parameter int  NUM_OUTPUT_IFS = 1,
    parameter bit  IGNORE_RDY_IN = 0,
    parameter bit  IGNORE_RDY_OUT = 0,
    parameter bit  DROP_ERRORED = 1,
    parameter int  MIN_PKT_SIZE = 0,
    parameter int  MAX_PKT_SIZE = 16384,
    parameter int  NUM_BUFFERS = 1,
    parameter int  BUFFER_SIZE = 2048,
    parameter int  MAX_RD_LATENCY = 8,
    parameter int  MAX_BURST_LEN = 1,
    parameter int  N_ALLOC = 1,
    parameter int  N_GATHER = 1,
    // Simulation-only
    parameter bit  SIM__FAST_INIT = 1,
    parameter bit  SIM__RAM_MODEL = 1
 ) (
    input  logic                clk,
    input  logic                srst,

    output logic                init_done,

    // Packet input (synchronous to packet_in_if.clk)
    packet_intf.rx              packet_in_if [NUM_INPUT_IFS],

    mem_wr_intf.controller      desc_mem_wr_if,
    mem_wr_intf.controller      mem_wr_if [NUM_INPUT_IFS],

    // Packet completion interface (to/from queue controller)
    packet_descriptor_intf.tx   desc_in_if [NUM_INPUT_IFS],
    packet_descriptor_intf.rx   desc_out_if[NUM_OUTPUT_IFS],
    
    // Packet output (synchronous to packet_out_if.clk)
    packet_intf.tx              packet_out_if [NUM_OUTPUT_IFS],

    mem_rd_intf.controller      desc_mem_rd_if,
    mem_rd_intf.controller      mem_rd_if [NUM_OUTPUT_IFS],

    input logic                 mem_init_done,

    axi4l_intf.peripheral       axil_if
);

    packet_sg_core     #(
        .NUM_INPUT_IFS  ( NUM_INPUT_IFS ),
        .NUM_OUTPUT_IFS ( NUM_OUTPUT_IFS ),
        .IGNORE_RDY_IN  ( IGNORE_RDY_IN ),
        .IGNORE_RDY_OUT ( IGNORE_RDY_OUT ),
        .DROP_ERRORED   ( DROP_ERRORED ),
        .MIN_PKT_SIZE   ( MIN_PKT_SIZE ),
        .MAX_PKT_SIZE   ( MAX_PKT_SIZE ),
        .NUM_BUFFERS    ( NUM_BUFFERS ),
        .BUFFER_SIZE    ( BUFFER_SIZE ),
        .MAX_RD_LATENCY ( MAX_RD_LATENCY ),
        .MAX_BURST_LEN  ( MAX_BURST_LEN ),
        .N_ALLOC        ( N_ALLOC ),
        .N_GATHER       ( N_GATHER )
    ) i_packet_sg_core  (
        .*
    );
endmodule : packet_q_core
