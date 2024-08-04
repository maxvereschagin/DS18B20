module OneWireFSM(
    input clk,
    input rst, 
    input s_busy,
    input [7:0] crc_data,
    input [7:0] m_data_i,
    input rd_strb,
    input convert_done,
    input s_error,
    output reg slave_presence,
    output reg [7:0] m_data_o,
    output wr,
    output rd,
    output reg crc_rst,
    output reg [15:0] Temp,
    output crc_en,
    output data_valid,
    output reg check_convert
);
localparam [2:0] s_reset = 3'd0, s_presence = 3'd1, s_init = 3'd2, s_start_convert = 3'd3, s_wait_conv = 3'd4, s_read_scratchpad = 3'd5, s_read_data = 3'd6;
reg [2:0] state;
reg [3:0] bytes_counter;
reg [7:0] tempL;
reg [7:0] tempH;
reg [7:0] CRC;
reg [7:0] InitData [4:0]; // �������� � ������� ��� ������������ 
reg [7:0] ConvertData [1:0]; // �������� � ������� ��� ������ �������������� 
reg [7:0] ReadData [1:0]; // �������� � ������� ��� ������ ������ 
reg slave_init;
integer i;
assign wr = ~s_busy & ((state == s_init & bytes_counter < 5) | (state == s_start_convert & bytes_counter < 2) | (state == s_read_scratchpad & bytes_counter < 2));
assign rd = ~s_busy & (state == s_read_data & bytes_counter < 9);
    
always @(posedge clk)
if(rst)
    state <= s_reset;
else 
    begin
        case(state)
        s_reset: 
        begin
            slave_presence <= 1'b1;
            state <= s_presence; 
            slave_init <= 1'b0;
        end
        s_presence:
        begin
            crc_rst <= 1'b0;
            bytes_counter <= 4'd0; 
            InitData[4] <= 8'hCC;
            InitData[3] <= 8'h4E;
            InitData[2] <= 8'hFF;
            InitData[1] <= 8'hFF;
            InitData[0] <= 8'h1F;  
            ConvertData[1] <= 8'hCC;
            ConvertData[0] <= 8'h44;
            ReadData[1] <= 8'hCC;
            ReadData[0] <= 8'hBE;
            slave_presence <= 1'b0;
            if(~s_busy) 
            begin
            if(s_error) state <= s_reset;
            if(~slave_init) state <= s_init;
            else if(convert_done) state <= s_read_scratchpad;
            else state <= s_start_convert; // ���� ����������� ���� error, �� ��������� � s_busy � �������� ������ 
            end
        end
        s_init:
        begin
            if(~s_busy) 
            begin
                slave_init <= 1'b1;
                bytes_counter <= bytes_counter + 1'b1;
                if(bytes_counter == 5)
                begin
                    state <= s_presence;
                    slave_presence <= 1'b1;
                end
                else if(bytes_counter < 5)
                begin
                    InitData[0] <= 8'd0;
                    for(i = 4; i > 0; i=i-1) InitData[i] <= InitData[i-1];
                end
            end
        end
        s_start_convert:
		begin
            if(bytes_counter == 2) 
            begin
                if(~s_busy) 
                begin
                state <= s_wait_conv;
                check_convert <= 1'b1;
                end
            end
            else if(bytes_counter < 2) begin    
                if(~s_busy)
                begin
                    bytes_counter <= bytes_counter + 1'b1;
                    ConvertData[1] <= ConvertData[0];
                    ConvertData[0] <= 8'd0; 
                end
            end   
        end
        s_wait_conv:
        begin
            check_convert <= 1'b0;
            slave_presence <= 1'b0;
            if(convert_done)
            begin
                state <= s_presence;
                slave_presence <= 1'b1;
            end
        end
        s_read_scratchpad:
        begin
            if(~s_busy)
            begin
                bytes_counter <= bytes_counter + 1'b1;
                if(bytes_counter == 2)
                begin
                    state <= s_read_data;
                    crc_rst <= 1'b1;
                    bytes_counter <= 4'd0;
                end
                else if(bytes_counter < 2)
                begin
                    ReadData[1] <= ReadData[0];
                    ReadData[0] <= 8'd0; 
                end
            end
        end
        s_read_data:
        begin
            crc_rst <= 1'b0;
            if(~s_busy)
            begin
                bytes_counter <= bytes_counter + 1'b1;
                if(bytes_counter == 9)
                begin
                    state <= s_presence;
                    slave_presence <= 1'b1;
                end
            end
        end
        default: state <= s_reset;
        endcase
    end
    
always @(posedge clk)
if(crc_rst)
    tempL <= 8'd0;//8'hFF;
else if(((state == s_read_data) & (bytes_counter == 4'd1)) & ~s_busy) // ����� ���������� ���������� ����� ������� ����� � ������ �� ������� 
    tempL <= m_data_i;

always @(posedge clk)
if(crc_rst)
    tempH <= 8'd0;//8'hFF;
else if(((state == s_read_data) & (bytes_counter == 4'd2)) & ~s_busy)
    tempH <= m_data_i;
    
always @(posedge clk)
if(crc_rst)
    CRC <= 8'd0;
else if(((state == s_read_data) & (bytes_counter == 4'd9)) & ~s_busy)
    CRC <= m_data_i;   

always @(posedge clk)
//if(rst)
//    Temp <= 16'hFFFF;
if(data_valid)
    Temp <= {tempH, tempL};    

//assign Temp = {tempH, tempL};
assign data_valid = (state != s_read_data) & (CRC == crc_data); // ���� ����������� ����� ������� � CRC �� ����� 0, �� ������� ���� ����� ��������. �� ���������� � ��� ������, ����� crc_data ����� ������� 
assign crc_en = (bytes_counter < 4'd9) ? rd_strb : 1'b0;


always @(state, InitData[4], ConvertData[1], ReadData[1]) // �������������, ���������� ����� ������ ��������� �� ���� 
begin
    case(state)
    s_init:      m_data_o = InitData[4];
    s_start_convert:   m_data_o = ConvertData[1];
    s_read_scratchpad: m_data_o = ReadData[1];
    default:           m_data_o = 8'h00;
    endcase
end

endmodule
