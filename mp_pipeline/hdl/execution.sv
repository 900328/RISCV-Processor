
/*****************************************************
 * EX Stage:
 * - Applies forwarding multiplexers
 * - Executes ALU operations
 * - Evaluates branches
 * - Generates signals for the MEM stage
 *****************************************************/
module ex_stage
  import rv32i_types::*;
  import forward_rs1_mux::*;
  import forward_rs2_mux::*;
(
    input  id_ex_t    id_ex,
    input  logic      mem_forward_br_en,
    input  logic [31:0] mem_forward_alu_out,
    input  logic [31:0] mem_forward_u_imm,
    input  logic [31:0] regfile_rdv_forward,
    input  forward_rs1_sel_t forward_rs1_sel,
    input  forward_rs2_sel_t forward_rs2_sel,
    input  logic      flushing_inst,
    input  if_id_t    if_id,
    output logic      stall_signal,
    output ex_mem_t   ex_mem
);

  logic signed   [31:0] as;
  logic unsigned [31:0] au;
  logic unsigned [31:0] bu;
  logic signed   [31:0] cmp_as;
  logic signed   [31:0] cmp_bs;
  logic unsigned [31:0] cmp_au;
  logic unsigned [31:0] cmp_bu;
  logic [31:0]          a;
  logic [31:0]          b;
  logic [31:0]          cmp_a, cmp_b;

  // Stall logic for load-use hazard
  always_comb begin
    // If EX stage is loading, and the next instruction depends on that load,
    // we stall one cycle.
    if ((id_ex.opcode == op_b_load) &&
        (id_ex.rd_s != 0) &&
        (if_id.inst[19:15] != 0) &&
        (if_id.inst[6:0] inside {op_b_load, op_b_store, op_b_imm,
                                 op_b_reg, op_b_br, op_b_jalr}) &&
        (id_ex.rd_s == if_id.inst[19:15]))
    begin
      stall_signal = 1'b1;
    end
    else if ((id_ex.opcode == op_b_load) &&
             (id_ex.rd_s != 0) &&
             (if_id.inst[24:20] != 0) &&
             (if_id.inst[6:0] inside {op_b_store, op_b_reg, op_b_br}) &&
             (id_ex.rd_s == if_id.inst[24:20]))
    begin
      stall_signal = 1'b1;
    end
    else begin
      stall_signal = 1'b0;
    end
  end

  // Flush EX->MEM pipeline register if requested
  always_comb begin
    if(flushing_inst) begin
      ex_mem.inst            = '0;
      ex_mem.funct3          = '0;
      ex_mem.opcode          = '0;
      ex_mem.rs1_s           = '0;
      ex_mem.rs2_s           = '0;
      ex_mem.rd_s            = '0;
      ex_mem.pc              = '0;
      ex_mem.regf_we         = '0;
      ex_mem.commit          = '0;
      ex_mem.i_imm           = '0;
      ex_mem.b_imm           = '0;
      ex_mem.j_imm           = '0;
      ex_mem.u_imm           = '0;
      ex_mem.s_imm           = '0;
      ex_mem.regfilemux_sel  = '0;
    end
    else begin
      ex_mem.inst            = id_ex.inst;
      ex_mem.funct3          = id_ex.funct3;
      ex_mem.opcode          = id_ex.opcode;
      ex_mem.rs1_s           = id_ex.rs1_s;
      ex_mem.rs2_s           = id_ex.rs2_s;
      ex_mem.rd_s            = id_ex.rd_s;
      ex_mem.pc              = id_ex.pc;
      ex_mem.regf_we         = id_ex.regf_we;
      ex_mem.commit          = id_ex.valid;
      ex_mem.i_imm           = id_ex.i_imm;
      ex_mem.b_imm           = id_ex.b_imm;
      ex_mem.j_imm           = id_ex.j_imm;
      ex_mem.u_imm           = id_ex.u_imm;
      ex_mem.s_imm           = id_ex.s_imm;
      ex_mem.regfilemux_sel  = id_ex.regfilemux_sel;
    end
  end

  // Forwarding multiplexers for rs1
  always_comb begin
    unique case (forward_rs1_sel)
      forward_rs1_mux::rs1_v       : ex_mem.rs1_v = id_ex.rs1_v;
      forward_rs1_mux::br_en       : ex_mem.rs1_v = {31'b0, mem_forward_br_en};
      forward_rs1_mux::alu_out     : ex_mem.rs1_v = mem_forward_alu_out;
      forward_rs1_mux::regfile_out : ex_mem.rs1_v = regfile_rdv_forward;
      forward_rs1_mux::u_imm       : ex_mem.rs1_v = mem_forward_u_imm;
      default                      : ex_mem.rs1_v = id_ex.rs1_v;
    endcase
  end

  // Forwarding multiplexers for rs2
  always_comb begin
    unique case (forward_rs2_sel)
      forward_rs2_mux::rs2_v       : ex_mem.rs2_v = id_ex.rs2_v;
      forward_rs2_mux::br_en       : ex_mem.rs2_v = {31'b0, mem_forward_br_en};
      forward_rs2_mux::alu_out     : ex_mem.rs2_v = mem_forward_alu_out;
      forward_rs2_mux::regfile_out : ex_mem.rs2_v = regfile_rdv_forward;
      forward_rs2_mux::u_imm       : ex_mem.rs2_v = mem_forward_u_imm;
      default                      : ex_mem.rs2_v = id_ex.rs2_v;
    endcase
  end

  // ALU input selection (after forwarding)
  always_comb begin
    unique case(id_ex.alu_rs1_sel)
      1'b0: a = ex_mem.rs1_v;
      1'b1: a = id_ex.pc;  // PC-based operations
      default: a = ex_mem.rs1_v;
    endcase
  end

  always_comb begin
    unique case(id_ex.alu_rs2_sel)
      1'b0: b = ex_mem.rs2_v;
      1'b1: b = id_ex.imm_out; // immediate
      default: b = ex_mem.rs2_v;
    endcase
  end

  // Compare input selection
  always_comb begin
    cmp_b = (id_ex.cmp_sel) ? id_ex.i_imm : ex_mem.rs2_v;
    cmp_a = ex_mem.rs1_v;
  end

  // Signed and unsigned conversions
  assign cmp_as = signed'(cmp_a);
  assign cmp_bs = signed'(cmp_b);
  assign cmp_au = unsigned'(cmp_a);
  assign cmp_bu = unsigned'(cmp_b);

  assign as = signed'(a);
  assign au = unsigned'(a);
  assign bu = unsigned'(b);

  // ALU operations
  always_comb begin
    unique case (id_ex.aluop)
      alu_op_add: ex_mem.aluout = au + bu;
      alu_op_sll: ex_mem.aluout = au << bu[4:0];
      alu_op_sra: ex_mem.aluout = unsigned'(as >>> bu[4:0]);
      alu_op_sub: ex_mem.aluout = au - bu;
      alu_op_xor: ex_mem.aluout = au ^ bu;
      alu_op_srl: ex_mem.aluout = au >> bu[4:0];
      alu_op_or : ex_mem.aluout = au | bu;
      alu_op_and: ex_mem.aluout = au & bu;
      default   : ex_mem.aluout = 'x;
    endcase
  end

  // Branch condition evaluation
  always_comb begin
    unique case (id_ex.cmpop)
      branch_f3_beq : ex_mem.br_en = (cmp_au == cmp_bu);
      branch_f3_bne : ex_mem.br_en = (cmp_au != cmp_bu);
      branch_f3_blt : ex_mem.br_en = (cmp_as <  cmp_bs);
      branch_f3_bge : ex_mem.br_en = (cmp_as >= cmp_bs);
      branch_f3_bltu: ex_mem.br_en = (cmp_au <  cmp_bu);
      branch_f3_bgeu: ex_mem.br_en = (cmp_au >= cmp_bu);
      default       : ex_mem.br_en = 1'bx;
    endcase
  end

endmodule

