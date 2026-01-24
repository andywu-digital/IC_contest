module triangle (clk, reset, nt, xi, yi, busy, po, xo, yo);
   input clk, reset, nt;
   input [2:0] xi, yi;
   output reg busy, po;
   output reg[2:0] xo, yo;
  
//=============================//
// Wire & Reg
//=============================//
//Input Memory
reg [2:0] IMEMX [0:2];		//memory of x coordinate
reg [2:0] IMEMY [0:2];		//memory of y coordinate
reg [2:0] i_counter;

//Triangle rendering
wire x2_direction;		//flag = 0 means (x2, y2) lie in the left side

reg [5:0] f_counter;		//counter for sweeping coordinate
wire [2:0] x, y;		//coordinate

reg flag1, flag2, flag3;	

reg signed [3:0] x_diff_12, y_diff_12, x_diff_1, y_diff_1;
reg signed [7:0] m11, m12, m13;
reg signed [7:0] a1;

reg signed [3:0] x_diff_23, y_diff_23, x_diff_3, y_diff_3;
reg signed [7:0] m21, m22, m23;
reg signed [7:0] b1;

reg busy_flag;

//=============================//
// Input Memory
//=============================//
//Memory
integer i;
always @(posedge clk or posedge reset)begin
	if(reset)begin
		for(i=0; i<3; i=i+1)begin
			IMEMX[i] <= 'd0;
			IMEMY[i] <= 'd0;	
		end
	end
	else if(i_counter < 'd3)begin	//loading three coordinate
		IMEMX[i_counter] <= xi;
		IMEMY[i_counter] <= yi;
	end

end


//counter for input memory
always @(posedge clk or posedge reset)begin
	if(reset)begin
		i_counter <= 'd0;
	end
	else if(nt)begin			//start loading
		i_counter <= 'd1;
	end
	else if(f_counter == 'd63)begin		//Initialize
		i_counter <= 'd0;
	end
	else if(i_counter == 'd3)begin		//Maintain
		i_counter <= i_counter;
	end
	else begin				//loading
		i_counter <= i_counter + 'd1;
	end
end
		

//=============================//
// Triangle rendering (function)
//=============================//
//x2 direction
assign x2_direction = (IMEMX[1] > IMEMX[0]) ? 'd1 : 'd0;

//counter for sweeping coordinate
always @(posedge clk or posedge reset)begin
	if(reset)begin
		f_counter <= 'd0;
	end
	else if(nt)begin
		f_counter <= 'd0;		//Initialize
	end
	else if(i_counter == 'd3)begin		//Counting
		if(f_counter == 'd63)begin	//Stop counting
			f_counter <= f_counter;
		end
		else begin
			f_counter <= f_counter + 'd1;
		end
	end
end

//generate coordinate
assign x = f_counter[2:0];
assign y = f_counter[5:3];

//line 1 (straight line)
always @(*)begin
	if(x2_direction)begin
		if(x >= IMEMX[0])begin
			flag1 = 'd1;
		end
		else begin
			flag1 = 'd0;
		end
	end
	else begin
		if(x <= IMEMX[0])begin
			flag1 = 'd1;
		end
		else begin
			flag1 = 'd0;
		end
	end
end

//line 2 (bottom line)
always @(*)begin
	x_diff_12 = $signed({1'd0, IMEMX[1]}) - $signed({1'd0, IMEMX[0]});
	y_diff_12 = $signed({1'd0, IMEMY[1]}) - $signed({1'd0, IMEMY[0]});
	x_diff_1 = $signed({1'd0, x}) - $signed({1'd0, IMEMX[0]});
	y_diff_1 = $signed({1'd0, y}) - $signed({1'd0, IMEMY[0]});
	m11 = x_diff_1*y_diff_12;
	m12 = y_diff_1*x_diff_12;
	a1 = m11 - m12;

end

always @(*)begin
	if(x2_direction)begin
		if(a1[7] == 'd0)begin
			flag2 = 'd0;
		end
		else begin
			flag2 = 'd1;
		end
	end
	else begin
		if(a1[7] == 'd0)begin
			flag2 = 'd1;
		end
		else begin
			flag2 = 'd0;
		end
	end
end

//line 3 (upper line)
always @(*)begin
	x_diff_23 = $signed({1'd0, IMEMX[1]}) - $signed({1'd0, IMEMX[2]});
	y_diff_23 = $signed({1'd0, IMEMY[1]}) - $signed({1'd0, IMEMY[2]});
	x_diff_3 = $signed({1'd0, x}) - $signed({1'd0, IMEMX[2]});
	y_diff_3 = $signed({1'd0, y}) - $signed({1'd0, IMEMY[2]});
	m21 = x_diff_3*y_diff_23;
	m22 = y_diff_3*x_diff_23;
	m23 = y_diff_3*y_diff_23;
	b1 = m21 - m22;
end

always @(*)begin
	if(x2_direction)begin
		if(b1[7] == 'd0)begin
			flag3 = 'd1;
		end
		else begin
			flag3 = 'd0;
		end
	end
	else begin
		if(b1[7] == 'd0)begin
			flag3 = 'd0;
		end
		else begin
			flag3 = 'd1;
		end
	end
end


//=============================//
// Output
//=============================//

//po
always @(posedge clk or posedge reset)begin
	if(reset)begin
		po <= 'd0;
	end
	else if(i_counter != 'd3)begin		//Idle
		po <= 'd0;
	end
	else if((flag1 && flag2 && flag3) || ((a1 == 'd0) || (b1 == 'd0)))begin
		po <= 'd1;
	end
	else begin
		po <= 'd0;
	end
	
end

//xo yo
always @(posedge clk or posedge reset)begin
	if(reset)begin
		xo <= 'd0;
		yo <= 'd0;
	end
	else begin
		xo <= x;
		yo <= y;
	end
end

//busy
always @(posedge clk or posedge reset)begin
	if(reset)begin
		busy <= 'd0;
		busy_flag <= 'd0;
	end
	else if(nt || busy_flag)begin
		if(f_counter == 'd63 && busy_flag)begin
			busy <= 'd0;
			busy_flag <= 'd0;
		end
		else begin
			busy <= 'd1;
			busy_flag <= 'd1;
		end
	end
	else begin
		busy <= 'd0;
		busy_flag <= 'd0;
	end
end


endmodule
