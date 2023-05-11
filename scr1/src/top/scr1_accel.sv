/// Copyright by Syntacore LLC © 2016-2020. See LICENSE for details
/// @file       <scr1_accel.sv>
/// @brief      Memory Mapped Accelerator
///

`include "scr1_memif.svh"
`include "scr1_arch_description.svh"

module scr1_accel
(
    // Control signals
    input   logic                           clk,
    input   logic                           rst_n,


    // Core data interface
    output  logic                           dmem_req_ack,
    input   logic                           dmem_req,
    input   type_scr1_mem_cmd_e             dmem_cmd,
    input   type_scr1_mem_width_e           dmem_width,
    input   logic [`SCR1_DMEM_AWIDTH-1:0]   dmem_addr,
    input   logic [`SCR1_DMEM_DWIDTH-1:0]   dmem_wdata,
    output  logic [`SCR1_DMEM_DWIDTH-1:0]   dmem_rdata,
    output  type_scr1_mem_resp_e            dmem_resp
);

//-------------------------------------------------------------------------------
// Local signal declaration
//-------------------------------------------------------------------------------
logic                               dmem_req_en;
logic                               dmem_rd;
logic                               dmem_wr;
logic [`SCR1_DMEM_DWIDTH-1:0]       dmem_writedata;
logic [`SCR1_DMEM_DWIDTH-1:0]       dmem_rdata_local;
logic [1:0]                         dmem_rdata_shift_reg;
//-------------------------------------------------------------------------------
// Core interface
//-------------------------------------------------------------------------------
assign dmem_req_en = (dmem_resp == SCR1_MEM_RESP_RDY_OK) ^ dmem_req;


always_ff @(posedge clk, negedge rst_n) begin
    if (~rst_n) begin
        dmem_resp <= SCR1_MEM_RESP_NOTRDY;
    end else if (dmem_req_en) begin
        dmem_resp <= dmem_req ? SCR1_MEM_RESP_RDY_OK : SCR1_MEM_RESP_NOTRDY;
    end
end

assign dmem_req_ack = 1'b1;
//-------------------------------------------------------------------------------
// Memory data composing
//-------------------------------------------------------------------------------
assign dmem_rd  = dmem_req & (dmem_cmd == SCR1_MEM_CMD_RD);
assign dmem_wr  = dmem_req & (dmem_cmd == SCR1_MEM_CMD_WR);

always_comb begin
    dmem_writedata = dmem_wdata;
    case ( dmem_width )
        SCR1_MEM_WIDTH_BYTE : begin
            dmem_writedata  = {(`SCR1_DMEM_DWIDTH /  8){dmem_wdata[7:0]}};
        end
        SCR1_MEM_WIDTH_HWORD : begin
            dmem_writedata  = {(`SCR1_DMEM_DWIDTH / 16){dmem_wdata[15:0]}};
        end
        default : begin
        end
    endcase
end

 
	 reg go_bit;
	 wire go_bit_in;
	 reg done_bit;
	 wire done_bit_in;
	 reg [15:0] counter;
	 reg [31:0] data_A;
	 reg [31:0] data_B;
	 wire [31:0] data_C;
	 reg [31:0] result;
	 reg [7:0] in1, in2;
	 wire[7:0] out;

	 assign ctr = counter;
	 
	 always @(dmem_addr[4:2], data_A, data_B, data_C, counter, done_bit, go_bit, counter) begin
		case(dmem_addr[4:2])
		3'b000: dmem_rdata_local = {done_bit, 30'b0, go_bit};
		3'b001: dmem_rdata_local = {16'b0, counter}; 
		3'b010: dmem_rdata_local = data_A;
		3'b011: dmem_rdata_local = data_B;
		3'b100: dmem_rdata_local = data_C;
		default: dmem_rdata_local = 32'b0;
		endcase
	 end
	 
	 assign go_bit_in = (dmem_wr & (dmem_addr[4:2] == 3'b000));
	
	 always @(posedge clk or negedge rst_n)
		if(~rst_n) go_bit <= 1'b0;
		else go_bit <=  go_bit_in ? 1'b1 : 1'b0;
		
	 always @(posedge clk or negedge rst_n)
		if(~rst_n) begin
			counter <=16'b0;
			data_A <= 32'b0;
			data_B <= 32'b0;
		end
		else begin
			if (dmem_wr) begin
				data_A <= (dmem_addr[4:2] == 3'b010) ? dmem_writedata : data_A;
				data_B <= (dmem_addr[4:2] == 3'b011) ? dmem_writedata : data_B;
			end
			else begin
				data_A <= data_A;
				data_B <= data_B;
			end
			counter <= go_bit_in? 16'h00 : done_bit_in ? counter : counter +16'h01;
		end
		
	 		
	 always @(data_A, counter) begin
		case(counter)
		16'b0: 	in1 = data_A[7:0];
		16'b1:	in1 = data_A[15:8];
		default: in1 = data_A[7:0];
		endcase
	 end
	
	  always @(data_B, counter) begin
		case(counter)
		32'b0: 	in2 = data_B[7:0];
		32'b1:	in2 = data_B[15:8];
		default: in2 = data_B[7:0];
		endcase
	 end
	 
	 
	 assign out = in1 * in2;
	 
	wire [31:0] result_in;

	assign result_in = (counter==16'd0) ? {result[31:8], out} : 
							(counter==16'd1) ? {result[31:16], out, result[7:0]}:
							 result; // Thready said we can delete if we don't use word split.
							 
	 always @(posedge clk or negedge rst_n)
		if(~rst_n) result <=32'h0;
		else result <= result_in;
	 	 
	 assign data_C = in1*in2;
	 
	 assign done_bit_in = (counter == 16'd2);
	 
	 always @(posedge clk or negedge rst_n)
		if(~rst_n) done_bit <= 1'b0;
		else done_bit <= go_bit_in ? 1'b0 : done_bit_in;
	 

always_ff @(posedge clk) begin
    if (dmem_rd) begin
        dmem_rdata_shift_reg <= dmem_addr[1:0];
    end
end

assign dmem_rdata = dmem_rdata_local >> ( 8 * dmem_rdata_shift_reg );

endmodule : scr1_accel