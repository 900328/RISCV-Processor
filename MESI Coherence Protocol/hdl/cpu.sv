import types::*;
module cpu
(
    input   logic           clk,
    input   logic           rst
);


    // Core to Cache
    logic                                   cpu_ready[NUM_CPUS];
    logic                                   cpu_resp[NUM_CPUS];
    logic                                   cpu_req[NUM_CPUS];
    logic                                   cpu_we[NUM_CPUS];
    logic       [XLEN-1:0]                  cpu_addr[NUM_CPUS];
    logic       [CACHELINE_SIZE-1:0]        cpu_wdata[NUM_CPUS];
    logic       [CACHELINE_SIZE-1:0]        cpu_rdata[NUM_CPUS];

    // Arbiter
    logic       [NUM_CPUS-1:0]              arbiter_gnt;
    logic       [NUM_CPUS-1:0]              arbiter_req;   
    logic       [NUM_CPUS-1:0]              arbiter_busy;

    // Snoop Bus
    logic       [XLEN-1:0]                  bus_addr[NUM_CPUS];
    bus_tx_t                                bus_tx[NUM_CPUS];
    bus_msg_t                               bus_msg;

    // Xbar
    xbar_msg_t                              xbar_in[NUM_CPUS+1];
    xbar_msg_t                              xbar_out[NUM_CPUS+1][NUM_CPUS];

    xbar_msg_t                              xbar_in1[NUM_CPUS];
    xbar_msg_t                              xbar_out1[NUM_CPUS][NUM_CPUS-1];
    
    cacheline_t                             cacheline[NUM_CPUS][NUM_SETS];

    for (genvar i = 0; i < NUM_CPUS; i++) begin : core_inst
        core #(
            .ID(i)
        ) core_inst(
            .clk(clk),
            .rst(rst),

            .cpu_ready(cpu_ready[i]),
            .cpu_resp(cpu_resp[i]),
            .cpu_req(cpu_req[i]),
            .cpu_we(cpu_we[i]),
            .cpu_addr(cpu_addr[i]),
            .cpu_wdata(cpu_wdata[i]),
            .cpu_rdata(cpu_rdata[i])
        );

        cache #(
            .ID(i)
        ) cache_inst (
            .clk(clk),
            .rst(rst),

            .cpu_ready(cpu_ready[i]),
            .cpu_resp(cpu_resp[i]),
            .cpu_req(cpu_req[i]),
            .cpu_we(cpu_we[i]),
            .cpu_addr(cpu_addr[i]),
            .cpu_wdata(cpu_wdata[i]),
            .cpu_rdata(cpu_rdata[i]),

            .bus_addr(bus_addr[i]),
            .bus_tx(bus_tx[i]),
            .bus_msg(bus_msg),

            .arbiter_req(arbiter_req[i]),
            .arbiter_gnt(arbiter_gnt[i]),
            .arbiter_busy(arbiter_busy[i]),

            .xbar_in(xbar_out[i]),
            .xbar_out(xbar_in[i]),
            .other_bus_tx(bus_tx),
            .cacheline(cacheline[i]),
            .xbar_in1(xbar_out1[i]),
            .xbar_out1(xbar_in1[i])
        );
    end


    arbiter arbiter_inst(
        .clk(clk),
        .rst(rst),

        .req(arbiter_req),
        .gnt(arbiter_gnt),
        .busy(arbiter_busy)
    );

    snoop_bus snoop_bus_inst(
        .clk(clk),        
        .gnt(arbiter_gnt),
        .bus_addr(bus_addr),
        .bus_tx(bus_tx),
        .bus_msg(bus_msg)
    );
    

    xbar xbar_inst(
        .xbar_in(xbar_in),
        .xbar_out(xbar_out)
    );
    xbar_core xbar_inst1( 
        .xbar_in1(xbar_in1),
        .xbar_out1(xbar_out1)
    );

    memory memory_inst(
        .clk(clk),
        .rst(rst),

        .xbar_in(xbar_out[NUM_CPUS]),
        .xbar_out(xbar_in[NUM_CPUS]),

        .bus_msg(bus_msg)
    );

// check two CPU holds M/E
generate
  for (genvar c1 = 0; c1 < NUM_CPUS; c1++) begin : oneowner_c1
    for (genvar c2 = c1+1; c2 < NUM_CPUS; c2++) begin : oneowner_c2
      for (genvar s = 0; s < NUM_SETS; s++) begin : oneowner_set
        assert_two_holds_ME: assert property(@(posedge clk) 
          !((!rst)&&(cacheline[c1][s].state inside {M, E}) &&
            (cacheline[c2][s].state inside {M, E}) &&
            (cacheline[c1][s].tag == cacheline[c2][s].tag))
        ) else $error(
          "One-Owner Violation: Both CPU %0d and CPU %0d hold M/E in set %0d!", c1, c2, s
        );
      end
    end
  end
endgenerate
// check two S shares same data
generate
  for (genvar A = 0; A < NUM_CPUS; A++) begin: owner1
    for (genvar B = A+1; B < NUM_CPUS; B++) begin: owner2
      for (genvar s = 0; s < NUM_SETS; s++) begin: owner_set
        assert_sharedata: assert property (@(posedge clk) 
          (cacheline[A][s].state == S) &&
          (cacheline[B][s].state == S) &&
          (cacheline[A][s].tag == cacheline[B][s].tag) 
          |-> (cacheline[A][s].data == cacheline[B][s].data)
        ) else $error("Shared data mismatch: CPU%0d and CPU%0d, set %0d!", A, B, s);
      end
    end
  end
endgenerate

endmodule


