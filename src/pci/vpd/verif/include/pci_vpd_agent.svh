// Base agent class for PCI Vital Product Data (VPD) access
// - interface class (can't be instantiated directly)
// - describes interface for 'generic' register agents, where methods are to be implemented by derived class
virtual class pci_vpd_agent extends std_verif_pkg::agent;

    local static const string __CLASS_NAME = "pci_verif_pkg::pci_vpd_agent";

    //===================================
    // Parameters
    //===================================
    parameter MAX_VPD_LEN = 2**VPD_ADDR_WID;

    //===================================
    // Properties
    //===================================
    protected int _WR_TIMEOUT = 8;
    protected int _RD_TIMEOUT = 8;

    vpd_t __VPD;

    //===================================
    // Pure Virtual Methods
    // (to be implemented by subclass)
    //===================================
    pure virtual protected task automatic idle();
    pure virtual protected task automatic _write_byte(input int addr, input byte data, output bit error, output bit timeout);
    pure virtual protected task automatic _read_byte(input int addr, output byte data, output bit error, output bit timeout);

    //===================================
    // Methods
    //===================================

    // Constructor
    function new(input string name="pci_vpd_agent");
        super.new(name);
        // WORKAROUND-INIT-PROPS {
        //     Provide/repeat default assignments for all remaining instance properties here.
        //     Works around an apparent object initialization bug (as of Vivado 2024.2)
        //     where properties are not properly allocated when they are not assigned
        //     in the constructor.
        this._WR_TIMEOUT = 8;
        this._RD_TIMEOUT = 8;
        this.__VPD.valid = 1'b0;
        this.__VPD.resources = new [0];
        // } WORKAROUND-INIT-PROPS
    endfunction

    // Destructor
    // [[ implements std_verif_pkg::base.destroy() ]]
    virtual function automatic void destroy();
        super.destroy();
    endfunction

    // Configure trace output
    // [[ overrides std_verif_pkg::base.trace_msg() ]]
    function automatic void trace_msg(input string msg);
        _trace_msg(msg, __CLASS_NAME);
    endfunction

    function void set_wr_timeout(input int WR_TIMEOUT);
        this._WR_TIMEOUT = WR_TIMEOUT;
    endfunction

    function int get_wr_timeout();
        return this._WR_TIMEOUT;
    endfunction

    function void set_rd_timeout(input int RD_TIMEOUT);
        this._RD_TIMEOUT = RD_TIMEOUT;
    endfunction

    function int get_rd_timeout();
        return this._RD_TIMEOUT;
    endfunction

    task automatic read_byte(input int idx, output byte data);
        bit error, timeout;
        if (idx < 2**VPD_ADDR_WID) _read_byte(idx, data, error, timeout);
        else $fatal(1, $sformatf("Attempted read from (out-of-range) index %0x.", idx));
    endtask

    task automatic write_byte(input int idx, input byte data);
        bit error, timeout;
        if (idx < 2**VPD_ADDR_WID) _write_byte(idx, data, error, timeout);
        else $fatal(1, $sformatf("Attempted write to (out-of-range) index %0x.", idx));
    endtask

    task automatic read();
        vpd_resource_t resources[$:MAX_VPD_LEN];
        vpd_resource_t resource;
        automatic int parse_idx = 0;
        __VPD.valid = 1'b0;
        do begin
            read_vpd_resource(parse_idx, resource);
            resources.push_back(resource);
        end while ((resource.tag != VPD_TAG_INVALID) && (resource.tag != VPD_TAG_END));
        if (resource.tag == VPD_TAG_END) __VPD.valid = 1'b1;
        __VPD.resources = resources;
        trace_msg({"Read VPD:\n", vpd_to_string(__VPD, "\t")});
    endtask

    // Read VPD resource at specified byte offset
    task automatic read_vpd_resource(inout int idx, output vpd_resource_t resource);
        byte data;
        byte len [0:1];
        bit [15:0] resource_len;
        vpd_rdt_t rdt;
        automatic byte sum;

        sum = 0;

        // Read next byte (should correspond to resource tag)
        read_byte(idx++, data);
        rdt = vpd_rdt_t'(data);
        resource.tag = vpd_get_tag(rdt);
        sum += data;
        
        // Determine length
        if (vpd_get_type(rdt) == VPD_RESOURCE_TYPE__SMALL) resource_len = rdt._small.len;
        else foreach(len[i]) begin
            read_byte(idx++, data);
            len[i] = data;
            sum += data;
        end
        
        resource_len = {<<8{len}};
        
        // Read value
        resource.value = new[resource_len];
        foreach (resource.value[i]) begin
            read_byte(idx++, data);
            resource.value[i] = data;
            sum += data;
        end
        resource.sum = sum;
        trace_msg({"Read resource:\n",vpd_resource_to_string(resource, "\t")});
    endtask

    function automatic vpd_t get_vpd();
        return __VPD;
    endfunction

    function automatic string to_string();
        return vpd_to_string(__VPD);
    endfunction

    function automatic bit is_valid();
        return __VPD.valid;
    endfunction

endclass