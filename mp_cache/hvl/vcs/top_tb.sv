module top_tb;
    //---------------------------------------------------------------------------------
    // Waveform generation.
    //---------------------------------------------------------------------------------
    initial begin
        $fsdbDumpfile("dump.fsdb");
        $fsdbDumpvars(0, "+all");
    end

    //---------------------------------------------------------------------------------
    // TODO: Declare cache port signals:
    //---------------------------------------------------------------------------------

    logic   [31:0]  ufp_addr;
    logic   [3:0]   ufp_rmask;
    logic   [3:0]   ufp_wmask;
    logic   [31:0]  ufp_rdata;
    logic   [31:0]  ufp_wdata;
    logic           ufp_resp;

    //---------------------------------------------------------------------------------
    // TODO: Generate a clock:
    //---------------------------------------------------------------------------------
    bit clk;
    always #1ns clk = ~clk;

    bit rst;
    int timeout = 1000; // in cycles, change according to your needs

    //---------------------------------------------------------------------------------
    // TODO: Write a task to generate reset:
    //---------------------------------------------------------------------------------
    
    task reset();
        rst <= '1;
        ufp_rmask <= '0;
        ufp_addr <= '0;
        ufp_wmask <= '0;
        ufp_wdata <= '0;
        @(posedge clk);
        @(posedge clk);
        rst <= '0;
    endtask : reset

    //---------------------------------------------------------------------------------
    // TODO: Instantiate the DUT and physical memory:
    //---------------------------------------------------------------------------------

    mem_itf_wo_mask mem_itf(.*);
    simple_memory_256_wo_mask mem(.itf(mem_itf));

    cache dut(
        .clk,
        .rst,

        .ufp_addr,
        .ufp_rmask,
        .ufp_wmask,
        .ufp_rdata,
        .ufp_wdata,
        .ufp_resp,

        .dfp_addr(mem_itf.addr[0]),
        .dfp_read(mem_itf.read[0]),
        .dfp_write(mem_itf.write[0]),
        .dfp_rdata(mem_itf.rdata[0]),
        .dfp_wdata(mem_itf.wdata[0]),
        .dfp_resp(mem_itf.resp[0])
    );

    //---------------------------------------------------------------------------------
    // TODO: Write tasks to test various functionalities:
    //---------------------------------------------------------------------------------
    

    task read_conflict();
        // read from address x200 (miss)
        ufp_addr <= 32'h200;
        ufp_rmask <= 4'hf;
        ufp_wmask <= '0;
        ufp_wdata <= '0;
        @(posedge clk);
        ufp_addr <= 32'h0;
        ufp_rmask <= 4'h0;
        @(posedge ufp_resp);

        // read from address x0 (miss)
        ufp_addr <= 32'h0;
        ufp_rmask <= 4'hf;
        @(posedge clk);
        ufp_addr <= 32'h0;
        ufp_rmask <= 4'h0;
        @(posedge ufp_resp);
        repeat (5) @(posedge clk);

        // read from address x0 (hit)
        ufp_addr <= 32'h0;
        ufp_rmask <= 4'hf;
        @(posedge clk);
        repeat (5) @(posedge clk);

        // read from address x400 (miss)
        ufp_addr <= 32'h400;
        ufp_rmask <= 4'hf;
        ufp_wmask <= '0;
        ufp_wdata <= '0;
        @(posedge clk);
        ufp_addr <= 32'h0;
        ufp_rmask <= 4'h0;
        @(posedge ufp_resp);

        // read from address x600 (miss)
        ufp_addr <= 32'h600;
        ufp_rmask <= 4'hf;
        ufp_wmask <= '0;
        ufp_wdata <= '0;
        @(posedge clk);
        ufp_addr <= 32'h0;
        ufp_rmask <= 4'h0;
        @(posedge ufp_resp);

        // read from address x800 (miss)
        ufp_addr <= 32'h800;
        ufp_rmask <= 4'hf;
        ufp_wmask <= '0;
        ufp_wdata <= '0;
        @(posedge clk);
        ufp_addr <= 32'h0;
        ufp_rmask <= 4'h0;
        @(posedge ufp_resp);
        repeat (10) @(posedge clk)

        ufp_addr <= 32'h400;
        ufp_rmask <= 4'hf;
        @(posedge clk);
        ufp_addr <= 32'h600;
        ufp_rmask <= 4'hf;
        @(posedge clk);
        ufp_addr <= 32'h000;
        ufp_rmask <= 4'hf;
        @(posedge clk);
        ufp_rmask <= '0;
        repeat (10) @(posedge clk);
        
    endtask : read_conflict

    

    task write_consec();
        read_conflict();
        repeat(5) @(posedge clk);
        ufp_addr <= 32'h0;
        ufp_rmask <= 4'h0;
        ufp_wmask <= 4'h0;
        ufp_wdata <= 32'h0;
        @(posedge clk); 
        ufp_wmask <= 4'hf; // write 1
        ufp_addr <= 32'h400;
        ufp_wdata <= 32'hbbbb;
        @(posedge clk); 
        ufp_addr <= 32'h600; // write 2
        repeat (2) @(posedge clk) 
        ufp_addr <= 32'h000; // write 3
        @(posedge clk);
        ufp_wmask <= '0;
        repeat (20) @(posedge clk);

    endtask : write_consec

    task read_4();
        // read from address x20 (miss)
        ufp_addr <= 32'h04;
        ufp_rmask <= 4'hf;
        ufp_wmask <= '0;
        ufp_wdata <= '0;
        @(posedge clk);
        ufp_addr <= 32'h0;
        ufp_rmask <= 4'h0;
        @(posedge ufp_resp);

        // read from address x20 (hit)
        ufp_addr <= 32'h04;
        ufp_rmask <= 4'hf;
        ufp_wmask <= '0;
        ufp_wdata <= '0;
        @(posedge clk);

        ufp_addr <= 32'h0;
        ufp_rmask <= 4'h0;
        repeat (10) @(posedge clk);

        // read from address x0 (miss)
        ufp_addr <= 32'h0;
        ufp_rmask <= 4'hf;
        @(posedge clk);
        ufp_addr <= 32'h0;
        ufp_rmask <= 4'h0;
        @(posedge ufp_resp);
        repeat (5) @(posedge clk);

        // read from address x0 (hit)
        ufp_addr <= 32'h0;
        ufp_rmask <= 4'hf;
        @(posedge clk);
        repeat (5) @(posedge clk);
        
    endtask : read_4

    task read_x();
        ufp_addr <= 32'h00000200;
        ufp_rmask <= 4'hf;
        ufp_wmask <= '0;
        ufp_wdata <= '0;
        @ (posedge clk);

        ufp_addr <= 'x;
        ufp_rmask <= '0;
        ufp_wmask <= '0;
        @ (posedge ufp_resp)
        @ (posedge clk)

        ufp_addr <= 32'h00000200;
        ufp_rmask <= 4'b1000;
        ufp_wmask <= '0;
        ufp_wdata <= '0;
        @ (posedge clk);

        ufp_addr <= 'x;
        ufp_rmask <= '0;
        ufp_wmask <= '0;
        repeat (5) @ (posedge clk)

        ufp_addr <= 32'h00000000;
        ufp_rmask <= 4'hf;
        ufp_wmask <= '0;
        ufp_wdata <= '0;
        @ (posedge clk);
        
        ufp_addr <= 'x;
        ufp_rmask <= '0;
        ufp_wmask <= '0;
        @ (posedge ufp_resp)
        @ (posedge clk)

        ufp_addr <= 32'h0000000;
        ufp_rmask <= 4'b1000;
        ufp_wmask <= '0;
        ufp_wdata <= '0;
        @ (posedge clk);

        ufp_addr <= 'x;
        ufp_rmask <= '0;
        ufp_wmask <= '0;
        repeat (20) @ (posedge clk);
    endtask : read_x

    task simple_read ();
        ufp_addr <= 32'h00000020;
        ufp_rmask <= 4'hf;
        ufp_wmask <= '0;
        ufp_wdata <= '0;
        @ (posedge clk);

        ufp_addr <= 'x;
        ufp_rmask <= '0;
        ufp_wmask <= '0;
        @ (posedge ufp_resp)
        @ (posedge clk)

        ufp_addr <= 32'h00000020;
        ufp_rmask <= 4'b1000;
        ufp_wmask <= '0;
        ufp_wdata <= '0;
        @ (posedge clk);

        ufp_addr <= 'x;
        ufp_rmask <= '0;
        ufp_wmask <= '0;
        repeat (5) @ (posedge clk)

        ufp_addr <= 32'h00000000;
        ufp_rmask <= 4'hf;
        ufp_wmask <= '0;
        ufp_wdata <= '0;
        @ (posedge clk);
        
        ufp_addr <= 'x;
        ufp_rmask <= '0;
        ufp_wmask <= '0;
        @ (posedge ufp_resp)
        @ (posedge clk)

        ufp_addr <= 32'h0000000;
        ufp_rmask <= 4'b1000;
        ufp_wmask <= '0;
        ufp_wdata <= '0;
        @ (posedge clk);

        ufp_addr <= 'x;
        ufp_rmask <= '0;
        ufp_wmask <= '0;
        repeat (20) @ (posedge clk);


    endtask : simple_read

    task write_read ();
        ufp_addr <= '0;
        ufp_rmask <= '1;
        ufp_wmask <= '0;
        ufp_wdata <= '0;
        @(posedge clk)
        ufp_addr <= 'x;
        ufp_rmask <= '0;
        ufp_wmask <= '0;
        ufp_wdata <= 'x;
        @(posedge ufp_resp)
        @(posedge clk)
        
        ufp_addr <= '0;
        ufp_rmask <= '0;
        ufp_wmask <= '1;
        ufp_wdata <= '1;
        @(posedge clk)
        
        ufp_addr <= '0;
        ufp_rmask <= '0;
        ufp_wmask <= '1;
        ufp_wdata <= 32'hCCCC;
        @(posedge clk)
        @(posedge clk)

        ufp_addr <= '0;
        ufp_rmask <= '0;
        ufp_wmask <= 4'b1000;
        ufp_wdata <= '1;
        @(posedge clk)
        
        ufp_addr <= 'x;
        ufp_rmask <= '0;
        ufp_wmask <= '0;
        ufp_wdata <= 'x;

        repeat (20) @(posedge clk);
        
    endtask

    task write_read_mask();
        ufp_addr <= 32'h1c;
        ufp_rmask <= 4'b1000;
        ufp_wmask <= '0;
        ufp_wdata <= '0;
        @(posedge clk)
        ufp_addr <= 'x;
        ufp_rmask <= '0;
        ufp_wmask <= '0;
        ufp_wdata <= 'x;
        @(posedge ufp_resp)
        @(posedge clk)
        
        ufp_addr <= 32'h1c;
        ufp_rmask <= '0;
        ufp_wmask <= 4'b0100;
        ufp_wdata <= '1;
        @(posedge clk)
        
        ufp_addr <= 32'h1c;
        ufp_rmask <= '0;
        ufp_wmask <= 4'b0010;
        ufp_wdata <= 32'hCCCC;
        @(posedge clk)
        @(posedge clk)

        ufp_addr <= 32'h1c;
        ufp_rmask <= 4'b0110;
        ufp_wmask <= '0;
        ufp_wdata <= '0;
        @(posedge clk)
        
        ufp_addr <= 'x;
        ufp_rmask <= '0;
        ufp_wmask <= '0;
        ufp_wdata <= 'x;

        repeat (20) @(posedge clk);
    endtask

    task write_read_dirty();
        ufp_addr <= '0;
        ufp_rmask <= '1;
        ufp_wmask <= '0;
        ufp_wdata <= '0;
        @(posedge clk)
        ufp_addr <= 'x;
        ufp_rmask <= '0;
        ufp_wmask <= '0;
        ufp_wdata <= 'x;
        @(posedge ufp_resp)
        @(posedge clk)
        
        ufp_addr <= '0;
        ufp_rmask <= '0;
        ufp_wmask <= '1;
        ufp_wdata <= '1;
        @(posedge clk)

        ufp_addr <= '0;
        ufp_rmask <= '1;
        ufp_wmask <= '0;
        ufp_wdata <= '0;
        @(posedge clk)

        ufp_addr <= 'x;
        ufp_rmask <= '0;
        ufp_wmask <= '0;
        ufp_wdata <= 'x;
        repeat (20) @(posedge clk);
        
    endtask

    task dirty_eviction ();
        ufp_addr <= 32'h0000;
        ufp_rmask <= 4'b1111;
        ufp_wmask <= '0;
        ufp_wdata <= '0;
        @(posedge clk)
        ufp_addr <= 'x;
        ufp_rmask <= '0;
        ufp_wmask <= '0;
        ufp_wdata <= 'x;
        @(posedge ufp_resp)
        
        ufp_addr <= 32'h0000;
        ufp_rmask <= '0;
        ufp_wmask <= 4'b1111;
        ufp_wdata <= 32'hbabe;
        @(posedge clk)
        
        ufp_addr <= 32'h200;
        ufp_rmask <= 4'b1111;
        ufp_wmask <= '0;
        ufp_wdata <= '0;
        @(posedge clk)
        ufp_addr <= 'x;
        ufp_rmask <= '0;
        ufp_wmask <= '0;
        ufp_wdata <= 'x;
        @(posedge ufp_resp)

        ufp_addr <= 32'h400;
        ufp_rmask <= 4'b1111;
        ufp_wmask <= '0;
        ufp_wdata <= '0;
        @(posedge clk)
        ufp_addr <= 'x;
        ufp_rmask <= '0;
        ufp_wmask <= '0;
        ufp_wdata <= 'x;
        @(posedge ufp_resp)
        
        ufp_addr <= 32'h600;
        ufp_rmask <= 4'b1111;
        ufp_wmask <= '0;
        ufp_wdata <= '0;
        @(posedge clk)
        ufp_addr <= 'x;
        ufp_rmask <= '0;
        ufp_wmask <= '0;
        ufp_wdata <= 'x;
        @(posedge ufp_resp)

        ufp_addr <= 32'h800;
        ufp_rmask <= 4'b1111;
        ufp_wmask <= '0;
        ufp_wdata <= '0;
        @(posedge clk)
        ufp_addr <= 'x;
        ufp_rmask <= '0;
        ufp_wmask <= '0;
        ufp_wdata <= 'x;
        @(posedge ufp_resp)
        @(posedge clk)

        ufp_addr <= 32'h800;
        ufp_rmask <= 4'b1111;
        ufp_wmask <= '0;
        ufp_wdata <= '0;
        @(posedge clk)
        ufp_addr <= 'x;
        ufp_rmask <= '0;
        ufp_wmask <= '0;
        ufp_wdata <= 'x;
        @(posedge clk)

        ufp_addr <= 32'h0000;
        ufp_rmask <= 4'b1111;
        ufp_wmask <= '0;
        ufp_wdata <= '0;
        @(posedge clk)
        ufp_addr <= 'x;
        ufp_rmask <= '0;
        ufp_wmask <= '0;
        ufp_wdata <= 'x;
        @(posedge ufp_resp)
        @(posedge clk)

        repeat (20) @(posedge clk);
    endtask

    task read (input logic [31:0] addr, input logic[3:0] rmask); 
        ufp_wmask <= '0;
        ufp_wdata <= '0;

        ufp_addr <= addr;
        ufp_rmask <= rmask;
        @(posedge clk)

        ufp_addr <= 'x;
        ufp_rmask <= '0;
        forever begin
            if (ufp_resp) break;
            @(posedge clk);
        end
    endtask

    task write (input logic [31:0] addr, input logic[3:0] wmask, input logic[31:0] wdata);
        ufp_rmask <= '0;

        ufp_addr <= addr;
        ufp_wmask <= wmask;
        ufp_wdata <= wdata;
        @(posedge clk)

        ufp_addr <= 'x;
        ufp_wmask <= '0;
        ufp_wdata <= 'x;
        forever begin
            @(posedge clk);
            if (ufp_resp) break;
            @(posedge clk);
        end
    endtask

   

    task multiple_set_eviction ();
        // read set 0 miss
        read(32'h0000, 4'b1111);
        
        // write set 0 hit
        write(32'h0000, 4'b1111, 32'hbeef);
        
        // read set 0 diff tag to fill ways
        read(32'h0200, 4'b1111);
        read(32'h0400, 4'b1111);
        read(32'h0600, 4'b1111);

        
        // read next set 1 miss
        read(32'h0020, 4'b1111);
        // write set 1 hit
        write(32'h0020, 4'b1111, 32'hb00b);
        // read diff tag
        read(32'h0220, 4'b1111);
        read(32'h0420, 4'b1111);
        read(32'h0620, 4'b1111);

        // read next set 2 miss
        read(32'h0040, 4'b1111);
        // write set 2 hit
        write(32'h0040, 4'b1111, 32'hffff);
        // read diff tag
        read(32'h0240, 4'b1111);
        read(32'h0440, 4'b1111);
        read(32'h0640, 4'b1111);
        
        // read next set 3 miss
        read(32'h0060, 4'b1111);
        // write set 3 hit
        write(32'h0060, 4'b1111, 32'hd00d);
        // read diff tag
        read(32'h0260, 4'b1111);
        read(32'h0460, 4'b1111);
        read(32'h0660, 4'b1111);
        
        // read next set 4 miss 
        read(32'h0080, 4'b1111);
        // write set 4 hit
        // write(32'h0080, 4'b1111, 32'hc00b);
        ufp_rmask <= '0;

        ufp_addr <= 32'h80;
        ufp_wmask <= 4'b1111;
        ufp_wdata <= 32'hc00b;
        @(posedge clk);

        // ufp_addr <= 'x;
        // ufp_wmask <= '0;
        // ufp_wdata <= 'x;
        // forever begin
        //     if (ufp_resp) break;
        //     @(posedge clk);
        // end

        // read diff tag
        read(32'h0280, 4'b1111);
        ufp_rmask <= '0;

        ufp_addr <= 32'h0;
        ufp_wmask <= 4'b0;
        ufp_wdata <= 32'h0;
        @(posedge ufp_resp)
        read(32'h0480, 4'b1111);
        read(32'h0680, 4'b1111);

        // read set 0 but diff tag for eviction
        read(32'h0800, 4'b1111);
        read(32'h0820, 4'b1111);

        // read set 1 again hit
        read(32'h0000, 4'b1111);

        // read set 2 again hit 
        read(32'h0020, 4'b1111);
    endtask

    task write_stripe();
        ufp_addr <= 32'h20; // read miss x0000
        ufp_rmask <= 4'hf;
        ufp_wmask <= 4'h0;
        ufp_wdata <= 'x;
        @(posedge clk)
        ufp_addr <= 'x;
        ufp_rmask <= 'x;
        ufp_wmask <= 'x;
        @(posedge ufp_resp)

        ufp_addr <= 32'h220; // write miss 0x200
        ufp_wmask <= 4'hf;
        ufp_rmask <= '0;
        ufp_wdata <= 32'hffffffff;
        @(posedge clk);
        ufp_addr <= 32'h0;
        ufp_wmask <= 'x;
        ufp_wdata <= 'x;
        @(posedge clk);
        @(ufp_resp)

        ufp_addr <= 32'h228; // write hit 0x208
        ufp_wmask <= 4'hf;
        ufp_rmask <= '0;
        ufp_wdata <= 32'hbeefbeef;
        @(posedge clk);
        
        ufp_addr <= 'x; // stall
        ufp_wmask <= 'x;
        ufp_rmask <= 'x;
        ufp_wdata <= 'x;
        @(posedge clk);
        ufp_rmask <= '0;
        ufp_addr <= 32'heeebbbcc; //write miss
        ufp_wmask <= 4'hf;
        ufp_wdata <= 32'hcccccccc;
        @(posedge clk);
        ufp_addr <= 'x; // stall
        ufp_wmask <= 'x;
        ufp_rmask <= 'x;
        ufp_wdata <= 'x;
        @(posedge ufp_resp);

        ufp_addr <= 32'h224;    //write hit
        ufp_wdata <= 32'hedcba;
        ufp_wmask <= '1;
        ufp_rmask <= '0;

        @(posedge clk);
        ufp_addr <= 'x; // stall
        ufp_wmask <= 'x;
        ufp_rmask <= 'x;
        ufp_wdata <= 'x;
        @(posedge clk);


        ufp_addr <= 32'h420; // write miss 0x400
        ufp_wmask <= 4'b0011;
        ufp_rmask <= '0;
        ufp_wdata <= 32'hffffffff;
        @(posedge clk) // stall
        
        ufp_addr <= 32'h0;
        ufp_wmask <= 'x;
        ufp_wdata <= 'x;
        @(posedge clk);
        @(posedge ufp_resp)

        ufp_addr <= 32'h0020;   //write hit 0x001c
        ufp_wmask <= 4'b1100;
        ufp_wdata <= 32'hAAAAAAAA;
        @(posedge clk)

        ufp_addr <= 'x; // stall
        ufp_wmask <= 'x;
        ufp_rmask <= 'x;
        ufp_wdata <= 'x;
        @(posedge clk);
        ufp_addr <= 32'h620; // write miss 
        ufp_wmask <= 4'hf;
        ufp_rmask <= '0;
        ufp_wdata <= 32'hffffffff;
        @(posedge clk);
        ufp_addr <= 32'h0;
        ufp_wmask <= 4'h0;
        ufp_wdata <= 'x;
        @(posedge clk);
        @(posedge ufp_resp)

        repeat (20) @(posedge clk);
        
        ufp_addr <= 32'h0228;
        ufp_rmask <= 4'hf;
        @(posedge clk)
        ufp_addr <= 32'h420;
        @(posedge clk)
        ufp_addr <= 32'h0020;
        @(posedge clk)
        ufp_addr <= 32'heeebbbcc;
        @(posedge ufp_resp)
        ufp_addr <= 32'h620;
        ufp_rmask <= 4'hf;
        @(posedge clk);
        ufp_addr <= 32'h000;
        ufp_rmask <= '0;

        
        repeat (20) @(posedge clk);
    endtask

    task dirty_eviction_overlap();
        ufp_addr <= 32'h20; // read miss x0000
        ufp_rmask <= 4'hf;
        ufp_wmask <= 4'h0;
        ufp_wdata <= 'x;
        @(posedge clk)
        ufp_addr <= 'x;
        ufp_rmask <= 'x;
        ufp_wmask <= 'x;
        @(posedge ufp_resp)

        ufp_addr <= 32'h220; // write miss 0x200
        ufp_wmask <= 4'hf;
        ufp_rmask <= '0;
        ufp_wdata <= 32'hffffffff;
        @(posedge clk);
        ufp_addr <= 32'h0;
        ufp_wmask <= 'x;
        ufp_wdata <= 'x;
        @(posedge clk);
        @(ufp_resp)

        ufp_addr <= 32'h228; // write hit 0x208
        ufp_wmask <= 4'hf;
        ufp_rmask <= '0;
        ufp_wdata <= 32'hbeefbeef;
        @(posedge clk);
        
        ufp_addr <= 'x; // stall
        ufp_wmask <= 'x;
        ufp_rmask <= 'x;
        ufp_wdata <= 'x;
        @(posedge clk);
        ufp_rmask <= '0;
        ufp_addr <= 32'heeebbbcc; //write miss
        ufp_wmask <= 4'hf;
        ufp_wdata <= 32'hcccccccc;
        @(posedge clk);
        ufp_addr <= 'x; // stall
        ufp_wmask <= 'x;
        ufp_rmask <= 'x;
        ufp_wdata <= 'x;
        @(posedge ufp_resp);

        ufp_addr <= 32'h224;    //write hit
        ufp_wdata <= 32'hedcba;
        ufp_wmask <= '1;
        ufp_rmask <= '0;

        @(posedge clk);
        ufp_addr <= 'x; // stall
        ufp_wmask <= 'x;
        ufp_rmask <= 'x;
        ufp_wdata <= 'x;
        @(posedge clk);


        ufp_addr <= 32'h420; // write miss 0x400
        ufp_wmask <= 4'b0011;
        ufp_rmask <= '0;
        ufp_wdata <= 32'hffffffff;
        @(posedge clk) // stall
        
        ufp_addr <= 32'h0;
        ufp_wmask <= 'x;
        ufp_wdata <= 'x;
        @(posedge clk);
        @(posedge ufp_resp)

        ufp_addr <= 32'h0020;   //write hit 0x001c
        ufp_wmask <= 4'b1100;
        ufp_wdata <= 32'hAAAAAAAA;
        @(posedge clk)

        ufp_addr <= 'x; // stall
        ufp_wmask <= 'x;
        ufp_rmask <= 'x;
        ufp_wdata <= 'x;
        @(posedge clk);
        ufp_addr <= 32'h620; // write miss 
        ufp_wmask <= 4'hf;
        ufp_rmask <= '0;
        ufp_wdata <= 32'hffffffff;
        @(posedge clk);
        ufp_addr <= 32'h0;
        ufp_wmask <= 4'h0;
        ufp_wdata <= 'x;
        @(posedge clk);
        @(posedge ufp_resp)

        ufp_addr <= 32'h820;
        ufp_rmask <= 4'hf;
        ufp_wmask <= 4'h0;
        ufp_wdata <= 'x;
        @(posedge clk)
        ufp_addr <= 32'h0;
        ufp_rmask <= 4'h0;

        @(posedge ufp_resp);
        repeat (20) @(posedge clk);
        
        ufp_addr <= 32'h0228;
        ufp_rmask <= 4'hf;
        @(posedge clk)
        ufp_addr <= 32'h420;
        @(posedge clk)
        ufp_rmask <= 4'h0;
        @(posedge ufp_resp);
        ufp_addr <= 32'h0020;
        ufp_rmask <= 4'hf;
        @(posedge ufp_resp)
        ufp_addr <= 32'heeebbbcc;
        @(posedge ufp_resp)
        ufp_addr <= 32'h620;
        ufp_rmask <= 4'hf;
        @(posedge ufp_resp)
        ufp_addr <= 32'h820;
        @(posedge clk);
        ufp_addr <= 32'h000;
        ufp_rmask <= '0;

        
        repeat (25) @(posedge clk);
    endtask


    //---------------------------------------------------------------------------------
    // TODO: Main initial block that calls your tasks, then calls $finish
    //---------------------------------------------------------------------------------
    
    logic [31:0] addr;
    logic [3:0] mask;
    logic [31:0] wdata;
    
    initial begin
        reset();

        // read(32'h0000, 4'b1010);
        // read(32'h0200, 4'b1111);
        // read(32'h0400, 4'b1111);
        // read(32'h0600, 4'b1111);

        // write(32'h0020, 4'b0011, 32'h000000ab); // write miss
        // write(32'h0200, 4'b1111, 32'hd00dd00d); // write hit
        // write(32'h0400, 4'b1111, 32'h99999999);
        // read(32'h200, 4'b1111);
        // write(32'h0600, 4'b1111, 32'h11111111);
        // write(32'h0220, 4'b1111, 32'hcafe0000); // write miss
        // write(32'h0400, 4'b1100, 32'heeeeeeee); // write hit
        // write(32'h0240, 4'b1111, 32'hbeebbeeb); // write miss
        
        // write(32'h0024, 4'b0001, 32'h0000000f); // write hit
        // write(32'h0800, 4'b1101, 32'hffffffff); //write miss

        // read(32'h0020, 4'b1111);
        // read(32'h0024, 4'b1111);
        // read(32'h0200, 4'b1111);
        // read(32'h0220, 4'b1111);
        // read(32'h0240, 4'b1111);
        // read(32'h0400, 4'b1111);
        // read(32'h0800, 4'b1111);
        // read(32'h0600, 4'b1111);


        // multiple_set_eviction();
        // repeat (5) @(posedge clk)

        dirty_eviction_overlap();

        // multiple_set_eviction();

        $finish;
    end

    always @(posedge clk) begin
        if (timeout == 0) begin
            $error("TB Error: Timed out");
            $fatal;
        end
        timeout <= timeout - 1;
    end

endmodule : top_tb
