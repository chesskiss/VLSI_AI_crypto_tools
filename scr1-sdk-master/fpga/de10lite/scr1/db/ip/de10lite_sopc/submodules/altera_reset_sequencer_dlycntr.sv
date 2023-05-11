// (C) 2001-2020 Intel Corporation. All rights reserved.
// Your use of Intel Corporation's design tools, logic functions and other 
// software and tools, and its AMPP partner logic functions, and any output 
// files from any of the foregoing (including device programming or simulation 
// files), and any associated documentation or information are expressly subject 
// to the terms and conditions of the Intel Program License Subscription 
// Agreement, Intel FPGA IP License Agreement, or other applicable 
// license agreement, including, without limitation, that your use is for the 
// sole purpose of programming logic devices manufactured by Intel and sold by 
// Intel or its authorized distributors.  Please refer to the applicable 
// agreement for further details.


// ---------------------------------------------------------------
// Module : Reset sequencer delay counter
// - This blocks counts until saturation value DELAY when cntr_en is high.
// - When cntr_en is low, the counter is reset and back to initial state.
// - qual - this is a signal used to saturate this counter immediately.
//        - this is expected to be used only when DELAY is not used.
// - sw_ovr/sw_qual - this is a software overwrite that is used to 
//                  - control this counter directly
// ----------------------------------------------------------------
`timescale 1 ns / 1 ns

module altera_reset_sequencer_dlycntr #(
    parameter USE_QUAL = 0,
    parameter DELAY = 8
) (
    input       clk,
    input       reset,
    input       cntr_en,
    input       qual,
    input       sw_ovr,
    input       sw_qual,
    output reg  count_done
);

logic [31:0] counter;
logic       count_reached;

assign count_reached = (counter == DELAY);
assign count_done    = count_reached & cntr_en;

always @(posedge clk or posedge reset) begin

    if (reset)
        counter <= '0;
    else if (!cntr_en)
        counter <= '0;
    else if (!count_reached) begin
        counter <= sw_ovr ? ( sw_qual? DELAY : '0 ) : 
                            USE_QUAL? ( qual ? DELAY : '0) : 
                                      counter + 1'b1;
    end
end

endmodule
