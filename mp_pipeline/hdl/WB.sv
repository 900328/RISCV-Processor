/*****************************************************
 * WB Stage:
 * - Selects the final register write-back value
 *   from ALU results or memory load data
 * - Asserts register-file write-enable if needed
 *****************************************************/
module wb_stage
  import rv32i_types::*;
(
    input  logic     clk,
    input  logic     rst,
    input  mem_wb_t  mem_wb,
    input  logic[31:0] dmem_rdata,
    input  logic       dmem_resp,
    output logic       regf_we_back,
    output logic[31:0] regfilerdv,
    output logic[4:0]  rds_back,
    output logic       dmem_req
);

  logic [31:0] rd_v;
  logic        commit;
  logic [63:0] order;
  logic [31:0] rvfi_dmem_rdata;

  // Capture memory load data if available
  always_comb begin
    if(dmem_resp && mem_wb.opcode == op_b_load)
      rvfi_dmem_rdata = dmem_rdata;
    else
      rvfi_dmem_rdata = '0;
  end

  // If memory response not valid but we have load/store, hold pipeline
  always_comb begin
    commit   = mem_wb.commit;
    dmem_req = 1'b0;
    if(((~dmem_resp) && mem_wb.opcode == op_b_load) ||
       ((~dmem_resp) && mem_wb.opcode == op_b_store))
    begin
      dmem_req = 1'b1;
      commit   = 1'b0; // do not commit if memory is not ready
    end
  end

  // Example of incrementing an internal retired-instruction counter
  always_ff @(posedge clk) begin
    if(rst)
      order <= '0;
    else if(commit)
      order <= order + 1'b1;
    else
      order <= order;
  end

  // Final Mux for register write-back
  always_comb begin
    case(mem_wb.regfilemux_sel)
      4'b0001: rd_v = {31'b0, mem_wb.br_en};  // e.g. set less than
      4'b0010: rd_v = mem_wb.u_imm;           // LUI
      4'b0000: rd_v = mem_wb.aluout;          // ALU result
      4'b0100: rd_v = mem_wb.pc + 32'd4;      // JAL / JALR link
      4'b0101: // LB
        rd_v = {{24{dmem_rdata[7 + 8*mem_wb.dmem_addr[1:0]]}},
                dmem_rdata[8*mem_wb.dmem_addr[1:0] +: 8]};
      4'b0110: // LBU
        rd_v = {{24{1'b0}},
                dmem_rdata[8*mem_wb.dmem_addr[1:0] +: 8]};
      4'b0111: // LH
        rd_v = {{16{dmem_rdata[15 + 16*mem_wb.dmem_addr[1]]}},
                dmem_rdata[16*mem_wb.dmem_addr[1] +: 16]};
      4'b1000: // LHU
        rd_v = {{16{1'b0}},
                dmem_rdata[16*mem_wb.dmem_addr[1] +: 16]};
      4'b0011: // LW
        rd_v = dmem_rdata;
      default:
        rd_v = 32'd0;
    endcase
  end

  // Final signals for register file
  assign rds_back     = mem_wb.rd_s;
  assign regf_we_back = mem_wb.regf_we;
  assign regfilerdv   = rd_v;

endmodule
