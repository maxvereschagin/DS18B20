`timescale 1ns / 1ps

module top_tb;

    logic clk;
    logic rst;
    logic [15:0] Temp;
    tri1 line;
    logic valid;
    logic select;
    logic sign;
    logic [1:0] hundreds;
    logic [6:0] seven_segment_out;
    
top DUT(.*);
parameter real Freq = 27; // ������ �������� ������� � ��������� 
parameter real PERIOD = 1000/Freq;

initial begin
    $dumpfile("DS18B20.vcd");
    $dumpvars;
    #1.25s;
    $finish;
end

initial begin 
    clk <= '0;
    #(PERIOD/2);
    forever
    #(PERIOD/2) clk <= ~clk;
end

initial begin
    rst <= 'x;
    @(posedge clk);
    rst <= '0;
    @(posedge clk);
    rst <= 'x;
end

logic slave_presence;

assign line = slave_presence ? 1'b0 : 1'bz;

initial begin // ������������� ������ � ��������� ������ ������� 
    slave_presence <= 1'b0;
    wait(DUT.slave_presence);
    slave_presence <= 1'b0;
    #780us;
    slave_presence <= 1'b1;
    #180us; // �������� ����� ��������� ����� 
    slave_presence <= 1'b0;
end

task slave_responce_one (input int n); // ��� �����/������� ����� ��������� ������� ������� ��� ����� 
    for(int i = 0; i < n; i++) #60us;
endtask

task slave_responce_zero (input int n);
    for(int i = 0; i < n; i++) begin // ���� ������ 0 
        slave_presence <= 1'b1; // slave �������� ���� � 0
        #50us;
        slave_presence <= 1'b0; // slave ��������� ���� 
        #10us; //5us �� ��������, ��� 5 us �� ��������� ����� ������ ������ 
    end
endtask

logic [7:0] CRC_tb;

function calcCRC(input [7:0] data);
    byte unsigned inbyte;
    inbyte = data;
    for(int i = 0; i < 8; ++i) begin
        byte unsigned mix;
        mix = (CRC_tb ^ inbyte) & 'h01;
        CRC_tb >>= 1;
        if(mix) CRC_tb ^= 'h8C;
        inbyte >>= 1;
    end
endfunction

task convert_hex_to_bin (input [7:0] hex);
    for(int i = 0; i < 8; i++) begin 
        if(hex[i]) slave_responce_one(1);
        else slave_responce_zero(1);
    end
endtask
logic [7:0] data;

initial begin
    wait(DUT.check_convert);
    slave_presence <= 1'b1;
    #1ms;
    slave_presence <= 1'b0;
end

task slave_responce_data (input [7:0] temp);
    wait(DUT.rd);
    CRC_tb <= 8'h00;
    for(int i=0; i < 9; i++) begin
        calcCRC(data);
        case(i)
        0: data <= {temp[3:0], 4'd0};
        1: data <= {4'd0, temp[7:4]};
        2: data <= 8'hFF;
        3: data <= 8'hFF;
        4: data <= 8'h1F;
        5: data <= 8'hFF;
        6: data <= 8'hFF;
        7: data <= 8'hFF;
        8: data <= CRC_tb;
        endcase
        wait(~line);
        #5us; // ����� ����������� ������� �� �����
        //if(i < 8) calc_crc(data);
        if(line === '0) convert_hex_to_bin(data);
    end
endtask

initial begin
    forever begin 
        //wait(convert);
        wait(DUT.rd);
        for(int i = -55; i < 128; i++) begin
        slave_responce_data(i);
        //slave_responce_data($urandom_range(-8'd55, 8'd127));
        end
    end
end

endmodule
