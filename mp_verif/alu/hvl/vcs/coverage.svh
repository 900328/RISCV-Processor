covergroup cg with function sample(
    bit [31:0]  a,
    bit [31:0]  b,
    bit [2:0]   op,
    bit [4:0]   b_shift_bits
);

    // This generates a bunch of ranges across possible values of a,
    // and ensures at least one value in each range is covered.
    coverpoint a;

    // Same for b.
    coverpoint b;

    // Checks that your testbench exercises all valid operations.
    coverpoint op {
        bins range[] = {[0:6]};
    }

    // This is called a "cross cover" -- it checks that for both
    // left and right shifts, you test all possible values of b
    // (there are only 32 possibilities for the shift value).

    all_shifts: cross b_shift_bits, op {
        ignore_bins other_ops = binsof(op) intersect {[0:4]};
    }

    // More complicated coverage could be written, but we'll leave
    // that for part 3.

endgroup : cg
