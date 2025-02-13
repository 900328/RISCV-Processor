module lfsr #(
    parameter bit   [15:0]  SEED_VALUE = 'hECEB
) (
    input   logic           clk,
    input   logic           rst,
    input   logic           en,
    output  logic           rand_bit,
    output  logic   [15:0]  shift_reg
);

// Recall: always_ff @(posedge clk) implements positive-edge clocked D flip flops
always_ff @(posedge clk) begin
    if(rst) begin
        shift_reg <= 16'heceb;
        rand_bit <= 1'bx;
    end
    else if(en) begin
    shift_reg <= {shift_reg[0]^shift_reg[2]^shift_reg[3]^shift_reg[5] ,shift_reg[15:1]};  
    rand_bit <= shift_reg[0];
    end
    else begin
    shift_reg <= shift_reg;
    rand_bit <= 1'bx;
    end
end

    // TODO: Fill this out!

endmodule : lfsr
