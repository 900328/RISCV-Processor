module alu
(
    input   logic           clk,
    input   logic   [2:0]   aluop,
    input   logic   [31:0]  a, b,
    input   logic           valid_i,
    output  logic   [31:0]  f,
    output  logic           valid_o
);

            logic   [2:0]   aluop_reg;
            logic   [31:0]  a_reg, b_reg;
            logic           valid_int;

            logic   [31:0]  f_and;
            logic   [31:0]  f_or;
            logic   [31:0]  f_not;
            logic   [31:0]  f_add;
            logic   [31:0]  f_sub;
            logic   [31:0]  f_shl;
            logic   [31:0]  f_shr;

            logic   [31:0]  f_next;

    always_ff @(posedge clk) begin
        aluop_reg <= aluop;
        a_reg <= a;
        b_reg <= b;
        valid_int <= valid_i;
    end

    always_comb begin
        f_and = a_reg & b_reg;
        f_or  = a_reg | b_reg;
        f_not = ~a_reg;
        f_add = a_reg + b_reg;
        f_sub = a_reg - b_reg;
        f_shl = a_reg << b_reg[4:0];
        f_shr = a_reg >> b_reg[4:0];
    end

    always_comb begin
        unique case (aluop_reg)
            3'd0 : f_next = f_and;
            3'd1 : f_next = f_or;
            3'd2 : f_next = f_not;
            3'd3 : f_next = f_add;
            3'd4 : f_next = f_sub;
            3'd5 : f_next = f_shl;
            3'd6 : f_next = f_shr;
            default: f_next=32'bx;
        endcase
    end

    always_ff @(posedge clk) begin
        f <= f_next;
        valid_o <= valid_int;
    end

endmodule : alu
