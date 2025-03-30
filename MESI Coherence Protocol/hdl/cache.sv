import types::*;
module cache
#(
    parameter ID
)
(
    input   logic           clk,
    input   logic           rst,

    // From CPU
    input   logic                                   cpu_req,
    input   logic                                   cpu_we,
    input   logic       [XLEN-1:0]                  cpu_addr,
    input   logic       [CACHELINE_SIZE-1:0]        cpu_wdata,

    // To CPU
    output  logic                                   cpu_ready,
    output  logic                                   cpu_resp,
    output  logic       [CACHELINE_SIZE-1:0]        cpu_rdata,
    output  cacheline_t                             cacheline[NUM_SETS],

    // From Snoop Bus
    input   bus_msg_t                               bus_msg,

    // To Snoop Bus
    output  logic       [XLEN-1:0]                  bus_addr,
    output  bus_tx_t                                bus_tx,

    // To Arbiter
    output  logic                                   arbiter_req,
    output  logic                                   arbiter_busy,
    // From Arbiter
    input   logic                                   arbiter_gnt,

    // To Xbar
    output  xbar_msg_t                              xbar_out,
    output  xbar_msg_t                              xbar_out1, 

    // From Xbar
    input   xbar_msg_t                              xbar_in[NUM_CPUS],
    input   xbar_msg_t                              xbar_in1[NUM_CPUS-1],
    // for detect Flush
    input   bus_tx_t                                other_bus_tx[NUM_CPUS]              
);

    //cacheline_t cacheline[NUM_SETS];
    cacheline_t cacheline_next[NUM_SETS];

    logic [INDEX_WIDTH-1:0] bus_msg_index;
    logic [TAG_WIDTH-1:0] bus_msg_tag;
    logic xbar_msg_valid;
    logic [$clog2(NUM_CPUS)-1:0] xbar_idx;
    logic [$clog2(NUM_CPUS)-1:0] xbar_idx1;

    logic [INDEX_WIDTH-1:0] cpu_index;
    logic [NUM_SETS-1:0] goIS;
    logic [NUM_SETS-1:0] goIM;
    logic [NUM_SETS-1:0] goSM;
    logic [NUM_SETS-1:0] goIE;
    logic all_invalid;
    // Xbar input logic
    always_comb begin
        xbar_msg_valid  = '0;
        xbar_idx        = '0;
        xbar_idx1        = '0;
        for (int i = 0; i < NUM_CPUS; i++) begin
            if (xbar_in[i].valid && xbar_in[i].destination == ID[$clog2(NUM_CPUS):0]) begin 
                xbar_msg_valid  = '1;
                xbar_idx        = ($clog2(NUM_CPUS))'(i);
            end
        end
        for (int i = 0; i < NUM_CPUS; i++) begin
            if (xbar_in1[i].valid && xbar_in1[i].destination == ID[$clog2(NUM_CPUS):0]) begin 
                xbar_msg_valid  = '1;
                xbar_idx1        = ($clog2(NUM_CPUS))'(i);
            end
        end
    end 
logic       other_all_I;
    // bus output logic
    always_comb begin
        bus_check='0;
        cpu_index = cpu_addr[$clog2(NUM_SETS)-1:0];
        arbiter_req     = '0;
        bus_addr        = '0;
        bus_tx          = Bus_Idle;
        goIS = '0;
        goIM = '0;
        goSM = '0;
        goIE = '0;
        other_all_I = '1;
        if(cpu_req && !cpu_we && cacheline[cpu_index].state==I)begin
            arbiter_req = 1'b1;
            for(int i=0;i<NUM_CPUS;i++)begin
                 if(bus_msg.source != i[$clog2(NUM_CPUS):0])begin
                         if(other_bus_tx[i] == Bus_Flush)begin
                              other_all_I = 1'b0;
                         end
                 end
            end
            if(arbiter_gnt)begin
                     if(other_all_I)begin
			    bus_tx      = Bus_Rd;
			    bus_addr    = cpu_addr;
			    goIE[cpu_index] = 1'b1;
                     end else begin
                            bus_tx      = Bus_Rd;
			    bus_addr    = cpu_addr;
			    goIS[cpu_index] = 1'b1;
                     end
            end
        end
        else if (cpu_req && cpu_we)begin
            unique case (cacheline[cpu_index].state)
            S: begin
            arbiter_req = 1'b1;
            if(arbiter_gnt)begin
		    bus_tx      = Bus_Upg;
		    bus_addr    = cpu_addr;
		    goSM[cpu_index] = 1'b1;
            end
            end
            I: begin
                arbiter_req = 1'b1;
                if(arbiter_gnt)begin
                bus_tx      = Bus_Rdx;
                bus_addr    = cpu_addr;
                goIM[cpu_index] = 1'b1;
            end
            end
            SM: begin
                arbiter_req = 1'b0;
                //bus_tx      = Bus_Upg;
                //bus_addr    = cpu_addr;
            end
            IM: begin
                arbiter_req = 1'b0;    
                //bus_tx      = Bus_Rdx;
                //bus_addr    = cpu_addr;
            end
            IS: begin
                arbiter_req = 1'b0;
                //bus_tx      = Bus_Rd;
                //bus_addr    = cpu_addr;
            end
            IE: begin
                arbiter_req = 1'b0;
                //bus_tx      = Bus_Rd;
                //bus_addr    = cpu_addr;
            end
            default: begin
            end
            endcase
        end
        //remote update to flush
        if (bus_msg.valid && (bus_msg.source != ID[$clog2(NUM_CPUS):0])) begin
        unique case (bus_msg.bus_tx)
            Bus_Rd: begin
                    if (cacheline[bus_msg_index].state == M || cacheline[bus_msg_index].state == E || cacheline[bus_msg_index].state == S) begin
                        bus_tx = Bus_Flush;
                    end
            end
            Bus_Rdx: begin
                    if (cacheline[bus_msg_index].state == M || cacheline[bus_msg_index].state == E ||cacheline[bus_msg_index].state == S) begin
                        bus_tx = Bus_Flush;
                    end
            end
            default: begin
            end
        endcase
    end
    end

    // bus input logic
    always_comb begin
    cacheline_next = cacheline;
    cpu_resp       = '0;
    cpu_rdata      = '0;
    arbiter_busy   = '0;
