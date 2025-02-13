/*****************************************************
 * MEM Stage:
 * - Performs data memory read/write operations
 * - Determines branch address
 * - Asserts flush signal if branch taken or jump
 *****************************************************/
module mem_stage
  import rv32i_types::*;
(
    output logic [31:0] dmem_addr,
    output logic [3:0]  dmem_rmask,
    output logic [3:0]  dmem_wmask,
    output logic [31:0] dmem_wdata,
    output logic [31:0] branch_addr,
    output logic        flushing_inst,
    output logic        mem_forward_br_en,
    output logic [31:0] mem_forward_alu_out,
    output logic [31:0] mem_forward_u_imm,
    input  ex_mem_t     ex_mem,
    output mem_wb_t     mem_wb
);

  logic [31:0] branch_addr_mem;

  // Forwarding signals from MEM to EX stage
  assign mem_forward_br_en   = ex_mem.br_en;
  assign mem_forward_alu_out = ex_mem.aluout;
  assign mem_forward_u_imm   = ex_mem.u_imm;

  // Default outputs
  always_comb begin
    dmem_addr       = '0;
    dmem_rmask      = '0;
    dmem_wmask      = '0;
    dmem_wdata      = '0;
    mem_wb.dmem_addr = '0;

    if(ex_mem.opcode == op_b_load) begin
      // Load from memory
      mem_wb.dmem_addr = ex_mem.rs1_v + ex_mem.i_imm;
      dmem_addr        = mem_wb.dmem_addr & 32'hfffffffc;

      unique case (ex_mem.funct3)
        load_f3_lb,
        load_f3_lbu: dmem_rmask = 4'b0001 << mem_wb.dmem_addr[1:0];
        load_f3_lh,
        load_f3_lhu: dmem_rmask = 4'b0011 << mem_wb.dmem_addr[1:0];
        load_f3_lw : dmem_rmask = 4'b1111;
        default    : dmem_rmask = 'x;
      endcase
    end
    else if(ex_mem.opcode == op_b_store) begin
      // Store to memory
      mem_wb.dmem_addr = ex_mem.rs1_v + ex_mem.s_imm;
      dmem_addr        = mem_wb.dmem_addr & 32'hfffffffc;

      unique case (ex_mem.funct3)
        store_f3_sb: dmem_wmask = 4'b0001 << mem_wb.dmem_addr[1:0];
        store_f3_sh: dmem_wmask = 4'b0011 << mem_wb.dmem_addr[1:0];
        store_f3_sw: dmem_wmask = 4'b1111;
        default    : dmem_wmask = 'x;
      endcase

      unique case (ex_mem.funct3)
        store_f3_sb: dmem_wdata[8 * mem_wb.dmem_addr[1:0] +: 8]
                     = ex_mem.rs2_v[7:0];
        store_f3_sh: dmem_wdata[16* mem_wb.dmem_addr[1]   +: 16]
                     = ex_mem.rs2_v[15:0];
        store_f3_sw: dmem_wdata = ex_mem.rs2_v;
        default    : dmem_wdata = 'x;
      endcase
    end
  end

  // Branch address calculation
  always_comb begin
    if(ex_mem.opcode == op_b_jalr)
      branch_addr_mem = (ex_mem.rs1_v + ex_mem.i_imm) & 32'hfffffffe;
    else if(ex_mem.opcode == op_b_jal)
      branch_addr_mem = (ex_mem.pc + ex_mem.j_imm) & 32'hfffffffe;
    else if((ex_mem.opcode == op_b_br) && ex_mem.br_en)
      branch_addr_mem = ex_mem.pc + ex_mem.b_imm;
    else
      branch_addr_mem = 32'd0;
  end
  assign branch_addr = branch_addr_mem;

  // Flush if jump or branch taken
  always_comb begin
    if((ex_mem.opcode inside {op_b_jal, op_b_jalr}) ||
       ((ex_mem.opcode == op_b_br) && ex_mem.br_en))
      flushing_inst = 1'b1;
    else
      flushing_inst = 1'b0;
  end

  // Pass signals to MEM->WB pipeline register
  assign mem_wb.inst        = ex_mem.inst;
  assign mem_wb.funct3      = ex_mem.funct3;
  assign mem_wb.opcode      = ex_mem.opcode;
  assign mem_wb.rs1_s       = (ex_mem.opcode inside {op_b_jalr, op_b_br, op_b_load,
                                                     op_b_store, op_b_reg, op_b_imm})
                              ? ex_mem.rs1_s : '0;
  assign mem_wb.rs2_s       = (ex_mem.opcode inside {op_b_br, op_b_store, op_b_reg})
                              ? ex_mem.rs2_s : 5'b0;
  assign mem_wb.rs1_v       = (ex_mem.opcode inside {op_b_jalr, op_b_br, op_b_load,
                                                     op_b_store, op_b_reg, op_b_imm})
                              ? ex_mem.rs1_v : '0;
  assign mem_wb.rs2_v       = (ex_mem.opcode inside {op_b_br, op_b_store, op_b_reg})
                              ? ex_mem.rs2_v : '0;
  assign mem_wb.pc          = ex_mem.pc;
  assign mem_wb.regf_we     = ex_mem.regf_we;
  assign mem_wb.commit      = ex_mem.commit;
  assign mem_wb.dmem_rmask  = dmem_rmask;
  assign mem_wb.dmem_wmask  = dmem_wmask;
  assign mem_wb.dmem_wdata  = dmem_wdata;
  assign mem_wb.br_en       = ex_mem.br_en;
  assign mem_wb.branch_addr = branch_addr_mem;
  assign mem_wb.u_imm       = ex_mem.u_imm;
  assign mem_wb.aluout      = ex_mem.aluout;
  assign mem_wb.regfilemux_sel = ex_mem.regfilemux_sel;
  assign mem_wb.rd_s        = ex_mem.rd_s;

  // For return PC after branch/jump
  always_comb begin
    if((ex_mem.br_en == 1'b1) && (ex_mem.opcode == op_b_br))
      mem_wb.rvfi_pc_wdata = branch_addr_mem;
    else if (ex_mem.opcode inside {op_b_jal, op_b_jalr})
      mem_wb.rvfi_pc_wdata = branch_addr_mem;
    else 
      mem_wb.rvfi_pc_wdata = ex_mem.pc + 32'd4;
  end

endmodule
