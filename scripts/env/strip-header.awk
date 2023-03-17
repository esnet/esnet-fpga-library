#!/bin/awk -f
BEGIN {
    header_open = 0;
    header_found = 0;
    header_done = 0;
}
{
    # Look for copyright header, if one has not already been processed
    # (this script is capable of removing at most one header in a given pass)
    if (!header_done) {

        # If known copyright header is currently in process, look for
        # 'banner' separator (e.g. ===) as end of header
        if (header_found) {
            if (/^\/\/\ *=+/ || /^#\ *=+/) {
                header_done = 1;
            }
        }
        # If 'banner' separator has been found, current banner is copyright
        # header if first line matches expected format
        else if (header_open) {
            if (/^\/\/\ *NOTICE:/ || /^#\ *NOTICE:/) header_found = 1;
            else {
                header_open = 0;
                print header_open_text;
            }
        }
        # Search for 'banner' separator (e.g. ===)
        # This separator *could* represent the first line of copyright header
        # (we don't know until we process the second line, so store this line
        #  in case it isn't part of a copyright header)
        else if (/^\/\/\ *=+/ || /^#\ *=+/) {
            header_open_text = $0;
            header_open = 1;
        }

    # Once the full header has been processed, also delete all trailing empty lines
    } else if (header_open && !/^\ *$/) header_open = 0;

    # Only emit lines not suspected as being part of header
    if (header_open == 0) print $0;
}
