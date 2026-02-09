`timescale 1ns/10ps

module  CONV(
	input 	wire 		clk,reset,
	output	reg 		busy,	
	input	wire		ready,	
			
	output	reg[11:0]	iaddr,
	input	wire[19:0]	idata,	
	
	output	reg	 	cwr,
	output	reg[11:0]	caddr_wr,
	output	reg[19:0] 	cdata_wr,
	
	output	reg 		crd,
	output  reg[11:0] 	caddr_rd,
	input	wire[19:0] 	cdata_rd,
	
	output reg[2:0] 	csel
);

//======================================//
// Wire & Reg
//======================================//
//Controller
reg [5:0] 		STATE, N_STATE;		//state, next state for FSM
reg 			KFLAG, N_KFLAG;		//kernel flag, next kernel flag(0 -> kernel0, 1 -> kernel1)
 
//Zero-padding & Conv. & Relu layer
reg [12:0] 		findx;			//input fifo index
reg [19:0] 		IBUF[0:140];		//input fifo buffer

reg [15:0] 		cindx;			//conv. calculate index (0~4096)
wire signed [19:0] 	BIAS[0:1];		//kernel bias
wire signed [19:0] 	KER[0:20];  	 	//kernel weight
reg signed [19:0] 	CO[0:8];		//conv. operand (0~9)
wire signed [20*2-1:0] 	CO_KER [0:8];		//conv. operand * kernel weight
reg signed [20*2-1:0] 	conv_r;			//conv. final output
reg signed [19:0] 	conv;			//conv. final output (truncate)

wire signed [19:0] 	relu;			//relu final output

//Max pooling layer
reg [15:0] 		pindx;			//max pooling calculate index (0~1024)
reg [2:0] 		mindx;			//max pooling inside loading index(0~3)
reg signed [19:0] 	MO[0:3];		//max pooling operand (0~3)
reg [19:0] 		max;			//max pooling output

//Flatten layer
reg [15:0] 		ftindx;			//flatten indx
reg signed [19:0] 	FO[0:1];		//flatten input (0~1)

//output
reg [20:0] counter;				//used for debug

//======================================//
// Controller
//======================================//
//FSM
always@(*)begin
	if(reset)begin
		N_STATE = 'd0;
	end
	else if(STATE == 'd0)begin	//layer 0 
		if(KFLAG && (caddr_wr == 'd4095))begin
			N_STATE = 'd1;
		end
	end
	else if(STATE == 'd1)begin	//layer 1
		if((N_KFLAG && ~KFLAG) && (caddr_wr == 'd1023))begin
			N_STATE = 'd2;
		end
	end
	else if(STATE == 'd2)begin	//layer 2
		N_STATE = 'd2;
	end
	else begin
		N_STATE = 'd0;
	end
end

always@(posedge clk or posedge reset)begin
	if(reset)begin
		STATE <= 'd0;
	end
	else begin
		STATE <= N_STATE;
	end
end

//kernel flag (0 -> kernel0, 1 -> kernel1)
always@(posedge clk or posedge reset)begin
	if(reset)begin
		KFLAG <= 'd0;
	end
	else if(STATE == 'd0)begin		//layer 0
		if(caddr_wr == 'd4095)begin
			KFLAG <= ~KFLAG;	//change kernel
		end
	end
	else if(STATE == 'd1)begin		//layer 1
		if((caddr_wr == 'd1023) && (mindx == 'd7))begin
			KFLAG <= ~KFLAG;
		end
	end
end

always@(posedge clk or posedge reset)begin
	if(reset)begin
		N_KFLAG <= 'd1;	
	end
	else begin
		N_KFLAG <= KFLAG;
	end
end

//======================================//
// Conv. && Relu Layer (Layer 0) 
//======================================//
//index
always@(posedge clk or posedge reset)begin
	if(reset)begin
		iaddr <= 'd0;
		findx <= 'd0;
		cindx <= 'd0;
	end
	else if(STATE == 'd0)begin		//layer 0
		if(caddr_wr == 'd4095)begin  	//finish writing to Memory -> initialize
			iaddr <= 'd0;
			findx <= 'd0;
			cindx <= 'd0;
		end
		else if(busy)begin
			iaddr <= iaddr + 'd1;
			findx <= findx + 'd1;
			if(findx >= 67)begin	//start calculate
				cindx <= cindx + 'd1;
			end
		end
	end
end

//FIFO Buffer
integer ib;

always@(posedge clk or posedge reset)begin
	if(reset)begin
		for(ib=0; ib<140; ib=ib+1)begin
			IBUF[ib] <= 'd0;
		end
	end
	else if(STATE == 'd0)begin				//layer 0
		if(STATE != N_STATE)begin			//initalize buffer for changing layer
			for(ib=0; ib<140; ib=ib+1)begin
				IBUF[ib] <= 'd0;
			end
		end
		else if(KFLAG && ~N_KFLAG)begin			//initalize buffer for changing kernel
	    		IBUF[0] <= idata;
			for(ib=1; ib<140; ib=ib+1)begin
				IBUF[ib] <= 'd0;
			end
		end
		else if(busy)begin 				//load input data
			if(findx >= 'd4096)begin
				IBUF[0] <= 'd0;
			end
			else begin
				IBUF[0] <= idata;
			end
			for(ib=1; ib<140; ib=ib+1)begin
				IBUF[ib] <= IBUF[ib-1];
			end
		end
	end
end

//Kernel
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

//Bias
assign BIAS[0] = 'h01310;      //Pixel 0: 7.446289e-02
assign BIAS[1] = 'hF7295;      //Pixel 1: -5.524139e-01

//Fetch Conv. operand
integer c;

always@(posedge clk or posedge reset)begin
	if(reset)begin
		for(c=0; c<9; c=c+1)begin
			CO[c] <= 'd0;
		end
	end
	else if(findx >= 67)begin
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

	end
end

//Conv. & Bias calculation
genvar cc;

generate 
	for(cc=0; cc<9; cc=cc+1)begin : GEN_CONV_BLK
		assign CO_KER[cc] = (~KFLAG) ? CO[cc]*KER[cc*2] : CO[cc]*KER[cc*2+1];
	end
endgenerate

integer ca;

always@(*)begin
	//add all of the conv. operand
	conv_r = CO_KER[0];
	for(ca=1; ca<9; ca=ca+1)begin
		conv_r = conv_r + CO_KER[ca];	
	end

        //add bias
	if(~KFLAG)begin
		conv_r = conv_r + $signed({{4{1'b0}}, BIAS[0], {16{1'b0}}});
	end
	else begin
		conv_r = conv_r + $signed({{4{1'b1}}, BIAS[1], {16{1'b0}}});
	end
        
	//truncate 
	if(~conv_r[15])begin
		conv = conv_r[20+16-1:16];
	end
	else begin
		conv = conv_r[20+16-1:16] + 'd1;
	end
end

//Relu calculation
assign relu = (conv[19])? 'd0 : conv;		//if conv < 0 then 0 else then conv

//======================================//
// Max Pooling (Layer 1)
//======================================//
//index
always@(posedge clk or posedge reset)begin
	if(reset)begin
		mindx <= 'd0;
		pindx <= 'd0;
	end
	else if(STATE == 'd1)begin		//layer 1
		if(KFLAG && ~N_KFLAG)begin
			mindx <= 'd0;
			pindx <= 'd0;
		end
		else if(mindx == 'd7)begin	//output
			mindx <= 'd0;
			pindx <= pindx + 'd1;
		end
		else begin			//loading 
			mindx <= mindx + 'd1;
			pindx <= pindx;
		end
	end
end

integer m;

//Input buffer
always@(posedge clk or posedge reset)begin
	if(reset)begin
		for(m=0; m<4; m=m+1)begin
			MO[m] <= 'd0;
		end
	end
	else if(STATE == 'd1)begin	//layer 1
		if(mindx < 'd5)begin
			MO[0] <= cdata_rd;
			for(m=1; m<4; m=m+1)begin
				MO[m] <= MO[m-1];
			end
		end
	end
end

//Find Max value
always@(*)begin
	max = 'd0;
	for(m=0; m<4; m=m+1)begin
		if(MO[m] > max)
			max = MO[m];
	end
end

//======================================//
// Flatten (Layer 2)
//======================================//
//index
always@(posedge clk or posedge reset)begin
	if(reset)begin
		ftindx <= 'd0;
	end
	else if(STATE == 'd2)begin	//layer 2
		ftindx <= ftindx + 'd1;
	end
end

		
//======================================//
// Output
//======================================//
//address & data
always@(posedge clk or posedge reset)begin
	if(reset)begin
		caddr_wr <= 'd0;		//write address
		cdata_wr <= 'd0;		//write data

		caddr_rd <= 'd0;		//read address

	end
	else if(STATE == 'd0)begin		//layer 0
		if(findx >= 67)begin
			if(findx >= 69)begin 	//delay 2 clk
				caddr_wr <= caddr_wr + 'd1;
			end
			cdata_wr <= relu;
		end
		caddr_rd <= 'd0;
	end
	else if(STATE == 'd1)begin		//layer 1	

		if(mindx >= 'd4)begin
			caddr_wr <= pindx;
			cdata_wr <= max;
		end
		else begin
			caddr_rd <= 2*pindx[4:0] + 2*64*pindx[9:5] + 1*mindx[0] + 64*mindx[1];
		end
	end
	else if(STATE == 'd2)begin		//layer 2
		if(~ftindx[0])begin
			caddr_rd <= (ftindx >> 2);
		end
		else begin
			if(~ftindx[1])
				caddr_wr <= 2*(ftindx >> 2);
			else
				caddr_wr <= 2*(ftindx >> 2) + 'd1;

			cdata_wr <= cdata_rd;
		end
	end

end
//csel (memory select)
always@(posedge clk or posedge reset)begin
	if(reset)begin
		csel <= 'd0;
	end
	else if(STATE == 'd0)begin	//layer 0
		if(~KFLAG)begin
			csel <= 'd1;	//kernel 0
		end	
		else begin
			csel <= 'd2;	//kernel 1
		end
	end
	else if(STATE == 'd1)begin	//layer 1
		if(~KFLAG)begin
			if(mindx >= 'd4)begin
				csel <= 'd3;	//kernel 0 write
			end
			else begin
				csel <= 'd1;	//kernel 0 read
			end
		end
		else begin
			if(mindx >= 'd4)begin
				csel <= 'd4;	//kernel 1 write
			end
			else begin
				csel <= 'd2;	//kernel 1 read
			end
		end
	end
	else if(STATE == 'd2)begin	//layer 2
		if(~ftindx[0])begin
			if(~ftindx[1])begin
				csel <= 'd3;	//kernel 0 read
			end
			else begin
				csel <= 'd4;	//kernel 0 read
			end
		end
		else begin
			csel <= 'd5;		//final write
		end
	end
end

//cwr(write enable), crd(read enable)
always@(posedge clk or posedge reset)begin
	if(reset)begin
		cwr <= 'd0;
		crd <= 'd0;
	end
	else if(STATE == 'd0)begin	//layer 0
		if(caddr_wr == 'd4095)begin
			cwr <= 'd0;
		end
		else if(findx >= 67)begin
			cwr <= 'd1;
		end

		if(N_STATE == 'd1)begin
			crd <= 'd1;
		end
	end
	else if(STATE == 'd1)begin	//layer 1
		if(mindx < 'd4)begin
			cwr <= 'd0;
			crd <= 'd1;
		end
		else begin
			if(mindx == 'd7)
				cwr <= 'd1;
			else
				cwr <= 'd0;
			crd <= 'd0;
		end
	end
	else if(STATE == 'd2)begin	//layer 2
		if(~ftindx[0])begin
			crd <= 'd1;
			cwr <= 'd0;
		end
		else begin
			crd <= 'd0;
			cwr <= 'd1;
		end
	end
end

//busy
always@(posedge clk or posedge reset)begin
    if(reset)begin
        busy <= 'd0;
    end
    else if(counter == 'd29048)begin
	    busy <= 'd0;
    end
    else if(ready)begin
        busy <= 'd1;
    end
end

//counter
always@(posedge clk or posedge reset)begin	
	if(reset)
		counter <= 'd0;
	else
		counter <= counter + 'd1;
end

endmodule