//transient state update
        for (int i = 0; i < NUM_SETS; i++) begin
            if (goIS[i]) begin
                if (cacheline[i].state == I) begin
                    cacheline_next[i].state = IS;
                end
            end
             if (goIE[i]) begin
                if (cacheline[i].state == I) begin
                    cacheline_next[i].state = IE;
                end
            end
            if (goIM[i]) begin
                if (cacheline[i].state == I) begin
                    cacheline_next[i].state = IM;
                end
            end
            if (goSM[i]) begin
                if (cacheline[i].state == S) begin
                    cacheline_next[i].state = SM;
                end
            end
        end
        for (int i = 0; i < NUM_SETS; i++) begin
            if ( (cacheline[i].state == IM)||(cacheline[i].state == SM)||(cacheline[i].state == IS)||(cacheline[i].state == IE)) begin
                arbiter_busy = 1'b1;
            end
        end
    bus_msg_index = bus_msg.addr[$clog2(NUM_SETS)-1:0];
    bus_msg_tag   = bus_msg.addr[XLEN-1:INDEX_WIDTH];

// local read value
    if (cpu_req && !cpu_we) begin
        unique case (cacheline[cpu_index].state)
            S: begin
                cpu_resp = '1;  
                cpu_rdata = cacheline[cpu_index].data;
                cacheline_next[cpu_index].state = S;
            end
            E: begin
                cpu_resp = '1;  
                cpu_rdata = cacheline[cpu_index].data;
                cacheline_next[cpu_index].state = E;
            end
            M: begin
                cpu_resp = '1;  
                cpu_rdata = cacheline[cpu_index].data;
                cacheline_next[cpu_index].state = M;
            end
            default: begin
            end
        endcase
    end
//local write
    else if (cpu_req && cpu_we) begin
        unique case (cacheline[cpu_index].state)
            M: begin
                cacheline_next[cpu_index].state = M;
                cpu_resp = '1;
                cacheline_next[cpu_index].data= cpu_wdata;
            end
            E: begin
                cacheline_next[cpu_index].state = M;
                cpu_resp = '1;
                cacheline_next[cpu_index].data= cpu_wdata;
            end
            default: begin
            end
        endcase
    end


    
all_invalid = 1'b1;
//transient update
        unique case (cacheline[cpu_index].state)
            IM: begin
                cacheline_next[cpu_index].state = M;
                cpu_resp = '1;
                cacheline_next[cpu_index].data  = cpu_wdata; 
            end
            IS: begin
                cacheline_next[cpu_index].state = S; 
                cpu_resp = '1;
                cpu_rdata = xbar_in1[xbar_idx1].data; 
                cacheline_next[cpu_index].data  = xbar_in1[xbar_idx1].data; 
            end
            IE: begin
                cacheline_next[cpu_index].state = E; 
                cpu_resp = '1;
                cpu_rdata = xbar_in[xbar_idx].data; 
                cacheline_next[cpu_index].data  = xbar_in[xbar_idx].data; 
            end
            SM: begin
                cacheline_next[cpu_index].state = M;
                cacheline_next[cpu_index].data  = cpu_wdata; 
                cpu_resp = '1;
            end
            default: begin
            end
        endcase
        if (bus_msg.valid && (bus_msg.source != ID[$clog2(NUM_CPUS):0])) begin
        unique case (bus_msg.bus_tx)
            Bus_Rd: begin
                    if (cacheline[bus_msg_index].state == M) begin
                        cacheline_next[bus_msg_index].state = S;
                    end
                    else if (cacheline[bus_msg_index].state == E) begin
                        cacheline_next[bus_msg_index].state = S;
                    end
            end
            Bus_Rdx: begin
                    if (cacheline[bus_msg_index].state == M || cacheline[bus_msg_index].state == E || cacheline[bus_msg_index].state == S) begin
                        cacheline_next[bus_msg_index].state = I;
                    end
            end
            Bus_Upg: begin
                    if (cacheline[bus_msg_index].state == S) begin
                        cacheline_next[bus_msg_index].state = I;
                    end
            end
            default: begin
            end
        endcase
    end
