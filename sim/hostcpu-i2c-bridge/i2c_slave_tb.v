`timescale 1ns / 1ps


// Example of I2C slave

// 8-bits IO extender controlled from I2C
// (c) 2005, 2008 fpga4fun.com, KNJN LLC
// modified 2011 for simulation in Xilinx ISE 10.1.03 , www.train-z.de, MBL

// Please define one of these before starting synthesis
`define Xilinx
//`define Altera

`timescale 1ns / 1ps

module i2c_slave_tb(sda, scl, out_valid, out);
inout        sda;
input        scl;
output       out_valid;
output [7:0] out;


// The 7-bits address that we want for our I2C slave
parameter I2C_ADR = 7'h39;

//////////////////////////
// I2C start and stop conditions detection logic
// That's the "black magic" part of this design...
// We use two wires with a combinatorial loop to detect the start and stop conditions
//  ... making sure these two wires don't get optimized away
`ifdef Xilinx
    BUF mybuf(
		.O(SDA_shadow),
		.I((~scl | start_or_stop) ? sda : SDA_shadow)
		);
    BUF SOS_BUF(
		.O(start_or_stop), 
		.I(~scl ? 1'b0 : (sda ^ SDA_shadow))
		); 
`else
    wire SDA_shadow = (~scl | start_or_stop) ? sda : SDA_shadow /* synthesis keep = 1 */;
    wire start_or_stop = ~scl ? 1'b0 : (sda ^ SDA_shadow) /* synthesis keep = 1 */;
`endif

//reg incycle;
reg incycle = 1'b0;  //for simulation MBL
always @(negedge scl or posedge start_or_stop) 
	if(start_or_stop) incycle <= 1'b0; 
	else if(~sda) incycle <= 1'b1;

//////////////////////////
// Now we are ready to count the I2C bits coming in
//reg [3:0] bitcnt;  // counts the I2C bits from 7 downto 0, plus an ACK bit
reg [3:0] bitcnt = 4'h0; //for simulation MBL
wire bit_DATA = ~bitcnt[3];  // the DATA bits are the first 8 bits sent
wire bit_ACK = bitcnt[3];  // the ACK bit is the 9th bit sent
//reg data_phase;
reg data_phase = 1'b0; //for simulation MBL

always @(negedge scl or negedge incycle)
if(~incycle)
begin
    bitcnt <= 4'h7;  // the bit 7 is received first
    data_phase <= 1'b0;
end
else
begin
    if(bit_ACK)
    begin
    	bitcnt <= 4'h7;
    	data_phase <= 1'b1;
    end
    else
    	bitcnt <= bitcnt - 4'h1;
end

// and detect if the I2C address matches our own
wire adr_phase = ~data_phase;
//reg adr_match, op_read, got_ACK;
reg adr_match = 1'b0, op_read = 1'b0 , got_ACK = 1'b0; //for simulation MBL
//reg SDAr;
reg SDAr = 1'b0; //for simulation MBL
always @(posedge scl) SDAr<=sda;  // sample sda on posedge since the I2C spec specifies as low as 0s hold-time on negedge
//reg [7:0] mem; 
reg [7:0] mem = 8'hFF; //for initial read access to slave and simulation MBL
wire op_write = ~op_read;

assign out_valid = ~(adr_match & bit_DATA & data_phase & op_write);

always @(negedge scl or negedge incycle)
if(~incycle)
begin
    got_ACK <= 1'b0;
    adr_match <= 1'b1;
    op_read <= 1'b0;
end
else
begin
    if(adr_phase & bitcnt==7 & SDAr!=I2C_ADR[6]) adr_match<=1'b0;
    if(adr_phase & bitcnt==6 & SDAr!=I2C_ADR[5]) adr_match<=1'b0;
    if(adr_phase & bitcnt==5 & SDAr!=I2C_ADR[4]) adr_match<=1'b0;
    if(adr_phase & bitcnt==4 & SDAr!=I2C_ADR[3]) adr_match<=1'b0;
    if(adr_phase & bitcnt==3 & SDAr!=I2C_ADR[2]) adr_match<=1'b0;
    if(adr_phase & bitcnt==2 & SDAr!=I2C_ADR[1]) adr_match<=1'b0;
    if(adr_phase & bitcnt==1 & SDAr!=I2C_ADR[0]) adr_match<=1'b0;
    if(adr_phase & bitcnt==0) op_read <= SDAr;
    if(bit_ACK) got_ACK <= ~SDAr;  // we monitor the ACK to be able to free the bus when the master doesn't ACK during a read operation

    if(adr_match & bit_DATA & data_phase & op_write) mem[bitcnt] <= SDAr;  // memory write
end


// and drive the sda line when necessary.
wire mem_bit_low = ~mem[bitcnt[2:0]];
wire SDA_assert_low = adr_match & bit_DATA & data_phase & op_read & mem_bit_low & got_ACK;
wire SDA_assert_ACK = adr_match & bit_ACK & (adr_phase | op_write);
wire SDA_low = SDA_assert_low | SDA_assert_ACK;
assign sda = SDA_low ? 1'b0 : 1'bz;

assign out = mem;
endmodule
