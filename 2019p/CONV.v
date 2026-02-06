
`timescale 1ns/10ps

module  CONV(
	input 	wire 		clk,reset,
	output	reg 		busy,	
	input	wire		ready,	
			
	output	reg[11:0]	iaddr,
	input	wire[19:0]	idata,	
	
	output	 	cwr,
	output	 	caddr_wr,
	output	 	cdata_wr,
	
	output	 	crd,
	output	 	caddr_rd,
	input	 	cdata_rd,
	
	output	 	csel
);

//======================================//
// Wire & Reg
//======================================//
//Input FIFO buffer
reg [19:0] IBUF[0:140];		

//Conv. layer
wire signed [19:0] BIAS;		//kernel bias
wire signed [19:0] KER[0:20];   	//kernel weight
reg signed [19:0] CO[0:8];		//conv. operand (0~9)
reg [8:0] cindx;			//conv. calculate indx
wire signed [20*2-1:0] CO_KER [0:8];	//conv. operand*kernel weight
reg signed [19:0] conv;			//conv. final output
wire signed [19:0] relu;		//relu final output

//======================================//
// Input FIFO Buffer
//======================================//
//input index
always@(posedge clk or posedge reset)begin
	if(reset)begin
		iaddr <= 'd0;
	end
	else if(busy)begin
		iaddr <= iaddr + 'd1;
	end
end

//shift register
integer ib;

always@(posedge clk or posedge reset)begin
	if(reset)begin
		for(ib=0; ib<140; ib=ib+1)begin
			IBUF[ib] <= 'd0;
		end
	end
	else if(busy)begin
		IBUF[0] <= idata;
		for(ib=1; ib<140; ib=ib+1)begin
			IBUF[ib] <= IBUF[ib-1];
		end
	end
end

//======================================//
// Conv. && Relu Layer (Layer 0) 
//======================================//
//kernel0
assign KER[0] = 'h0A89E;      //Pixel 0: 6.586609e-01
assign KER[1] = 'hFDB55;      //Pixel 1: -1.432343e-01
assign KER[2] = 'h092D5;      //Pixel 2: 5.735626e-01
assign KER[3] = 'h02992;      //Pixel 3: 1.623840e-01
assign KER[4] = 'h06D43;      //Pixel 4: 4.268036e-01
assign KER[5] = 'hFC994;      //Pixel 5: -2.125854e-01
assign KER[6] = 'h01004;      //Pixel 6: 6.256104e-02
assign KER[7] = 'h050FD;      //Pixel 7: 3.163605e-01
assign KER[8] = 'hF8F71;      //Pixel 8: -4.396820e-01
assign KER[9] = 'h02F20;      //Pixel 9: 1.840820e-01
assign KER[10] = 'hF6E54;      //Pixel 10: -5.690308e-01
assign KER[11] = 'h0202D;      //Pixel 11: 1.256866e-01
assign KER[12] = 'hFA6D7;      //Pixel 12: -3.482819e-01
assign KER[13] = 'h03BD7;      //Pixel 13: 2.337494e-01
assign KER[14] = 'hFC834;      //Pixel 14: -2.179565e-01
assign KER[15] = 'hFD369;      //Pixel 15: -1.741791e-01
assign KER[16] = 'hFAC19;      //Pixel 16: -3.277435e-01
assign KER[17] = 'h05E68;      //Pixel 17: 3.687744e-01

//Bias0
assign BIAS = 'h01310;

//Find Conv. operand
integer c;

always@(posedge clk or posedge reset)begin
	if(reset)begin
		for(c=0; c<9; c=c+1)begin
			CO[c] <= 'd0;
		end
		cindx <= 'd0;
	end
	else if(iaddr >= 67)begin
		if(cindx[5:0] == 'd63)begin	
			//if conv. indx at right edge
			CO[0] <= IBUF[66+64+1];		CO[1] <= IBUF[66+64]; 		CO[2] <= 'd0; 
			CO[3] <= IBUF[66+1]; 		CO[4] <= IBUF[66]; 		CO[5] <= 'd0; 
			CO[6] <= IBUF[66-64+1]; 	CO[7] <= IBUF[66-64]; 		CO[8] <= 'd0;
		end
		else if(cindx[5:0] == 'd0)begin 
			//if conv. indx at left edge
			CO[0] <= 'd0;			CO[1] <= IBUF[66+64]; 		CO[2] <= IBUF[66+64-1]; 
			CO[3] <= 'd0; 			CO[4] <= IBUF[66]; 		CO[5] <= IBUF[66-1]; 
			CO[6] <= 'd0; 			CO[7] <= IBUF[66-64]; 		CO[8] <= IBUF[66-64-1];
		end
		else begin 
			//conv. indx at middle
			CO[0] <= IBUF[66+64+1];		CO[1] <= IBUF[66+64]; 		CO[2] <= IBUF[66+64-1];
			CO[3] <= IBUF[66+1]; 		CO[4] <= IBUF[66]; 		CO[5] <= IBUF[66-1]; 
			CO[6] <= IBUF[66-64+1]; 	CO[7] <= IBUF[66-64]; 		CO[8] <= IBUF[66-64-1];
		end
		cindx <= cindx + 'd1;
	end
end

//Conv. & Bias calculation
genvar cc;

generate 
	for(cc=0; cc<9; cc=cc+1)begin : GEN_CONV_BLK
		assign CO_KER[cc] = CO[cc]*KER[cc*2];
	end
endgenerate

integer ca;

always@(*)begin
	//add all of the conv. operand
	conv = $signed(CO_KER[0][16+20-1:16]);
	for(ca=1; ca<9; ca=ca+1)begin
		conv = conv + $signed(CO_KER[ca][16+20-1:16]);	
	end
	conv = conv + BIAS;
end

//Relu calculation
assign relu = (conv[19])? 'd0 : conv;		//if conv < 0 then 0 else then conv

//======================================//
// Output
//======================================//

always@(posedge clk or posedge reset)begin
    if(reset)
        busy <= 'd0;
    else if(ready)
        busy <= 'd1;
end

endmodule