end
    // Xbar output logic
    always_ff @(posedge clk) begin
        if (rst) begin
            xbar_out <= '{
                valid: 0,
                destination: 0,
                addr: 0,
                data: 0
            };
        end else begin
            
            if (arbiter_gnt && (bus_tx != Bus_Idle)) begin
                case (bus_tx)
                    Bus_Rdx: begin
                        xbar_out.data <= '0;
                        xbar_out.valid       <= '0;
                        xbar_out.destination <= NUM_CPUS[$clog2(NUM_CPUS):0];  
                        xbar_out.addr        <= bus_addr;
                    end
                    Bus_Upg: begin
                        xbar_out.data <= '0;
                        xbar_out.valid       <= '0;
                        xbar_out.destination <= NUM_CPUS[$clog2(NUM_CPUS):0]; 
                        xbar_out.addr        <= bus_addr;

                    end
                    Bus_Rd: begin
                        xbar_out.data <= '0;
                        xbar_out.valid       <= '0;
                        xbar_out.destination <= NUM_CPUS[$clog2(NUM_CPUS):0]; 
                        xbar_out.addr        <= bus_addr;
                    end

                    default: begin
                        xbar_out.data <= '0;
                        xbar_out.valid       <= '0;
                        xbar_out.destination <= '0; 
                        xbar_out.addr        <= '0;
                    end
                endcase
            end
            else if (!arbiter_gnt && bus_msg.valid &&  (bus_msg.source != ID[$clog2(NUM_CPUS):0])) begin
                    case(bus_msg.bus_tx)
		    Bus_Rd:begin
		    if (cacheline[bus_msg_index].state == M ||cacheline[bus_msg_index].state == S||cacheline[bus_msg_index].state == E) begin  //need to pass to both MEM and source
		        xbar_out.valid       <= '1;
		        xbar_out.destination <= NUM_CPUS[$clog2(NUM_CPUS):0]; 
		        xbar_out.addr        <= bus_msg.addr;
		        xbar_out.data        <= cacheline[bus_msg_index].data;

                        xbar_out1.valid       <= '1;
		        xbar_out1.destination <= bus_msg.source; 
		        xbar_out1.addr        <= bus_msg.addr;
		        xbar_out1.data        <= cacheline[bus_msg_index].data;
		    end
		    end
		    Bus_Rdx:begin
		    if (cacheline[bus_msg_index].state ==M  ) begin 
		        xbar_out.valid       <= '1;
		        xbar_out.destination <= NUM_CPUS[$clog2(NUM_CPUS):0]; 
		        xbar_out.addr        <= bus_msg.addr;
		        xbar_out.data        <= cacheline[bus_msg_index].data;
		    end
                    else if  (cacheline[bus_msg_index].state ==E || cacheline[bus_msg_index].state ==S ) begin
		        xbar_out.valid       <= '1;
		        xbar_out.destination <= NUM_CPUS[$clog2(NUM_CPUS):0];   //bus_msg.source
		        xbar_out.addr        <= bus_msg.addr;
		        xbar_out.data        <= cacheline[bus_msg_index].data;
		    end
		    end
		    default:begin
		    end
		    endcase
            end
            else begin
            xbar_out.data <= '0;
            xbar_out.valid       <= '0;
            xbar_out.destination <= '0;  
            xbar_out.addr        <= '0;
            xbar_out1.data <= '0;
            xbar_out1.valid       <= '0;
            xbar_out1.destination <= '0;  
            xbar_out1.addr        <= '0;
            end
           
          
        end
    end



    // Cache logic
    always_ff @(posedge clk) begin
        if (rst) begin
            for (int i = 0; i < NUM_SETS; i++) begin
                cacheline[i] <= '{
                    state: I,
                    data: 0,
                    tag: 0
                };
            end
            cpu_ready <= '1;
        end else begin
            for (int i = 0; i < NUM_SETS; i++) begin
                cacheline[i] <= cacheline_next[i];
            end

            if (cpu_req) begin
                cpu_ready <= '0;
            end
            if (cpu_resp) begin
                cpu_ready <= '1;
            end
        end
    end
// verfication
// I to IM/IS/IE && S to SM
property I_to_ISIE(i);
  @(posedge clk) 
    (((cacheline[i].state == I))&& (cpu_req && !cpu_we)&& (cpu_index == i[INDEX_WIDTH-1:0])&& arbiter_gnt )  // need to wait for arbiter_gnt
      |-> ##1 (cacheline[i].state ==IE || cacheline[i].state ==IS );
endproperty
generate
  for (genvar si = 0; si < NUM_SETS; si++) begin: I_toISIE1
    assert_I_to_ISIE: assert property (I_to_ISIE(si))
      else $error("Set %0d: read I doen't go to IS/IE", si);
  end
endgenerate
property I_to_IM(i);
  @(posedge clk) 
    (((cacheline[i].state == I))&& (cpu_req && cpu_we)&& (cpu_index == i[INDEX_WIDTH-1:0])&& arbiter_gnt )  // need to wait for arbiter_gnt
      |-> ##1 (cacheline[i].state ==IM );
endproperty
generate
  for (genvar si = 0; si < NUM_SETS; si++) begin: I_to_IM1
    assert_I_to_IM: assert property (I_to_IM(si))
      else $error("Set %0d: write I doen't go to IM", si);
  end
endgenerate
property S_to_SM(i);
  @(posedge clk) 
    (((cacheline[i].state == S))&& (cpu_req && cpu_we)&& (cpu_index == i[INDEX_WIDTH-1:0])&& arbiter_gnt )  // need to wait for arbiter_gnt
      |-> ##1 (cacheline[i].state ==SM );
