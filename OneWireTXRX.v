module OneWireTXRX(
	input clk,
	input rst,
	input rd,
	input wr,
	input presence,
	input check_convert,
	input [7:0] data_i,
	inout line,
	output busy,
	output rd_strb,
	output reg error,
	output [7:0] data_o,
	output major_data,
	output reg convert_done
);

reg [2:0] state;
reg [31:0] timer;
reg line_en;
reg [7:0] receive_data;
reg [7:0] transmit_data;
reg [3:0] bit_counter;
reg  slave_ready;
reg [2:0] major_sel;
assign major_data = (major_sel[2] & major_sel[1]) | (major_sel[2] & major_sel[0]) | (major_sel[1] & major_sel[0]);
localparam [2:0] s_wait = 3'd0, s_presence = 3'd1,
				 s_write_byte = 3'd2, s_write_zero = 3'd3, s_write_one = 3'd4, 
				 s_read_line = 3'd5, s_check_convert = 3'd6;

parameter FREQ = 48; // �������� ������� 
localparam ReadTime          = 5    * FREQ;		// 5 ��� - ����� ��������� ����� � 0 ��� ������ ������ ������ �� ������� �����������
localparam ReadTimeSlot      = 65   * FREQ;	    // 65 ��� - ����� ����� ������ � ������ ������� �� �������� ����� � 5 ���
localparam ReadTakeTime      = 15   * FREQ;		// 15 ��� - ����� ������� ������ � ����� 1-wire
localparam WriteZeroTime     = 60   * FREQ;		// �������� ���������� 0, 60 ���
localparam WriteOneTime      = 5    * FREQ;		// �������� ���������� 1, 5 ���
//localparam TimeSlotPause     = 5    * FREQ; 	// ����� ����� ������� ������, 5 ���
localparam WriteTimeSlot     = 65   * FREQ;     // 65 ��� - ����� ����� ������ � ������ ������� �� �������� ����� � 5 ���  
localparam PresenceTime      = 720  * FREQ; 	// 720 ��� - ����� ����������� ������� �� ����� 
localparam PresenceCheckTime = 780  * FREQ;	    // 780 ��� - ����� �����, ������� ����� ������ ��������� ������� ������ �� ����� 
localparam PresenceTimeSlot  = 1020 * FREQ; 	// 1020 ��� - ����� �����, ������� ����� ������ �� ������� ������ �� ������   
//localparam PresenceTimeClear = 1080 * FREQ;     // 1080 ��� - ����� �����, ������� ����� ������������ ����� ������ ������  
localparam TimeForMajorSel   = 1    * FREQ;     // 1 ��� - �������� ������ ����� ��� ������������ �������� 
assign line = line_en ? 1'b0 : 1'bz; // ���������� ����� � 3-� ���������� 
assign rd_strb = (state == s_read_line) & (timer == ReadTakeTime + 2*TimeForMajorSel); // � ��������� ������ ����� � ������� ������� ������, ������������� ����� ��� ������ ������ 
assign busy = ~(state == s_wait); // ������-���������� �������� � ����� ��������� �������: ������, ������, �����/����������� 
assign data_o = transmit_data; // ��������� ������� � ����������� ������� � ��������� ���������� 

always @(posedge clk)
begin
	if(rst) 
		state <= s_wait;
	else 
	begin
		case(state)
		s_presence:
		begin
		    convert_done <= 1'b0;
			timer <= timer + 1'b1;
			if(timer == PresenceTimeSlot)
				begin
				state <= s_wait;
				if(slave_ready) error <= 1'b0;
				else error <= 1'b1;
				end
			else if(timer < PresenceTime)
				line_en <= 1'b1;
			else if((PresenceTime < timer) & (timer < PresenceCheckTime)) 
			    line_en <= 1'b0;
			else if(timer > PresenceCheckTime)
			    begin
				if(~line) slave_ready <= 1'b1;
				line_en <= 1'b0;
				end	
		end
		s_wait:
		begin
		    slave_ready <= 1'b0;
		    line_en <= 1'b0; // ���������� ����� 
			bit_counter <= 4'd0;
			timer <= 32'd0;
			transmit_data <= 8'd0;
			timer <= 32'd0;
			receive_data <= 8'd0;
			if(presence) state <= s_presence;
			else if(rd) state <= s_read_line;
			else if(wr)
			begin
				state <= s_write_byte;
				receive_data <= data_i; // caienaou aaeo a i?aia?aciaaoaeu ia?aeeaeuiiai eiaa a iineaaiaaoaeuiue 
			end
			else if(check_convert) 
				state <= s_check_convert;
		end
		s_write_byte:
		begin
		    convert_done <= 1'b0;
			timer <= 32'd0;
			if (bit_counter == 4'd8)  state <= s_wait; // ����� �������� ����, ��������� � ��������� �������� ��������� ������� 
			else if(receive_data[0])  state <= s_write_one;
			else if(~receive_data[0]) state <= s_write_zero;
		end
		s_write_zero:
		begin
			timer <= timer + 1'b1;
			if(timer == WriteTimeSlot) // �� ��������� ������� ��� ������ 0, ������� ��������� � ���������� ��������� 
			begin
				state <= s_write_byte;
				receive_data <= {1'b0, receive_data[7:1]};
				bit_counter <= bit_counter + 1'b1;
			end
			else if(timer < WriteZeroTime)
				line_en <= 1'b1;
			else if(timer > WriteZeroTime)
				line_en <= 1'b0;
		end
		s_write_one:
		begin
			timer <= timer + 1'b1;
			if(timer == WriteTimeSlot)
			begin
				state <= s_write_byte;
				receive_data <= {1'b0, receive_data[7:1]};
				bit_counter <= bit_counter + 1'b1;
			end
			else if(timer < WriteOneTime)
				line_en <= 1'b1;
			else if(timer > WriteOneTime)
				line_en <= 1'b0;
		end
		s_read_line:
		begin
		    convert_done <= 1'b0;
			timer <= timer + 1'b1;
			if(timer == ReadTimeSlot)
			begin
				timer <= 32'd0;
				if(bit_counter == 4'd8)
					state <= s_wait;	
			end
			else if(timer == ReadTakeTime)
			    major_sel <= {line, major_sel[2:1]};
			else if(timer == ReadTakeTime + TimeForMajorSel) 
                major_sel <= {line, major_sel[2:1]};
			else if(timer == ReadTakeTime + 2*TimeForMajorSel)
			begin 
                major_sel <= {line, major_sel[2:1]};
                bit_counter <= bit_counter + 1'b1;
				if(bit_counter <= 8)
				transmit_data <= {major_data, transmit_data[7:1]}; 
			end
			else if(timer < ReadTime)
				line_en <= 1'b1;
			else if(timer > ReadTime)
				line_en <= 1'b0;
		end
		s_check_convert:
		begin
			convert_done <= 1'b0;
			if(timer < ReadTime)
			begin
				timer <= timer + 1'b1;
				line_en <= 1'b1;
			end
			else 
			begin
				line_en <= 1'b0;
				if(line)
				begin
					convert_done <= 1'b1;
					state <= s_wait;
				end
			end
		end
		default: state <= s_wait;
		endcase
	end
end
endmodule 
