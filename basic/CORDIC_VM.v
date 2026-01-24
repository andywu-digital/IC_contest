`timescale 1ns / 1ps

module CORDIC_VM #(
	//u wordlength //default Q1.8 
	parameter U_WL = 9,	   //u wordlength 
	parameter U_F  = 8,	   //u fractional bit

	//phase wordlength //default Q4.7
	parameter P_WL = 11,	//phase wordlength
	parameter P_F = 7,	    //phase fractional bit

	//CORDIC iteration //default 5
	parameter ITER = 5
)(
	input wire signed [U_WL-1:0] i_u_real, i_u_imag,
	output wire signed [P_WL-1:0] o_phase	
);

//===============================//
// Wire & Reg
//===============================//
//Rotational angle
wire signed [24:0] pi_2;
wire signed [24:0] atan2 [0:10];

assign pi_2 = 25'b0000000001100100100010000;   		//pi/2, Q10.15 

assign  atan2[0] = 25'b0000000000110010010001000;	//atan(2^(indx)), Q10.15	
assign  atan2[1] = 25'b0000000000011101101011001;
assign  atan2[2] = 25'b0000000000001111101011011;
assign  atan2[3] = 25'b0000000000000111111101011;
assign  atan2[4] = 25'b0000000000000011111111101;
assign  atan2[5] = 25'b0000000000000010000000000;
assign  atan2[6] = 25'b0000000000000001000000000;
assign  atan2[7] = 25'b0000000000000000100000000;
assign  atan2[8] = 25'b0000000000000000010000000;
assign  atan2[9] = 25'b0000000000000000001000000;
assign  atan2[10] = 25'b0000000000000000000100000;

//Pre & Iterative Rotation
reg signed [U_WL-1:0] u_real [0:ITER];
reg signed [U_WL-1:0] u_imag [0:ITER];
reg signed [P_WL-1:0] phase [0:ITER];

//===============================//
// Pre-Rotation
//===============================//
always @(*)begin
	if(~i_u_real[U_WL-1])begin
		//no rotation
		u_real[0] = i_u_real;
		u_imag[0] = i_u_imag;
		phase[0] = 'd0;
	end
	else begin
		if(~i_u_imag[U_WL-1])begin
			u_real[0] = i_u_imag;
			u_imag[0] = -i_u_real;
			phase[0] = $signed(pi_2[14-P_F+P_WL:15 -P_F]);
		end
		else begin
			u_real[0] = -i_u_imag;
			u_imag[0] = i_u_real;
			phase[0] = -$signed(pi_2[14-P_F+P_WL:15-P_F]);
		end
	end
end

//================================//
// Iterative Rotation 
//================================//
genvar iter;

generate
	for(iter = 1; iter <=ITER; iter = iter+1)begin : GEN_ITER_BLOCK
		always @(*)begin
			if(~u_imag[iter-1][U_WL-1])begin
				u_real[iter] = u_real[iter-1] + $signed((u_imag[iter-1] >>> (iter-1)));
				u_imag[iter] = u_imag[iter-1] - $signed((u_real[iter-1] >>> (iter-1)));
				phase[iter] = phase[iter-1] + $signed(atan2[iter-1][14-P_F+P_WL:15-P_F]);
			end
			else begin
				u_real[iter] = u_real[iter-1] - $signed((u_imag[iter-1] >>> (iter-1)));
				u_imag[iter] = u_imag[iter-1] + $signed((u_real[iter-1] >>> (iter-1)));
				phase[iter] = phase[iter-1] - $signed(atan2[iter-1][14-P_F+P_WL:15-P_F]);
			end
	   end
	end
endgenerate

//===============================//
// Output phase
//===============================//
assign o_phase = phase[ITER];

endmodule