endproperty
generate
  for (genvar si = 0; si < NUM_SETS; si++) begin: S_to_SM1
    assert_S_to_SM: assert property (S_to_SM(si))
      else $error("Set %0d: write S doen't go to SM", si);
  end
endgenerate
// transient state

property IM_transient_resolve(i);
  @(posedge clk) 
    ((cacheline[i].state == IM))
      |-> ##1 (cacheline[i].state == M);
endproperty

generate
  for (genvar si = 0; si < NUM_SETS; si++) begin: IMtrans_state_check
    assert_IMtransient_resolve: assert property (IM_transient_resolve(si))
      else $error("Set %0d: IMtransient state never resolves to stable!", si);
  end
endgenerate
property IE_transient_resolve(i);
  @(posedge clk) 
    ((cacheline[i].state == IE))
      |-> ##1 (cacheline[i].state == E);
endproperty

generate
  for (genvar si = 0; si < NUM_SETS; si++) begin: IEtrans_state_check
    assert_IEtransient_resolve: assert property (IE_transient_resolve(si))
      else $error("Set %0d: IEtransient state never resolves to stable!", si);
  end
endgenerate
property SM_transient_resolve(i);
  @(posedge clk) 
    ((cacheline[i].state == SM))
      |-> ##1 (cacheline[i].state == M);
endproperty

generate
  for (genvar si = 0; si < NUM_SETS; si++) begin: SMtrans_state_check
    assert_SMtransient_resolve: assert property (SM_transient_resolve(si))
      else $error("Set %0d: SMtransient state never resolves to stable!", si);
  end
endgenerate
property IS_transient_resolve(i);
  @(posedge clk) 
    ((cacheline[i].state == IS))
      |-> ##1 (cacheline[i].state == S);
endproperty

generate
  for (genvar si = 0; si < NUM_SETS; si++) begin: IStrans_state_check
    assert_IStransient_resolve: assert property (IS_transient_resolve(si))
      else $error("Set %0d: IStransient state never resolves to stable!", si);
  end
endgenerate


// local read no change (MES)
property p_local_read_Mstate_no_change(i);
  @(posedge clk) 
    ((cacheline[i].state == M)&& (cpu_req && !cpu_we)&& (cpu_index == i[INDEX_WIDTH-1:0]) && (bus_msg.bus_tx == Bus_Idle))  
      |-> ##1 (cacheline[i].state ==M);
endproperty
generate
  for (genvar si = 0; si < NUM_SETS; si++) begin: p_local_read_Mstate_no_change1
    assert_local_readM_no_change: assert property (p_local_read_Mstate_no_change(si))
      else $error("Set %0d: local read in M but state changed??", si);
  end
endgenerate
property p_local_read_Estate_no_change(i);
  @(posedge clk) 
    ((cacheline[i].state == E)&& (cpu_req && !cpu_we)&& (cpu_index == i[INDEX_WIDTH-1:0]) && (bus_msg.bus_tx == Bus_Idle))  
      |-> ##1 (cacheline[i].state ==E);
endproperty
generate
  for (genvar si = 0; si < NUM_SETS; si++) begin: p_local_read_Estate_no_change1
    assert_local_readE_no_change: assert property (p_local_read_Estate_no_change(si))
      else $error("Set %0d: local read in E but state changed??", si);
  end
endgenerate
property p_local_read_Sstate_no_change(i);
  @(posedge clk) 
    (cacheline[i].state == S && cpu_req && !cpu_we && cpu_index == i[INDEX_WIDTH-1:0] && bus_msg.bus_tx == Bus_Idle)  
      |-> ##1(cacheline[i].state ==S);
endproperty
generate
  for (genvar si = 0; si < NUM_SETS; si++) begin: p_local_read_Sstate_no_change1
    assert_local_readS_no_change: assert property (p_local_read_Sstate_no_change(si))
      else $error("Set %0d: local read in S but state changed??", si);
  end
endgenerate

// local write no change (ME)
property p_local_write_e_to_m(i);
  @(posedge clk) 
    (((cacheline[i].state == M) || (cacheline[i].state == E)) && (cpu_req && cpu_we)&& (cpu_index == i[INDEX_WIDTH-1:0])&& (bus_msg.bus_tx == Bus_Idle)) //bus needs to be idle or would flush
      |-> ##1(cacheline[i].state == M);
endproperty
generate
  for (genvar si = 0; si < NUM_SETS; si++) begin: p_local_write_e_to_m1
    assert_local_write_no_change: assert property (p_local_write_e_to_m(si))
      else $error("Set %0d: local write in E/M but state changed??", si);
  end
endgenerate



// Bus=Rd remote M->S, E->S, S->S, I->I
property p_bus_rd_remote_M(i);
  @(posedge clk) 
    (bus_msg.valid && bus_msg.bus_tx == Bus_Rd && bus_msg.source != ID[$clog2(NUM_CPUS):0] && bus_msg_index==i[INDEX_WIDTH-1:0] && (cacheline[i].state == M))
      |-> ##1(cacheline[i].state == S);
endproperty

generate 
  for(genvar si=0; si<NUM_SETS; si++) begin: p_bus_rd_remote_M1
    assert_bus_rd_remote_M: assert property (p_bus_rd_remote_M(si))
      else $error("Set %0d: Bus_Rd remote M state not correct transformation!", si);
  end
