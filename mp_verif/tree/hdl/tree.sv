module tree(
    input   logic           clk,
    input   logic   [15:0]  a,
    output  logic           b
);

            logic   [15:0]  a_reg;
            logic   [7:0]   intermediate1;
            logic   [3:0]   intermediate2;
            logic   [1:0]   intermediate3;
            logic   [3:0]   intermediate2_reg;
            logic           intermediate4;

    always_ff @(posedge clk) begin
        a_reg <= a;
    end
    always_comb begin
        intermediate1 = a_reg[15:8] & a_reg[7:0];
        intermediate2 = intermediate1[7:4] ^ intermediate1[3:0];
    end
        always_ff @(posedge clk) begin
         intermediate2_reg <= intermediate2;
    end

    always_comb begin
        intermediate3 = intermediate2_reg[3:2] | intermediate2_reg[1:0];
        intermediate4 = intermediate3[1] ^ intermediate3[0];
    end

    always_ff @(posedge clk) begin
        b <= intermediate4;
    end

endmodule
