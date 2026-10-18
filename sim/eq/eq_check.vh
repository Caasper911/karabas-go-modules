// The comparison of the equivalence testbenches: old (the VHDL module) against new (its kg_*
// port), counts in checks / errors. An old output that is (partly) X has not been set yet in
// the VHDL (no initial value there, 0 on the FPGA) and is not compared.
// automatic: several processes call it at the same time, and iverilog may switch between them
// after the arguments of a static task are set (a call then checked the arguments of another).
integer checks = 0, errors = 0;
task automatic eq_check(input [8*24-1:0] name, input [63:0] old_v, input [63:0] new_v);
	begin
		checks = checks + 1;
		if (^old_v !== 1'bx && old_v !== new_v) begin
			if (errors < 20) $display("%t ERROR: %0s old %h new %h", $time, name, old_v, new_v);
			errors = errors + 1;
		end
	end
endtask
