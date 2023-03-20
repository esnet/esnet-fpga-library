interface db_info_intf;

    // Imports
    import db_pkg::*;

    // Signals
    type_t       _type;
    subtype_t    subtype;
    logic [31:0] size;

    modport controller(
        input  _type,
        input  subtype,
        input  size
    );

    modport peripheral(
        output _type,
        output subtype,
        output size
    );
endinterface : db_info_intf
