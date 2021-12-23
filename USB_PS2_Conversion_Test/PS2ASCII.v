//PS/2 keyboard driver
//Returns ASCII code from the pressed key
//Antonio Sánchez


//Constants for the State Machine
`define 	StartBit			4'd0
`define 	ParityBit		4'd9
`define 	StopBit			4'd10

`define 	ExtKey			8'hE0		//Extended keys require 2 bytes keycode
`define	Break				8'hF0		//Release of a key

`define	Key_LeftShift	8'h12		//Keycodes for some special keys
`define	Key_RightShift	8'h59
`define	Key_AltGR		8'h91
`define	Key_CapsLock	8'h58


//ASCII codes of the letters supported by uppercase
`define	letterA			8'h41
`define	lettera			8'h61
`define	letterZ			8'h5A
`define	letterz			8'h7A
`define	letterENIE	8'hD1
`define	letterenie	8'hF1
`define	letterCEDILLA	8'hC7
`define	lettercedilla	8'hE7

// NewKey output indicates a new char available
// The last outputs are only required to show them on the board's LEDs
module PS2ASCII(
	input wire sys_clk,
	input wire PS2Clk,
	input wire PS2Data,
	output reg [7:0] Result,
	output reg NewKey);

reg Key_LeftShift=0;
reg Key_RightShift=0;
reg Key_AltGR=0;
reg Key_CapsLock=0;
reg [3:0] CharState=0;
reg [7:0] Char=0;
reg [7:0] KeyCode=0;
reg EOC,Parity;
reg Extended,Release,EOK;
wire [7:0] ascii;
reg intPS2Clk,intPS2Data;
reg RiseEOC,RiseEOK;

reg [3:0]debPS2Clk;
reg [3:0]debPS2Data;

reg [7:0] keymap [767:0];
assign ascii = (Key_AltGR)?keymap [KeyCode+512]:(Key_LeftShift|Key_RightShift)?keymap [KeyCode+256]:keymap[KeyCode];
  
initial 
	$readmemh ("Key_PS2_Spanish.txt",keymap);

// This block acts as a low pass filter to debounce noisy signals
// Just the signals with a minimun length are recognized
//	PS2Clk  ==>   FILTER   ==>  intPS2Clk
//	PS2Data ==>   FILTER   ==>  intPS2Data
always @(posedge sys_clk) begin
	debPS2Clk<=debPS2Clk+((PS2Clk)?(debPS2Clk<4'hF)?1:0:(debPS2Clk>4'h0)?-4'h1:4'h0);
	debPS2Data<=debPS2Data+((PS2Data)?(debPS2Data<4'hF)?1:0:(debPS2Data>4'h0)?-4'h1:4'h0);
	intPS2Clk<=(debPS2Clk==4'hF)?1'b1:(debPS2Clk==4'h0)?1'b0:intPS2Clk;
	intPS2Data<=(debPS2Data==4'hF)?1'b1:(debPS2Data==4'h0)?1'b0:intPS2Data;end


// Deserializer
// intPS2Clk + intPS2Data	==> STATE MACHINE	==> Char
always @ (negedge intPS2Clk)
begin
case (CharState)
		`StartBit: begin 
			Char<=8'h00;EOC<=0;Parity<=0;
			if (!intPS2Data) CharState<=4'd1;end
		`ParityBit: begin 
			if (Parity^intPS2Data)CharState<=`StopBit;
			else CharState<=`StartBit;end
		`StopBit:	begin
			CharState<=`StartBit;
			if (intPS2Data)EOC<=1;end
		default:	begin 
			Char<={intPS2Data,Char[7:1]};
			CharState<=CharState+1'b1;
			Parity<=Parity^intPS2Data;end
		endcase
end


// Char + previous flags  ==> KeyCode + Shift flags
// EOK is only one cycle long, use RiseEOC to detect posedge of EOC
always @ (posedge sys_clk)
begin
	if (EOC & ~RiseEOC) begin
		RiseEOC<=1'b1;
		if (Char==`ExtKey) Extended<=1'b1;
		else	if (Char==`Break) Release<=1'b1;
		else begin
			if (Release) begin
				Key_LeftShift <= (Char==`Key_LeftShift)?0:Key_LeftShift;
				Key_RightShift	<=(Char==`Key_RightShift)?0:Key_RightShift;
				Key_AltGR <=  ({Extended||Char[7],Char[6:0]}==`Key_AltGR)?0:Key_AltGR;end
			else begin
				case ({Extended||Char[7],Char[6:0]})
					`Key_LeftShift: Key_LeftShift<=1;
					`Key_RightShift: Key_RightShift<=1;
					`Key_AltGR : Key_AltGR<=1;
					`Key_CapsLock : Key_CapsLock<=~Key_CapsLock;
					default : begin 
						KeyCode<={Extended||Char[7],Char[6:0]};
						EOK<=1'b1;
						end
				endcase
			end
			Extended<=0;
			Release<=0;
		end
		end
	else
		EOK<=1'b0;
		if (~EOC)RiseEOC<=1'b0;
end


// CAPS Lock and some Spanish letters require special treatment
// If any Shift Key is pressed when CAPS is set, returns a lowercase
always @(posedge sys_clk)
begin
	NewKey<=EOK;
	if (Key_CapsLock^(Key_LeftShift|Key_RightShift)) begin
		if (ascii>=`lettera & ascii <=`letterz) Result<=(ascii & 8'hDF);
		else  if (ascii==`letterenie) Result<= `letterENIE;
		else	if (ascii==`lettercedilla) Result <= `letterCEDILLA;
		else Result<=ascii;end
	else begin
		if (ascii>=`letterA & ascii <=`letterZ) Result<=(ascii | 8'h20);
		else  if (ascii==`letterENIE) Result<= `letterenie;
		else	if (ascii==`letterCEDILLA) Result <= `lettercedilla;
		else Result<=ascii;end
end

endmodule
