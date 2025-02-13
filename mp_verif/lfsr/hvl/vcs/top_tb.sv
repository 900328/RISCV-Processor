module top_tb;

    //----------------------------------------------------------------------
    // Waveforms.
    //----------------------------------------------------------------------
    initial begin
        $fsdbDumpfile("dump.fsdb");
        $fsdbDumpvars(0, "+all");
    end

    //----------------------------------------------------------------------
    // Generate the clock.
    //----------------------------------------------------------------------
    bit clk;
    always #500ps clk = ~clk;

    //----------------------------------------------------------------------
    // Generate the reset.
    //----------------------------------------------------------------------
    bit rst;
    task do_reset();
        rst = 1'b1;
        repeat (2) @(posedge clk);
        rst <= 1'b0;
    endtask : do_reset

    //----------------------------------------------------------------------
    // DUT instance.
    //----------------------------------------------------------------------
            logic           en;
            logic           rand_bit;
            logic   [15:0]  shift_reg;

    lfsr dut (.*);

    //----------------------------------------------------------------------
    // LFSR modeling and verification API.
    //----------------------------------------------------------------------
    localparam bit [15:0] SEED_VALUE = 'hECEB;

    function bit lfsr_next(ref bit [15:0] state);
        bit new_bit;
        bit ret;

        new_bit = state[0] ^ state[2] ^ state[3] ^ state[5];
        ret = state[0];
        state = 16'(state >> 1);
        state = 16'(state | (new_bit << 15));
        return ret;
    endfunction : lfsr_next

    function check_values(
        bit [15:0]  shift_reg,
        bit [15:0]  shift_reg_shadow,
        bit         rand_bit,
        bit         rand_bit_shadow
    );
        if (shift_reg !== shift_reg_shadow) begin
            $error("Expected shift_reg value of %x, got %x", shift_reg_shadow, shift_reg);
            $error("TB Error: Verification Failed");
            $fatal;
        end
        if (rand_bit !== rand_bit_shadow) begin
            $error("Expected rand_bit value of %x, got %x", rand_bit_shadow, rand_bit);
            $error("TB Error: Verification Failed");
            $fatal;
        end
    endfunction : check_values

    task verify_lfsr();
        bit [15:0] shift_reg_shadow;
        bit                rand_bit_shadow;
        int                delay;

        shift_reg_shadow = SEED_VALUE;

        repeat (2**16 - 1) begin
            en <= 1'b1;
            @(posedge clk);
            en <= 1'b0;
            @(posedge clk);
            rand_bit_shadow = lfsr_next(shift_reg_shadow);
            check_values(shift_reg, shift_reg_shadow, rand_bit, rand_bit_shadow);
            std::randomize(delay) with { delay inside {[0:3]}; };
            repeat (delay) @(posedge clk);
        end

        // Check that LFSR is maximal-length (spec provides primitive polynomial)
        if (shift_reg !== SEED_VALUE) begin
            $error("Shift register not of maximum period.");
            $error("TB Error: Verification Failed");
            $fatal;
        end

    endtask : verify_lfsr

    //----------------------------------------------------------------------
    // Main process.
    //----------------------------------------------------------------------
    initial begin
        do_reset();
        verify_lfsr();
        $finish;
    end

    //----------------------------------------------------------------------
    // Timeout.
    //----------------------------------------------------------------------
    initial begin
        #5ms;
        $error("TB Error: Timed out");
        $fatal;
    end

endmodule
