/*****************************************************
 * ID Stage:
 * - Decodes instruction fields
 * - Reads register file
 * - Generates immediate values and control signals
 *****************************************************/
module id_stage
  import rv32i_types::*;
(
    input  logic       clk,
    input  logic       rst,
    input  logic [4:0] rd_s_back,
    input  logic       regf_we_back,
    input  logic [31:0] regfilerdv,
    input  logic       flushing_inst,
    input  logic       stall_signal,
    input  if_id_t     if_id,
    output id_ex_t     id_ex
);

  // Generate pipeline fields; flush or stall zeros them
  always_comb begin
    if(flushing_inst || stall_signal) begin
      id_ex.inst    = '0;
      id_ex.pc      = '0;
      id_ex.valid   = '0;
      id_ex.funct3  = '0;
      id_ex.funct7  = '0;
      id_ex.opcode  = '0;
      id_ex.i_imm   = '0;
      id_ex.s_imm   = '0;
      id_ex.b_imm   = '0;
      id_ex.u_imm   = '0;
      id_ex.j_imm   = '0;
      id_ex.rs1_s   = '0;
      id_ex.rs2_s   = '0;
      id_ex.rd_s    = '0;
    end
    else begin
      id_ex.inst    = if_id.inst;
      id_ex.pc      = if_id.pc;
      id_ex.valid   = if_id.valid;
      id_ex.funct3  = id_ex.inst[14:12];
      id_ex.funct7  = id_ex.inst[31:25];
      id_ex.opcode  = id_ex.inst[6:0];
      id_ex.i_imm   = {{21{id_ex.inst[31]}}, id_ex.inst[30:20]};
      id_ex.s_imm   = {{21{id_ex.inst[31]}}, id_ex.inst[30:25], id_ex.inst[11:7]};
      id_ex.b_imm   = {{20{id_ex.inst[31]}}, id_ex.inst[7], id_ex.inst[30:25], id_ex.inst[11:8], 1'b0};
      id_ex.u_imm   = {id_ex.inst[31:12], 12'h000};
      id_ex.j_imm   = {{12{id_ex.inst[31]}}, id_ex.inst[19:12], id_ex.inst[20], id_ex.inst[30:21], 1'b0};
      id_ex.rs1_s   = id_ex.inst[19:15];
      id_ex.rs2_s   = id_ex.inst[24:20];
      // For store/branch, rd_s is 0. Otherwise it's bits [11:7].
      id_ex.rd_s    = (id_ex.opcode != op_b_store && id_ex.opcode != op_b_br)
                      ? id_ex.inst[11:7] : '0;
    end
  end

  // Register File Instantiation
  regfile regfile(
      .clk(clk),
      .rst(rst),
      .rs1_s(id_ex.rs1_s),
      .rs2_s(id_ex.rs2_s),
      .rd_s(rd_s_back),
      .rd_v(regfilerdv),
      .rs1_v(id_ex.rs1_v),
      .rs2_v(id_ex.rs2_v),
      .regf_we(regf_we_back)
  );

  // Immediate selection for ALU
    always_comb begin
        unique case(id_ex.opcode) 
            op_b_lui :   id_ex.imm_out = id_ex.u_imm;
            op_b_auipc : id_ex.imm_out = id_ex.u_imm;
            op_b_jal :   id_ex.imm_out = id_ex.j_imm;
            op_b_jalr :  id_ex.imm_out = id_ex.i_imm;
            op_b_br :    id_ex.imm_out = id_ex.b_imm;
            op_b_load :  id_ex.imm_out = id_ex.i_imm;
            op_b_store : id_ex.imm_out = id_ex.s_imm;
            op_b_imm :   id_ex.imm_out = id_ex.i_imm;
            default :    id_ex.imm_out = 32'd0;
        endcase
    end
  // ALU operand selection signals
  always_comb begin
    unique case(id_ex.opcode)
      op_b_lui   : id_ex.alu_rs1_sel = 1'b0;
      op_b_auipc : id_ex.alu_rs1_sel = 1'b1; // Use PC
      op_b_jal   : id_ex.alu_rs1_sel = 1'b1; // Use PC
      op_b_jalr  : id_ex.alu_rs1_sel = 1'b0;
      op_b_br    : id_ex.alu_rs1_sel = 1'b1; // Use PC
      op_b_load,
      op_b_store,
      op_b_imm,
      op_b_reg   : id_ex.alu_rs1_sel = 1'b0;
      default    : id_ex.alu_rs1_sel = 1'b0;
    endcase
  end

  always_comb begin
    if(id_ex.opcode inside {op_b_lui, op_b_auipc, op_b_jal, op_b_jalr, op_b_br,
                            op_b_load, op_b_store})
      id_ex.alu_rs2_sel = 1'b1;  // immediate
    else if((id_ex.opcode == op_b_imm) &&
            (id_ex.funct3 inside {arith_f3_add, arith_f3_slt, arith_f3_sltu,
                                  arith_f3_xor, arith_f3_or, arith_f3_and, arith_f3_sll}))
      id_ex.alu_rs2_sel = 1'b1;
    else if((id_ex.opcode == op_b_imm) && (id_ex.funct3 == arith_f3_sr))
      id_ex.alu_rs2_sel = 1'b1;
    else
      id_ex.alu_rs2_sel = 1'b0;
  end

  // Comparator selection for branches / SLT
  always_comb begin
    if(id_ex.opcode == op_b_br) begin
      id_ex.cmp_sel = 1'b0;
    end
    else if((id_ex.opcode == op_b_imm) &&
            (id_ex.funct3 inside {arith_f3_slt, arith_f3_sltu})) begin
      id_ex.cmp_sel = 1'b1;
    end
    else begin
      id_ex.cmp_sel = 1'b0;
    end
  end

  // CMP opcode signals
  always_comb begin
    if((id_ex.opcode inside {op_b_imm, op_b_reg}) && (id_ex.funct3 == arith_f3_slt))
      id_ex.cmpop = branch_f3_blt;
    else if((id_ex.opcode inside {op_b_imm, op_b_reg}) && (id_ex.funct3 == arith_f3_sltu))
      id_ex.cmpop = branch_f3_bltu;
    else if (id_ex.opcode == op_b_br)
      id_ex.cmpop = id_ex.funct3;
    else
      id_ex.cmpop = '0;
  end

  // RegFile Write-Enable
  always_comb begin
    if(id_ex.opcode inside {op_b_load, op_b_lui, op_b_auipc,
                            op_b_jal, op_b_jalr, op_b_imm, op_b_reg})
      id_ex.regf_we = 1'b1;
    else
      id_ex.regf_we = 1'b0;
  end

  // ALU opcode selection
  always_comb begin
    if(id_ex.opcode inside {op_b_lui, op_b_auipc, op_b_br, op_b_jal, op_b_jalr}) begin
      id_ex.aluop = alu_op_add;
    end
    else if (id_ex.opcode == op_b_imm) begin
      if(id_ex.funct3 == arith_f3_sr)
        id_ex.aluop = (id_ex.funct7[5] ? alu_op_sra : alu_op_srl);
      else if(id_ex.funct3 inside {arith_f3_slt, arith_f3_sltu})
        id_ex.aluop = alu_op_add; // for SLT we do difference
      else
        id_ex.aluop = id_ex.funct3;
    end
    else if (id_ex.opcode == op_b_reg) begin
      if(id_ex.funct3 == arith_f3_sr)
        id_ex.aluop = (id_ex.funct7[5] ? alu_op_sra : alu_op_srl);
      else if (id_ex.funct3 == arith_f3_add)
        id_ex.aluop = (id_ex.funct7[5] ? alu_op_sub : alu_op_add);
      else if(id_ex.funct3 inside {arith_f3_slt, arith_f3_sltu})
        id_ex.aluop = alu_op_add;
      else
        id_ex.aluop = id_ex.funct3;
    end
    else begin
      id_ex.aluop = id_ex.funct3;
    end
  end

  // Mux selection for writing data back to the register file
  always_comb begin
    case(id_ex.opcode)
      op_b_br: // no register write
        id_ex.regfilemux_sel = 'x;

      op_b_jal,
      op_b_jalr:
        id_ex.regfilemux_sel = 4'b0100; // PC+4

      op_b_reg,
      op_b_imm: begin
        if(id_ex.funct3 inside {arith_f3_slt, arith_f3_sltu})
          id_ex.regfilemux_sel = 4'b0001; // set if less than
        else
          id_ex.regfilemux_sel = 4'b0000; // ALU
      end

      op_b_auipc:
        id_ex.regfilemux_sel = 4'b0000; // PC + imm

      op_b_lui:
        id_ex.regfilemux_sel = 4'b0010; // immediate only

      op_b_load: begin
        // Different sub-types of load have different sign extensions
        case(id_ex.funct3)
          load_f3_lb  : id_ex.regfilemux_sel = 4'b0101;
          load_f3_lbu : id_ex.regfilemux_sel = 4'b0110;
          load_f3_lh  : id_ex.regfilemux_sel = 4'b0111;
          load_f3_lhu : id_ex.regfilemux_sel = 4'b1000;
          default     : id_ex.regfilemux_sel = 4'b0011; // LW
        endcase
      end

      default:
        id_ex.regfilemux_sel = 4'b0000;
    endcase
  end

endmodule