endgenerate
property p_bus_rd_remote_E(i);
  @(posedge clk) 
    (bus_msg.valid && bus_msg.bus_tx == Bus_Rd && bus_msg.source != ID[$clog2(NUM_CPUS):0] && bus_msg_index==i[INDEX_WIDTH-1:0] && (cacheline[i].state == E))
      |-> ##1(cacheline[i].state == S);
endproperty

generate 
  for(genvar si=0; si<NUM_SETS; si++) begin: p_bus_rd_remote_E1
    assert_bus_rd_remote_E: assert property (p_bus_rd_remote_E(si))
      else $error("Set %0d: Bus_Rd remote E state not correct transformation!", si);
  end
endgenerate
property p_bus_rd_remote_S(i);
  @(posedge clk) 
    (bus_msg.valid && bus_msg.bus_tx == Bus_Rd && bus_msg.source != ID[$clog2(NUM_CPUS):0] && bus_msg_index==i[INDEX_WIDTH-1:0] && (cacheline[i].state == S))
      |-> ##1(cacheline[i].state == S);
endproperty

generate 
  for(genvar si=0; si<NUM_SETS; si++) begin: p_bus_rd_remote_S1
    assert_bus_rd_remote_S: assert property (p_bus_rd_remote_S(si))
      else $error("Set %0d: Bus_Rd remote S state not correct transformation!", si);
  end
endgenerate
property p_bus_rd_remote_I(i);
  @(posedge clk) 
    (bus_msg.valid && bus_msg.bus_tx == Bus_Rd && bus_msg.source != ID[$clog2(NUM_CPUS):0] && bus_msg_index==i[INDEX_WIDTH-1:0] && (cacheline[i].state == I))
      |-> ##1(cacheline[i].state == I);
endproperty

generate 
  for(genvar si=0; si<NUM_SETS; si++) begin: p_bus_rd_remote_I1
    assert_bus_rd_remote_I: assert property (p_bus_rd_remote_I(si))
      else $error("Set %0d: Bus_Rd remote I state not correct transformation!", si);
  end
endgenerate

//Bus_Rdx：remote M->I, E->I, S->I, I->I
property p_bus_rdx_remote(i);
  @(posedge clk) 
    (bus_msg.valid && bus_msg.bus_tx == Bus_Rdx && bus_msg.source != ID[$clog2(NUM_CPUS):0] && bus_msg_index==i[INDEX_WIDTH-1:0] )
      |-> ##1(cacheline[i].state == I);
endproperty

generate 
  for(genvar si=0; si<NUM_SETS; si++) begin: p_bus_rdx_remote1
    assert_bus_rdx_remote: assert property (p_bus_rdx_remote(si))
      else $error("Set %0d: Bus_Rdx remote state not I!", si);
  end
endgenerate

//Bus_Upg：remote no M/E，S->I, I->I
property p_bus_upg_no_me(i);
  @(posedge clk) 
    (bus_msg.valid && bus_msg.bus_tx == Bus_Upg && bus_msg.source != ID[$clog2(NUM_CPUS):0] && bus_msg_index==i[INDEX_WIDTH-1:0])
      |-> !(cacheline[i].state == M || cacheline[i].state == E);  
endproperty

property p_bus_upg_remote(i);
  @(posedge clk) 
    (bus_msg.valid && bus_msg.bus_tx == Bus_Upg && bus_msg.source != ID[$clog2(NUM_CPUS):0] && bus_msg_index==i[INDEX_WIDTH-1:0] && (cacheline[i].state == S || cacheline[i].state == I))
      |-> ##1(cacheline[i].state == I);
endproperty

generate 
  for(genvar si=0; si<NUM_SETS; si++) begin: p_bus_upg_remote1
    assert_bus_upg_no_me: assert property (p_bus_upg_no_me(si))
      else $error("Set %0d: Bus_Upg remote state error! Should not see M/E.", si);

    assert_bus_upg_remote: assert property (p_bus_upg_remote(si))
      else $error("Set %0d: Bus_Upg remote state incorrect (should be S->I or I->I).", si);
  end
endgenerate
// check cacheline_data==cpu_wdata 
property p_cpu_write_data_ok(i);
  @(posedge clk) 
    ((cpu_req && cpu_we && (cpu_index == i[INDEX_WIDTH-1:0]) && cpu_resp))
    |-> (cacheline_next[i].data == cpu_wdata);
endproperty
generate
  for (genvar si = 0; si < NUM_SETS; si++) begin : p_cpu_write_data_check
    assert_cpu_write_data_ok: assert property (p_cpu_write_data_ok(si))
      else $error("Local Write Data Mismatch: set %0d does not match CPU's wdata!", si);
  end
endgenerate
// check cacheline_data==cpu_rdata
property p_cpu_read_data_ok(i);
  @(posedge clk) 
    ((cpu_req && !cpu_we && (cpu_index == i[INDEX_WIDTH-1:0]) && cpu_resp))
    |-> (cpu_rdata == cacheline_next[i].data);
endproperty

generate
  for (genvar si = 0; si < NUM_SETS; si++) begin : p_cpu_read_data_check
    assert_cpu_read_data_ok: assert property (p_cpu_read_data_ok(si))
      else $error("Local Read Data Mismatch: set %0d does not match CPU's rdata!", si);
  end
