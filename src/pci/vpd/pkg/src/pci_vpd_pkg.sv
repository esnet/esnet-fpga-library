package pci_vpd_pkg;

    //===================================
    // Parameters
    //===================================
    localparam int VPD_ADDR_WID = 15;

    //===================================
    // Typedefs
    //===================================
    typedef enum logic {
        VPD_RESOURCE_TYPE__SMALL = 0,
        VPD_RESOURCE_TYPE__LARGE = 1
    } vpd_resource_type_t;

    typedef enum logic [6:0] {
        VPD_TAG_INVALID = 7'h0,
        VPD_TAG_ID      = 7'h2,
        VPD_TAG_END     = 7'hf,
        VPD_TAG_VPD_R   = 7'h10,
        VPD_TAG_VPD_W   = 7'h11
    } vpd_tag_t;

    typedef logic [3:0] vpd_tag_small_t;

    typedef struct packed {
        vpd_resource_type_t _type; // 0 for small resource data type
        vpd_tag_small_t     tag;
        logic [2:0]         len;
    } vpd_srdt_t;

    typedef struct packed {
        vpd_resource_type_t _type; // 1 for small resource data type
        vpd_tag_t           tag;
    } vpd_lrdt_t;

    typedef union packed {
        vpd_srdt_t  _small;
        vpd_lrdt_t  _large;
        logic [7:0] raw;
    } vpd_rdt_t;

    //===================================
    // Typedefs
    //===================================
    function automatic vpd_tag_small_t vpd_get_small_tag(input vpd_tag_t tag);
        if (tag <= 'hf) return vpd_tag_small_t'(tag);
        else            return vpd_tag_small_t'(VPD_TAG_INVALID);
    endfunction

    function automatic string vpd_get_tag_name(input vpd_tag_t tag);
        case (tag)
            VPD_TAG_ID    : return "ID";
            VPD_TAG_VPD_R : return "VPD-R";
            VPD_TAG_VPD_W : return "VPD-W";
            VPD_TAG_END   : return "END";
            default       : return "INVALID";
        endcase
    endfunction

    function automatic vpd_rdt_t vpd_get_srdt(input vpd_tag_t tag, input logic [2:0] len);
        vpd_rdt_t rdt;
        rdt._small._type = VPD_RESOURCE_TYPE__SMALL;
        rdt._small.tag = vpd_get_small_tag(tag);
        rdt._small.len = len;
        return rdt;
    endfunction

    function automatic vpd_rdt_t vpd_get_lrdt(input vpd_tag_t tag);
        vpd_rdt_t rdt;
        rdt._large._type = VPD_RESOURCE_TYPE__LARGE;
        rdt._large.tag = tag;
        return rdt;
    endfunction

    function automatic vpd_resource_type_t vpd_get_type(input vpd_rdt_t rdt);
        if (rdt._large._type == VPD_RESOURCE_TYPE__LARGE) return VPD_RESOURCE_TYPE__LARGE;
        else                                              return VPD_RESOURCE_TYPE__SMALL;
    endfunction

    function automatic vpd_tag_t vpd_get_tag(input vpd_rdt_t rdt);
        vpd_tag_t tag;
        case (vpd_get_type(rdt))
            VPD_RESOURCE_TYPE__LARGE: begin
                if ($cast(tag, rdt._large.tag)) return tag;
                else                            return VPD_TAG_INVALID;
            end
            VPD_RESOURCE_TYPE__SMALL: begin
                if ($cast(tag, rdt._small.tag)) return tag;
                else                            return VPD_TAG_INVALID;
            end
        endcase
    endfunction

endpackage : pci_vpd_pkg
