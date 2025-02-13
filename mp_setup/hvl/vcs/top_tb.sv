module top_tb;

    bit             clk;
    logic   [2:0]   aluop;
    logic   [31:0]  a;
    logic   [31:0]  b;
    logic   [31:0]  f;

    always #500ps clk = ~clk;

    alu dut(.*);

    initial begin
        $fsdbDumpfile("dump.fsdb");
        $fsdbDumpvars(0, "+all");

        @(posedge clk);
        a <= 32'h800055AA;
        b <= 32'h00000004;

        for (int i = 0; i < 8; i++) begin
            aluop <= 3'(i);
            @(posedge clk);
        end

        a <= 'x;
        b <= 'x;
        aluop <= 'x;

        repeat (2) @(posedge clk);
        $finish;
    end

endmodule
