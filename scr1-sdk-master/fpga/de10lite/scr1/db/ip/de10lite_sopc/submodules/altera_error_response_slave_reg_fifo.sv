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


// -----------------------------------------
// Merlin AXI Default Slave (Register FIFO)
//
//      This is a specific FIFO based register to hold the CSR status registers.
//	Behavior of the FIFO:
//	1.  Data Content Management:
//	a.  Full/Empty
//	    •   When write_pointer == next_read_pointer, FIFO will be empty.
//	    •   When next_wr_ptr == read_pointer, FIFO will be full.
//	    •   When read and write occurs together during a full, full will continue be asserted. With the write taking effect on the FIFO.
//	    •   When read and write occurs together during a empty, empty will be de-asserted, assuming that the write data gets into the FIFO.
//	b.  Pointers
//	    •   When a write/load occurs, the input content will be loaded. 
//	    •   The write pointer increments unless FIFO is full.
//	    •   When a read/unload occurs to the FIFO the content of that address will be presented. 
//	    •   The read pointer is incremented, unless FIFO is empty. [No read ahead]
//	2.  Valid Content Management:
//	    a.  This will be managed through a register bit that is set during load and unset during unload.
//	    b.  When read and write occurs with wr_ptr==rd_ptr, load takes precedence.
//	3.  Status
//	    a.  When write occurs during full, set overflow bit.
//
//
// Author       : kevtan
// Project      : Qsys 13.0
//
// -----------------------------------------

module altera_error_response_slave_reg_fifo #(
    parameter DEPTH     = 'd16,    
    parameter DATA_W    = 'd8    
) 
(

    // Clock and Resets      
    input  clk, 
    input  rst_n,     

    // Control Signals
    input           load,
    input           unload,
    output  logic   overflow,

    // Data
    input       [ DATA_W - 1 : 0]   data_in,
    output  reg                     not_empty,
    output  reg [ DATA_W : 0]       data_out    // LSB padded with valid bit

);
// ---------------------
// Local Params
// ---------------------
localparam  PTR_W   = log2ceil (DEPTH);

// ----------------
// Declarations 
// ----------------

logic   [PTR_W - 1 : 0] next_wr_ptr;
logic   [PTR_W - 1 : 0] wr_ptr;
logic   [PTR_W - 1 : 0] wr_ptr_incremented;
logic   [PTR_W - 1 : 0] next_rd_ptr;
logic   [PTR_W - 1 : 0] rd_ptr;
logic   [PTR_W - 1 : 0] rd_ptr_incremented;
logic   [DEPTH - 1 : 0] valid;

logic   [DATA_W - 1 : 0]    mem     [DEPTH - 1 : 0];

logic empty;
logic next_empty;
logic full;
logic next_full;

// -------------------------
// Pointers
// -------------------------

assign wr_ptr_incremented   = (wr_ptr == DEPTH) ? '0 : wr_ptr + 1'b1;
assign rd_ptr_incremented   = (rd_ptr == DEPTH) ? '0 : rd_ptr + 1'b1;

assign next_wr_ptr  = (load   && !(full && !unload) )  ? wr_ptr_incremented : wr_ptr;
assign next_rd_ptr  = (unload && !empty) ? rd_ptr_incremented : rd_ptr;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        wr_ptr      <= '0;
        rd_ptr      <= '0;
    end
    else begin
        wr_ptr      <= next_wr_ptr;
        rd_ptr      <= next_rd_ptr;
    end
end

// ---------------------------
// Full/Empty 
// ---------------------------

always_comb begin

    next_full = full;
    next_empty = empty;

    if (unload && !load) begin
        next_full   = 1'b0;
        next_empty  = empty ? 1'b1 : (rd_ptr_incremented == wr_ptr);
    end

    if (load && !unload ) begin
        next_empty  = 1'b0;
        next_full   = full ? 1'b1 : (wr_ptr_incremented == rd_ptr);
    end

    if (load && unload && empty)    next_empty  = 1'b0;

//    if (load && unload && full)     next_full   = 1'b1; // redundant

end

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        full      <= 1'b0;
        empty     <= 1'b1;
    end
    else begin
        full      <= next_full;
        empty     <= next_empty;
    end
end

assign not_empty    = !empty;

// ---------------------------
// Data
// ---------------------------

always @(posedge clk) begin
    if (load & !(full & !unload)) begin
        mem[wr_ptr]     <= data_in;
    end
end

assign    data_out[DATA_W : 1]    = mem  [rd_ptr];
assign    data_out[0]             = valid[rd_ptr];

// ----------------------------
// Valid
// ----------------------------
    always @(posedge clk, negedge rst_n) begin
        if (!rst_n) begin
            valid <= '0;
        end 
        else begin
            if (load & unload & (rd_ptr == wr_ptr))
                valid[wr_ptr] <= 1'b1;
            if (unload)     
                valid[rd_ptr] <= 1'b0;
            if (load)       
                valid[wr_ptr] <= 1'b1;
        end
    end

// ------------------------------
// Status
// ------------------------------

assign overflow = load & full;

    // --------------------------------------------------
    // Calculates the log2ceil of the input value
    // --------------------------------------------------
    function integer log2ceil;
        input integer val;
        integer i;

        begin
            i = 1;
            log2ceil = 0;

            while (i < val) begin
                log2ceil = log2ceil + 1;
                i = i << 1; 
            end
        end
    endfunction

//--------------------------------------
// Assertions
//--------------------------------------
// synthesis translate_off

`define assert_and_cover_clk(LABEL, arg) \
    property ``LABEL; \
        @(posedge clk) disable iff (!rst_n) arg; \
    endproperty \
    a_``LABEL: assert property (``LABEL)

`assert_and_cover_clk ( ERR_FULL_AND_LOAD,               (full  && load  && !unload)   |=> ( $stable(wr_ptr) && full ) );
`assert_and_cover_clk ( ERR_EMPTY_AND_UNLOAD,            (empty && !load && unload)    |=> ( $stable(rd_ptr) && empty) );
`assert_and_cover_clk ( ERR_FULL_AND_LOAD_UNLOAD,        (full  && load  && unload)    |=> full );
`assert_and_cover_clk ( ERR_EMPTY_AND_LOAD_UNLOAD,       (empty && load  && unload)    |=> !empty );
`assert_and_cover_clk ( ERR_EMPTY_WHEN_VALID_NOT_CLEAR,  
                        $rose(empty) && ! (!(|(valid)) && (rd_ptr == wr_ptr)) |=> 1'b0 ); // should never trigger
`assert_and_cover_clk ( ERR_FULL_WHEN_VALID_NOT_ALL_SET, 
                        $rose(full)  && ! (&(valid) ) |=> 1'b0);         // should never trigger
`assert_and_cover_clk ( ERR_FULL_AND_EMPTY_SET,
                        empty & full |=> 1'b0);                          // should never trigger

`ifdef UNIT_LEVEL_COVERAGE
c_ERR_FULL_AND_LOAD           : cover property (ERR_FULL_AND_LOAD);
c_ERR_EMPTY_AND_UNLOAD        : cover property (ERR_EMPTY_AND_UNLOAD);
c_ERR_FULL_AND_LOAD_UNLOAD    : cover property (ERR_FULL_AND_LOAD_UNLOAD);
c_ERR_EMPTY_AND_LOAD_UNLOAD   : cover property (ERR_EMPTY_AND_LOAD_UNLOAD);
`endif

`undef assert_and_cover_clk

// synthesis translate_on

endmodule : altera_error_response_slave_reg_fifo


