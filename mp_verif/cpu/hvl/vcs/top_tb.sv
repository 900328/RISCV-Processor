module top_tb;

    bit clk;
    initial clk = 1'b1;
    always #2ns clk = ~clk;

    bit rst;

    int timeout = 10000000; // In cycles, change according to your needs

    mem_itf_w_mask mem_itf(.*);
    mon_itf mon_itf(.*);

    // Pick one of the two options (only one of these should be uncommented at a time):
    simple_memory_32_w_mask simple_memory(.itf(mem_itf)); 
    //random_tb random_tb(.itf(mem_itf));// For directed testing with PROG
    //random_tb random_tb(.itf(mem_itf)); // For randomized testing

    monitor monitor(.itf(mon_itf));

    cpu dut(
        .clk          (clk),
        .rst          (rst),
        .mem_addr     (mem_itf.addr [0]),
        .mem_rmask    (mem_itf.rmask[0]),
        .mem_wmask    (mem_itf.wmask[0]),
        .mem_rdata    (mem_itf.rdata[0]),
        .mem_wdata    (mem_itf.wdata[0]),
        .mem_resp     (mem_itf.resp [0])
    );

    `include "../../hvl/common/rvfi_reference.svh"

    initial begin
        $fsdbDumpfile("dump.fsdb");
        $fsdbDumpvars(0, "+all");
        rst = 1'b1;
        repeat (2) @(posedge clk);
        rst <= 1'b0;
    end

    always @(posedge clk) begin
        if (mon_itf.halt[0]) begin
            $finish;
        end
        if (timeout == 0) begin
            $error("TB Error: Timed out");
            $fatal;
        end
        if (mem_itf.error != 0 || mon_itf.error != 0) begin
            repeat (2) @(posedge clk);
            $fatal;
        end
        timeout <= timeout - 1;
    end

endmodule : top_tb
