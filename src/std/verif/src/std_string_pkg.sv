// String manipulation utility package
package std_string_pkg;

    // String : indent
    function automatic string indent(
            input string str,
            input int indent_spaces=8,
            input bit newline=1
        );
        string _str = {{indent_spaces{" "}}, str};
        if (newline) _str = {_str, "\n"};
        return _str;
    endfunction : indent

    // String : horizontal line
    function automatic string horiz_line(
            input int length=70,
            input bit newline=1
        );
        string _str = {length{"-"}};
        if (newline) _str = {_str, "\n"};
        return _str;
    endfunction

    // String : convert byte array to hex string
    function automatic string byte_array_to_hex_string(input byte ba[$]);
        string str = "";
        foreach (ba[i]) begin
            str = {str, $sformatf("%2x", ba[i])};
        end
        return str;
    endfunction

    // String : convert byte array to ASCII string
    function automatic string byte_array_to_ascii_string(input byte ba[$]);
        string str = "";
        byte c;
        foreach (ba[i]) begin
            // Filter unprintable characters (replace with space)
            if (ba[i] < 'd32) c = " ";
            else              c = ba[i];
            str = {str, $sformatf("%c", c)};
        end
        return str;
    endfunction

    // String : print byte array in hex and ASCII format, in rows of 16 bytes (similar to xxd)
    function automatic string byte_array_to_string(input byte ba[$]);
        string str = "";
        int byte_idx = 0;
        int row_idx = 0;
        while (ba.size() > 0) begin
            string hex_str = "";
            string ascii_str = "";
            for (int i = 0; i < 2; i++) begin
                for (int j = 0; j < 4; j++) begin
                    byte ba_segment [$] = {};
                    string pad_str = "";
                    for (int k = 0; k < 2; k++) begin
                        if (ba.size() > 0) ba_segment.push_back(ba.pop_front());
                        else pad_str = {pad_str, " "};
                        byte_idx++;
                    end
                    hex_str = {hex_str, byte_array_to_hex_string(ba_segment), {2{pad_str}}, " "};
                    ascii_str = {ascii_str, byte_array_to_ascii_string(ba_segment), pad_str};
                end
                hex_str = {hex_str, " "};
            end
            str = {str, $sformatf("0x%4x:  %s|  %s\n", row_idx*16, hex_str, ascii_str)};
            row_idx++;
        end
        return str;
    endfunction

endpackage : std_string_pkg

