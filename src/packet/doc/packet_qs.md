QUEUING BLOCK DESIGN NOTES
--------------------------
These notes capture the design intent for a packet queueing and scheduling RTL component. This component could be used, for example, for traffic management to address congestion, support QoS, provide shaping, etc.

The requirements are summarized as:
- parameterizable
- vendor-independent implementation
- application-indpendent implementation
- support flexible allocation of memory, queue depths, buffer sizes, etc.
- support multi-context access to the same underlying memory; i.e. 2 ports writing simulataneously into the queues
- support flexible scheduling algorithm
- efficient use of memory resources
- support on-chip (e.g. BRAM) and off-chip (e.g. DDR/HBM) memory implementations
- support control and monitoring functions, via debug registers

SCATTER-GATHER BUFFER ALLOCATION
--------------------------------
To support flexibility in allocation of memory and queues, the queuing block is implemented as a scatter-gather memory controller. The data memory is subdivided into equally-sized buffers - e.g. 2kB. Packets are segmented and written into buffers; a linked list of buffer descriptors is created during writing and this descriptor list can be traversed in order to support retrieval of the packet data.

The scatter-gather method has some nice properties - specifically, efficient use of the memory is possible because:
1. Memory fragmentation is not an issue (the buffer descriptors need not be associated with contiguous regions of memory)
2. The buffers can be 'small', since several buffers can be combined to accommodate large packets (e.g. jumbo frames)

The buffers are allocated using a bit-vector allocator, which can be maintained in on-chip RAM, even for very large (>1M) numbers of buffers. This allows for fast allocation/deallocation and minimizes 'background' access to the larger memory structures (likely off-chip) required for descriptor and data storage.

The queuing block supports storing descriptors and packet data in either on-chip or off-chip RAM, although the expectation is that both of these would be stored in off-chip RAM for all but the smallest queue implementations.

PACKET ENQUEUE
--------------
A received packet is enqueued by segmenting it into chunks equivalent to the chosen buffer size (e.g. 2kB). For each chunk, a 'store' request is made to the scatter-gather (SG) controller. The SG returns a buffer pointer describing an available buffer into which the packet data can be written. If the packet chunk represents the 'end-of-packet' the descriptor is marked to reflect this and then stored to descriptor memory. Otherwise, it is held until a buffer is allocated for the next packet chunk - the pointer to the 'next' chunk is written into the descriptor and the descriptor is then written to descriptor memory.

Once the entire packet is written, the pointer to the first descriptor is provided to the appropriate queue, as indicated by the packet metadata.

QUEUES
------
While the packet data is 'scattered' across the memory, the queues are maintained in output queues, which are implemented as ordered lists of buffer pointers. Each item in the queue contains the address of the first descriptor representing a packet. Depending on the maximum depth of the queues these data structures can be stored on-chip or off-chip.

SCHEDULING
----------
The scheduling algorithm has access to the output queues and determines the order in which those queues are serviced. The design of the queueing component is independent of the scheduling algorithm (which is application-specific). The scheduling algorithm can enforce priorities or QoS, or can be used with shapers to spread out burst traffic.

PACKET DEQUEUE
--------------
Once a packet has been scheduled it is dequeued. This is accomplished by fetching the descriptor representing the first buffer associated with the packet, and then following the linked list to retrieve all additional buffers until the end-of-packet is found.
