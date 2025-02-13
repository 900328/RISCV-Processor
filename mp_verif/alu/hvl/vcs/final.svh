final begin
    if (cg_inst.get_coverage != 100.0) begin
        $error("Coverage: Not 100%%");
        $fatal;
    end else begin
        $display("Coverage: 100%%");
    end
end
