// FPGA video driver project 2019
// modified for USB Keyboard on 2021
// Antonio Sánchez (@TheSonders)

module VideoText(
	input wire  sys_clk,
	inout wire  dp,
    inout wire  dm,
    
    output wire LED_1,
    output wire LED_2,
    
	output wire VSync,
	output wire HSync,
    output reg VGA_CLK=0,
	output wire [3:0] VGA_Red,
	output wire [3:0] VGA_Green,
	output wire [3:0] VGA_Blue);

wire NewKey;
wire [7:0] Result;
wire [10:0] mem_addr;
wire [15:0] mem_data;
wire [15:0] ret_data;
wire we;
wire clk48,clk50;

wire Device_Connected;
assign LED_2=(Device_Connected)?0:1;
assign LED_1=1;

always @(posedge clk50) VGA_CLK<=~VGA_CLK;

///CLOCK CROSS DOMAIN ISSUE
wire [7:0] R0;
wire [7:0] R2;
reg [7:0] CDCR0=0;
reg [7:0] CDCR2=0;
reg [7:0] rR0=0;
reg [7:0] rR2=0;
//Slow to fast CD (double flop)
always @(posedge clk50) begin
    CDCR0<=R0;
    CDCR2<=R2;
    rR0<=CDCR0;
    rR2<=CDCR2;
end

wire Key_CapsLock;
wire Key_ScrollLock;
wire Key_NumLock;
reg LedCaps=0;
reg LedScroll=0;
reg LedNum=0;
always @(posedge clk48)begin
    LedCaps<=Key_CapsLock;
    LedScroll<=Key_ScrollLock;
    LedNum<=Key_NumLock;
end
//////////////////////////

pll48 PLL(
    .sys_clk(sys_clk),
    .clk48(clk48),    
    .clk50(clk50));   

USB_L1 USB (
    .clk(clk48),
    .LedNum(LedNum),
    .LedCaps(LedCaps),
    .LedScroll(LedScroll),
    .dp(dp),
    .dm(dm),
    .Rmodifiers(R0),
    .R0(R2),
    .Device_Connected(Device_Connected));

USB2ASCII USB2ASCII(
    .clk(clk50),
    .R0(rR0),
    .R2(rR2),
    .Result(Result),
	.NewKey(NewKey),
    .Key_CapsLock(Key_CapsLock),
    .Key_ScrollLock(Key_ScrollLock),
    .Key_NumLock(Key_NumLock));

Text_Editor Editor(
	.sys_clk(clk50),
	.NewKey(NewKey),
	.Ascii(Result),
	.mem_addr(mem_addr),
	.mem_data(mem_data),
	.we(we),
	.ret_data(ret_data));	 
	 
Video_Driver Video(
	.sys_clk(clk50),
	.we(we),
	.mem_addr(mem_addr),
	.mem_data(mem_data),
	.ret_data(ret_data),
	.VSync(VSync),
	.HSync(HSync),
	.Red(VGA_Red),
	.Green(VGA_Green),
	.Blue(VGA_Blue));	  

endmodule
