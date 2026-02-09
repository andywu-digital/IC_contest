`timescale 1ns/10ps

module SAO ( clk, reset, in_en, din, sao_type, sao_band_pos, sao_eo_class, sao_offset, lcu_x, lcu_y, lcu_size, busy, finish);
input   clk;
input   reset;
input   in_en;
input   [7:0]  din;
input   [1:0]  sao_type;
input   [4:0]  sao_band_pos;
input          sao_eo_class;
input   [15:0] sao_offset;
input   [2:0]  lcu_x;
input   [2:0]  lcu_y;
input   [1:0]  lcu_size;
output  busy;
output  finish;

//=======================================================//
// Wire & Reg
//=======================================================//
//Input Buffer
reg [7:0] IMEM [0:191];      	//Input buffer
reg [13:0] AMEM [0:191];     	//Address buffer
reg CMEM [0:191];     	     	//EO Class buffer
reg [1:0] TMEM [0:191];	     	//SAO Type buffer
reg [15:0] SMEM [0:191];	//Offset buffer
reg [4:0] PMEM [0:191];	     	//Band pos buffer

//SAO
wire [7:0] off_out, bo_out, eo_out;
reg [7:0] a, b;
reg [7:0] sel_out;

//SRAM control
reg [13:0] lcu_length;
reg [13:0] lcu_width;
reg [13:0] sram_addr;
reg [13:0] sram_count;
reg [13:0] sram_count_p;

reg WEN;
reg WEN_flag;

//Output control
wire busy;
reg finish;

//=======================================================//
// Input Buffer
//=======================================================//
//Input, EO_Class, SAO_Type, Offset, Band_pos buffer
integer i;

always @(negedge clk or negedge reset)begin
	if(reset)begin
		for(i=0;i<191;i=i+1)begin
			IMEM[i] <= 'd0;
			CMEM[i] <= 'd0;
			TMEM[i] <= 'd0;
			SMEM[i] <= 'd0;
			PMEM[i] <= 'd0;
		end
	end
	else begin
		IMEM[0] <= din;
		CMEM[0] <= sao_eo_class;
		TMEM[0] <= sao_type;
		SMEM[0] <= sao_offset;
		PMEM[0] <= sao_band_pos;

		//Shift reg
		for(i=1;i<191;i=i+1)begin
			IMEM[i] <= IMEM[i-1];
			CMEM[i] <= CMEM[i-1];
			TMEM[i] <= TMEM[i-1];
			SMEM[i] <= SMEM[i-1];
			PMEM[i] <= PMEM[i-1];
		end
	end
end

//Address buffer
integer j;

always @(negedge clk or negedge reset)begin
	if(reset)begin
		for(j=0;j<191;j=j+1)begin
			AMEM[j] <= 'd0;
		end
	end
	else begin
		if(AMEM[0] == 14'd16383)
			AMEM[0] <= 14'd16383; 	//stop counter
		else
			AMEM[0] <= sram_addr;

		//Shift reg
		for(j=1;j<191;j=j+1)begin
			AMEM[j] <= AMEM[j-1];
		end
	end
end

//=========================================================//
// SAO function
//=========================================================//
//OFF function
off o1(
	.i_in(IMEM[65]),
	.o_in(off_out)
);

//BO function
bo b1(
	.i_in(IMEM[65]),
	.sao_offset(SMEM[65]),
	.sao_band_pos(PMEM[65]),
	.o_in(bo_out)
);

//EO function
always @(*)begin

	//fetch a, b
	if(CMEM[65])begin
		a = IMEM[65-lcu_width];
		b = IMEM[65+lcu_width];
	end
	else begin
		a = IMEM[65-1];
		b = IMEM[65+1];
	end
end

eo e1(
	.i_in(IMEM[65]),
	.i_addr(AMEM[64]),
	.a(a),
	.b(b),
	.sao_offset(SMEM[65]),
	.sao_eo_class(CMEM[65]),
	.lcu_size(lcu_size),
	.lcu_width(lcu_width),
	.o_in(eo_out)

);

//Output select
always @(*)begin
	case(TMEM[65])
		'd0: sel_out = off_out;
	       	'd1: sel_out = bo_out;
		'd2: sel_out = eo_out;
		default: sel_out = 'd0;
	endcase
end	

//=========================================================//
// SRAM Control
//=========================================================//
//lcu width select (16x16, 32x32, 64x64)
always @(posedge clk or negedge reset)begin
	if(reset)
		lcu_width <= 'd0;
	else begin
		case(lcu_size)
			'd0: lcu_width <= 'd16;
			'd1: lcu_width <= 'd32;
			'd2: lcu_width <= 'd64;
			default: lcu_width <= 'd0;
		endcase
	end
end

//lcu length select (16x16, 32x32, 64x64)
always @(posedge clk or negedge reset)begin
	if(reset)
		lcu_length <= 'd0;
	else begin
		case(lcu_size)
			'd0: lcu_length <= 'd256;
			'd1: lcu_length <= 'd1024;
			'd2: lcu_length <= 'd4096;
			default: lcu_length <= 'd0;
		endcase
	end
end

//lcu counter (0~lcu_length)
always @(negedge clk or negedge reset)begin
	if(reset)
		sram_count <= 'd0;
	else if(~in_en)
	    sram_count <= 'd0;
	else if(sram_count < (lcu_length - 'd1))
		sram_count <= sram_count + 'd1;
	else
		sram_count <= 'd0;
end	

//SRAM counter (0~16383)
always @(negedge clk)begin
	
	case(lcu_size)	
		'd0: sram_addr <= (sram_count[3:0] + (lcu_width*lcu_x)) + (sram_count[13:4] + (lcu_width*lcu_y))*128;
		'd1: sram_addr <= (sram_count[4:0] + (lcu_width*lcu_x)) + (sram_count[13:5] + (lcu_width*lcu_y))*128;
		'd2: sram_addr <= (sram_count[5:0] + (lcu_width*lcu_x)) + (sram_count[13:6] + (lcu_width*lcu_y))*128;
		default: sram_addr <= 'd0;
	endcase
end

//Write Enable Control
always @(negedge clk or negedge reset)begin
	if(reset)begin
		WEN <= 'd1;
		WEN_flag <= 'd0;
	end
	else begin
		if(IMEM[63] == 'd0 && ~WEN_flag)begin
			WEN <= 'd1;
			WEN_flag <= 'd0;
		end
		else begin
			if(AMEM[64] == 'd16383)begin
				WEN <= 'd1;
				WEN_flag <= 'd0;
			end
			else begin
				WEN <= 'd0;
				WEN_flag <= 'd1;
			end
		end
	end	
end

//SRAM
sram_16384x8 golden_sram(.Q( ), .CLK(clk), .CEN(1'd0), .WEN(WEN), .A(AMEM[64]), .D(sel_out)); 
  
//===========================================================//
// Output Control
//===========================================================//
//busy (not used)
assign busy = 'd0;

//finish
always @(posedge clk or negedge reset)begin
	if(reset)
		finish <= 'd0;
	else if(AMEM[64] == 'd16383)begin
		finish <= 'd1;
	end
	else begin
		finish <= 'd0;
	end
end
		
endmodule

//=========================================================================//
//
// Local Function
//
//=========================================================================//

//================== off function ==================//
module off(
	input wire [7:0] i_in,
	output wire [7:0] o_in
);

assign o_in = i_in;  	//bypass

endmodule

//================== bo function ====================//
module bo(
    input wire [7:0] i_in,
	input wire [4:0] sao_band_pos,
	input wire [15:0] sao_offset,
   	output wire [7:0] o_in
);

wire [4:0] band;
wire [4:0] band_pos;

reg signed [8:0] sign_in;

assign band = i_in[7:3];  	//input_pixel/8

assign band_pos = (band < sao_band_pos) ? 'd4 : band - sao_band_pos;	//find band 1~4

//add offset to particular band
always @(*)begin
	case(band_pos)
		//Signed Operation
		'd0: sign_in = $signed({1'd0, i_in}) + $signed({sao_offset[15:12]});  	//Band 1
		'd1: sign_in = $signed({1'd0, i_in}) + $signed({sao_offset[11:8]});	//Band 2
		'd2: sign_in = $signed({1'd0, i_in}) + $signed({sao_offset[7:4]}); 	//Band 3
		'd3: sign_in = $signed({1'd0, i_in}) + $signed({sao_offset[3:0]});	//Band 4
		default: sign_in = $signed({1'd0, i_in});				//Other Band
	endcase
end

//Signed 2 Unsigned
assign o_in = sign_in[7:0];

endmodule

//================== eo function =====================//
module eo(
	input wire [7:0] i_in,
	input wire [13:0] i_addr,
	input wire [7:0] a, b,
	input wire [15:0] sao_offset,
	input wire sao_eo_class,
	input wire [1:0] lcu_size,
	input wire [13:0] lcu_width,
	output wire [7:0] o_in
);

reg [6:0] sel;
reg [6:0] sel_p;

reg [3:0] categ;
reg signed [8:0] sign_in;

//find the particular row or col for bypass (0 or lcu_width)
always@(*)begin
	if(sao_eo_class)
		sel = i_addr[13:7];
	else
		sel = i_addr[6:0];
end

always@(*)begin
	case(lcu_size)
		'd0: sel_p = {3'd0, sel[3:0]};
		'd1: sel_p = {2'd0, sel[4:0]};
		'd2: sel_p = {1'd0, sel[5:0]};
		default: sel_p = 'd0;
	endcase
end

//Find Category
always @(*)begin
	if((sel_p == 'd0) || (sel_p == (lcu_width-'d1)))
		categ = 'd0;
	else if((i_in < a) && (i_in < b))	
		categ = 'd1;
	else if(((i_in < a) && (i_in == b)) || ((i_in < b) && (i_in == a)))
		categ = 'd2;
	else if(((i_in > a) && (i_in == b)) || ((i_in > b) && (i_in == a)))
		categ = 'd3;
	else if((i_in > a) && (i_in > b))
		categ = 'd4;
	else
		categ = 'd0;
end

//Add offset to particular pixel (depand on Category)
always @(*)begin
	case(categ)
		//Signed Operation
		'd0: sign_in = $signed({1'd0, i_in});
		'd1: sign_in = $signed({1'd0, i_in}) + $signed({sao_offset[15:12]});
		'd2: sign_in = $signed({1'd0, i_in}) + $signed({sao_offset[11:8]});
		'd3: sign_in = $signed({1'd0, i_in}) + $signed({sao_offset[7:4]});
		'd4: sign_in = $signed({1'd0, i_in}) + $signed({sao_offset[3:0]});
		default: sign_in = $signed({1'd0, i_in});
	endcase
end

//Signed 2 Unsigned 
assign o_in = sign_in[7:0];

endmodule























