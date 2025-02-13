module loop(
    input   logic           clk,
    input   logic           rst,
    output  logic           ack
);

            logic           req;
            logic   [3:0]   req_key;

    foo foo(.*);
    bar bar(.*);

endmodule
