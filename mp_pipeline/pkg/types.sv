/////////////////////////////////////////////////////////////
// Maybe merge what is in mp_verif/pkg/types.sv over here? //
/////////////////////////////////////////////////////////////

package rv32i_types;
    typedef enum logic [6:0] {
        op_b_lui       = 7'b0110111, // load upper immediate (U type)
        op_b_auipc     = 7'b0010111, // add upper immediate PC (U type)
        op_b_jal       = 7'b1101111, // jump and link (J type)
        op_b_jalr      = 7'b1100111, // jump and link register (I type)
        op_b_br        = 7'b1100011, // branch (B type)
        op_b_load      = 7'b0000011, // load (I type)
        op_b_store     = 7'b0100011, // store (S type)
        op_b_imm       = 7'b0010011, // arith ops with register/immediate operands (I type)
        op_b_reg       = 7'b0110011  // arith ops with register operands (R type)
    } rv32i_opcode;

    typedef enum logic [2:0] {
        arith_f3_add   = 3'b000, // check logic 30 for sub if op_reg op
        arith_f3_sll   = 3'b001,
        arith_f3_slt   = 3'b010,
        arith_f3_sltu  = 3'b011,
        arith_f3_xor   = 3'b100,
        arith_f3_sr    = 3'b101, // check logic 30 for logical/arithmetic
        arith_f3_or    = 3'b110,
        arith_f3_and   = 3'b111
    } arith_f3_t;

    typedef enum logic [2:0] {
        load_f3_lb     = 3'b000,
        load_f3_lh     = 3'b001,
        load_f3_lw     = 3'b010,
        load_f3_lbu    = 3'b100,
        load_f3_lhu    = 3'b101
    } load_f3_t;

    typedef enum logic [2:0] {
        store_f3_sb    = 3'b000,
        store_f3_sh    = 3'b001,
        store_f3_sw    = 3'b010
    } store_f3_t;

    typedef enum logic [2:0] {
        branch_f3_beq  = 3'b000,
        branch_f3_bne  = 3'b001,
        branch_f3_blt  = 3'b100,
        branch_f3_bge  = 3'b101,
        branch_f3_bltu = 3'b110,
        branch_f3_bgeu = 3'b111
    } branch_f3_t;

    typedef enum logic [2:0] {
        alu_op_add     = 3'b000,
        alu_op_sll     = 3'b001,
        alu_op_sra     = 3'b010,
        alu_op_sub     = 3'b011,
        alu_op_xor     = 3'b100,
        alu_op_srl     = 3'b101,
        alu_op_or      = 3'b110,
        alu_op_and     = 3'b111
    } alu_ops;

       typedef enum logic [6:0] {
        base           = 7'b0000000,
        variant        = 7'b0100000
    } funct7_t;

    typedef union packed {
        logic [31:0] word;

        struct packed {
            logic [11:0] i_imm;
            logic [4:0]  rs1;
            logic [2:0]  funct3;
            logic [4:0]  rd;
            rv32i_opcode opcode;
        } i_type;

        struct packed {
            logic [6:0]  funct7;
            logic [4:0]  rs2;
            logic [4:0]  rs1;
            logic [2:0]  funct3;
            logic [4:0]  rd;
            rv32i_opcode opcode;
        } r_type;

        struct packed {
            logic [11:5] imm_s_top;
            logic [4:0]  rs2;
            logic [4:0]  rs1;
            logic [2:0]  funct3;
            logic [4:0]  imm_s_bot;
            rv32i_opcode opcode;
        } s_type;
        struct packed {
            logic [11:5] imm_b_top;
            logic [4:0]  rs2;
            logic [4:0]  rs1;
            logic [2:0]  funct3;
            logic [4:0]  imm_b_bot;
            rv32i_opcode opcode;
        } b_type;

        struct packed {
            logic [31:12] imm;
            logic [4:0]  rd;
            rv32i_opcode opcode;
        } u_type;
        struct packed {
            logic [31:12] imm;
            logic [4:0]   rd;
            rv32i_opcode  opcode;
        } j_type;

    } instr_t;


typedef struct packed {     
    logic [31:0] pc;    
    logic [31:0] inst; 
    logic        valid;
} if_id_t;

typedef struct packed {
    logic [31:0] inst;
    logic [4:0]  rs1_s; 
    logic [4:0]  rs2_s;
    logic [31:0] rs1_v; 
    logic [31:0] rs2_v; 
    logic [31:0] pc;
    logic [6:0]  opcode;
    logic [4:0]  rd_s;
    logic [31:0] s_imm;
    logic [31:0] i_imm;
    logic [31:0] u_imm;
    logic [31:0] b_imm;
    logic [31:0] j_imm;   
    logic [2:0]  funct3;
    logic [6:0]  funct7;       
    logic        valid;
    logic        alu_rs1_sel;
    logic        alu_rs2_sel;
    logic [31:0] imm_out;
    logic        cmp_sel;
    logic   [2:0]   cmpop;
    logic   [2:0]   aluop;
    logic        regf_we;
    logic   [3:0]regfilemux_sel;
} id_ex_t;

typedef struct packed {
    logic [31:0] inst; 
    logic [2:0]  funct3;
    logic [6:0]  opcode;
    logic [4:0]  rs1_s; 
    logic [4:0]  rs2_s;
    logic [31:0] rs1_v; 
    logic [31:0] rs2_v;
    logic [31:0] pc;
    logic        regf_we; 
    logic [4:0]  rd_s;      
    logic        commit;
    logic        br_en;
    logic [31:0] i_imm;
    logic [31:0] j_imm;  
    logic [31:0] b_imm; 
    logic [31:0] u_imm; 
    logic [31:0] s_imm;
    logic [31:0] aluout;
    logic   [3:0]regfilemux_sel;
} ex_mem_t;

typedef struct packed {
    logic [31:0] inst; 
    logic [2:0]  funct3;
    logic [6:0]  opcode;
    logic [4:0]  rs1_s; 
    logic [4:0]  rs2_s;
    logic [31:0] rs1_v; 
    logic [31:0] rs2_v;
    logic [31:0] pc;
    logic        regf_we; 
    logic [4:0]  rd_s;       
    logic        commit;
    logic   [31:0]  dmem_addr;
    logic   [3:0]   dmem_rmask;
    logic   [3:0]   dmem_wmask;
    logic   [31:0]  dmem_wdata;
    logic   [31:0]  u_imm;
    logic          br_en;
    logic   [31:0] branch_addr;
    logic  [31:0]  aluout;
    logic   [3:0]regfilemux_sel;
   logic   [31:0] rvfi_pc_wdata;
} mem_wb_t;
endpackage: rv32i_types

package forward_rs1_mux;
typedef enum bit [2:0] {
   rs1_v    = 3'b000,
   alu_out  = 3'b001,
   br_en    = 3'b010,
   u_imm    = 3'b011,
   regfile_out = 3'b100,
    pc       =  3'b101
} forward_rs1_sel_t;
endpackage

package forward_rs2_mux;
typedef enum bit [2:0] {
   rs2_v    = 3'b000,
   alu_out  = 3'b001,
   br_en    = 3'b010,
   u_imm    = 3'b011,
   regfile_out = 3'b100,
    imm_out       =  3'b101
} forward_rs2_sel_t;
endpackage

