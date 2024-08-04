module top(
    input clk,
    input rst,
    output sign,
    output [1:0] hundreds,
    output [6:0] seven_segment_out,
    output select, 
    inout line,
    //output error,
    output valid
);

reg [12:0] counter;

always @(posedge clk)
    counter <= counter + 1'b1;
wire [7:0] led_bits;
wire [15:0] digital;
reg [6:0] seven_segment_tens;
reg [6:0] seven_segment_units;

wire [3:0] tens, units;
//wire [1:0] hundreds;
wire [7:0] remains;

assign hundreds = led_bits / 100;
assign remains = led_bits % 100;
assign tens = remains / 10;
assign units = remains % 10; 
assign led_bits = digital[11] ? ( ~ digital[11:4] + 1'b1 ) : digital[11:4]; // display bits
assign sign = digital[11];
assign select = counter[12]; // assign signal, that do dynamic shift 
assign seven_segment_out = counter[12] ? ~seven_segment_tens : ~seven_segment_units; // shifting between tens and units 
always @(*)
begin
    seven_segment_tens = 7'dx;
    case(tens)
    4'd0: seven_segment_tens = 7'b1111_110;
    4'd1: seven_segment_tens = 7'b0110_000;
    4'd2: seven_segment_tens = 7'b1101_101;
    4'd3: seven_segment_tens = 7'b1111_001;
    4'd4: seven_segment_tens = 7'b0110_011;
    4'd5: seven_segment_tens = 7'b1011_011;
    4'd6: seven_segment_tens = 7'b1011_111;
    4'd7: seven_segment_tens = 7'b1110_000;
    4'd8: seven_segment_tens = 7'b1111_111;
    4'd9: seven_segment_tens = 7'b1111_011;
    default: seven_segment_tens = 7'dx;    
    endcase
end

always @(*)
begin
    seven_segment_units = 7'dx;
    case(units)
    4'd0: seven_segment_units = 7'b1111_110;
    4'd1: seven_segment_units = 7'b0110_000;
    4'd2: seven_segment_units = 7'b1101_101;
    4'd3: seven_segment_units = 7'b1111_001;
    4'd4: seven_segment_units = 7'b0110_011;
    4'd5: seven_segment_units = 7'b1011_011;
    4'd6: seven_segment_units = 7'b1011_111;
    4'd7: seven_segment_units = 7'b1110_000;
    4'd8: seven_segment_units = 7'b1111_111;
    4'd9: seven_segment_units = 7'b1111_011;
    default: seven_segment_units = 7'dx;    
    endcase
end

 wire rd_strb; 
 wire slave_presence; 
 wire wr, rd;
 wire [7:0] m_data_i;
 wire [7:0] m_data_o;
 wire crc_rst;
 wire crc_en;
 wire [7:0] crc_data;
 wire major_data;
 wire s_busy;   
 wire s_error;
 wire check_convert;
 wire convert_done;
OneWireFSM ControlFSM(
    .clk(clk),
    .rst(rst),
    .check_convert(check_convert),
    .s_busy(s_busy),
    .s_error(s_error),
    .crc_data(crc_data),
    .m_data_i(m_data_i),
    .rd_strb(rd_strb),
    .slave_presence(slave_presence),
    .m_data_o(m_data_o),
    .wr(wr),
    .rd(rd),
    .crc_rst(crc_rst),
    .Temp(digital),
    .crc_en(crc_en),
    .data_valid(valid),
    .convert_done(convert_done)
);  
OneWireTXRX #(.FREQ(27)) RecieveTransmitModule( 
    .clk(clk),
	.rst(rst),
	.rd(rd),
	.wr(wr),
	.presence(slave_presence),
	.check_convert(check_convert),
	.data_i(m_data_o),
	.line(line),
	.busy(s_busy),
	.rd_strb(rd_strb),
	.error(s_error),
	.data_o(m_data_i),
	.major_data(major_data),
	.convert_done(convert_done)
);
CRC CRC8 (
    .clk(clk),
    .rst(crc_rst),
    .enable(crc_en), 
    .DataIn(major_data), 
    .DataOut(crc_data)
);
endmodule
