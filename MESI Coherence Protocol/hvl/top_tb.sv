module top_tb ();
    timeunit 1ps;
    timeprecision 1ps;

    int clock_half_period_ps;
    initial begin
        $value$plusargs("CLOCK_PERIOD_PS_ECE511=%d", clock_half_period_ps);
        clock_half_period_ps = clock_half_period_ps / 2;
    end

    bit clk;
    always #(clock_half_period_ps) clk = ~clk;

    bit rst;
    longint timeout;

    initial begin
        $fsdbDumpfile("dump.fsdb");
        $value$plusargs("TIMEOUT_ECE511=%d", timeout);
        if ($test$plusargs("NO_DUMP_ALL_ECE511")) begin
            $fsdbDumpvars(0, dut, "+all");
            $fsdbDumpoff();
        end else begin
            $fsdbDumpvars(0, "+all");
        end
        rst = 1'b1;
        repeat (2) @(posedge clk);
        rst <= 1'b0;
    end
    


    cpu dut(.*);
    

    always @(posedge clk) begin
        if (timeout == 0) begin
            $display("Monitor: Timed out");
            $finish;
        end
        timeout <= timeout - 1;
    end

    final begin
        $display("Monitor: Simulation finished");
    end

endmodule : top_tb
