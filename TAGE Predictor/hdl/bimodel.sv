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
localparam BTableSize=8;
logic prediction;
assign prediction=update_prediction; // don't need this input
assign lookup_ready =1'b1;
// CTB update
logic [CounterLen-1:0] counterTB [0:CTableSize-1];
integer i;
always_ff @(posedge clk)begin
    if(rst)begin
         for(i=0;i<32;i++)begin
            counterTB[i]<=2'b01;
         end
    end
    else if(update_valid)begin
             if(update_actual)begin 
                  if (counterTB[update_pc[4:0]] != 2'b11) counterTB[update_pc[4:0]] <= counterTB[update_pc[4:0]]+1'b1;
             end
             else begin
                  if (counterTB[update_pc[4:0]] != 2'b00) counterTB[update_pc[4:0]] <= counterTB[update_pc[4:0]]-1'b1;
             end
    end
end
//BTB update
integer k;
logic [28:0] btb_tag    [0:BTableSize-1]; 
logic [31:0] btb_target [0:BTableSize-1];
always_ff @(posedge clk)begin
    if(rst)begin
         for(k=0;k<8;k++)begin
            btb_tag[k]<='0;
            btb_target[k] <='0;
         end
    end
    else if(update_valid)begin
             if(update_actual)begin 
                 btb_target[update_pc[2:0]] <= update_target[31:0];
                 btb_tag[update_pc[2:0]]<= update_pc[31:3];
             end
    end
end
//lookup logic
	always_comb begin
	   if(rst)begin
           	lookup_prediction='0;
                lookup_target='0;   
           end 
           else begin
                if(lookup_valid)begin
                     if(counterTB[lookup_pc[4:0]] >=2'b10) begin
                          lookup_prediction=1'b1;
                          lookup_target = btb_target[lookup_pc[2:0]];
                     end
                     else begin
                           lookup_prediction=1'b0;
                           lookup_target = 32'b0;
                     end
                     
                
                end 
                 

           end 
	end
endmodule


