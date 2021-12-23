// FPGA video driver project 2019
// Internally uses a PS/2 keyboard.
// Modified (Dec-2021) to test the USB->PS/2 keyboard conversion.
// Antonio Sánchez (@TheSonders)

module VideoText(
	input wire  sys_clk,
	inout wire  dp,
    inout wire  dm,
    
    output wire LED_1,
    output wire LED_2,
    
    output wire PS2data,
    output wire PS2clock,
    
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
//assign LED_2=(Device_Connected)?0:1;
assign LED_2=0;
assign LED_1=1;

always @(posedge clk50) VGA_CLK<=~VGA_CLK;

pll48 PLL(
    .sys_clk(sys_clk),
    .clk48(clk48),    
    .clk50(clk50));  

USB_PS2 USB (
    .clk(clk48), 
    .LedNum(0), 
    .LedCaps(0), 
    .LedScroll(0), 
    .dp(dp), 
    .dm(dm), 
    .PS2data(PS2data), 
    .PS2clock(PS2clock));
       
PS2ASCII PS2ASCII (
    .sys_clk(clk50), 
    .PS2Clk(PS2clock), 
    .PS2Data(PS2data), 
    .Result(Result), 
    .NewKey(NewKey));    

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
	.Blue(VGA_Blue)
    //.VisibleMouse(VisibleMouse),
    //.MouseX(MouseX),
    //.MouseY(MouseY)
    );	  

endmodule
