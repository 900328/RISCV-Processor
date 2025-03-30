module bp
(
    input   logic           clk,
    input   logic           rst,

    input   logic   [31:0]  lookup_pc,
    input   logic           lookup_valid,
    output  logic           lookup_prediction, //1=taken
    output  logic   [31:0]  lookup_target,
    output  logic           lookup_ready,

    input   logic   [31:0]  update_pc,
    input   logic           update_prediction,//1=taken
    input   logic           update_actual, //actual=1:taken
    input   logic   [31:0]  update_target,
    input   logic           update_valid
);

localparam CTableSize=32;
localparam  CounterLen=2;
localparam BTableSize=1024;
localparam TABLE_ADDR_SZ =2;
logic [1:0]  T1_ctr [0:3];
logic [1:0]  T2_ctr [0:3];
logic [1:0]  T3_ctr [0:3];
logic [1:0]  T4_ctr [0:3];
logic [0:0]  T1_u[0:3];
logic [0:0]  T2_u[0:3];
logic [0:0]  T3_u[0:3];
logic [0:0]  T4_u[0:3];
logic [7:0]  T1_tag[0:3];
logic [7:0]  T2_tag[0:3];
logic [7:0]  T3_tag[0:3];
logic [7:0]  T4_tag[0:3];


assign lookup_ready =1'b1;
//BTB update  
integer k;
logic [23:0] btb_tag    [0:BTableSize-1]; 
logic [31:0] btb_target [0:BTableSize-1];
always_ff @(posedge clk)begin
    if(rst)begin
         for(k=0;k<1024;k++)begin
            btb_tag[k]<='0;
            btb_target[k] <='0;
         end
    end
    else if(update_valid)begin
             if(update_actual)begin 
                 btb_target[update_pc[9:0]] <= update_target[31:0];
                 btb_tag[update_pc[9:0]]<= update_pc[31:8];
             end
    end
end

// CTB update  
logic [CounterLen-1:0] counterTB [0:CTableSize-1];
integer i;

//GHR
logic [31:0] GHR;
always_ff @(posedge clk)begin
    if(rst) GHR <= '0;
    else if(update_valid) GHR <= {GHR[30:0], update_actual};
end
//hash function
 function automatic logic [TABLE_ADDR_SZ-1:0] tage_index(
    input logic [31:0] pc,
    input logic [15:0] ghr,
    input logic [4:0]  histLen
  );
    logic [15:0] hist_subset;
    logic [TABLE_ADDR_SZ-1:0] hash_val;
    logic [31:0] pc_shifted;
    pc_shifted = pc >> histLen;
    hash_val = pc_shifted[TABLE_ADDR_SZ-1:0] ^ ghr[TABLE_ADDR_SZ-1:0];
   /*  get_tage_index = partial;
    case(histLen)
	    2:  hist_subset = {14'b0,ghr[1:0]};
	    4:  hist_subset = {12'b0,ghr[3:0]};
	    8:  hist_subset = {8'b0,ghr[7:0]};
	    16: hist_subset = ghr[15:0];
            default:hist_subset= '0;
    endcase
    //hist_subset = ghr[histLen-1:0];
    hash_val = pc ^ hist_subset;*/
    return hash_val[TABLE_ADDR_SZ-1:0];
  endfunction : tage_index
 function automatic logic [7:0] tage_tag(
    input logic [31:0] pc,
    input logic [15:0] ghr,
    input int          histLen
  );
    logic [7:0] tag_val;
    logic [31:0] pc_shifted;
    pc_shifted = pc >> histLen;
    tag_val = (pc_shifted[7:0] ^ ghr[7:0]);
    return tag_val;
  endfunction : tage_tag




//update logic
    logic [TABLE_ADDR_SZ-1:0] idx_T1, idx_T2, idx_T3, idx_T4;
    logic [7:0] t_T1, t_T2, t_T3, t_T4;
    logic T1_m, T2_m, T3_m, T4_m;
    integer provider;
    integer altpred;
    integer d;
    logic altpred_taken;
    logic actual_taken; 
    assign actual_taken = update_actual;
    logic provider_correct;
    assign provider_correct =(update_prediction == update_actual);




