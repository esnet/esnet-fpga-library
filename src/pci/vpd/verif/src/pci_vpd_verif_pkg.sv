package pci_vpd_verif_pkg;

    //===================================
    // Imports
    //===================================
    import pci_vpd_pkg::*;

    // Verif class definitions
    // (declared here to enforce htable_verif_pkg:: namespace for verification definitions)
    `include "pci_vpd_agent.svh"
    `include "pci_vpd_intf_agent.svh"

    //===================================
    // Typedefs
    //===================================
    typedef byte value_t [];

    typedef struct {
        vpd_tag_t tag;
        value_t value;
        byte sum;
    } vpd_resource_t;

    typedef struct {
        string name;
        value_t value;
    } vpd_record_t;

    typedef struct {
        bit valid;
        vpd_resource_t resources [];
    } vpd_t;

    typedef struct {
        bit valid;
        vpd_record_t records [];
        bit checksum_ok;
    } vpd_r_t;

    //===================================
    // Functions
    //===================================

    // Return resource data object containing specified tag
    function automatic vpd_resource_t vpd_get_resource(input vpd_t vpd, input vpd_tag_t tag);
        vpd_resource_t INVALID_RESOURCE;
        INVALID_RESOURCE.tag = VPD_TAG_INVALID;
        INVALID_RESOURCE.value = new[0];
        if (!vpd.valid) return INVALID_RESOURCE;
        foreach (vpd.resources[i]) begin
            if (vpd.resources[i].tag == tag) return vpd.resources[i];
        end
        return INVALID_RESOURCE; 
    endfunction

    // Extract VPD-R resource from VPD database, including evaluating RO checksum
    function automatic vpd_r_t vpd_parse_vpd_r(input vpd_t vpd);
        vpd_r_t vpd_r;
        vpd_record_t records [$];
        vpd_record_t record;
        byte name [2];
        byte sum;

        // Initialize result
        vpd_r.valid = 1'b0;
        vpd_r.checksum_ok = 1'b0;
        vpd_r.records = new[0];

        // Bail immediately if VPD cannot contain VPD-R resource
        if (!vpd.valid)               return vpd_r;
        if (vpd.resources.size() < 1) return vpd_r;

        sum = 0;

        foreach (vpd.resources[i]) begin
            automatic vpd_resource_t resource;

            resource = vpd.resources[i];

            // Accumulate sum for checksum calculation
            sum += resource.sum;

            if (resource.tag == VPD_TAG_VPD_R) begin
                vpd_record_t record;
                automatic int parse_idx = 0;

                // At a minimum, each record consists of a 2-byte name/tag and 1-byte length
                if (resource.value.size < 3) return vpd_r;

                // Parse VPD-R records
                do begin
                    bit[7:0] record_len;

                    // First two bytes of record indicate record name
                    foreach (name[i]) name[i] = resource.value[parse_idx++];
                    record.name = string_pkg::byte_array_to_ascii_string(name);

                    // Next byte indicates length
                    record_len = resource.value[parse_idx++];

                    // Fail out if record value size exceeds available bytes
                    if (parse_idx + record_len > resource.value.size()) return vpd_r;

                    // Read value
                    record.value = new[record_len];
                    foreach (record.value[i]) record.value[i] = resource.value[parse_idx++];

                    // Record parse done
                    records.push_back(record);

                    // Proceed to next record, if remaining bytes are sufficient to at least encode name/len
                end while (parse_idx + 3 < resource.value.size());

                // Parsing should terminate on the last byte of the resource; otherwise VPD-R resource is invalid
                if (parse_idx == resource.value.size()) begin
                    vpd_r.valid = 1'b1;
                    vpd_r.records = records;
                end

                // Process RV record (should be last record)
                if (record.name == "RV") begin
                    if (record.value.size() > 0) begin
                        sum -= record.value[0];
                        foreach (record.value[i]) sum += record.value[i];
                        if (sum == 0) vpd_r.checksum_ok = 1'b1;
                    end
                end

                return vpd_r;
            end
        end
        return vpd_r;
    endfunction

    // Return the data associated with a record of a specified 'name', within the specified VPD-R resource
    function automatic value_t vpd_r_get_record_value(input vpd_r_t vpd_r, input string name);
        foreach (vpd_r.records[i]) if (vpd_r.records[i].name == name) return vpd_r.records[i].value;
        return "";
    endfunction

    // Display functions
    function automatic string vpd_to_string(input vpd_t vpd, input string indent="");
        string str;
        automatic string valid = vpd.valid ? "Valid" : "Invalid";
        str = {str, indent, string_pkg::horiz_line()};
        str = {str, indent, "Vital Product Data (", valid, ")\n"};
        str = {str, indent, string_pkg::horiz_line()};
        foreach (vpd.resources[i]) begin
            str = {str, indent, vpd_resource_to_string(vpd.resources[i], {indent, "\t"})};
            case (vpd.resources[i].tag)
                VPD_TAG_VPD_R : str = {str, indent, vpd_r_to_string(vpd_parse_vpd_r(vpd), {indent, "\t\t"})};
                default       : str = str; 
            endcase
        end
        return str;
    endfunction

    function automatic string vpd_resource_to_string(input vpd_resource_t resource, input string indent="");
        string str;
        string value_str;
        automatic byte sum = 0;

        str = {str, indent, vpd_get_tag_name(resource.tag), "\n"};
        str = {str, indent, "\t", "Len: ", $sformatf("%0d", resource.value.size()), "\n"};
        str = {str, indent, "\t", "Sum: ", $sformatf("0x%0x", resource.sum), "\n"};
        if (resource.value.size() < 256) begin
            str = {str, indent, "\t", "Value: "};
            value_str = "";
            case (resource.tag)
                VPD_TAG_ID    : value_str = string_pkg::byte_array_to_ascii_string(resource.value);
                default       : value_str = string_pkg::byte_array_to_hex_string(resource.value);
            endcase
            str = {str, value_str, "\n\n"};
        end else str = {str, indent, "\t", "Value: Size error, can't be displayed.\n\n"};
        return str;
    endfunction

    function automatic string vpd_record_to_string(input vpd_record_t record, input string indent="");
        string str;
        string value_str;
        str = {str, indent, record.name, ": "};
        case (record.name)
            "SN", "PN", "V3" : value_str = string_pkg::byte_array_to_ascii_string(record.value);
            "RV"   : begin
                value_str = {"\n", indent, "\t", $sformatf("Checksum: 0x%0x", record.value[0])};
                if (record.value.size() > 1) value_str = {value_str, "\n", indent, "\t", $sformatf("RSVD: %0dB", record.value.size()-1)};
            end
            default: value_str = string_pkg::byte_array_to_hex_string(record.value);
        endcase
        str = {str, value_str, "\n"};
        return str;
    endfunction

    function automatic string vpd_r_to_string(input vpd_r_t vpd_r, input string indent="");
        string str;
        automatic string valid = vpd_r.valid ? "Valid" : "Invalid";
        automatic string checksum_valid = vpd_r.checksum_ok ? "Checksum OK" : "Checksum bad";
        str = {str, indent, "VPD-R (Read-Only) Data (", valid, ", ", checksum_valid, ")\n"};
        foreach (vpd_r.records[i]) str = {str, vpd_record_to_string(vpd_r.records[i], {indent, "\t"})};
        return str;
    endfunction

endpackage : pci_vpd_verif_pkg