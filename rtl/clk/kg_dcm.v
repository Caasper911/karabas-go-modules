`timescale 1ns / 1ps
`default_nettype wire

/*
 kg_dcm.v

 Spartan-6 DCM_SP for a CLKFX clock, with the structure of a coregen clocking wizard DCM (CLK0
 through a BUFG back to CLKFB, CLK_FEEDBACK 1X, SYSTEM_SYNCHRONOUS): clk_fx = clk_in *
 CLKFX_MULTIPLY / CLKFX_DIVIDE, clk_fx180 its inverse, clk_0 the deskewed input. Copy the
 parameters of the generated ipcore_dir file (e.g. pllx5.v: 1 / 5, 40 ns).
 IBUFG = 1 puts an IBUFG on clk_in (clk_in comes straight from a pin).
*/

module kg_dcm #(
	parameter CLKIN_PERIOD = 20.0, // ns
	parameter CLKFX_MULTIPLY = 2,
	parameter CLKFX_DIVIDE = 1,
	parameter IBUFG = 0
) (
	input wire clk_in,
	input wire rst,
	output wire clk_fx,
	output wire clk_fx180,
	output wire clk_0,
	output wire locked
);

wire clkin;
wire clk0, clkfx, clkfx180;

generate
	if (IBUFG) begin : kg_dcm_ibufg
		IBUFG clkin_buf (.I(clk_in), .O(clkin));
	end
	else begin : kg_dcm_noibufg
		assign clkin = clk_in;
	end
endgenerate

DCM_SP #(
	.CLKDV_DIVIDE(2.000),
	.CLKFX_DIVIDE(CLKFX_DIVIDE),
	.CLKFX_MULTIPLY(CLKFX_MULTIPLY),
	.CLKIN_DIVIDE_BY_2("FALSE"),
	.CLKIN_PERIOD(CLKIN_PERIOD),
	.CLKOUT_PHASE_SHIFT("NONE"),
	.CLK_FEEDBACK("1X"),
	.DESKEW_ADJUST("SYSTEM_SYNCHRONOUS"),
	.PHASE_SHIFT(0),
	.STARTUP_WAIT("FALSE")
) dcm_sp_inst (
	.CLKIN(clkin),
	.CLKFB(clk_0),
	.CLK0(clk0),
	.CLK90(),
	.CLK180(),
	.CLK270(),
	.CLK2X(),
	.CLK2X180(),
	.CLKFX(clkfx),
	.CLKFX180(clkfx180),
	.CLKDV(),
	.PSCLK(1'b0),
	.PSEN(1'b0),
	.PSINCDEC(1'b0),
	.PSDONE(),
	.LOCKED(locked),
	.STATUS(),
	.RST(rst),
	.DSSEN(1'b0)
);

BUFG clkf_buf (.I(clk0), .O(clk_0));
BUFG clkfx_buf (.I(clkfx), .O(clk_fx));
BUFG clkfx180_buf (.I(clkfx180), .O(clk_fx180));

endmodule