endgenerate
// check xbar gets right data to mem when Bus_flush 
property p_bus_flush_sends_data(i);
  @(posedge clk) 
    (bus_tx == Bus_Flush && bus_msg_index == i[INDEX_WIDTH-1:0])
    |-> ##1 (xbar_out.valid && xbar_out.data == cacheline[i].data && (xbar_out.destination== NUM_CPUS[$clog2(NUM_CPUS):0]));
endproperty

generate
  for (genvar si=0; si<NUM_SETS; si++) begin
    assert_bus_flush_sends_data: assert property(p_bus_flush_sends_data(si))
      else $error("Flush triggered but no data sent to memory for set%0d", si);
  end
endgenerate
//  remote BusRd && is M/E， bus_tx==Bus_Flush
property p_bus_rd_must_flush_me(i);
  @(posedge clk) 
     ( bus_msg.valid && (bus_msg.bus_tx == Bus_Rd) && 
      (bus_msg.source != ID[$clog2(NUM_CPUS):0]) && 
      (bus_msg_index == i[INDEX_WIDTH-1:0]) &&
      (cacheline[i].state inside {M, E})
    )|-> (bus_tx == Bus_Flush);
endproperty

generate
  for (genvar si=0; si<NUM_SETS; si++) begin: busrd_me_flush
    assert_bus_rd_me_flush: assert property (p_bus_rd_must_flush_me(si))
      else $error("BusRd on M/E but no Bus_Flush triggered! Set %0d", si);
  end
endgenerate

//remote BusRdx && is M/E/S, bus_tx==Bus_Flush
property p_bus_rdx_must_flush_mes(i);
  @(posedge clk) 
    ( bus_msg.valid && (bus_msg.bus_tx == Bus_Rdx) && 
      (bus_msg.source != ID[$clog2(NUM_CPUS):0]) && 
      (bus_msg_index == i[INDEX_WIDTH-1:0]) &&
      (cacheline[i].state inside {M, E, S}) 
    )
    |-> (bus_tx == Bus_Flush);
endproperty
generate
  for (genvar si=0; si<NUM_SETS; si++) begin: busrdx_mes_flush
    assert_bus_rdx_mes_flush: assert property (p_bus_rdx_must_flush_mes(si))
      else $error("BusRdx on M/E/S but no Bus_Flush triggered! Set %0d", si);
  end
endgenerate
//check bus_rd
property p_bus_rd_only_from_i_read(i);
  @(posedge clk) 
    (((cacheline[i].state == I))&& (cpu_req && !cpu_we)&& (cpu_index == i[INDEX_WIDTH-1:0])&& arbiter_gnt )
    |-> (bus_tx == Bus_Rd);
endproperty
generate
   for (genvar si=0; si<NUM_SETS; si++) begin: bus_rd_only_from_i_read
     assert_bus_rd_only_from_i_read: assert property(p_bus_rd_only_from_i_read(si))
  else $error("BusRd occurred but we are not in I-state read scenario!");
  end
endgenerate
//check bus_Rdx
property p_bus_rdx_only_from_i_read(i);
  @(posedge clk) 
    (((cacheline[i].state == I))&& (cpu_req && cpu_we)&& (cpu_index == i[INDEX_WIDTH-1:0])&& arbiter_gnt )
    |-> (bus_tx == Bus_Rdx);
endproperty
generate
   for (genvar si=0; si<NUM_SETS; si++) begin: bus_rdx_only_from_i_read
     assert_bus_rdx_only_from_i_read: assert property(p_bus_rdx_only_from_i_read(si))
  else $error("BusRd occurred but we are not in I-state read scenario!");
  end
endgenerate
//check bus_Upg
property p_bus_upg_only_from_i_read(i);
  @(posedge clk) 
    (((cacheline[i].state == S))&& (cpu_req && cpu_we)&& (cpu_index == i[INDEX_WIDTH-1:0])&& arbiter_gnt )
    |-> (bus_tx == Bus_Upg);
endproperty
generate
   for (genvar si=0; si<NUM_SETS; si++) begin: bus_upg_only_from_i_read
     assert_bus_upg_only_from_i_read: assert property(p_bus_upg_only_from_i_read(si))
  else $error("BusRd occurred but we are not in I-state read scenario!");
  end
endgenerate
//coverage
cacheline_state_t prev_state [NUM_SETS];

always_ff @(posedge clk) begin
    if (rst) begin
        for (int i = 0; i < NUM_SETS; i++) begin
            prev_state[i] <= I;
        end
    end else begin
        for (int i = 0; i < NUM_SETS; i++) begin
            prev_state[i] <= cacheline[i].state;
        end
    end
end
cover_I_to_IS: cover property (@(posedge clk) 
    ((prev_state[0] == I) && (cacheline[0].state == IS)) ||
    ((prev_state[1] == I) && (cacheline[1].state == IS)) ||
    ((prev_state[2] == I) && (cacheline[2].state == IS)) ||
    ((prev_state[3] == I) && (cacheline[3].state == IS))
	);
