
/*****************************************************
 * IF Stage:
 * - Maintains and updates the program counter (PC)
 * - Handles instruction fetch interface signals
 * - Stalls or flushes as required
 *****************************************************/
module if_stage
  import rv32i_types::*;
(
    input  logic       clk,
    input  logic       rst,
    input  logic       imem_resp,
    input  logic [31:0] imem_rdata,
    input  logic       dmem_req,
    input  logic       flushing_inst,
    input  logic [31:0] branch_addr,
    input  logic       stall_signal,
    output logic [3:0] imem_rmask,
    output logic [31:0] imem_addr,
    input  if_id_t     if_id_reg_stall,
    output if_id_t     if_id
);

  logic [31:0] pc;
  logic [31:0] pc_next;
  logic [31:0] inst_stall;
  logic [31:0] inst;
  logic        stall_next;
  logic        br_en_nextpc;
  logic        br_en_next;

  // PC register update
  always_ff @(posedge clk) begin
    if(rst) begin
      pc <= 32'h1eceb000;
    end
    else if(flushing_inst) begin
      pc <= branch_addr;
    end
    else if(!imem_resp || dmem_req || br_en_nextpc || stall_signal) begin
      pc <= pc; // stall/hold PC
    end
    else begin
      pc <= pc + 32'd4; // next PC
    end
  end

  // Calculate next address for IMEM
  always_comb begin
    if(flushing_inst) begin
      imem_addr = branch_addr;
    end
    else if(!imem_resp || stall_signal || dmem_req || br_en_nextpc) begin
      imem_addr = pc;
    end 
    else begin
      imem_addr = pc + 4;
    end
  end

  // Pipeline IF/ID register for PC
  always_ff @(posedge clk) begin
    if (rst) begin
      if_id.pc <= '0;
    end
    else if (stall_signal) begin
      if_id.pc <= if_id_reg_stall.pc;
    end
    else begin
      if_id.pc <= pc;
    end
  end

  // Branch enable handshake (delays flush until instruction is valid)
  always_comb begin
    br_en_nextpc = 1'b0;
    if (br_en_next && imem_resp)
      br_en_nextpc = 1'b1;
  end

  always_ff @(posedge clk) begin
    if(rst) 
      br_en_next <= 1'b0;
    else if(flushing_inst)
      br_en_next <= 1'b1;
    else if(br_en_nextpc && imem_resp)
      br_en_next <= 1'b0;
  end

  // Pipeline IF/ID register for instruction validity and data
  always_ff @(posedge clk) begin
    if(rst) begin
      if_id.valid <= '0;
      if_id.inst  <= '0;
    end
    else if(stall_signal) begin
      if_id.valid <= if_id_reg_stall.valid;
      if_id.inst  <= if_id_reg_stall.inst;
    end
    else if(flushing_inst || br_en_nextpc) begin
      if_id.valid <= '0;
      if_id.inst  <= '0;
    end 
    else begin
      if_id.valid <= imem_resp;
      if_id.inst  <= inst;
    end
  end

  // Read instruction; mask is zero when stalling
  always_comb begin
    imem_rmask = 4'b1111;  
    if(stall_next || dmem_req) begin
      imem_rmask = 4'b0000;
      inst       = inst_stall;
    end
    else begin
      inst = imem_rdata;
    end
  end

  // Stall register
  always_ff @(posedge clk) begin
    if(rst) begin
      inst_stall <= '0;
    end
    else begin
      inst_stall <= inst;
      stall_next <= dmem_req;
    end
  end

endmodule