always_comb begin
    idx_T1 = tage_index(update_pc, GHR, 4);
    idx_T2 = tage_index(update_pc, GHR, 8);
    idx_T3 = tage_index(update_pc, GHR, 16);
    idx_T4 = tage_index(update_pc, GHR, 32);

    t_T1   = tage_tag(update_pc, GHR, 4);
    t_T2   = tage_tag(update_pc, GHR, 8);
    t_T3   = tage_tag(update_pc, GHR, 16);
    t_T4   = tage_tag(update_pc, GHR, 32);

    T1_m   = (T1_tag[idx_T1[TABLE_ADDR_SZ-1:0]] == t_T1);
    T2_m   = (T2_tag[idx_T2[TABLE_ADDR_SZ-1:0]] == t_T2);
    T3_m   = (T3_tag[idx_T3[TABLE_ADDR_SZ-1:0]] == t_T3);
    T4_m   = (T4_tag[idx_T4[TABLE_ADDR_SZ-1:0]] == t_T4);

    if (T4_m) begin
        provider = 4;
        if(T3_m) altpred = 3;
        else if(T2_m) altpred =2;
        else if(T1_m) altpred =1;
        else altpred=0;
    end
    else if (T3_m)begin
        provider = 3;
        if(T2_m) altpred =2;
        else if(T1_m) altpred =1;
        else altpred=0;
    end
    else if (T2_m)begin
        provider = 2;
        if(T1_m) altpred =1;
        else altpred=0;
    end
    else if (T1_m) begin
        provider = 1;
        altpred = 0;
    end
    else begin
        provider = 0; 
        altpred = 0;
    end

    case (altpred)
      3: altpred_taken = (T3_ctr[idx_T3[TABLE_ADDR_SZ-1:0]] >= 2'b10);
      2: altpred_taken = (T2_ctr[idx_T2[TABLE_ADDR_SZ-1:0]] >= 2'b10);
      1: altpred_taken = (T1_ctr[idx_T1[TABLE_ADDR_SZ-1:0]] >= 2'b10);
      default: altpred_taken = (counterTB[update_pc[4:0]] >= 2'b10); 
    endcase
end
always_ff @(posedge clk) begin  
  if (rst) begin
   for (d = 0; d < 512; d++) begin
      T1_ctr[d] <= 2'b01;
      T1_u[d]   <= 1'b0;
      T1_tag[d] <= 8'b00000000;
      
      T2_ctr[d] <= 2'b01;
      T2_u[d]   <= 1'b0;
      T2_tag[d] <= 8'b00000000;

      T3_ctr[d] <= 2'b01;
      T3_u[d]   <= 1'b0;
      T3_tag[d] <= 8'b00000000;

      T4_ctr[d] <= 2'b01;
      T4_u[d]   <= 1'b0;
      T4_tag[d] <= 8'b00000000;
    end
    for(i=0;i<32;i++)begin
            counterTB[i]<=2'b01;
    end
   
  end
  else if (update_valid) begin
    if (provider == 4) begin
      if (actual_taken && T4_ctr[idx_T4[TABLE_ADDR_SZ-1:0]] != 2'b11)
        T4_ctr[idx_T4[TABLE_ADDR_SZ-1:0]] <= T4_ctr[idx_T4[TABLE_ADDR_SZ-1:0]] + 2'b01;
      else if (!actual_taken && T4_ctr[idx_T4[TABLE_ADDR_SZ-1:0]] != 2'b00)
        T4_ctr[idx_T4[TABLE_ADDR_SZ-1:0]] <= T4_ctr[idx_T4[TABLE_ADDR_SZ-1:0]] - 2'b01;
    end
    else if (provider == 3) begin
      if (actual_taken && T3_ctr[idx_T3[TABLE_ADDR_SZ-1:0]] != 2'b11)
        T3_ctr[idx_T3[TABLE_ADDR_SZ-1:0]] <= T3_ctr[idx_T3[TABLE_ADDR_SZ-1:0]] + 2'b01;
      else if (!actual_taken && T3_ctr[idx_T3[TABLE_ADDR_SZ-1:0]] != 2'b00)
        T3_ctr[idx_T3[TABLE_ADDR_SZ-1:0]] <= T3_ctr[idx_T3[TABLE_ADDR_SZ-1:0]] - 2'b01;
    end
    else if (provider == 2) begin
      if (actual_taken && T2_ctr[idx_T2[TABLE_ADDR_SZ-1:0]] != 2'b11)
        T2_ctr[idx_T2[TABLE_ADDR_SZ-1:0]] <= T2_ctr[idx_T2[TABLE_ADDR_SZ-1:0]] + 2'b01;
      else if (!actual_taken && T2_ctr[idx_T2[TABLE_ADDR_SZ-1:0]] != 2'b00)
        T2_ctr[idx_T2[TABLE_ADDR_SZ-1:0]] <= T2_ctr[idx_T2[TABLE_ADDR_SZ-1:0]] - 2'b01;
    end
    else if (provider == 1) begin
      if (actual_taken && T1_ctr[idx_T1[TABLE_ADDR_SZ-1:0]] != 2'b11)
        T1_ctr[idx_T1[TABLE_ADDR_SZ-1:0]] <= T1_ctr[idx_T1[TABLE_ADDR_SZ-1:0]] + 2'b01;
      else if (!actual_taken && T1_ctr[idx_T1[TABLE_ADDR_SZ-1:0]] != 2'b00)
        T1_ctr[idx_T1[TABLE_ADDR_SZ-1:0]] <= T1_ctr[idx_T1[TABLE_ADDR_SZ-1:0]] - 2'b01;
    end
      // base predictor
      if(actual_taken && counterTB[update_pc[4:0]] != 2'b11)
        counterTB[update_pc[4:0]] <= counterTB[update_pc[4:0]] + 2'b01;
      else if(!actual_taken && counterTB[update_pc[4:0]] != 2'b00)
        counterTB[update_pc[4:0]] <= counterTB[update_pc[4:0]] - 2'b01;
    

	    if (provider == 4) begin
	      if (provider_correct) T4_u[idx_T4[TABLE_ADDR_SZ-1:0]] <= 1'b1;
	      else                  T4_u[idx_T4[TABLE_ADDR_SZ-1:0]] <= 1'b0;
	    end
	    else if (provider == 3) begin
	      if (provider_correct) T3_u[idx_T3[TABLE_ADDR_SZ-1:0]] <= 1'b1;
	      else                  T3_u[idx_T3[TABLE_ADDR_SZ-1:0]] <= 1'b0;
	    end
	    else if (provider == 2) begin
	      if (provider_correct) T2_u[idx_T2[TABLE_ADDR_SZ-1:0]] <= 1'b1;
	      else                  T2_u[idx_T2[TABLE_ADDR_SZ-1:0]] <= 1'b0;
	    end
	    else if (provider == 1) begin
	      if (provider_correct) T1_u[idx_T1[TABLE_ADDR_SZ-1:0]] <= 1'b1;
	      else                  T1_u[idx_T1[TABLE_ADDR_SZ-1:0]] <= 1'b0;
	    end

    if(!provider_correct)begin
	case (provider)
	  4: begin
	  end

	  3: begin
	    if ((T4_u[idx_T3] == 1'b0)) begin
	      T4_tag[idx_T3] <= t_T3;
	      T4_ctr[idx_T3] <= actual_taken ? 2'b10 : 2'b01;
	      T4_u[idx_T3]   <= 1'b0;
	    end
            else begin 
              T4_u[idx_T3] <= 1'b0;
            end
	  end

	  2: begin
	    if ((T3_u[idx_T2] == 1'b0)) begin
	      T3_tag[idx_T2] <= t_T2;
	      T3_ctr[idx_T2] <= actual_taken ? 2'b10 : 2'b01;
	      T3_u[idx_T2]   <= 1'b0;
	    end
	    else if ((T4_u[idx_T2] == 1'b0)) begin
	      T4_tag[idx_T2] <= t_T2;
	      T4_ctr[idx_T2] <= actual_taken ? 2'b10 : 2'b01;
	      T4_u[idx_T2]   <= 1'b0;
	    end
            else begin 
              T4_u[idx_T2] <= 1'b0;
	      T3_u[idx_T2] <= 1'b0;
            end
	  end
	  1: begin
	    if ( (T2_u[idx_T1] == 1'b0)) begin
	      T2_tag[idx_T1] <= t_T1;
	      T2_ctr[idx_T1] <= actual_taken ? 2'b10 : 2'b01;
	      T2_u[idx_T1]   <= 1'b0;
	    end
	    else if ( (T3_u[idx_T1] == 1'b0)) begin
	      T3_tag[idx_T1] <= t_T1;
	      T3_ctr[idx_T1] <= actual_taken ? 2'b10 : 2'b01;
	      T3_u[idx_T1]   <= 1'b0;
	    end
	    else if ( (T4_u[idx_T1] == 1'b0)) begin
	      T4_tag[idx_T1] <= t_T1;
	      T4_ctr[idx_T1] <= actual_taken ? 2'b10 : 2'b01;
	      T4_u[idx_T1]   <= 1'b0;
	    end
            else begin 
              T4_u[idx_T1] <= 1'b0;
	      T3_u[idx_T1] <= 1'b0;
	      T2_u[idx_T1] <= 1'b0;
            end
	  end

	  default: begin
            if ( (T1_u[idx_T1] == 1'b0)) begin
	      T1_tag[idx_T1] <= t_T1;
	      T1_ctr[idx_T1] <= actual_taken ? 2'b10 : 2'b01;
	      T1_u[idx_T1]   <= 1'b0;
	    end
            else if ( (T2_u[idx_T1] == 1'b0)) begin
	      T2_tag[idx_T1] <= t_T1;
	      T2_ctr[idx_T1] <= actual_taken ? 2'b10 : 2'b01;
	      T2_u[idx_T1]   <= 1'b0;
	    end
	    else if ( (T3_u[idx_T1] == 1'b0)) begin
	      T3_tag[idx_T1] <= t_T1;
	      T3_ctr[idx_T1] <= actual_taken ? 2'b10 : 2'b01;
	      T3_u[idx_T1]   <= 1'b0;
	    end
	    else if ( (T4_u[idx_T1] == 1'b0)) begin
	      T4_tag[idx_T1] <= t_T1;
	      T4_ctr[idx_T1] <= actual_taken ? 2'b10 : 2'b01;
	      T4_u[idx_T1]   <= 1'b0;
	    end
            else begin 
              T4_u[idx_T1] <= 1'b0;
	      T3_u[idx_T1] <= 1'b0;
	      T2_u[idx_T1] <= 1'b0;
	      T1_u[idx_T1] <= 1'b0;
            end
end
	endcase



     end // !provider_correct

  end // if (update_valid)
end
// TAGE lookup

logic [TABLE_ADDR_SZ-1:0] index_T1, index_T2, index_T3, index_T4;
logic [7:0] tag_T1,   tag_T2,   tag_T3,   tag_T4;
logic T1_match,T2_match,T3_match,T4_match;
  always_comb begin
    index_T1 = tage_index(lookup_pc, GHR, 4);
    index_T2 = tage_index(lookup_pc, GHR, 8);
    index_T3 = tage_index(lookup_pc, GHR, 16);
    index_T4 = tage_index(lookup_pc, GHR, 32);

    tag_T1   = tage_tag(lookup_pc, GHR, 4);
    tag_T2   = tage_tag(lookup_pc, GHR, 8);
    tag_T3   = tage_tag(lookup_pc, GHR, 16);
    tag_T4   = tage_tag(lookup_pc, GHR, 32);
  
  T1_match = (T1_tag[index_T1[TABLE_ADDR_SZ-1:0]] == tag_T1);
  T2_match = (T2_tag[index_T2[TABLE_ADDR_SZ-1:0]] == tag_T2);
  T3_match = (T3_tag[index_T3[TABLE_ADDR_SZ-1:0]] == tag_T3);
  T4_match = (T4_tag[index_T4[TABLE_ADDR_SZ-1:0]] == tag_T4);
  end
//lookup logic
integer outputTable;
	always_comb begin
	   if(rst)begin
           	lookup_prediction='0;
                lookup_target='0;   
           end 
           else begin
                if(lookup_valid)begin
                     if(T4_match) begin
                     outputTable=4;
                             if(T4_ctr[index_T4[TABLE_ADDR_SZ-1:0]]>=2'b10)begin
                                    if(btb_tag[lookup_pc[9:0]] == lookup_pc[31:8]) begin
                                       lookup_prediction=1'b1;
                                       lookup_target = btb_target[lookup_pc[9:0]];
                                    end
                                    else begin
                                       lookup_prediction=1'b1;
                                       lookup_target = lookup_pc + 4;
                                    end
                             end
                             else begin
                                    lookup_prediction=1'b0;
                                    lookup_target = 32'b0;
                             end
                     end
                     else if(T3_match) begin
                     outputTable=3;
                             if(T3_ctr[index_T3[TABLE_ADDR_SZ-1:0]]>=2'b10)begin
                                    if(btb_tag[lookup_pc[9:0]] == lookup_pc[31:8]) begin
                                       lookup_prediction=1'b1;
                                       lookup_target = btb_target[lookup_pc[9:0]];
                                    end
                                    else begin
                                       lookup_prediction=1'b1;
                                       lookup_target = lookup_pc + 4;
                                    end
                             end
                             else begin
                                    lookup_prediction=1'b0;
                                    lookup_target = 32'b0;
                             end
                     end 
                     else if(T2_match) begin
                     outputTable=2;
                             if(T2_ctr[index_T2[TABLE_ADDR_SZ-1:0]]>=2'b10)begin
                                    if(btb_tag[lookup_pc[9:0]] == lookup_pc[31:8]) begin
                                       lookup_prediction=1'b1;
                                       lookup_target = btb_target[lookup_pc[9:0]];
                                    end
                                    else begin
                                       lookup_prediction=1'b1;
                                       lookup_target = lookup_pc + 4;
                                    end
                             end
                             else begin
                                    lookup_prediction=1'b0;
                                    lookup_target = 32'b0;
                             end
                     end 
                     else if(T1_match) begin
                     outputTable=1;
                             if(T1_ctr[index_T1[TABLE_ADDR_SZ-1:0]]>=2'b10)begin
                                    if(btb_tag[lookup_pc[9:0]] == lookup_pc[31:8]) begin
                                       lookup_prediction=1'b1;
                                       lookup_target = btb_target[lookup_pc[9:0]];
                                    end
                                    else begin
                                       lookup_prediction=1'b1;
                                       lookup_target = lookup_pc + 4;
                                    end
                             end
                             else begin
                                    lookup_prediction=1'b0;
                                    lookup_target = 32'b0;
                             end
                     end 
                     else begin
                     outputTable=0;
                           if(counterTB[lookup_pc[4:0]]>=2'b10) begin
                                  if(btb_tag[lookup_pc[9:0]] == lookup_pc[31:8]) begin
                                       lookup_prediction=1'b1;
                                       lookup_target = btb_target[lookup_pc[9:0]];
                                    end
                                    else begin
                                       lookup_prediction=1'b1;
                                       lookup_target = lookup_pc + 4;
                                    end

                           end
                           else begin
                                  lookup_prediction=1'b0;
                                  lookup_target = 32'b0;
                           end
                     end
                end
           end 
	end

endmodule


