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


// -------------------------------------------------------
// Reset Sequencer Top
// - Contains block that controls the deassertion sequencer and assertion sequencer based on input resets
// - FSM is to control sequencing when multiple reset assertion (when in middle of asrt/dsrt sequence)
//      - in case of multiple assertion while in sequencing, it will only be evaluated at end of sequences 
//        (either assertion/deassertion)
// Parameter details : as per specified below.
// Sequencer flow:
//  1. Input resets are OR'ed and synchronized using the standard reset controller.
//  2. This synchronized reset is then fed into the sequencer_main FSM.
//  3. The sequencer_main will sequenced between assertion and deassertion sequence. 
//     [And deciding if there are new pending reset, and what to do with it]
//  4. If reset assertion is detected, the main FSM will kick off the assertion sequencer.
//  5. Assertion sequencer does the following:
//     - Depending on the ASRT_DELAYN set for the reset_outN, it will wait for that amount of clock, before asserting the reset_outN.
//     - This repeats until the last reset (reset_out{NUM_OUTPUTS}} is asserted.
//     - Then, it will return a done to the main FSM.
//  6. Upon receiving the done, the main FSM will then move on to the next state, deasertion, 
//     where it kicks of now the de-assertion sequencer. 
//     If MIN_ASRT_TIME is set to non-zero value, it will now wait until that amount of time before starting the de-assertion sequencer.
//  7. The de-assertion sequencer is the same block as the assertion sequencer, with exception that:
//     - It has option to depend on an extra input qualification for reset deassertion (apart from waiting the DSRT_DELAYN amount of clocks)
//     - NOTE: Deassertion sequence will always complete. Hence, if a new reset occurs during this time, 
//             the whole deassertion sequencer will still be completed before being retriggered.
//     - This is enabled in UI through the "USE_DSRT_QUAL[N]" in the UI.
//       (In HDL, it is translated to the per-bit settings on the ENABLE_DEASSERTION_INPUT_QUAL)
//  8. Again, the sequencer will walk through all the required bits until the last reset_out{NUM_OUTPUTS} is deasserted.
//  9. When a done is received by the main FSM from the deassertion sequencer, it will move back to IDLE. (DONE)
// -------------------------------------------------------

