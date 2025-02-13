package rv32i_types;

    typedef struct packed {

        logic [31:0] mem_addr;
        logic [31:0] wdata;
        logic [3:0] rmask;
        logic [3:0] wmask;
        logic [22:0] tag;
        logic [3:0]  set;
        logic [4:0]  offset;
        logic dirty_write_back;
        logic mem_resp;
    } stage_reg_t;


endpackage
