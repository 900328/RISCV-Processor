module forward 
import rv32i_types ::*;
import forward_rs1_mux::*;
import forward_rs2_mux::*;
(
    input id_ex_t id_ex,
    input ex_mem_t ex_mem,
    input mem_wb_t mem_wb,
    output forward_rs1_sel_t forward_rs1_sel,
    output forward_rs2_sel_t forward_rs2_sel 
);

always_comb begin
    // Forwarding logic for rs1
    if (id_ex.rs1_s == ex_mem.rd_s && id_ex.rs1_s != 5'b0 && ex_mem.regf_we) begin
        case (ex_mem.opcode)
            op_b_lui: forward_rs1_sel = forward_rs1_mux::u_imm;
            op_b_reg, op_b_imm:
                if (ex_mem.funct3 == arith_f3_slt || ex_mem.funct3 == arith_f3_sltu)
                    forward_rs1_sel = forward_rs1_mux::br_en;
                else
                    forward_rs1_sel = forward_rs1_mux::alu_out;
            default: forward_rs1_sel = forward_rs1_mux::alu_out;
        endcase
    end
    else if (id_ex.rs1_s == mem_wb.rd_s && id_ex.rs1_s != 5'b0 && mem_wb.regf_we) 
        forward_rs1_sel = forward_rs1_mux::regfile_out;
    else   
           forward_rs1_sel = forward_rs1_mux::rs1_v;




    // Forwarding logic for rs2
    if (id_ex.rs2_s == ex_mem.rd_s && id_ex.rs2_s != 5'b0 && ex_mem.regf_we) begin
        case (ex_mem.opcode)
            op_b_lui: forward_rs2_sel = forward_rs2_mux::u_imm;
            op_b_reg, op_b_imm:
                if (ex_mem.funct3 == arith_f3_slt || ex_mem.funct3 == arith_f3_sltu)
                    forward_rs2_sel = forward_rs2_mux::br_en;
                else
                    forward_rs2_sel = forward_rs2_mux::alu_out;
            default: forward_rs2_sel = forward_rs2_mux::alu_out;
        endcase
    end
    else if (id_ex.rs2_s == mem_wb.rd_s && id_ex.rs2_s != 5'b0 && mem_wb.regf_we) 
        forward_rs2_sel = forward_rs2_mux::regfile_out;  
    else 
        forward_rs2_sel = forward_rs2_mux::rs2_v;
end

endmodule
