`timescale 1ns/10ps

`define N 9	//input number

module CS(Y, X, reset, clk);

input clk, reset; 
input [7:0] X;
output wire [9:0] Y;

//==============================//
// Wire & Reg
//==============================//
//Input Memory
reg [7:0] XMEM [0:`N-1];		//input shift register

//Calculate Approx. Average
wire [7+8:0] isum;			//input sum
wire [7:0] iavg;			//input average
wire signed [8:0] diff [0:`N-1];	//input differential val.
wire [3*8:0] indx [0:3];		//comparative propagation index
wire [7:0] appr;			//approx. average

//Output 
wire [7+8+9:0] isum2;			//output sum

//==============================//
// Input Memory
//==============================//
//Shift Register
integer i;
always@(negedge clk or posedge reset)begin
	if(reset)begin	
		for(i=0; i<`N; i=i+1)begin
			XMEM[i] <= 'd0;
		end
	end
	else begin
		XMEM[0] <= X;
		for(i=1; i<`N; i=i+1)begin
			XMEM[i] <= XMEM[i-1];
		end
	end
end

//=============================//
// Calculate Approx. Average
//=============================//
//Calculate input average
assign isum = XMEM[0] + XMEM[1] + XMEM[2] + XMEM[3] + XMEM[4] + XMEM[5] + XMEM[6] + XMEM[7] + XMEM[8];
assign iavg = isum/`N;

//Caclulate input differential val.
genvar d;
generate 
	for(d=0; d<`N; d=d+1)begin : GEN_DIFF_BLK
		assign diff[d] = $signed({1'd0, iavg}) - $signed({1'd0, XMEM[d]});
	end
endgenerate

//Find Minimum & >0 differential val. index
assign indx[0] = {3'd7, 3'd6, 3'd5, 3'd4, 3'd3, 3'd2, 3'd1, 3'd0};	//initialize indx

genvar ai, aj;
generate
	for(ai=1; ai<=3; ai=ai+1)begin : GEN_CMP_BLKI
		for(aj=0; aj < 4/ai; aj=aj+1)begin : GEN_CMP_BLKJ
			assign indx[ai][(aj+1)*3-1:aj*3] = (diff[indx[ai-1][aj*6+2:aj*6]][8]) ? indx[ai-1][aj*6+5:aj*6+3]: 		//if a<0 then output b
								(diff[indx[ai-1][aj*6+5:aj*6+3]][8]) ? indx[ai-1][aj*6+2:aj*6]: 	//if b<0 then output a
									(diff[indx[ai-1][aj*6+2:aj*6]] <= diff[indx[ai-1][aj*6+5:aj*6+3]]) ? indx[ai-1][aj*6+2:aj*6] :indx[ai-1][aj*6+5:aj*6+3]; //if a<=b then output a
		end
	end
endgenerate

//Fetch Input by index mention above
assign appr =  (diff[indx[3][2:0]][8]) ? XMEM[8]:
                  (diff[8][8]) ? XMEM[indx[3][2:0]]: 
		            (diff[indx[3][2:0]] <= diff[8]) ? XMEM[indx[3][2:0]] :XMEM[8];

//===========================//
// Output
//===========================//
assign isum2 = isum + 9*appr;		//output sum
assign Y = isum2/8;

endmodule
