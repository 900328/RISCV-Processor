module top_tb;

    bit clk;
    always #1ns clk = ~clk;

    bit rst;

    int timeout = 10000000; // in cycles, change according to your needs

    mem_itf_w_mask #(.CHANNELS(2)) mem_itf(.*);
    n_port_pipeline_memory_32_w_mask #(.CHANNELS(2), .MAGIC(1)) mem(.itf(mem_itf));

    mon_itf mon_itf(.*);
    monitor monitor(.itf(mon_itf));

    cpu dut(
        .clk            (clk),
        .rst            (rst),
        .imem_addr      (mem_itf.addr [0]),
        .imem_rmask     (mem_itf.rmask[0]),
        .imem_rdata     (mem_itf.rdata[0]),
        .imem_resp      (mem_itf.resp [0]),

        .dmem_addr      (mem_itf.addr [1]),
        .dmem_rmask     (mem_itf.rmask[1]),
        .dmem_wmask     (mem_itf.wmask[1]),
        .dmem_rdata     (mem_itf.rdata[1]),
        .dmem_wdata     (mem_itf.wdata[1]),
        .dmem_resp      (mem_itf.resp [1])
    );

    assign mem_itf.wmask[0] = '0;
    assign mem_itf.wdata[0] = 'x;

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

endmodule
