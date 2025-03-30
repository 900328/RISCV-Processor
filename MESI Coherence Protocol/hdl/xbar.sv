module xbar 
import types::*;
(
    input   xbar_msg_t xbar_in  [NUM_CPUS+1],
    output  xbar_msg_t xbar_out [NUM_CPUS+1][NUM_CPUS]
);

    /*
    Assuming NUM_CPUS = 4
    O[0][0] = I[1]
    O[0][1] = I[2]
    O[0][2] = I[3]
    O[0][3] = I[4]

    O[1][0] = I[0]
    O[1][1] = I[2]
    O[1][2] = I[3]
    O[1][3] = I[4]

    ...

    This goes to memory controller
    O[4][0] = I[0]
    O[4][1] = I[1]
    O[4][2] = I[2]
    O[4][3] = I[3]
    */
    
    for (genvar i = 0; i < NUM_CPUS+1; i++) begin : xbar_out_gen
        for (genvar j = 0; j < NUM_CPUS; j++) begin : xbar_in_gen
            always_comb begin
                if (j >= i) begin
                    xbar_out[i][j] = xbar_in[j+1];
                end else begin
                    xbar_out[i][j] = xbar_in[j];
                end
            end
        end
    end

endmodule