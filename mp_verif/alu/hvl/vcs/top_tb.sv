module top_tb;

    //----------------------------------------------------------------------
    // Waveforms.
    //----------------------------------------------------------------------
    initial begin
        $fsdbDumpfile("dump.fsdb");
        $fsdbDumpvars(0, "+all");
    end

    //----------------------------------------------------------------------
    // Coverage
    //----------------------------------------------------------------------
    `include "../../hvl/vcs/coverage.svh"
    cg cg_inst = new;

    //----------------------------------------------------------------------
    // Generate the clock.
    //----------------------------------------------------------------------
    bit clk;
    always #500ps clk = ~clk; // Always drive clocks with blocking assignment.

    //----------------------------------------------------------------------
    // DUT instance.
    //----------------------------------------------------------------------
            logic   [2:0]   aluop;
            logic   [31:0]  a, b;
            logic   [31:0]  f;
            logic           valid_i, valid_o;

    alu dut (.*);

    //----------------------------------------------------------------------
    // Verification helper functions/tasks.
    //----------------------------------------------------------------------
    bit PASSED;

    function sample_cg(bit [31:0] a, bit [31:0] b, bit [2:0] op);
        cg_inst.sample(a, b, op, b[4:0]);
    endfunction : sample_cg

    `include "../../hvl/vcs/verify.svh"

    //----------------------------------------------------------------------
    // Main process.
    //----------------------------------------------------------------------
    initial begin
        bit passed;
        @(posedge clk);

        verify_alu(passed);

        if (passed) begin
            $finish;
        end else begin
            $error("TB Error: Verification Failed");
            $fatal;
        end
    end

    //----------------------------------------------------------------------
    // Timeout.
    //----------------------------------------------------------------------
    initial begin
        #1ms;
        $error("TB Error: Timed out");
        $fatal;
    end

    //----------------------------------------------------------------------
    // Final coverage checking.
    //----------------------------------------------------------------------
    `include "../../hvl/vcs/final.svh"

endmodule
