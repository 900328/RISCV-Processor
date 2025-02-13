import "DPI-C" function string getenv(input string env_name);

module simple_memory_32_w_mask #(
    parameter DELAY = 3
)(
    mem_itf_w_mask.mem itf
);

    logic [31:0] internal_memory_array [logic [31:2]];

    enum int {
        MEMORY_STATE_IDLE,
        MEMORY_STATE_READ,
        MEMORY_STATE_WRITE
    } state;

    int delay_counter;

    always_ff @(posedge itf.clk) begin
        if (itf.rst) begin
            state <= MEMORY_STATE_IDLE;
            delay_counter <= '0;
            itf.resp[0] <= 1'b0;
            itf.rdata[0] <= 'x;
        end else begin
            itf.resp[0] <= 1'b0;
            itf.rdata[0] <= 'x;
            unique case (state)
            MEMORY_STATE_IDLE: begin
                if (|itf.rmask[0]) begin
                    state <= MEMORY_STATE_READ;
                    delay_counter <= DELAY;
                end
                if (|itf.wmask[0]) begin
                    state <= MEMORY_STATE_WRITE;
                    delay_counter <= DELAY;
                end
            end
            MEMORY_STATE_READ: begin
                if (delay_counter == 2) begin
                    itf.resp[0] <= 1'b1;
                    for (int i = 0; i < 4; i++) begin
                        if (itf.rmask[0][i]) begin
                            itf.rdata[0][i*8+:8] <= internal_memory_array[itf.addr[0][31:2]][i*8+:8];
                        end
                    end
                end
                if (delay_counter == 1) begin
                    state <= MEMORY_STATE_IDLE;
                end
                delay_counter <= delay_counter - 1;
            end
            MEMORY_STATE_WRITE: begin
                if (delay_counter == 2) begin
                    itf.resp[0] <= 1'b1;
                end
                if (delay_counter == 1) begin
                    for (int i = 0; i < 4; i++) begin
                        if (itf.wmask[0][i]) begin
                            internal_memory_array[itf.addr[0][31:2]][i*8 +: 8] = itf.wdata[0][i*8 +: 8];
                        end
                    end
                    state <= MEMORY_STATE_IDLE;
                end
                delay_counter <= delay_counter - 1;
            end
            endcase
        end
    end

    logic [31:0] cached_addr;
    logic [3:0] cached_mask;

    always_ff @(posedge itf.clk) begin
        if (|itf.rmask[0]) begin
            cached_addr <= itf.addr[0];
            cached_mask <= itf.rmask[0];
        end
        if (|itf.wmask[0]) begin
            cached_addr <= itf.addr[0];
            cached_mask <= itf.wmask[0];
        end
    end

    always @(posedge itf.clk iff !itf.rst) begin
        if ($isunknown(itf.rmask[0]) || $isunknown(itf.wmask[0])) begin
            $error("Memory Error: mask containes 'x");
            itf.error <= 1'b1;
        end
        if ((|itf.rmask[0]) && (|itf.wmask[0])) begin
            $error("Memory Error: simultaneous memory read and write");
            itf.error <= 1'b1;
        end
        if ((|itf.rmask[0]) || (|itf.wmask[0])) begin
            if ($isunknown(itf.addr[0])) begin
                $error("Memory Error: address contained 'x");
                itf.error <= 1'b1;
            end
            if (itf.addr[0][1:0] != 2'b00) begin
                $error("Memory Error: address is not 32-bit aligned");
                itf.error <= 1'b1;
            end
        end

        case (state)
        MEMORY_STATE_READ: begin
            if (itf.addr[0] != cached_addr) begin
                $error("Memory Error: address changed");
                itf.error <= 1'b1;
            end
            if (itf.rmask[0] != cached_mask) begin
                $error("Memory Error: mask changed");
                itf.error <= 1'b1;
            end
        end
        MEMORY_STATE_WRITE: begin
            if (itf.addr[0] != cached_addr) begin
                $error("Memory Error: address changed");
                itf.error <= 1'b1;
            end
            if (itf.wmask[0] != cached_mask) begin
                $error("Memory Error: mask changed");
                itf.error <= 1'b1;
            end
        end
        endcase
    end

    always @(posedge itf.clk iff itf.rst) begin
        automatic string memfile = {getenv("ECE411_MEMFILE"), "_4.lst"};
        internal_memory_array.delete();
        $readmemh(memfile, internal_memory_array);
    end

endmodule
