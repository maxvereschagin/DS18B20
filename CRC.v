module CRC(
	input clk,
	input rst,
	input DataIn,
	input enable,
	output reg [7:0] DataOut
);

always @(posedge clk)
	if(rst)
		DataOut <= 8'd0;
	else if(enable)
		begin
		DataOut[7] <= DataIn^DataOut[0];
		DataOut[6] <= DataOut[7];
		DataOut[5] <= DataOut[6];
		DataOut[4] <= DataOut[5];
		DataOut[3] <= (DataIn^DataOut[0])^DataOut[4];
		DataOut[2] <= (DataIn^DataOut[0])^DataOut[3];
		DataOut[1] <= DataOut[2];
		DataOut[0] <= DataOut[1];
		end
endmodule
