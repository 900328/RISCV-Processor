    import "DPI-C" function void bt9_shim_init(string name);
    import "DPI-C" function int unsigned bt9_shim_get_type();
    import "DPI-C" function int unsigned bt9_shim_get_pc();
    import "DPI-C" function int unsigned bt9_shim_get_taken();
    import "DPI-C" function int unsigned bt9_shim_get_target();
    import "DPI-C" function int unsigned bt9_shim_advance();

    longint timeout;
    initial begin
        $value$plusargs("TIMEOUT_ECE411=%d", timeout);
    end

    logic   [31:0]  lookup_pc;
    logic           lookup_valid;
    logic           lookup_prediction;
    logic   [31:0]  lookup_target;
    logic           lookup_ready;

    logic   [31:0]  update_pc;
    logic           update_prediction;
    logic           update_actual;
    logic   [31:0]  update_target;
    logic           update_valid;

    bp dut(.*);

    typedef struct packed {
        bit     [31:0]  pc;
        bit             actual;
        bit     [31:0]  target;
        bit             valid;
    } bp_update_entry_t ;

    typedef struct packed {
        logic           prediction;
    } bp_lookup_entry_t ;

    longint total_branches;
    longint total_taken;
    longint correct_prediction;
    longint correct_target;

    bp_update_entry_t  invalid_entry;
    bp_update_entry_t  current;
    bp_update_entry_t  next;

    parameter delay = 5;

    bp_update_entry_t  update_queue [delay];
    bp_lookup_entry_t  lookup_queue [delay];

    bit         halt = 1'b0;

    function bp_update_entry_t  bt9_get();
        automatic bp_update_entry_t  retval;
        retval.pc     = bt9_shim_get_pc();
        retval.actual = 1'(bt9_shim_get_taken());
        retval.target = bt9_shim_get_target();
        retval.valid  = 1'b1;
        bt9_get       = retval;
    endfunction






    initial begin
        automatic string trace_file;
        $value$plusargs("CBP_TRACE_ECE411=%s", trace_file);
        bt9_shim_init(trace_file);

        invalid_entry.valid = 1'b0;
        current             = bt9_get();
        lookup_pc           = current.pc;
        lookup_valid        = 1'b1;
        update_valid        = 1'b0;
    end

    always @(posedge clk) begin
        if (!rst) begin
            for (int i = 0; i < delay-1; i++) begin
                update_queue[i] <= update_queue[i+1];
                lookup_queue[i] <= lookup_queue[i+1];
            end


            if (lookup_ready) begin
                if (!halt) begin
                    total_branches = total_branches + 64'd1;
                    
                    if (lookup_prediction == current.actual) begin
                        correct_prediction = correct_prediction + 64'd1;

                        if (current.actual == 1'b1) begin
                            total_taken = total_taken + 64'b1;
                            if (lookup_target == current.target) begin
                                correct_target = correct_target + 64'd1;
                            end
                        end

                    end
                end
                if (bt9_shim_advance() != 0) begin
                    halt <= 1'b1;
                end
                update_queue[delay-1]            <= current;
                lookup_queue[delay-1].prediction <= lookup_prediction;
                next              = bt9_get();
                current          <= next;
                lookup_pc       <= next.pc;
                lookup_valid    <= next.valid & (~halt);
            end else begin
                update_queue[delay-1]  <= invalid_entry;
                lookup_queue[delay-1]  <= 'x;
            end


            
            update_pc         <= update_queue[0].pc;
            update_prediction <= lookup_queue[0].prediction;
            update_actual     <= update_queue[0].actual;
            update_target     <= update_queue[0].target;
            update_valid      <= update_queue[0].valid;
        end
    end

    always @(posedge clk) begin
        if (halt) begin
            $finish;
        end
        if (timeout == 0) begin
            $error("TB Error: Timed out");
            $fatal;
        end
        timeout <= timeout - 1;
    end

    always @(posedge clk) begin
        if (total_branches != 0 && total_branches % 10000 == 0) begin
            $display("dut commit No.%d, accuracy %f, btb %f", total_branches, real'(correct_prediction) / total_branches, real'(correct_target) / total_taken);
        end
    end

    final begin
        $display("Monitor: Total branch: %d", total_branches);
        $display("Monitor: Prediction accuracy:   %f", real'(correct_prediction) / total_branches);
        $display("Monitor: Branch target accuracy: %f", real'(correct_target) / total_taken);
    end
