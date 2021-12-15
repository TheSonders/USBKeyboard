// Text video driver
// http://tinyvga.com/vga-timing/640x480@60Hz
// Antonio Sánchez (@TheSonders)

// Data for 640x480@60Hz 25.175MHz pixel clock

// 16x16 pixels font
// 40 columns x 30 lines of text

// Video Ram Struct:
// [14]Cursor [13]Blink [12]Inverted Video [11:9]RGB Color [8]Intensity [7:0]ASCII Char

`define	BlinkPeriod	6'd60
`define	BlinkDuty	6'd50

`define	XVisible		640
`define	XFrontPorch	16
`define	XSync			96
`define	XBackPorch	48
`define	XTotal		800
`define	YVisible		480
`define	YFrontPorch	10
`define	YSync			2
`define	YBackPorch	33
`define	YTotal		525

`define	MCursor		14
`define	MBlink		13
`define	MInverted	12
`define	MRed			11
`define	MGreen		10
`define	MBlue			9
`define	MIntensity 	8

`define 	CBlack		12'h0

module Video_Driver (
	input sys_clk,we,
	input	[10:0] mem_addr,
	input [15:0] mem_data,
	output reg [15:0] ret_data,
	output VSync,HSync,
	output wire [3:0] Red,
	output wire [3:0] Green,
	output wire [3:0] Blue);
	
reg int_clk;
reg [9:0] HCounter=0;
reg [9:0] VCounter=0;
wire [10:0] RamPos;
reg [5:0] BlinkCounter=0;

reg [15:0] font [4095:0];
 initial 
	$readmemh ("monospace_font.txt",font);
	
reg [15:0] v_ram [1199:0];
 initial 
	$readmemh ("video_ram.txt",v_ram);

wire VisibleArea;
wire [11:0] Color;
wire Pixel,Blink;
reg [15:0]RamReg=0;

assign VisibleArea=((HCounter<`XVisible)&(VCounter<`YVisible))?1:0;
assign Red=(VisibleArea)?Color[11:8]:0;
assign Green=(VisibleArea)?Color[7:4]:0;
assign Blue=(VisibleArea)?Color[3:0]:0;

assign RamPos=((VCounter>>4)*40)+(HCounter>>4);
assign Blink=(BlinkCounter<`BlinkDuty)?1:0;

assign Pixel=((font[(RamReg[7:0])*16+(VCounter & 4'hF)] & (2<<(HCounter & 4'Hf)))>0)
				|(((VCounter & 10'hF)==10'hF) & RamReg[`MCursor] & Blink);
assign Color=(Pixel^(RamReg[`MInverted])) & (~RamReg[`MBlink] | Blink) & ((RamReg[7:0]>0) | RamReg[`MCursor])?
				(RamReg[`MIntensity])?
				{{4{(RamReg[`MRed])}},{4{(RamReg[`MGreen])}},{4{(RamReg[`MBlue])}}}:
				{1'b0,{3{(RamReg[`MRed])}},1'b0,{3{(RamReg[`MGreen])}},1'b0,{3{(RamReg[`MBlue])}}}:
				`CBlack;

assign HSync=(HCounter>(`XVisible+`XFrontPorch-1)) && (HCounter<(`XVisible+`XFrontPorch+`XSync)) ?0:1;
assign VSync=(VCounter>(`YVisible+`YFrontPorch-1)) && (VCounter<(`YVisible+`YFrontPorch+`YSync)) ?0:1;

always @(posedge sys_clk) int_clk=int_clk+1'b1;

always @(posedge int_clk) begin
	if (HCounter==`XTotal-1) begin
		HCounter<=0;
		if (VCounter==`YTotal-1) begin
			VCounter<=0;
			if (BlinkCounter==`BlinkPeriod) BlinkCounter<=0;
			else	BlinkCounter<=BlinkCounter+1;end
		else VCounter<=VCounter+1;end
	else HCounter<=HCounter+1;
end	

always @(negedge sys_clk) begin
	if (we) v_ram[mem_addr]<=mem_data;
	else ret_data<=v_ram[mem_addr];
    RamReg<= v_ram[RamPos];
end
endmodule