// IS->S
cover_IS_to_S: cover property (@(posedge clk) 
    ((prev_state[0] == IS) && (cacheline[0].state == S)) ||
    ((prev_state[1] == IS) && (cacheline[1].state == S)) ||
    ((prev_state[2] == IS) && (cacheline[2].state == S)) ||
    ((prev_state[3] == IS) && (cacheline[3].state == S))
);
// I->IM
cover_I_to_IM: cover property (@(posedge clk) 
    ((prev_state[0] == I) && (cacheline[0].state == IM)) ||
    ((prev_state[1] == I) && (cacheline[1].state == IM)) ||
    ((prev_state[2] == I) && (cacheline[2].state == IM)) ||
    ((prev_state[3] == I) && (cacheline[3].state == IM))
);
// IM->M
cover_IM_to_M: cover property (@(posedge clk) 
    ((prev_state[0] == IM) && (cacheline[0].state == M)) ||
    ((prev_state[1] == IM) && (cacheline[1].state == M)) ||
    ((prev_state[2] == IM) && (cacheline[2].state == M)) ||
    ((prev_state[3] == IM) && (cacheline[3].state == M))
);
// S->SM
cover_S_to_SM: cover property (@(posedge clk) 
    ((prev_state[0] == S) && (cacheline[0].state == SM)) ||
    ((prev_state[1] == S) && (cacheline[1].state == SM)) ||
    ((prev_state[2] == S) && (cacheline[2].state == SM)) ||
    ((prev_state[3] == S) && (cacheline[3].state == SM))
);
// SM->M
cover_SM_to_M: cover property (@(posedge clk) 
    ((prev_state[0] == SM) && (cacheline[0].state == M)) ||
    ((prev_state[1] == SM) && (cacheline[1].state == M)) ||
    ((prev_state[2] == SM) && (cacheline[2].state == M)) ||
    ((prev_state[3] == SM) && (cacheline[3].state == M))
);
// local read
cover_localread_MM: cover property (@(posedge clk) 
    ((cpu_req && !cpu_we) && (cacheline[0].state == M) && (cacheline_next[0].state == M)) ||
    ((cpu_req && !cpu_we) && (cacheline[1].state == M) && (cacheline_next[1].state == M)) ||
    ((cpu_req && !cpu_we) && (cacheline[2].state == M) && (cacheline_next[2].state == M)) ||
    ((cpu_req && !cpu_we) && (cacheline[3].state == M) && (cacheline_next[3].state == M))
);

cover_localread_EE: cover property (@(posedge clk) 
    ((cpu_req && !cpu_we) && (cacheline[0].state == E) && (cacheline_next[0].state == E)) ||
    ((cpu_req && !cpu_we) && (cacheline[1].state == E) && (cacheline_next[1].state == E)) ||
    ((cpu_req && !cpu_we) && (cacheline[2].state == E) && (cacheline_next[2].state == E)) ||
    ((cpu_req && !cpu_we) && (cacheline[3].state == E) && (cacheline_next[3].state == E))
);

cover_localread_SS: cover property (@(posedge clk) 
    ((cpu_req && !cpu_we) && (cacheline[0].state == S) && (cacheline_next[0].state == S)) ||
    ((cpu_req && !cpu_we) && (cacheline[1].state == S) && (cacheline_next[1].state == S)) ||
    ((cpu_req && !cpu_we) && (cacheline[2].state == S) && (cacheline_next[2].state == S)) ||
    ((cpu_req && !cpu_we) && (cacheline[3].state == S) && (cacheline_next[3].state == S))
);
//local write
cover_localwrite_EM: cover property (@(posedge clk) 
    ((cpu_req && cpu_we) && (prev_state[0] == E) && (cacheline_next[0].state == M)) ||
    ((cpu_req && cpu_we) && (prev_state[1] == E) && (cacheline_next[1].state == M)) ||
    ((cpu_req && cpu_we) && (prev_state[2] == E) && (cacheline_next[2].state == M)) ||
    ((cpu_req && cpu_we) && (prev_state[3] == E) && (cacheline_next[3].state == M))
);

cover_localwrite_MM: cover property (@(posedge clk) 
    ((cpu_req && cpu_we) && (prev_state[0] == M) && (cacheline_next[0].state == M)) ||
    ((cpu_req && cpu_we) && (prev_state[1] == M) && (cacheline_next[1].state == M)) ||
    ((cpu_req && cpu_we) && (prev_state[2] == M) && (cacheline_next[2].state == M)) ||
    ((cpu_req && cpu_we) && (prev_state[3] == M) && (cacheline_next[3].state == M))
);


cover_remote_Bus_Rd_MS: cover property (@(posedge clk)
    (bus_msg.valid && (bus_msg.bus_tx == Bus_Rd) && (bus_msg.source != ID[$clog2(NUM_CPUS):0]) &&
    ((bus_msg_index == 0 && cacheline[0].state == M && cacheline_next[0].state == S) ||
     (bus_msg_index == 1 && cacheline[1].state == M && cacheline_next[1].state == S) ||
     (bus_msg_index == 2 && cacheline[2].state == M && cacheline_next[2].state == S) ||
     (bus_msg_index == 3 && cacheline[3].state == M && cacheline_next[3].state == S)))
);

cover_remote_Bus_Rd_ES: cover property (@(posedge clk)
    (bus_msg.valid && (bus_msg.bus_tx == Bus_Rd) && (bus_msg.source != ID[$clog2(NUM_CPUS):0]) &&
    ((bus_msg_index == 0 && cacheline[0].state == E && cacheline_next[0].state == S) ||
     (bus_msg_index == 1 && cacheline[1].state == E && cacheline_next[1].state == S) ||
     (bus_msg_index == 2 && cacheline[2].state == E && cacheline_next[2].state == S) ||
     (bus_msg_index == 3 && cacheline[3].state == E && cacheline_next[3].state == S)))
);

