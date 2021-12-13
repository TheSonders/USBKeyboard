`timescale 1ns / 1ps
`default_nettype none

`define LEFT_CTRL       0
`define LEFT_SHIFT      1
`define LEFT_ALT        2
`define LEFT_GUI        3
`define RIGHT_CTRL      4
`define RIGHT_SHIFT     5
`define RIGHT_ALT       6
`define RIGHT_GUI       7
`define Key_CapsLock    8'h39
`define Key_ScrollLock  8'h47
`define Key_NumLock     8'h53

//ASCII codes of the letters supported by uppercase
`define	letterA			8'h41
`define	lettera			8'h61
`define	letterZ			8'h5A
`define	letterz			8'h7A
`define	letterENIE	8'hD1
`define	letterenie	8'hF1
`define	letterCEDILLA	8'hC7
`define	lettercedilla	8'hE7

//////////////////////////////////////////////////////////////////////////////////
// From USB Keycodes (0x07) to ASCII conversion
// Antonio Sánchez (@TheSonders)
//////////////////////////////////////////////////////////////////////////////////
module USB2ASCII(
    input wire clk,
    input wire [7:0]R0,
    input wire [7:0]R2,
    output reg [7:0] Result,
    output reg Key_CapsLock=0,
    output reg Key_ScrollLock=0,
    output reg Key_NumLock=0,
	output reg NewKey);

reg [7:0] keymap [383:0];
wire Key_AltGR=R0[`RIGHT_ALT];
wire Key_LeftShift=R0[`LEFT_SHIFT];
wire Key_RightShift=R0[`RIGHT_SHIFT];
reg [7:0]prevR2=0;
wire [7:0]ascii;

assign ascii = (Key_AltGR)?keymap [R2+256]:(Key_LeftShift|Key_RightShift)?keymap [R2+128]:keymap[R2];
  
initial 
	$readmemh ("Key_USB_Spanish.txt",keymap);
    
    
always @(posedge clk) begin
    prevR2<=R2;  
    if (prevR2!=R2)begin
        NewKey<=1;
        if (R2==`Key_CapsLock) Key_CapsLock<=~Key_CapsLock;
        else if (R2==`Key_ScrollLock) Key_ScrollLock<=~Key_ScrollLock;
        else if (R2==`Key_NumLock) Key_NumLock<=~Key_NumLock;
    end
    else NewKey<=0;
	if (Key_CapsLock^(Key_LeftShift|Key_RightShift)) begin
		if (ascii>=`lettera & ascii <=`letterz) Result<=(ascii & 8'hDF);
		else if (ascii==`letterenie) Result<= `letterENIE;
		else if (ascii==`lettercedilla) Result <= `letterCEDILLA;
		else Result<=ascii;
    end
	else begin
		if (ascii>=`letterA & ascii <=`letterZ) Result<=(ascii | 8'h20);
		else  if (ascii==`letterENIE) Result<= `letterenie;
		else	if (ascii==`letterCEDILLA) Result <= `lettercedilla;
		else Result<=ascii;
    end
end
    
endmodule