`timescale 1 ns / 1 ns

module altera_reset_sequencer
#(
    // --------------------------------
    // Number of output ports to sequence
    // --------------------------------
    parameter NUM_OUTPUTS = 'd3,

    // -----------------------------
    // Number of input reset in port is not handled
    // in HDL, input port should be terminated hw_tcl

    // --------------------------------
    // Basic sequence enables
    // --------------------------------
    parameter ENABLE_ASSERTION_SEQUENCE = 'd0,
    parameter ENABLE_DEASSERTION_SEQUENCE = 'd0,

    // This is a bit-wise enable for deassertion input signal
    // If set to 1, deassertion sequence will wait for input signal qual, and ignore the
    // delay count being set.
    // Set by hw.tcl based on the SELECT in UI
    parameter ENABLE_DEASSERTION_INPUT_QUAL = 'h0,

    // ------------------------------
    // Minimum reset assertion count
    // --------------------------------
    parameter MIN_ASRT_TIME = 'd5,

    // -------------------------------
    // Deassertion input qualification deglitch count
    // -------------------------------
    parameter DSRT_QUALCNT_0 = 'd2,
    parameter DSRT_QUALCNT_1 = 'd3,
    parameter DSRT_QUALCNT_2 = 'd4,
    parameter DSRT_QUALCNT_3 = 'd5,
    parameter DSRT_QUALCNT_4 = 'd6,
    parameter DSRT_QUALCNT_5 = 'd7,
    parameter DSRT_QUALCNT_6 = 'd8,
    parameter DSRT_QUALCNT_7 = 'd9,
    parameter DSRT_QUALCNT_8 = 'd10,
    parameter DSRT_QUALCNT_9 = 'd11,

    // ----------------------------------
    // Sequence delay count
    // ----------------------------------
    parameter ASRT_DELAY0 = 'd1,
    parameter ASRT_DELAY1 = 'd2,
    parameter ASRT_DELAY2 = 'd3,
    parameter ASRT_DELAY3 = 'd4,
    parameter ASRT_DELAY4 = 'd5,
    parameter ASRT_DELAY5 = 'd6,
    parameter ASRT_DELAY6 = 'd7,
    parameter ASRT_DELAY7 = 'd8,
    parameter ASRT_DELAY8 = 'd9,
    parameter ASRT_DELAY9 = 'd10,
    parameter DSRT_DELAY0 = 'd1,
    parameter DSRT_DELAY1 = 'd2,
    parameter DSRT_DELAY2 = 'd3,
    parameter DSRT_DELAY3 = 'd4,
    parameter DSRT_DELAY4 = 'd5,
    parameter DSRT_DELAY5 = 'd6,
    parameter DSRT_DELAY6 = 'd7,
    parameter DSRT_DELAY7 = 'd8,
    parameter DSRT_DELAY8 = 'd9,
    parameter DSRT_DELAY9 = 'd10,

    // ---------------------------------
    // Sequence remapping
    // Default is from 0-1-2-3-...9
    // - Can be defined to be 3-2-1-5-...
    // ---------------------------------
    parameter ASRT_REMAP0 = 'd0,
    parameter ASRT_REMAP1 = 'd1,
    parameter ASRT_REMAP2 = 'd2,
    parameter ASRT_REMAP3 = 'd3,
    parameter ASRT_REMAP4 = 'd4,
    parameter ASRT_REMAP5 = 'd5,
    parameter ASRT_REMAP6 = 'd6,
    parameter ASRT_REMAP7 = 'd7,
    parameter ASRT_REMAP8 = 'd8,
    parameter ASRT_REMAP9 = 'd9,

    parameter DSRT_REMAP0 = 'd0,
    parameter DSRT_REMAP1 = 'd1,
    parameter DSRT_REMAP2 = 'd2,
    parameter DSRT_REMAP3 = 'd3,
    parameter DSRT_REMAP4 = 'd4,
    parameter DSRT_REMAP5 = 'd5,
    parameter DSRT_REMAP6 = 'd6,
    parameter DSRT_REMAP7 = 'd7,
    parameter DSRT_REMAP8 = 'd8,
    parameter DSRT_REMAP9 = 'd9,   

    // -------------------------
    // CSR interface settings
    // -------------------------
    parameter ENABLE_CSR                = 'd1,
    parameter REGISTER_CSR_INTERFACE    = 'd1,
    parameter AV_DATA_W = 'd32, // Not exposed to be modified
    parameter AV_ADDR_W = 'd8   // Not exposed to be modified

)(
    // ------------------------------
    // Clock and reset
    // This reset is used to reset the logic in the sequencer
    // ------------------------------
    input clk,
    input csr_reset,

    // -----------------
    // IRQ output
    // -----------------
    output logic            irq,

    //----------------------------
    // Avalon CSR Interface
    //----------------------------
    input  [AV_ADDR_W-1:0]       av_address,
    input                        av_write,
    input                        av_read,
    input  [AV_DATA_W-1:0]       av_writedata,
    output logic [AV_DATA_W-1:0] av_readdata,

    // ------------------------------
    // Input reset to be use for sequencing
    // ------------------------------
    input  reset_in0,
    input  reset_in1,
    input  reset_in2,
    input  reset_in3,
    input  reset_in4,
    input  reset_in5,
    input  reset_in6,
    input  reset_in7,
    input  reset_in8,
    input  reset_in9,

    input  reset_req_in0,
    input  reset_req_in1,
    input  reset_req_in2,
    input  reset_req_in3,
    input  reset_req_in4,
    input  reset_req_in5,
    input  reset_req_in6,
    input  reset_req_in7,
    input  reset_req_in8,
    input  reset_req_in9,

    // ------------------------------
    // Input qualification use for deassertion sequencing
    // ------------------------------
    input   reset0_dsrt_qual,
    input   reset1_dsrt_qual,
    input   reset2_dsrt_qual,
    input   reset3_dsrt_qual,
    input   reset4_dsrt_qual,
    input   reset5_dsrt_qual,
    input   reset6_dsrt_qual,
    input   reset7_dsrt_qual,
    input   reset8_dsrt_qual,
    input   reset9_dsrt_qual,

    // ------------------------------
    // Output reset and reset_req
    // ------------------------------
    output  reg reset_out0,
    output  reg reset_out1,
    output  reg reset_out2,
    output  reg reset_out3,
    output  reg reset_out4,
    output  reg reset_out5,
    output  reg reset_out6,
    output  reg reset_out7,
    output  reg reset_out8,
    output  reg reset_out9,
    output  reg reset_req_out0,
    output  reg reset_req_out1,
    output  reg reset_req_out2,
    output  reg reset_req_out3,
    output  reg reset_req_out4,
    output  reg reset_req_out5,
    output  reg reset_req_out6,
    output  reg reset_req_out7,
    output  reg reset_req_out8,
    output  reg reset_req_out9
);


 localparam MAX_OUTPUT = 10;

 // --------------------------------------
 // Internal logic/wire declarations
 // --------------------------------------
 logic asrt_seq_en, asrt_seq_done;
 logic dsrt_seq_en, dsrt_seq_done, dsrt_seq_done_q;
 logic [MAX_OUTPUT-1:0]    asrt_track, asrt_track_map;
 logic [MAX_OUTPUT-1:0]    dsrt_track, dsrt_track_map;
 logic [MAX_OUTPUT-1:0]    dsrt_in_qual, dsrt_in_qual_map;
 logic [MAX_OUTPUT-1:0]    reset_out, reset_req_out, reset_dsrt_qual;
 logic [MAX_OUTPUT-1:0]    reset_in_vec, reset_in_dsync;
 logic                     reset_in;
 logic [MAX_OUTPUT-1:0]    reset_log_pending, reset_log_update;
 logic [MAX_OUTPUT-1:0]    reset_in_dsync_q;

 // CSRs
 logic                    raw_csr_sw_rst, csr_sw_rst;
 logic [MAX_OUTPUT-1:0]   raw_csr_sw_aseq_bit_en, csr_sw_aseq_bit_en;   
 logic [MAX_OUTPUT-1:0]   raw_csr_sw_dseq_bit_en, csr_sw_dseq_bit_en;   
 logic [MAX_OUTPUT-1:0]   raw_csr_rst_ovr_en, csr_rst_ovr_en;  
 logic [MAX_OUTPUT-1:0]   raw_csr_rst_ovr, csr_rst_ovr;
 logic [MAX_OUTPUT-1:0]   raw_csr_rst_msk, csr_rst_msk;
 logic                    csr_set_dsrt_wait_sw;
 logic                    csr_set_asrt_wait_sw;
 logic                    raw_csr_asrt_seq_next, csr_asrt_seq_next;
 logic                    raw_csr_dsrt_seq_next, csr_dsrt_seq_next;
 logic                    csr_reset_sync, csr_reset_sync_req;

 // ------------------------------
 // Input reset synchronization
 //     - For synchronization, reuse reset controller
 //     - for detection, treat all input resets as asynchronous and internally double sync it
 // ------------------------------
 altera_reset_controller #(
    .NUM_RESET_INPUTS          (MAX_OUTPUT),
    .OUTPUT_RESET_SYNC_EDGES   ("both"),
    .RESET_REQUEST_PRESENT (0),
    .SYNC_DEPTH                (3)
 ) reset_in_sync (
    .reset_in0 (reset_in0), .reset_req_in0 (1'b0),
    .reset_in1 (reset_in1), .reset_req_in1 (1'b0),
    .reset_in2 (reset_in2), .reset_req_in2 (1'b0),
    .reset_in3 (reset_in3), .reset_req_in3 (1'b0),
    .reset_in4 (reset_in4), .reset_req_in4 (1'b0),
    .reset_in5 (reset_in5), .reset_req_in5 (1'b0),
    .reset_in6 (reset_in6), .reset_req_in6 (1'b0),
    .reset_in7 (reset_in7), .reset_req_in7 (1'b0),
    .reset_in8 (reset_in8), .reset_req_in8 (1'b0),
    .reset_in9 (reset_in9), .reset_req_in9 (1'b0),
    .reset_in10 (1'b0),     .reset_req_in10 (1'b0),
    .reset_in11 (1'b0),     .reset_req_in11 (1'b0),
    .reset_in12 (1'b0),     .reset_req_in12 (1'b0),
    .reset_in13 (1'b0),     .reset_req_in13 (1'b0),
    .reset_in14 (1'b0),     .reset_req_in14 (1'b0),
    .reset_in15 (1'b0),     .reset_req_in15 (1'b0),
    .clk (clk),
    .reset_out(reset_in),
    .reset_req()
 );

generate if (ENABLE_CSR == 1) begin : gen_csr_reset

 altera_reset_controller #(
    .NUM_RESET_INPUTS          (1),
    .OUTPUT_RESET_SYNC_EDGES   ("both"),
    .RESET_REQUEST_PRESENT     (1),
    .SYNC_DEPTH                (3)
 ) reset_csr_sync (
    .reset_in0 (csr_reset), .reset_req_in0 (1'b0), 
    .reset_in1 (1'b0),      .reset_req_in1 (1'b0),
    .reset_in2 (1'b0),      .reset_req_in2 (1'b0),
    .reset_in3 (1'b0),      .reset_req_in3 (1'b0),
    .reset_in4 (1'b0),      .reset_req_in4 (1'b0),
    .reset_in5 (1'b0),      .reset_req_in5 (1'b0), 
    .reset_in6 (1'b0),      .reset_req_in6 (1'b0),
    .reset_in7 (1'b0),      .reset_req_in7 (1'b0),
    .reset_in8 (1'b0),      .reset_req_in8 (1'b0),
    .reset_in9 (1'b0),      .reset_req_in9 (1'b0),
    .reset_in10 (1'b0),     .reset_req_in10 (1'b0),
    .reset_in11 (1'b0),     .reset_req_in11 (1'b0),
    .reset_in12 (1'b0),     .reset_req_in12 (1'b0),
    .reset_in13 (1'b0),     .reset_req_in13 (1'b0),
    .reset_in14 (1'b0),     .reset_req_in14 (1'b0),
    .reset_in15 (1'b0),     .reset_req_in15 (1'b0),
    .clk (clk),
    .reset_out(csr_reset_sync),
    .reset_req(csr_reset_sync_req)
 );
 end else begin
    assign csr_reset_sync       = 1'b0;
    assign csr_reset_sync_req   = 1'b0;
 end
endgenerate

 // ----------------------------------------
 // Reset synchronization for CSR reset logging purpose
 // ----------------------------------------
 assign reset_in_vec = { reset_in9, reset_in8, reset_in7, reset_in6, reset_in5,
                         reset_in4, reset_in3, reset_in2, reset_in1, reset_in0 };

 genvar i;
 generate 
 for (i=0 ; i<MAX_OUTPUT ; i++) begin : dsync
    altera_reset_synchronizer #(
        .ASYNC_RESET (0),
        .DEPTH       (3)
    ) reset_dsync (
        .reset_in   (reset_in_vec[i]),
        .clk        (clk),
        .reset_out  (reset_in_dsync[i])
    );
 end
 endgenerate

 // ------------------------------
 // Input logic qualifications
 // ------------------------------
 assign reset_dsrt_qual = { reset9_dsrt_qual, reset8_dsrt_qual, reset7_dsrt_qual, reset6_dsrt_qual,
                            reset5_dsrt_qual, reset4_dsrt_qual, reset3_dsrt_qual, reset2_dsrt_qual,
                            reset1_dsrt_qual, reset0_dsrt_qual };

 altera_reset_sequencer_deglitch_main #(
    .ENABLE         (ENABLE_DEASSERTION_INPUT_QUAL),
    .DEGLITCH_CNT0  (DSRT_QUALCNT_0),
    .DEGLITCH_CNT1  (DSRT_QUALCNT_1),
    .DEGLITCH_CNT2  (DSRT_QUALCNT_2),
    .DEGLITCH_CNT3  (DSRT_QUALCNT_3),
    .DEGLITCH_CNT4  (DSRT_QUALCNT_4),
    .DEGLITCH_CNT5  (DSRT_QUALCNT_5),
    .DEGLITCH_CNT6  (DSRT_QUALCNT_6),
    .DEGLITCH_CNT7  (DSRT_QUALCNT_7),
    .DEGLITCH_CNT8  (DSRT_QUALCNT_8),
    .DEGLITCH_CNT9  (DSRT_QUALCNT_9)
  ) dsrt_deg (
    .clk            (clk),
    .reset          (1'b0),//reset),
    .deg_clr        (~dsrt_seq_en), // Reset the deglitch counters when not in used
                                    // It is only evaluated on deassertion sequence
                                    // This however, means a "1" can be possible detected during resets.
    .sig_in         ((ENABLE_DEASSERTION_SEQUENCE ==1) ? reset_dsrt_qual: {MAX_OUTPUT{1'b0}}),
    .sig_out        (dsrt_in_qual)
  );

  assign dsrt_in_qual_map[DSRT_REMAP0] = dsrt_in_qual[0];
  assign dsrt_in_qual_map[DSRT_REMAP1] = dsrt_in_qual[1];
  assign dsrt_in_qual_map[DSRT_REMAP2] = dsrt_in_qual[2];
  assign dsrt_in_qual_map[DSRT_REMAP3] = dsrt_in_qual[3];
  assign dsrt_in_qual_map[DSRT_REMAP4] = dsrt_in_qual[4];
  assign dsrt_in_qual_map[DSRT_REMAP5] = dsrt_in_qual[5];
  assign dsrt_in_qual_map[DSRT_REMAP6] = dsrt_in_qual[6];
  assign dsrt_in_qual_map[DSRT_REMAP7] = dsrt_in_qual[7];
  assign dsrt_in_qual_map[DSRT_REMAP8] = dsrt_in_qual[8];
  assign dsrt_in_qual_map[DSRT_REMAP9] = dsrt_in_qual[9];

 // -------------- //
 // Main Sequencer //
 // -------------- //
 altera_reset_sequencer_main #( 
    .MIN_ASRT_TIME (MIN_ASRT_TIME)
 ) main (
    .clk            (clk),
    .reset          (1'b0),//reset),
    .reset_in       (reset_in),
    .reset_sw_in    (csr_sw_rst), 
    .asrt_seq_done  (asrt_seq_done),
    .asrt_seq_en    (asrt_seq_en),
    .dsrt_seq_done  (dsrt_seq_done),
    .dsrt_seq_en    (dsrt_seq_en)
 );

 // ------------------- //
 // Assertion Sequencer //
 // ------------------- //
 altera_reset_sequencer_seq #(
    .NUM_OUTPUTS (NUM_OUTPUTS),
    .SEQUENCER_EN(ENABLE_ASSERTION_SEQUENCE),
    .USE_QUAL    (0),
    .DELAY0      (ASRT_DELAY0),
    .DELAY1      (ASRT_DELAY1),
    .DELAY2      (ASRT_DELAY2),
    .DELAY3      (ASRT_DELAY3),
    .DELAY4      (ASRT_DELAY4),
    .DELAY5      (ASRT_DELAY5),
    .DELAY6      (ASRT_DELAY6),
    .DELAY7      (ASRT_DELAY7),
    .DELAY8      (ASRT_DELAY8),
    .DELAY9      (ASRT_DELAY9)
 ) asrt_seq (
    .clk            (clk),
    .reset          (1'b0),//reset),
    .csr_seq_ovr    (csr_sw_aseq_bit_en),
    .csr_seq_next   (csr_asrt_seq_next),
    .csr_wait_sw    (csr_set_asrt_wait_sw),
    .in_qual        ({MAX_OUTPUT{1'b0}}), // asrt_in_qual not supported for now
    .enable         (asrt_seq_en),
    .done           (asrt_seq_done),
    .track_out      (asrt_track)
 );

 // ---------------------- //
 // De-assertion Sequencer //
 // ---------------------- //
 altera_reset_sequencer_seq #(
    .NUM_OUTPUTS (NUM_OUTPUTS),
    .USE_QUAL    (ENABLE_DEASSERTION_INPUT_QUAL),
    .SEQUENCER_EN(ENABLE_DEASSERTION_SEQUENCE),
    .DELAY0      (DSRT_DELAY0),
    .DELAY1      (DSRT_DELAY1),
    .DELAY2      (DSRT_DELAY2),
    .DELAY3      (DSRT_DELAY3),
    .DELAY4      (DSRT_DELAY4),
    .DELAY5      (DSRT_DELAY5),
    .DELAY6      (DSRT_DELAY6),
    .DELAY7      (DSRT_DELAY7),
    .DELAY8      (DSRT_DELAY8),
    .DELAY9      (DSRT_DELAY9)
 ) dsrt_seq (
    .clk            (clk),
    .reset          (1'b0),
    .csr_seq_ovr    (csr_sw_dseq_bit_en),
    .csr_seq_next   (csr_dsrt_seq_next),
    .csr_wait_sw    (csr_set_dsrt_wait_sw),
    .in_qual        (dsrt_in_qual_map), // use remapped version
    .enable         (dsrt_seq_en),
    .done           (dsrt_seq_done),
    .track_out      (dsrt_track)
 );

 // ---------------------- //
 // Reset request controls //
 // ---------------------- //
 // Pass through reset request signals
 // Termination of unused port is done in hw.tcl
 assign reset_req_out = {{MAX_OUTPUT{reset_req_in9 | reset_req_in8 | reset_req_in7 | reset_req_in6 | reset_req_in5 | reset_req_in4 | reset_req_in3 | reset_req_in2 | reset_req_in1 | reset_req_in0}}};

 generate if (ENABLE_CSR == 1) begin : gen_csr
    altera_reset_sequencer_av_csr #(
        .REGISTER_CSR_INTERFACE  (REGISTER_CSR_INTERFACE)
    ) csr (
        .clk            (clk),
        .reset          (csr_reset_sync),
        .irq            (irq),
        .av_address     (av_address),
        .av_write       (av_write),
        .av_read        (av_read),
        .av_writedata   (av_writedata),
        .av_readdata    (av_readdata),
        // CSR register outputs
        .csr_sw_rst             (raw_csr_sw_rst),
        .csr_sw_aseq_bit_en_out (raw_csr_sw_aseq_bit_en),
        .csr_sw_aseq_seq_next   (raw_csr_asrt_seq_next),
        .csr_sw_dseq_bit_en_out (raw_csr_sw_dseq_bit_en),
        .csr_sw_dseq_seq_next   (raw_csr_dsrt_seq_next),
        .csr_rst_ovr            (raw_csr_rst_ovr),
        .csr_rst_ovr_en         (raw_csr_rst_ovr_en),
        .csr_rst_msk            (raw_csr_rst_msk),  
        // CSR Status inputs
        .csr_sts_reset_act      (~dsrt_seq_done & (asrt_seq_en | dsrt_seq_en)),
        .csr_sts_asrt_act       (asrt_seq_en),
        .csr_set_reset_in_sts   (reset_log_update),
        .csr_set_in_dsrt_qual   (dsrt_in_qual), // csr mapping is 1-1
        .csr_set_dsrt_wait_sw   (csr_set_dsrt_wait_sw),
        .csr_set_asrt_wait_sw   (csr_set_asrt_wait_sw)
    );
        assign csr_sw_rst           = ~csr_reset_sync_req & raw_csr_sw_rst;
        assign csr_sw_aseq_bit_en   = ~csr_reset_sync_req & raw_csr_sw_aseq_bit_en;
        assign csr_asrt_seq_next    = ~csr_reset_sync_req & raw_csr_asrt_seq_next;
        assign csr_sw_dseq_bit_en   = ~csr_reset_sync_req & raw_csr_sw_dseq_bit_en;
        assign csr_dsrt_seq_next    = ~csr_reset_sync_req & raw_csr_dsrt_seq_next;
        assign csr_rst_ovr          = ~csr_reset_sync_req & raw_csr_rst_ovr;
        assign csr_rst_ovr_en       = ~csr_reset_sync_req & raw_csr_rst_ovr_en;
        assign csr_rst_msk          = ~csr_reset_sync_req & raw_csr_rst_msk;

 // ----------------------------------
 // Reset logging logic
 // - log goes to status only on DSRT seq done assertion
 // - reset is logged only when reset sequence is completed. (and IRQ generation)
 // - reset that is asserted during assertion phase, will be all considered 'serviced' already
 // - reset that is asserted during de-assertion phase, will be pending, and set only on next completion.
 //   In this case, the SW will get IRQ for resets triggered during assertion phase, but will see that possibly
 //   ResetActive is set during this time. This implies that multiple reset has occured.
 // ----------------------------------
 always @(posedge clk or posedge csr_reset_sync) begin
    if (csr_reset_sync) begin
        reset_log_pending        <= '0;
        reset_log_update         <= '0;
        reset_in_dsync_q         <= '0;
        dsrt_seq_done_q            <= '0;
    end
    else if (csr_reset_sync_req) begin
        reset_log_pending        <= '0;
        reset_log_update         <= '0;
        reset_in_dsync_q         <= '0;
        dsrt_seq_done_q            <= '0;
    end
    else begin
        reset_log_pending <= (dsrt_seq_done & ~dsrt_seq_done_q) ? 
                                (reset_in_dsync & ~reset_in_dsync_q) : // update only on boundary
                                 reset_log_pending | (reset_in_dsync & ~reset_in_dsync_q); // set and hold
        reset_log_update  <= (dsrt_seq_done & ~dsrt_seq_done_q) ? reset_log_pending : '0;
        reset_in_dsync_q  <= reset_in_dsync;
        dsrt_seq_done_q   <= dsrt_seq_done;
    end
 
 end

 end else begin
    // Tie off outputs from av_csr block when CSR is not enabled.
    assign irq                    = 1'b0;
    assign av_readdata            = '0;
    assign csr_sw_rst             = '0;
    assign csr_sw_aseq_bit_en     = '0;
    assign csr_sw_dseq_bit_en     = '0;
    assign csr_rst_ovr            = '0;
    assign csr_rst_ovr_en         = '0;
    assign csr_rst_msk            = '0;
    assign csr_asrt_seq_next      = '0;
    assign csr_dsrt_seq_next      = '0;
 end
 endgenerate

 // ---------------------
 // Output Mappings 
 // ---------------------
 assign reset_out0 = reset_out[0];
 assign reset_out1 = reset_out[1];
 assign reset_out2 = reset_out[2];
 assign reset_out3 = reset_out[3];
 assign reset_out4 = reset_out[4];
 assign reset_out5 = reset_out[5];
 assign reset_out6 = reset_out[6];
 assign reset_out7 = reset_out[7];
 assign reset_out8 = reset_out[8];
 assign reset_out9 = reset_out[9];

 assign reset_req_out0 = reset_req_out[0];
 assign reset_req_out1 = reset_req_out[1];
 assign reset_req_out2 = reset_req_out[2];
 assign reset_req_out3 = reset_req_out[3];
 assign reset_req_out4 = reset_req_out[4];
 assign reset_req_out5 = reset_req_out[5];
 assign reset_req_out6 = reset_req_out[6];
 assign reset_req_out7 = reset_req_out[7];
 assign reset_req_out8 = reset_req_out[8];
 assign reset_req_out9 = reset_req_out[9];


 // ---------------------------
 // Remap if user defined sequence is done
 // ---------------------------
  assign    asrt_track_map[0]   = asrt_track[ASRT_REMAP0];
  assign    asrt_track_map[1]   = asrt_track[ASRT_REMAP1];
  assign    asrt_track_map[2]   = asrt_track[ASRT_REMAP2];
  assign    asrt_track_map[3]   = asrt_track[ASRT_REMAP3];
  assign    asrt_track_map[4]   = asrt_track[ASRT_REMAP4];
  assign    asrt_track_map[5]   = asrt_track[ASRT_REMAP5];
  assign    asrt_track_map[6]   = asrt_track[ASRT_REMAP6];
  assign    asrt_track_map[7]   = asrt_track[ASRT_REMAP7];
  assign    asrt_track_map[8]   = asrt_track[ASRT_REMAP8];
  assign    asrt_track_map[9]   = asrt_track[ASRT_REMAP9];
 
  assign    dsrt_track_map[0]   = dsrt_track[DSRT_REMAP0];
  assign    dsrt_track_map[1]   = dsrt_track[DSRT_REMAP1];
  assign    dsrt_track_map[2]   = dsrt_track[DSRT_REMAP2];
  assign    dsrt_track_map[3]   = dsrt_track[DSRT_REMAP3];
  assign    dsrt_track_map[4]   = dsrt_track[DSRT_REMAP4];
  assign    dsrt_track_map[5]   = dsrt_track[DSRT_REMAP5];
  assign    dsrt_track_map[6]   = dsrt_track[DSRT_REMAP6];
  assign    dsrt_track_map[7]   = dsrt_track[DSRT_REMAP7];
  assign    dsrt_track_map[8]   = dsrt_track[DSRT_REMAP8];
  assign    dsrt_track_map[9]   = dsrt_track[DSRT_REMAP9];

  // -------------------------------------------------
  // Output reset controls based on sequencer outputs
  // - set priority if both dsrt/asrt pulse is asserted (although not possible)
  // -------------------------------------------------
    initial
    begin
        reset_out <= '1;
    end

  always @(posedge clk) begin
        reset_out   <=  csr_rst_ovr_en ? 
                            csr_rst_ovr : 
                            ( (asrt_track_map & ~csr_rst_msk) & ~dsrt_track_map );
  end

endmodule