cover_remote_Bus_Rd_SS: cover property (@(posedge clk)
    (bus_msg.valid && (bus_msg.bus_tx == Bus_Rd) && (bus_msg.source != ID[$clog2(NUM_CPUS):0]) &&
    ((bus_msg_index == 0 && cacheline[0].state == S && cacheline_next[0].state == S) ||
     (bus_msg_index == 1 && cacheline[1].state == S && cacheline_next[1].state == S) ||
     (bus_msg_index == 2 && cacheline[2].state == S && cacheline_next[2].state == S) ||
     (bus_msg_index == 3 && cacheline[3].state == S && cacheline_next[3].state == S)))
);

cover_remote_Bus_Rd_II: cover property (@(posedge clk)
    (bus_msg.valid && (bus_msg.bus_tx == Bus_Rd) && (bus_msg.source != ID[$clog2(NUM_CPUS):0]) &&
    ((bus_msg_index == 0 && cacheline[0].state == I && cacheline_next[0].state == I) ||
     (bus_msg_index == 1 && cacheline[1].state == I && cacheline_next[1].state == I) ||
     (bus_msg_index == 2 && cacheline[2].state == I && cacheline_next[2].state == I) ||
     (bus_msg_index == 3 && cacheline[3].state == I && cacheline_next[3].state == I)))
);

cover_remote_Bus_Rdx_MI: cover property (@(posedge clk)
    (bus_msg.valid && (bus_msg.bus_tx == Bus_Rdx) && (bus_msg.source != ID[$clog2(NUM_CPUS):0]) &&
    ((bus_msg_index == 0 && cacheline[0].state == M && cacheline_next[0].state == I) ||
     (bus_msg_index == 1 && cacheline[1].state == M && cacheline_next[1].state == I) ||
     (bus_msg_index == 2 && cacheline[2].state == M && cacheline_next[2].state == I) ||
     (bus_msg_index == 3 && cacheline[3].state == M && cacheline_next[3].state == I)))
);

cover_remote_Bus_Rdx_EI: cover property (@(posedge clk)
    (bus_msg.valid && (bus_msg.bus_tx == Bus_Rdx) && (bus_msg.source != ID[$clog2(NUM_CPUS):0]) &&
    ((bus_msg_index == 0 && cacheline[0].state == E && cacheline_next[0].state == I) ||
     (bus_msg_index == 1 && cacheline[1].state == E && cacheline_next[1].state == I) ||
     (bus_msg_index == 2 && cacheline[2].state == E && cacheline_next[2].state == I) ||
     (bus_msg_index == 3 && cacheline[3].state == E && cacheline_next[3].state == I)))
);

cover_remote_Bus_Rdx_SI: cover property (@(posedge clk)
    (bus_msg.valid && (bus_msg.bus_tx == Bus_Rdx) && (bus_msg.source != ID[$clog2(NUM_CPUS):0]) &&
    ((bus_msg_index == 0 && cacheline[0].state == S && cacheline_next[0].state == I) ||
     (bus_msg_index == 1 && cacheline[1].state == S && cacheline_next[1].state == I) ||
     (bus_msg_index == 2 && cacheline[2].state == S && cacheline_next[2].state == I) ||
     (bus_msg_index == 3 && cacheline[3].state == S && cacheline_next[3].state == I)))
);

cover_remote_Bus_Rdx_II: cover property (@(posedge clk)
    (bus_msg.valid && (bus_msg.bus_tx == Bus_Rdx) && (bus_msg.source != ID[$clog2(NUM_CPUS):0]) &&
    ((bus_msg_index == 0 && cacheline[0].state == I && cacheline_next[0].state == I) ||
     (bus_msg_index == 1 && cacheline[1].state == I && cacheline_next[1].state == I) ||
     (bus_msg_index == 2 && cacheline[2].state == I && cacheline_next[2].state == I) ||
     (bus_msg_index == 3 && cacheline[3].state == I && cacheline_next[3].state == I)))
);

cover_remote_Bus_Upg_SI: cover property (@(posedge clk)
    (bus_msg.valid && (bus_msg.bus_tx == Bus_Upg) && (bus_msg.source != ID[$clog2(NUM_CPUS):0]) &&
    ((bus_msg_index == 0 && cacheline[0].state == S && cacheline_next[0].state == I) ||
     (bus_msg_index == 1 && cacheline[1].state == S && cacheline_next[1].state == I) ||
     (bus_msg_index == 2 && cacheline[2].state == S && cacheline_next[2].state == I) ||
     (bus_msg_index == 3 && cacheline[3].state == S && cacheline_next[3].state == I)))
);

cover_remote_Bus_Upg_II: cover property (@(posedge clk)
    (bus_msg.valid && (bus_msg.bus_tx == Bus_Upg) && (bus_msg.source != ID[$clog2(NUM_CPUS):0]) &&
    ((bus_msg_index == 0 && cacheline[0].state == I && cacheline_next[0].state == I) ||
     (bus_msg_index == 1 && cacheline[1].state == I && cacheline_next[1].state == I) ||
     (bus_msg_index == 2 && cacheline[2].state == I && cacheline_next[2].state == I) ||
     (bus_msg_index == 3 && cacheline[3].state == I && cacheline_next[3].state == I)))
);





endmodule
