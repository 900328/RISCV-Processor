package types;

    parameter NUM_CPUS = 4;
    parameter NUM_SETS = 4;

    parameter XLEN = 6;
    parameter CACHELINE_SIZE = 8;

    parameter INDEX_WIDTH = $clog2(NUM_SETS);
    parameter TAG_WIDTH = XLEN - INDEX_WIDTH;

    typedef enum {
        CPU_READ,
        CPU_WRITE,
        CPU_IDLE
    } cpu_state_t;

    typedef enum {
        Bus_Idle,
        Bus_Rd,
        Bus_Rdx, // Read-For-Ownership (Read with intent to Write)
        Bus_Upg,
        Bus_Flush // S to M
     //   Bus_Flush// writeback to mem
         // What else do we need?
    } bus_tx_t;

    typedef enum {
        M, // Modified
        E, // Exclusive
        S, // Shared
        I,  // Invalid
        IM,
        IS,
        IE,
        SM

        // Do we need transient states?
    } cacheline_state_t;

    typedef struct packed {
        cacheline_state_t               state;
        logic [CACHELINE_SIZE-1:0]      data;
        logic [TAG_WIDTH-1:0]           tag;
    } cacheline_t;

    typedef struct packed {
        logic valid;
        logic [$clog2(NUM_CPUS):0] source;
        logic [XLEN-1:0] addr;
        bus_tx_t bus_tx;
    } bus_msg_t;

    typedef struct packed {
        logic valid;
        logic [$clog2(NUM_CPUS):0] destination;
        logic [XLEN-1:0] addr;
        logic [CACHELINE_SIZE-1:0] data;
    } xbar_msg_t;

endpackage




