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
// Reset Sequencer Main 
// - Contains block that controls the deassertion sequencer and assertion sequencer based on input resets
// - FSM is to control sequencing when multiple reset assertion (when in middle of asrt/dsrt sequence)
// -------------------------------------------------------

`timescale 1 ns / 1 ns

module altera_reset_sequencer_main #(
    parameter MIN_ASRT_TIME = 0
)
(
    // -----------------------------------------------
    // Clock and reset
    // This reset is used to reset the logic in the sequencer
    // -----------------------------------------------
    input clk,
    input reset,

    // -----------------------------------------------
    // Reset Control Input
    // -----------------------------------------------
    input  reset_in,    // assumed already synchronized
    input  reset_sw_in,

    // -----------------------------------------------
    // Control interface with asrt/dsrt sequencer
    // -----------------------------------------------
    input       asrt_seq_done,
    output reg  asrt_seq_en,
    input       dsrt_seq_done,
    output reg  dsrt_seq_en
);

  // -----------------------
  // FSM state definitions
  // -----------------------
  typedef enum logic [1:0] {
 //   S_IDLE         = 2'b00, // Idle state. No active reset sequencing
    S_ASRT_SEQ     = 2'b00, // Assertion state      : the assertion sequence block will be triggered.
    S_ASRT_HOLD    = 2'b01, // Assertion hold state : Hold the assertion until minimum time required is met.
    S_DSRT_SEQ     = 2'b10  // De-assertion state   : the deassertion sequencer block will be triggered
  } fsm_state;
  fsm_state state, next_state;

    // --------------------------------------------------
    // Ceil(log2()) function
    // --------------------------------------------------
    function unsigned[63:0] log2ceil;
        input reg[63:0] val;
        reg [63:0] i;

        begin
            i = 1;
            log2ceil = 0;

            while (i < val) begin
                log2ceil = log2ceil + 1;
                i = i << 1;
            end
        end
    endfunction

  // -----------------------------
  // Local derived parameters
  // -----------------------------
  localparam HOLD_CNT_W = (MIN_ASRT_TIME == 0) ? 1 : log2ceil(MIN_ASRT_TIME+1);

  // -----------------------
  // Intermediate signals
  // -----------------------
  logic reset_pulse_pending;
  logic set_reset_pulse_pending;
  logic clr_reset_pulse_pending;
  logic [HOLD_CNT_W-1:0] hold_count, hold_count_nxt;

  logic reset_in_sync;
  logic asrt_seq_en_nxt;
  logic dsrt_seq_en_nxt;

  // ---------------------------------------------------
  // Reset edge detection
  // ---------------------------------------------------
    initial begin
        reset_in_sync       <= 1'b0;
        reset_pulse_pending <= 1'b0;
    end
  always @(posedge clk or posedge reset) begin
    if (reset)  begin
        reset_in_sync       <= 1'b0;
        reset_pulse_pending <= 1'b0;
    end
    else begin
        reset_in_sync       <= reset_in;
        reset_pulse_pending <= set_reset_pulse_pending | (reset_pulse_pending & ~clr_reset_pulse_pending);
    end
  end

  always_comb begin

        // Set pulse when 
        // - rising edge is detected OR
        // - software triggers a reset
        set_reset_pulse_pending = (reset_in & ~reset_in_sync) | reset_sw_in;

        // Clear this pulse when assertion sequence is done
        // Note: If pending is set during deassertion sequence, 
        //       the whole reset entry and deassertion will be restarted
        //       If pending is set during assertion sequence, 
        //       the active assertion sequence is assumed to cover this reset assertion already, and will not retrigger
        clr_reset_pulse_pending = (state == S_ASRT_SEQ) | (state == S_ASRT_HOLD);
  end


  // ----------------------------------------------------
  // FSM : Finite State Machine
  // ---------------------------------------------------
  always_comb begin : state_transition

    case (state)

    S_ASRT_SEQ : begin
        next_state = S_ASRT_SEQ;
        // Waits for deassertion of reset_in as well as assertion sequence done
        // to arc to DSRT_SEQ
        if (asrt_seq_done & ~reset_in_sync)  begin
            if (MIN_ASRT_TIME == 0) next_state = S_DSRT_SEQ;
            else                    next_state = S_ASRT_HOLD;
        end
    end

    S_ASRT_HOLD : begin
        next_state = S_ASRT_HOLD;
        // Wait for minimum hold count
        if (~reset_in_sync & hold_count == MIN_ASRT_TIME) next_state = S_DSRT_SEQ;
    end

    S_DSRT_SEQ : begin
        next_state = S_DSRT_SEQ;

        // Waits for deassertion sequence done and arc back to IDLE unless
        // there is pending reset
        //if (~reset_in_sync & dsrt_seq_done & ~reset_pulse_pending)   next_state = S_IDLE;
        // no longer has S_IDLE

        // If there is pending reset, immediately are to ASRT_SEQ
        if (reset_pulse_pending & dsrt_seq_done)                    next_state = S_ASRT_SEQ;
    end

    default : begin
        next_state = S_ASRT_SEQ;
    end

    endcase
  end

  // ----------------------------------------------------
  // FSM : Controlled output control signals
  // ----------------------------------------------------
  // Enable the assertion/deassertion block whenever in the respective states
  always_comb begin : fsm_outputs
        asrt_seq_en_nxt     = ~dsrt_seq_done; // (next_state != S_IDLE); // (next_state == S_ASRT_SEQ) | (next_state == S_ASRT_HOLD);
        dsrt_seq_en_nxt     = (next_state == S_DSRT_SEQ);
        hold_count_nxt      = (next_state == S_ASRT_HOLD) ? 
                                ( (hold_count == MIN_ASRT_TIME) ? hold_count : hold_count + 1'b1 ) : '0;
  end  

  initial begin
        state           <= S_ASRT_SEQ; // S_IDLE;
        asrt_seq_en     <= 1'b0;
        dsrt_seq_en     <= 1'b0;
        hold_count      <= '0;
  end

  always @(posedge clk or posedge reset) begin
	if (reset) 	begin
        // Reset to DSRT_SEQ state, since this is the power-up state
        // - waits for reset to be deasserted, and start the deassertion sequence
		state		    <= S_ASRT_SEQ; // S_IDLE;
		asrt_seq_en 	<= 1'b0;
		dsrt_seq_en 	<= 1'b0;
        hold_count      <= '0;
	end
	else begin
        state           <= next_state;
        asrt_seq_en     <= asrt_seq_en_nxt;
        dsrt_seq_en     <= dsrt_seq_en_nxt;
        hold_count      <= hold_count_nxt;
	end
  end 
 
 
endmodule


