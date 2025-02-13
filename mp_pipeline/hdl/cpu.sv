/***************************************
 * CPU Top-Level Pipeline Module
 * Instantiates the IF, ID, EX, MEM, WB stages
 * and wires them together.
 ***************************************/
module cpu
  import rv32i_types::*;
  import forward_rs1_mux::*;
  import forward_rs2_mux::*;
(
    input  logic         clk,
    input  logic         rst,

    // Instruction Memory Interface
    output logic [31:0]  imem_addr,
    output logic [3:0]   imem_rmask,
    input  logic [31:0]  imem_rdata,
    input  logic         imem_resp,

    // Data Memory Interface
    output logic [31:0]  dmem_addr,
    output logic [3:0]   dmem_rmask,
    output logic [3:0]   dmem_wmask,
    input  logic [31:0]  dmem_rdata,
    output logic [31:0]  dmem_wdata,
    input  logic         dmem_resp
);

  // Pipeline Registers
  if_id_t    if_id_reg,       if_id_reg_stall;
  id_ex_t    id_ex_reg,       id_ex_reg_next;
  ex_mem_t   ex_mem_reg,      ex_mem_reg_next;
  mem_wb_t   mem_wb_reg,      mem_wb_reg_next;

  // Forwarding Control Signals
  forward_rs2_sel_t forward_rs2_sel;
  forward_rs1_sel_t forward_rs1_sel;

  // Control Signals
  logic        stall_signal;
  logic        mem_forward_br_en;
  logic [31:0] mem_forward_alu_out;
  logic [31:0] mem_forward_u_imm;
  logic [31:0] branch_addr;
  logic        flushing_inst;
  logic [31:0] regfilerdv;
  logic        regf_we_wb; 
  logic [4:0]  rd_s_back;
  logic        dmem_req;

  // Pass IF register directly to "stall" register (placeholder for stall logic)
  assign if_id_reg_stall = if_id_reg;

  /****************************************************
   * Simple pipeline register update example
   * If dmem_req is asserted, hold pipeline registers;
   * else load from previous pipeline stage or reset.
   ****************************************************/
  always_ff @(posedge clk) begin
    if (dmem_req) begin
      // Hold pipeline states if dmem_req is active
      id_ex_reg_next   <= id_ex_reg_next;
      ex_mem_reg_next  <= ex_mem_reg_next;
      mem_wb_reg_next  <= mem_wb_reg_next;
    end
    else begin
      // On reset, clear pipeline registers
      id_ex_reg_next   <= (rst ? '0 : id_ex_reg);
      ex_mem_reg_next  <= (rst ? '0 : ex_mem_reg);
      mem_wb_reg_next  <= (rst ? '0 : mem_wb_reg);
    end
  end

  /****************************************
   * IF (Instruction Fetch) Stage
   * Fetches instructions from IMEM,
   * updates program counter (PC).
   ****************************************/
  if_stage if_stage(
      .rst(rst),
      .clk(clk),
      .stall_signal(stall_signal),
      .branch_addr(branch_addr),
      .flushing_inst(flushing_inst),
      .imem_resp(imem_resp),
      .dmem_req(dmem_req),
      .imem_rmask(imem_rmask),
      .imem_rdata(imem_rdata),
      .imem_addr(imem_addr),
      .if_id_reg_stall(if_id_reg_stall),
      .if_id(if_id_reg)
  );

  /***********************************************
   * ID (Instruction Decode) Stage
   * Decodes the fetched instruction, reads
   * registers from RegFile, computes control signals.
   ***********************************************/
  id_stage id_stage(
      .rst(rst),
      .clk(clk),
      .flushing_inst(flushing_inst),
      .stall_signal(stall_signal),
      .regf_we_back(regf_we_wb),
      .rd_s_back(rd_s_back),
      .regfilerdv(regfilerdv),
      .if_id(if_id_reg),
      .id_ex(id_ex_reg)
  );

  /***********************************************
   * EX (Execute) Stage
   * Performs ALU operations, branch comparisons,
   * and sets up signals for memory stage.
   ***********************************************/
  ex_stage ex_stage(
      .flushing_inst(flushing_inst),
      .forward_rs1_sel(forward_rs1_sel),
      .forward_rs2_sel(forward_rs2_sel),
      .regfile_rdv_forward(regfilerdv),
      .mem_forward_br_en(mem_forward_br_en),
      .mem_forward_alu_out(mem_forward_alu_out),
      .mem_forward_u_imm(mem_forward_u_imm),
      .stall_signal(stall_signal),
      .if_id(if_id_reg),
      .id_ex(id_ex_reg_next),
      .ex_mem(ex_mem_reg)
  );

  /***********************************************
   * MEM (Memory) Stage
   * Handles data memory reads/writes,
   * calculates branch address if needed,
   * decides whether to flush instructions.
   ***********************************************/
  mem_stage mem_stage(
      .mem_forward_br_en(mem_forward_br_en),
      .mem_forward_alu_out(mem_forward_alu_out),
      .mem_forward_u_imm(mem_forward_u_imm),
      .flushing_inst(flushing_inst),
      .branch_addr(branch_addr),
      .ex_mem(ex_mem_reg_next),
      .dmem_rmask(dmem_rmask),
      .dmem_wmask(dmem_wmask),
      .dmem_wdata(dmem_wdata),
      .dmem_addr(dmem_addr),
      .mem_wb(mem_wb_reg)
  );

  /***********************************************
   * WB (Write-Back) Stage
   * Selects final write-back data for RegFile
   * from ALU results or memory loads.
   ***********************************************/
  wb_stage wb_stage (
      .clk(clk),
      .rst(rst),
      .mem_wb(mem_wb_reg_next),
      .regfilerdv(regfilerdv),
      .rds_back(rd_s_back),
      .dmem_req(dmem_req),
      .dmem_rdata(dmem_rdata),
      .dmem_resp(dmem_resp),
      .regf_we_back(regf_we_wb)
  );

  /****************************************************
   * Forwarding Unit
   * Chooses correct source for ALU inputs (EX stage)
   * based on hazards with later pipeline stages.
   ****************************************************/
  forward forward(
      .id_ex(id_ex_reg_next),
      .ex_mem(ex_mem_reg_next),
      .mem_wb(mem_wb_reg_next),
      .forward_rs1_sel(forward_rs1_sel),
      .forward_rs2_sel(forward_rs2_sel)
  );

endmodule : cpu
