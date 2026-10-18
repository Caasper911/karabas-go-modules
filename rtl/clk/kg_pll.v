`timescale 1ns / 1ps
`default_nettype wire

/*
 kg_pll.v

 Spartan-6 PLL_BASE with the structure of a coregen clocking wizard PLL (CLKFBOUT through a BUFG
 back to CLKFBIN, SYSTEM_SYNCHRONOUS), so a core moves from its ipcore_dir/pll.v to this one with
 the same clocks: copy DIVCLK_DIVIDE, CLKFBOUT_MULT and the CLKOUTn_DIVIDE / _PHASE of the
 generated file.
 IBUFG = 1 puts an IBUFG on clk_in (clk_in comes straight from a pin), 0 takes it from the fabric
 or another clock buffer. BUFG_MASK bit n puts a BUFG on clk_out[n]; a 0 bit gives the raw PLL
 output (for a BUFPLL, or an unused output).
*/

module kg_pll #(
	parameter CLKIN_PERIOD = 20.0, // ns
	parameter DIVCLK_DIVIDE = 1,
	parameter CLKFBOUT_MULT = 10,
	parameter CLKOUT0_DIVIDE = 1,
	parameter CLKOUT1_DIVIDE = 1,
	parameter CLKOUT2_DIVIDE = 1,
	parameter CLKOUT3_DIVIDE = 1,
	parameter CLKOUT4_DIVIDE = 1,
	parameter CLKOUT5_DIVIDE = 1,
	parameter CLKOUT0_PHASE = 0.0,
	parameter CLKOUT1_PHASE = 0.0,
	parameter CLKOUT2_PHASE = 0.0,
	parameter CLKOUT3_PHASE = 0.0,
	parameter CLKOUT4_PHASE = 0.0,
	parameter CLKOUT5_PHASE = 0.0,
	parameter BANDWIDTH = "OPTIMIZED",
	parameter IBUFG = 1,
	parameter [5:0] BUFG_MASK = 6'b111111
) (
	input wire clk_in,
	input wire rst,
	output wire [5:0] clk_out,
	output wire locked
);

wire clkin;
wire clkfbout, clkfbout_buf;
wire [5:0] clkout;

generate
	if (IBUFG) begin : kg_pll_ibufg
		IBUFG clkin_buf (.I(clk_in), .O(clkin));
	end
	else begin : kg_pll_noibufg
		assign clkin = clk_in;
	end
endgenerate

PLL_BASE #(
	.BANDWIDTH(BANDWIDTH),
	.CLK_FEEDBACK("CLKFBOUT"),
	.COMPENSATION("SYSTEM_SYNCHRONOUS"),
	.DIVCLK_DIVIDE(DIVCLK_DIVIDE),
	.CLKFBOUT_MULT(CLKFBOUT_MULT),
	.CLKFBOUT_PHASE(0.000),
	.CLKOUT0_DIVIDE(CLKOUT0_DIVIDE), .CLKOUT0_PHASE(CLKOUT0_PHASE), .CLKOUT0_DUTY_CYCLE(0.500),
	.CLKOUT1_DIVIDE(CLKOUT1_DIVIDE), .CLKOUT1_PHASE(CLKOUT1_PHASE), .CLKOUT1_DUTY_CYCLE(0.500),
	.CLKOUT2_DIVIDE(CLKOUT2_DIVIDE), .CLKOUT2_PHASE(CLKOUT2_PHASE), .CLKOUT2_DUTY_CYCLE(0.500),
	.CLKOUT3_DIVIDE(CLKOUT3_DIVIDE), .CLKOUT3_PHASE(CLKOUT3_PHASE), .CLKOUT3_DUTY_CYCLE(0.500),
	.CLKOUT4_DIVIDE(CLKOUT4_DIVIDE), .CLKOUT4_PHASE(CLKOUT4_PHASE), .CLKOUT4_DUTY_CYCLE(0.500),
	.CLKOUT5_DIVIDE(CLKOUT5_DIVIDE), .CLKOUT5_PHASE(CLKOUT5_PHASE), .CLKOUT5_DUTY_CYCLE(0.500),
	.CLKIN_PERIOD(CLKIN_PERIOD),
	.REF_JITTER(0.010)
) pll_base_inst (
	.CLKFBOUT(clkfbout),
	.CLKOUT0(clkout[0]),
	.CLKOUT1(clkout[1]),
	.CLKOUT2(clkout[2]),
	.CLKOUT3(clkout[3]),
	.CLKOUT4(clkout[4]),
	.CLKOUT5(clkout[5]),
	.LOCKED(locked),
	.RST(rst),
	.CLKFBIN(clkfbout_buf),
	.CLKIN(clkin)
);

BUFG clkf_buf (.I(clkfbout), .O(clkfbout_buf));

genvar i;
generate
	for (i = 0; i < 6; i = i + 1) begin : kg_pll_out
		if (BUFG_MASK[i]) begin : kg_pll_bufg
			BUFG clkout_buf (.I(clkout[i]), .O(clk_out[i]));
		end
		else begin : kg_pll_raw
			assign clk_out[i] = clkout[i];
		end
	end
endgenerate

endmodule
