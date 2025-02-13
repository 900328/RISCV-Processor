module cache 
import rv32i_types::*;(
    input   logic           clk,
    input   logic           rst,

    // cpu side signals, ufp -> upward facing port
    input   logic   [31:0]  ufp_addr,
    input   logic   [3:0]   ufp_rmask,
    input   logic   [3:0]   ufp_wmask,
    output  logic   [31:0]  ufp_rdata,
    input   logic   [31:0]  ufp_wdata,
    output  logic           ufp_resp,

    // memory side signals, dfp -> downward facing port
    output  logic   [31:0]  dfp_addr,
    output  logic           dfp_read,
    output  logic           dfp_write,
    input   logic   [255:0] dfp_rdata,
    output  logic   [255:0] dfp_wdata,
    input   logic           dfp_resp
);
    logic [3:0]     set_addr;
    stage_reg_t stage_reg;
    stage_reg_t stage_reg_next;
    logic [22:0]    cache_tag [3:0];
    logic [255:0]   cache_data [3:0];
    logic           cache_valid [3:0];
    logic [22:0]    tag;
    logic [4:0]     offset;
    logic [3:0]     set;
    logic [31:0]    wmask0;
    logic [255:0]   din_data;
    logic [3:0]     csb_data;
    logic           web_data;
    logic           dfp_stall;
    logic           miss;

    logic [1:0] way_bin_idx;
    logic [2:0] old_lrubits;
    logic [2:0] new_lrubits;
    logic [3:0] csb_overwrite;
    logic [1:0] plru_bin_idx;

    logic [3:0] jank_set;

    logic dirty_stall;
    logic dirty_in;
    logic [3:0] dirty_out;
    logic web_tag;
    logic [22:0] din_tag;
    logic [3:0] hit_check;
    logic [3:0] csb_tag;

    always_ff @(posedge clk) begin
        if(rst) 
             stage_reg <= '0;
        else
             stage_reg <= stage_reg_next;
        if((stage_reg.wmask != '0 && hit_check != '0) && (stage_reg_next.wmask != '0 || stage_reg_next.rmask != '0)) 
             dfp_stall <= 1;
        else 
             dfp_stall <= 0;
    end


	always_comb begin
	    if (old_lrubits[2]) begin
		if (old_lrubits[0]) begin 
		    csb_overwrite = 4'b1110; 
		    plru_bin_idx = 2'b00; 
		end else begin 
		    csb_overwrite = 4'b1101; 
		    plru_bin_idx = 2'b01; 
		end
	    end else begin
		if (old_lrubits[1]) begin 
		    csb_overwrite = 4'b1011; 
		    plru_bin_idx = 2'b10; 
		end else begin 
		    csb_overwrite = 4'b0111; 
		    plru_bin_idx = 2'b11;
		end
	    end
	end

    always_comb begin
        dirty_stall = '0;
        new_lrubits = 'x;
        way_bin_idx = '0;

        hit_check = '0;
        miss = '0;
        ufp_resp = '0;
        dfp_addr = '0;
        dfp_read = '0;
        ufp_rdata = 'x;
        dfp_write = '0;
        dfp_wdata = 'x;
        if((stage_reg.rmask != '0 || stage_reg.wmask != '0) && ! dfp_stall) begin
            for(int i = 0; i < 4; i += 1) begin
                hit_check[i] = cache_tag[i] == stage_reg.tag && cache_valid[i] ? 1'b1 : 1'b0;
            end

            miss = hit_check == 4'b0 ? '1 : '0;
            if(miss && !stage_reg.dirty_write_back && cache_valid[plru_bin_idx] && dirty_out[plru_bin_idx])
                dirty_stall ='1;

            ufp_resp = !miss;
            if(dirty_stall)begin
            dfp_addr = {cache_tag[plru_bin_idx], stage_reg.set, 5'b0};
            dfp_read = '0;
            dfp_write = '1;
            dfp_wdata = cache_data[plru_bin_idx];
            end else begin
            dfp_addr = {stage_reg.mem_addr[31:5], 5'b0};
            dfp_read = (miss && !stage_reg.mem_resp);
            dfp_write = '0;
            dfp_wdata = 'x;
            end
            
            if(!miss) begin
                unique case(hit_check)
                    4'b0001: begin 
                        way_bin_idx = 2'b00;
                        new_lrubits = {1'b0, old_lrubits[1], 1'b0}; 
                    end
                    4'b0010: begin
                        way_bin_idx = 2'b01;
                        new_lrubits = {1'b0, old_lrubits[1], 1'b1};  
                    end
                    4'b0100: begin
                        way_bin_idx = 2'b10;
                        new_lrubits = {1'b1, 1'b0, old_lrubits[0]}; 
                    end
                    4'b1000: begin
                        way_bin_idx = 2'b11;
                        new_lrubits = {1'b1, 1'b1, old_lrubits[0]}; 
                    end
                    default: begin
                        way_bin_idx = 2'b00; 
                        new_lrubits = old_lrubits;
                    end
                endcase
                ufp_rdata = (stage_reg.rmask != '0) ? cache_data[way_bin_idx][31+(stage_reg.offset*8) -: 32] : 'x;
            end
      end 
end

    always_comb begin
        if(miss || dfp_stall) begin
            stage_reg_next = stage_reg;
            stage_reg_next.mem_resp = dfp_resp;
            if(dirty_stall) begin 
                stage_reg_next.mem_resp = '0; 
                stage_reg_next.dirty_write_back = dfp_resp; 
            end
            else begin 
                stage_reg_next.dirty_write_back = stage_reg.dirty_write_back; 
                stage_reg_next.mem_resp = dfp_resp; 
            end
        end else begin
            stage_reg_next.tag = ufp_addr[31:9];
            stage_reg_next.set = ufp_addr[8:5];
            stage_reg_next.offset = ufp_addr[4:0];
            stage_reg_next.mem_addr = ufp_addr;
            stage_reg_next.rmask = ufp_rmask;
            stage_reg_next.mem_resp = '0;
            stage_reg_next.dirty_write_back = '0;
            stage_reg_next.wmask = ufp_wmask;
            stage_reg_next.wdata = ufp_wdata;
        end
   end

    always_comb begin
        if(dfp_resp && !dirty_stall)begin
		csb_data = csb_overwrite;
		web_data = 1'b0;
		csb_tag = csb_overwrite;
		web_tag = '0;
        end else begin
		csb_data = (stage_reg.wmask != '0) ? ~hit_check : '0;
		web_data = (stage_reg.wmask == '0);
		csb_tag = '0;
		web_tag = '1;
        end
        set_addr = (stage_reg.wmask != '0 && hit_check != '0) ? stage_reg.set : stage_reg_next.set;

        dirty_in = '0;
        if(stage_reg.wmask != '0 && hit_check != '0) 
                dirty_in = '1;

        wmask0 = (dfp_resp && !dirty_stall) || (stage_reg.wmask != '0) ? '1 : '0;
        din_tag = (stage_reg.wmask != '0 && hit_check != '0) ? cache_tag[way_bin_idx] : stage_reg_next.tag ;

        if(dfp_resp && !dirty_stall) din_data = dfp_rdata;
        else begin
            din_data = cache_data[way_bin_idx];
            if(stage_reg.wmask[0])din_data[7+(stage_reg.offset*8) -: 8] = stage_reg.wdata[7:0];
            if(stage_reg.wmask[1])din_data[15+(stage_reg.offset*8) -: 8] = stage_reg.wdata[15:8];
            if(stage_reg.wmask[2])din_data[23+(stage_reg.offset*8) -: 8] = stage_reg.wdata[23:16];
            if(stage_reg.wmask[3])din_data[31+(stage_reg.offset*8) -: 8] = stage_reg.wdata[31:24];
        end
    end






    generate for (genvar i = 0; i < 4; i++) begin : arrays
        mp_cache_data_array data_array (
            .clk0       (clk),
            .csb0       (csb_data[i]),
            .web0       (web_data),
            .wmask0     (wmask0),
            .addr0      (set_addr),
            .din0       (din_data),
            .dout0      (cache_data[i])
        );
        mp_cache_tag_array tag_array (
            .clk0       (clk),
            .csb0       (csb_data[i]),
            .web0       (web_data),
            .addr0      (set_addr),
            .din0       ({dirty_in, din_tag}),
            .dout0      ({dirty_out[i], cache_tag[i]})
        );
        valid_array valid_array (
            .clk0       (clk),
            .rst0       (rst),
            .csb0       (csb_data[i]),
            .web0       (web_data),
            .addr0      (set_addr),
            .din0       ('1),
            .dout0      (cache_valid[i])
        );
    end endgenerate

    lru_array lru_array (
        .clk0       (clk),
        .rst0       (rst),
        .csb0       ('0),
        .web0       ('1),  
        .addr0      (stage_reg_next.set),
        .din0       ('0),
        .dout0      (old_lrubits),
        .csb1       (!ufp_resp),
        .web1       (!ufp_resp),  
        .addr1      (stage_reg.set),
        .din1       (new_lrubits),
        .dout1      ()
    );

endmodule
