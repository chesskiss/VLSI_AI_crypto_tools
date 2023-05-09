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


// ---------------------------
// Main module that instantiates per-signal deglitcher
// ---------------------------
`timescale 1 ns / 1 ns

module altera_reset_sequencer_deglitch_main #(
    parameter MAX_OUTPUTS = 10,
    parameter ENABLE     = 10'h1,
    parameter DEGLITCH_CNT0 = 2,
    parameter DEGLITCH_CNT1 = 3,
    parameter DEGLITCH_CNT2 = 4,
    parameter DEGLITCH_CNT3 = 5,
    parameter DEGLITCH_CNT4 = 6,
    parameter DEGLITCH_CNT5 = 7,
    parameter DEGLITCH_CNT6 = 8,
    parameter DEGLITCH_CNT7 = 9,
    parameter DEGLITCH_CNT8 = 10,
    parameter DEGLITCH_CNT9 = 11
) (
    // Clock and resets
    input   clk,
    input   reset,
    input   deg_clr,

    // Deglitch signals
    input       [MAX_OUTPUTS-1:0]    sig_in,
    output reg  [MAX_OUTPUTS-1:0]    sig_out
);

    // -------------------------------------
    // Internal logic/wire declaration
    // -------------------------------------
    logic [MAX_OUTPUTS-1:0] int_sig_out;
   
    // ------------------------------------
    // Output logic qualification with ENABLE
    // -----------------------------------
    genvar k;
    generate begin : en_loop
        for (k = 0; k < MAX_OUTPUTS; k = k+1) begin : sig_map
            assign sig_out[k] = (ENABLE[0] == 1)? int_sig_out[k] : sig_in[k];
        end
    end
    endgenerate

    // ---------------------------------------
    // Deglitch logic instantiations
    // --------------------------------------
    generate if (DEGLITCH_CNT0 > 0) begin : gen_deg0
    altera_reset_sequencer_deglitch #(
        .RESET_VALUE        (1'b0),
        .DEGLITCH_CYCLES    (DEGLITCH_CNT0)
    ) deg0 (
        .clk     (clk),
        .reset   (reset),
        .cnt_clr(deg_clr),
        .sig_in  (sig_in[0]),
        .sig_out (int_sig_out[0])
    );
    end else begin
        assign int_sig_out[0] = sig_in[0];
    end endgenerate

    generate if (DEGLITCH_CNT1 > 0) begin : gen_deg1
    altera_reset_sequencer_deglitch #(
        .RESET_VALUE        (1'b0),
        .DEGLITCH_CYCLES    (DEGLITCH_CNT1)
    ) deg1 (
        .clk     (clk),
        .reset   (reset),
        .cnt_clr(deg_clr),
        .sig_in  (sig_in[1]),
        .sig_out (int_sig_out[1])
    );
    end else begin
        assign int_sig_out[1] = sig_in[1];
    end endgenerate

    generate if (DEGLITCH_CNT2 > 0) begin : gen_deg2
    altera_reset_sequencer_deglitch #(
        .RESET_VALUE        (1'b0),
        .DEGLITCH_CYCLES    (DEGLITCH_CNT2)
    ) deg2 (
        .clk     (clk),
        .reset   (reset),
        .cnt_clr(deg_clr),
        .sig_in  (sig_in[2]),
        .sig_out (int_sig_out[2])
    );
    end else begin
        assign int_sig_out[2] = sig_in[2];
    end endgenerate

    generate if (DEGLITCH_CNT3 > 0) begin : gen_deg3
    altera_reset_sequencer_deglitch #(
        .RESET_VALUE        (1'b0),
        .DEGLITCH_CYCLES    (DEGLITCH_CNT3)
    ) deg3 (
        .clk     (clk),
        .reset   (reset),
        .cnt_clr(deg_clr),
        .sig_in  (sig_in[3]),
        .sig_out (int_sig_out[3])
    );
    end else begin
        assign int_sig_out[3] = sig_in[3];
    end endgenerate

    generate if (DEGLITCH_CNT4 > 0) begin : gen_deg4
    altera_reset_sequencer_deglitch #(
        .RESET_VALUE        (1'b0),
        .DEGLITCH_CYCLES    (DEGLITCH_CNT4)
    ) deg4 (
        .clk     (clk),
        .reset   (reset),
        .cnt_clr(deg_clr),
        .sig_in  (sig_in[4]),
        .sig_out (int_sig_out[4])
    );
    end else begin
        assign int_sig_out[4] = sig_in[4];
    end endgenerate

    generate if (DEGLITCH_CNT5 > 0) begin : gen_deg5
    altera_reset_sequencer_deglitch #(
        .RESET_VALUE        (1'b0),
        .DEGLITCH_CYCLES    (DEGLITCH_CNT5)
    ) deg5 (
        .clk     (clk),
        .reset   (reset),
        .cnt_clr(deg_clr),
        .sig_in  (sig_in[5]),
        .sig_out (int_sig_out[5])
    );
    end else begin
        assign int_sig_out[5] = sig_in[5];
    end endgenerate

    generate if (DEGLITCH_CNT6 > 0) begin : gen_deg6
    altera_reset_sequencer_deglitch #(
        .RESET_VALUE        (1'b0),
        .DEGLITCH_CYCLES    (DEGLITCH_CNT6)
    ) deg6 (
        .clk     (clk),
        .reset   (reset),
        .cnt_clr(deg_clr),
        .sig_in  (sig_in[6]),
        .sig_out (int_sig_out[6])
    );
    end else begin
        assign int_sig_out[6] = sig_in[6];
    end endgenerate

    generate if (DEGLITCH_CNT7 > 0) begin : gen_deg7
    altera_reset_sequencer_deglitch #(
        .RESET_VALUE        (1'b0),
        .DEGLITCH_CYCLES    (DEGLITCH_CNT7)
    ) deg7 (
        .clk     (clk),
        .reset   (reset),
        .cnt_clr(deg_clr),
        .sig_in  (sig_in[7]),
        .sig_out (int_sig_out[7])
    );
    end else begin
        assign int_sig_out[7] = sig_in[7];
    end endgenerate

    generate if (DEGLITCH_CNT8 > 0) begin : gen_deg8
    altera_reset_sequencer_deglitch #(
        .RESET_VALUE        (1'b0),
        .DEGLITCH_CYCLES    (DEGLITCH_CNT8)
    ) deg8 (
        .clk     (clk),
        .reset   (reset),
        .cnt_clr(deg_clr),
        .sig_in  (sig_in[8]),
        .sig_out (int_sig_out[8])
    );
    end else begin
        assign int_sig_out[8] = sig_in[8];
    end endgenerate

    generate if (DEGLITCH_CNT9 > 0) begin : gen_deg9
    altera_reset_sequencer_deglitch #(
        .RESET_VALUE        (1'b0),
        .DEGLITCH_CYCLES    (DEGLITCH_CNT9)
    ) deg9 (
        .clk     (clk),
        .reset   (reset),
        .cnt_clr(deg_clr),
        .sig_in  (sig_in[9]),
        .sig_out (int_sig_out[9])
    );
    end else begin
        assign int_sig_out[9] = sig_in[9];
    end endgenerate

endmodule
