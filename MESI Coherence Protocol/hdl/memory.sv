import types::*;
module memory
(
    input   logic           clk,
    input   logic           rst,

    input   xbar_msg_t      xbar_in[NUM_CPUS],
    output  xbar_msg_t      xbar_out,
    input   bus_msg_t       bus_msg
);


    logic [2**XLEN-1:0][CACHELINE_SIZE-1:0] mem;
    xbar_msg_t xbar_out_next;
logic [INDEX_WIDTH-1:0] bus_msg_index;
    // update mem          
    always_comb begin
    xbar_out_next = '0;
    bus_msg_index = bus_msg.addr[$clog2(NUM_SETS)-1:0];
            if (rst) begin
            for (int i = 0; i < 2**XLEN; i++) begin
                mem[i] = CACHELINE_SIZE'(i);
            end
            end else begin
            for (int i = 0; i < NUM_CPUS; i++) begin
                if (xbar_in[i].valid && xbar_in[i].destination == NUM_CPUS[$clog2(NUM_CPUS):0]) begin
                    mem[xbar_in[i].addr] = xbar_in[i].data;
                end
            end
            if (bus_msg.valid) begin
                unique case (bus_msg.bus_tx) 
                    Bus_Rdx: begin
                        xbar_out_next.valid       = 1'b1;
                        xbar_out_next.addr        = bus_msg.addr;
                        xbar_out_next.data        = mem[bus_msg.addr];
                        xbar_out_next.destination = bus_msg.source; 
                    end
                    Bus_Rd: begin
                        xbar_out_next.valid       = 1'b1;
                        xbar_out_next.addr        = bus_msg.addr;
                        xbar_out_next.data        = mem[bus_msg.addr];
                        xbar_out_next.destination = bus_msg.source; 
                    end
                    Bus_Upg: begin
                    end
                    default: begin
                    end
                endcase
            end
            end
    end
    always_ff @(posedge clk) begin
        if (rst) begin
            xbar_out<= '0;
        end else begin
            xbar_out <= xbar_out_next;
        end
    end
// check mem data == xbar_in data when Bus_Flush
property p_flush_data_ok(i);
  @(posedge clk) 
    ( bus_msg.valid && (bus_msg.bus_tx == Bus_Flush) )
    |->  ( xbar_in[i].data == mem[bus_msg_index] );
endproperty
generate
 for (genvar si = 0; si < NUM_SETS; si++) begin: flush_data_ok
assert_flush_data_ok: assert property(p_flush_data_ok(si))
  else $error("Flush data mismatch: mem[bus_msg.addr] != flush data from xbar_in!");
  end
endgenerate
endmodule
