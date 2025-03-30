module snoop_bus 
import types::*;
(
    input logic clk,
    
    // From Arbiter
    input logic [NUM_CPUS-1:0] gnt,

    // From Cores and Main Memory
    input logic [XLEN-1:0] bus_addr[NUM_CPUS],
    input bus_tx_t bus_tx[NUM_CPUS],

    // To Caches
    output bus_msg_t bus_msg
);

    logic [$clog2(NUM_CPUS)-1:0] gnt_idx;
    logic grant_valid;

    always_comb begin
        gnt_idx = '0;
        grant_valid = '0;
        for (int i = 0; i < NUM_CPUS; i++) begin
            if (gnt[i]) begin
                gnt_idx = ($clog2(NUM_CPUS))'(i);
                grant_valid = '1;
            end
        end
    end
    
    always_comb begin
        bus_msg = '{
            valid: grant_valid,
            source: gnt_idx,
            addr: bus_addr[gnt_idx],
            bus_tx: bus_tx[gnt_idx]
        };
    end


    property p_gnt_one_hot;
        @(posedge clk)
        $onehot0(gnt) || (gnt == 0);
    endproperty
    assert_p_gnt_one_hot: assert property (p_gnt_one_hot) else $error("gnt is not one-hot");

endmodule
