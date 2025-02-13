module cpu
import rv32i_types::*;
(
    input   logic           clk,
    input   logic           rst,
    output  logic   [31:0]  mem_addr,
    output  logic   [3:0]   mem_rmask,
    output  logic   [3:0]   mem_wmask,
    input   logic   [31:0]  mem_rdata,
    output  logic   [31:0]  mem_wdata,
    input   logic           mem_resp
);

    enum int unsigned {
        s_reset,
        s_halt,
        s_fetch,
        s_decode,
        s_lui,
        s_aupic,
        s_jal,
        s_jalr,
        s_br,
        s_load,
        s_store,
        s_ri,
        s_rr
    } state, state_next;

            logic   [63:0]  order;

            logic           commit;
            logic   [31:0]  pc;
            logic   [31:0]  pc_next;

            logic           load_ir;
            logic   [31:0]  inst;
            logic   [2:0]   funct3;
            logic   [6:0]   funct7;
            logic   [6:0]   opcode;
            logic   [31:0]  i_imm;
            logic   [31:0]  s_imm;
            logic   [31:0]  b_imm;
            logic   [31:0]  u_imm;
            logic   [31:0]  j_imm;
            logic   [4:0]   rs1_s;
            logic   [4:0]   rs2_s;
            logic   [4:0]   rd_s;

            logic           regf_we;
            logic   [31:0]  rs1_v;
            logic   [31:0]  rs2_v;
            logic   [31:0]  rd_v;

            logic   [31:0]  a;
            logic   [31:0]  b;

            logic   [2:0]   aluop;
            logic   [2:0]   cmpop;

            logic   [31:0]  aluout;
            logic           br_en;

    assign funct3 = inst[14:12];
    assign funct7 = inst[31:25];
    assign opcode = inst[6:0];
    assign i_imm  = {{21{inst[31]}}, inst[30:20]};
    assign s_imm  = {{21{inst[31]}}, inst[30:25], inst[11:7]};
    assign b_imm  = {{20{inst[31]}}, inst[7], inst[30:25], inst[11:8], 1'b0};
    assign u_imm  = {inst[31:12], 12'h000};
    assign j_imm  = {{12{inst[31]}}, inst[19:12], inst[20], inst[30:21], 1'b0};
    assign rs1_s  = inst[19:15];
    assign rs2_s  = inst[24:20];
    assign rd_s   = inst[11:7];

    always_ff @(posedge clk) begin
        if (rst) begin
            inst <= '0;
        end else if (load_ir) begin
            inst <= mem_rdata;
        end
    end

    logic signed   [31:0] as;
    logic signed   [31:0] bs;
    logic unsigned [31:0] au;
    logic unsigned [31:0] bu;

    assign as =   signed'(a);
    assign bs =   signed'(b);
    assign au = unsigned'(a);
    assign bu = unsigned'(b);

    always_comb begin
        unique case (aluop)
            alu_op_add: aluout = au +   bu;
            alu_op_sll: aluout = au <<  bu[4:0];
            alu_op_sra: aluout = unsigned'(as >>> bu[4:0]);
            alu_op_sub: aluout = au -   bu;
            alu_op_xor: aluout = au ^   bu;
            alu_op_srl: aluout = au >>  bu[4:0];
            alu_op_or : aluout = au |   bu;
            alu_op_and: aluout = au &   bu;
            default   : aluout = 'x;
        endcase
    end

    always_comb begin
        unique case (cmpop)
            branch_f3_beq : br_en = (au == bu);
            branch_f3_bne : br_en = (au != bu);
            branch_f3_blt : br_en = (as <  bs);
            branch_f3_bge : br_en = (as >= bs);
            branch_f3_bltu: br_en = (au <  bu);
            branch_f3_bgeu: br_en = (au >= bu);
            default       : br_en = 1'bx;
        endcase
    end

    regfile regfile(
        .*
    );

    always_ff @(posedge clk) begin
        if (rst) begin
            state <= s_reset;
            pc    <= 32'h1eceb000;
            order <= '0;
        end else begin
            state <= state_next;
            pc    <= pc_next;
            if (commit) begin
                order <= order + 'd1;
            end
        end
    end

    always_comb begin
        state_next = state;
        commit     = 1'b0;
        pc_next    = pc;
        mem_addr   = 'x;
        mem_rmask  = '0;
        mem_wmask  = '0;
        mem_wdata  = 'x;
        rd_v       = 'x;
        load_ir    = 1'b0; //load instruction register
        regf_we    = 1'b0; //write enable
        a          = 'x;
        b          = 'x;
        aluop      = 'x;
        cmpop      = 'x;  // compare operation
        unique case (state)
            s_halt: begin
                pc_next = pc;
                commit = 1'b1;
            end
            s_reset: begin
                state_next = s_fetch;
            end
            s_fetch: begin
                mem_addr = pc;
                mem_rmask = '1;
                if (mem_resp) begin
                   load_ir = 1'b1;
                   state_next = s_decode;
                end
            end
            s_decode: begin
                unique case (opcode)
                    op_b_lui  : state_next = s_lui;
                    op_b_auipc: state_next = s_aupic;
                    op_b_jal  : state_next = s_jal;
                    op_b_jalr : state_next = s_jalr;
                    op_b_br   : state_next = s_br;
                    op_b_load : state_next = s_load;
                    op_b_store: state_next = s_store;
                    op_b_imm  : state_next = s_ri;
                    op_b_reg  : state_next = s_rr;
                    default   : state_next = s_halt;
                endcase
            end
            s_lui: begin
                rd_v = u_imm;
                regf_we = 1'b1;
                pc_next = pc + 'd4;
                commit = 1'b1;
                state_next = s_fetch;
            end
            s_aupic: begin
                rd_v = pc + u_imm;
                regf_we = 1'b1;
                pc_next = pc + 'd4;
                commit = 1'b1;
                state_next = s_fetch;
            end
            s_jal: begin
                rd_v = pc + 'd4;
                regf_we = 1'b1;
                pc_next = pc + j_imm;
                commit = 1'b1;
                state_next = s_fetch;
            end
            s_jalr: begin
                rd_v = pc + 'd4;
                regf_we = 1'b1;
                pc_next = (rs1_v + i_imm) & 32'hfffffffe;
                commit = 1'b1;
                state_next = s_fetch;
            end
            s_br: begin
                cmpop = funct3;
                a = rs1_v;
                b = rs2_v;
                if (br_en) begin
                    pc_next = pc + b_imm;
                end else begin
                    pc_next = pc + 'd4;
                end
                commit = 1'b1;
                state_next = s_fetch;
            end
            s_load: begin
                mem_addr = rs1_v+i_imm;
    
                unique case (funct3)
                    load_f3_lb, load_f3_lbu: mem_rmask = 4'b0001 << mem_addr[1:0];
                    load_f3_lh, load_f3_lhu: mem_rmask = 4'b0011 << mem_addr[1:0];
                                 load_f3_lw :mem_rmask = 4'b1111; 
                                 default: mem_rmask = 'x;
                endcase
                if (mem_resp) begin
                    regf_we = 1'b1;
                    unique case (funct3)
                        load_f3_lb : rd_v = {{24{mem_rdata[7 +8 *mem_addr[1:0]]}}, mem_rdata[8 *mem_addr[1:0] +: 8 ]};
                        load_f3_lbu: rd_v = {{24{1'b0}}                          , mem_rdata[8 *mem_addr[1:0] +: 8 ]};
                        load_f3_lh : rd_v = {{16{mem_rdata[15+16*mem_addr[1]  ]}}, mem_rdata[16*mem_addr[1]   +: 16]};    
                        load_f3_lhu: rd_v = {{16{1'b0}}                          , mem_rdata[16*mem_addr[1]   +: 16]};
                        load_f3_lw : rd_v =mem_rdata;
                        default    : rd_v = 'x;
                    endcase
                    pc_next = pc + 'd4;
                    commit = 1'b1;
                    state_next = s_fetch;
                end
                mem_addr[1:0] = 2'd0;
            end
            s_store: begin                
                mem_addr = rs1_v + s_imm;
                unique case (funct3)
                    store_f3_sb: mem_wmask = 4'b0001 << mem_addr[1:0];
                    store_f3_sh: mem_wmask = 4'b0011 << mem_addr[1:0];                          
                    store_f3_sw: mem_wmask = 4'b1111;     
                    default    : mem_wmask = 'x;
                endcase
                unique case (funct3)
                    store_f3_sb: mem_wdata[8 *mem_addr[1:0] +: 8 ] = rs2_v[7 :0];
                    store_f3_sh: mem_wdata[16*mem_addr[1]   +: 16] = rs2_v[15:0];
                    store_f3_sw: mem_wdata = rs2_v; 
                    default    : mem_wdata = 'x;
                endcase
                if (mem_resp) begin
                    pc_next = pc + 'd4;
                    commit = 1'b1;
                    state_next = s_fetch;
                end
                mem_addr[1:0] = 2'd0;
            end
            s_ri: begin
                a = rs1_v;
                b = i_imm;
                unique case (funct3)
                    arith_f3_slt: begin
                        cmpop = branch_f3_blt;
                        rd_v = {31'd0, br_en};
                    end
                    arith_f3_sltu: begin
                        cmpop = branch_f3_bltu;
                        rd_v = {31'd0, br_en};
                    end
                    arith_f3_sr: begin
                        if (funct7[5]) begin
                            aluop = alu_op_sra;
                        end else begin
                            aluop = alu_op_srl;
                        end
                        rd_v = aluout;
                    end
                    default: begin
                        aluop = funct3;
                        rd_v = aluout;
                    end
                endcase
                regf_we = 1'b1;
                pc_next = pc + 'd4;
                commit = 1'b1;
                state_next = s_fetch;
            end
            s_rr: begin
                a = rs1_v;
                b = rs2_v;
                unique case (funct3)
                    arith_f3_slt: begin
                        cmpop = branch_f3_blt;
                        rd_v = {31'd0, br_en};
                    end
                    arith_f3_sltu: begin
                        cmpop = branch_f3_bltu;
                        rd_v = {31'd0, br_en};
                    end
                    arith_f3_sr: begin
                        if (funct7[5]) begin
                            aluop = alu_op_sra;
                        end else begin
                            aluop = alu_op_srl;
                        end
                        rd_v = aluout;
                    end
                    arith_f3_add: begin
                        if (funct7[5]) begin
                            aluop = alu_op_sub;
                        end else begin
                            aluop = alu_op_add;
                        end
                        rd_v = aluout;
                    end
                    default: begin
                        aluop = funct3;
                        rd_v = aluout;
                    end
                endcase
                regf_we = 1'b1;
                pc_next = pc + 'd4;
                commit = 1'b1;
                state_next = s_fetch;
            end
            default: begin
                state_next = s_halt;
            end
        endcase
    end

            logic           monitor_valid;
            logic   [63:0]  monitor_order;
            logic   [31:0]  monitor_inst;
            logic   [4:0]   monitor_rs1_addr;
            logic   [4:0]   monitor_rs2_addr;
            logic   [31:0]  monitor_rs1_rdata;
            logic   [31:0]  monitor_rs2_rdata;
            logic           monitor_regf_we;
            logic   [4:0]   monitor_rd_addr;
            logic   [31:0]  monitor_rd_wdata;
            logic   [31:0]  monitor_pc_rdata;
            logic   [31:0]  monitor_pc_wdata;
            logic   [31:0]  monitor_mem_addr;
            logic   [3:0]   monitor_mem_rmask;
            logic   [3:0]   monitor_mem_wmask;
            logic   [31:0]  monitor_mem_rdata;
            logic   [31:0]  monitor_mem_wdata;

    assign monitor_valid     = commit;
    assign monitor_order     = order;
    assign monitor_inst      = inst;
    assign monitor_rs1_addr  = rs1_s;
    assign monitor_rs2_addr  = rs2_s;
    assign monitor_rs1_rdata = rs1_v;
    assign monitor_rs2_rdata = rs2_v;
    assign monitor_rd_addr   = regf_we ? rd_s : 5'd0;
    assign monitor_rd_wdata  = rd_v;
    assign monitor_pc_rdata  = pc;
    assign monitor_pc_wdata  = pc_next;
    assign monitor_mem_addr  = mem_addr;
    assign monitor_mem_rmask = state != s_fetch ? mem_rmask : 4'd0;
    assign monitor_mem_wmask = mem_wmask;
    assign monitor_mem_rdata = mem_rdata;
    assign monitor_mem_wdata = mem_wdata;

endmodule : cpu
