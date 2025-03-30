module arbiter 
import types::*;
(
    input logic clk,
    input logic rst,

    input logic [NUM_CPUS-1:0] req,
    output logic [NUM_CPUS-1:0] gnt,

    input logic [NUM_CPUS-1:0] busy
);

    logic [NUM_CPUS-1:0] priority_reg;
    logic [NUM_CPUS-1:0] priority_next;
    logic grant_valid;
    int i, idx;
    logic transient_stall; // Can be utilized to stall the bus arbitration if any of the cache is in transient state

    always_comb begin
        grant_valid = '0;
        priority_next = priority_reg;
        
        gnt = '0;
        transient_stall = |busy;

        for (i = 0; i < NUM_CPUS; i++) begin
            idx = (i + priority_reg) % NUM_CPUS;
            if (!grant_valid && req[idx] && !transient_stall) begin
                gnt[idx] = '1;
                grant_valid = '1;
                priority_next = idx[NUM_CPUS-1:0] + 4'b1; // Update priority to next CPU  
            end
        end
    end

    always_ff @(posedge clk) begin
        if (rst) begin
            priority_reg <= '0;
        end else begin
            priority_reg <= priority_next;
        end
    end



endmodule
