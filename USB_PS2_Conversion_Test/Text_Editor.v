`timescale 1ns / 1ps
`default_nettype none
// Simple text editor for testing
// Antonio Sánchez (@TheSonders)

// Each character require 16 bits
// Video Ram Struct:
// [14]Cursor [13]Blink [12]Inverted Video [11:8]RGBI Color [7:0]ASCII Char


// Masks for Set/Reset cursor
`define	ResetCursor		16'hBFFF
`define	SetCursor		16'h4000

// State Machine
`define 	WaitingKey		3'h0
`define	EraseCursor		3'h1
`define	UpdateCursor	3'h3
`define	FinishCursor	3'h4

`define	CWhite		3'h7
`define	CYellow		3'h6
`define	CMagenta		3'h5
`define	CRed			3'h4
`define	CCyan			3'h3
`define	CGreen		3'h2
`define	CBlue			3'h1
`define	BIntensity	0
`define	BInverted	4
`define	BBlink		5

`define	NULLCHAR		8'h00
`define	PAGEUP 		8'h01
`define	HOME			8'h02
`define	END			8'h03
`define	PAGEDN		8'h04
`define	BACKSPACE	8'h08
`define	TAB			8'h09
`define	RETURN		8'h0D
`define	UP				8'h11
`define	DOWN			8'h12
`define	LEFT			8'h13
`define	RIGHT			8'h14
`define	F1				8'h15
`define	F2				8'h16
`define	F3				8'h17
`define	F4				8'h18
`define	F5				8'h19
`define	F6				8'h1A
`define	F7				8'h1B
`define	F8				8'h1C
`define	F9				8'h1D
`define	F10			8'h1E
`define	F11			8'h1F
`define	DEL			8'h7F
`define	SPACE			8'h20
`define	TILDE			8'hB4
`define	DIERESIS		8'hA8

`define	MaxColumns	6'd40
`define	MaxRows		5'd28

module Text_Editor(
	input wire  sys_clk,
    input wire  NewKey,
	input wire  [7:0] Ascii,
	output reg [10:0] mem_addr=0,
	output reg [15:0] mem_data=0,
	output reg  we=0,
	input wire  [15:0]ret_data
    );
	 
reg [2:0] State=`WaitingKey;

reg [7:0] CurrentMode=8'h0F;
reg SignalDelete;
reg Tilde,Dieresis;

reg [5:0]Column=0;
reg [4:0]Row=0;

always @(posedge sys_clk) begin
case (State)
	`WaitingKey:
		if (NewKey) begin
			case (Ascii)
				`NULLCHAR:;
				`UP:
					if (mem_addr>11'd39) begin 
						mem_data=(mem_data & `ResetCursor);we=1;Row=Row-1;State=`EraseCursor;end
				`DOWN:
					if (mem_addr<11'd1080) begin 
						mem_data=(mem_data & `ResetCursor);we=1;Row=Row+1;State=`EraseCursor;end
				`LEFT:
					if (mem_addr>11'd0) begin 
						mem_data=(mem_data & `ResetCursor);we=1;
							if (Column>0) Column=Column-1;
							else begin Column=`MaxColumns-1;Row=Row-1;end
						State=`EraseCursor;end
				`RIGHT:
					if (mem_addr<11'd1119) begin 
						mem_data=(mem_data & `ResetCursor);we=1;
						if (Column==(`MaxColumns-1)) begin Column=0;Row=Row+1;end
						else Column=Column+6'd1;
						State=`EraseCursor;end
				`BACKSPACE:
					if (mem_addr>11'd0) begin 
						mem_data=(mem_data & `ResetCursor);we=1;
							if (Column) Column=Column-1;
							else begin Column=`MaxColumns-1;Row=Row-1;end
						State=`EraseCursor;SignalDelete=1;end
				`TILDE: begin
					Tilde=~Tilde;Dieresis=1'b0;end
				`DIERESIS: begin
					Dieresis=~Dieresis;Tilde=1'b0;end
				`RETURN: begin
					mem_data=(mem_data & `ResetCursor);we=1;Column=0;
					if (Row<(`MaxRows-1)) Row=Row+1;
					State=`EraseCursor;end
				`F1:  CurrentMode={CurrentMode[7:4],`CWhite,CurrentMode[0]};
				`F2:  CurrentMode={CurrentMode[7:4],`CYellow,CurrentMode[0]};
				`F3:  CurrentMode={CurrentMode[7:4],`CMagenta,CurrentMode[0]};
				`F4:  CurrentMode={CurrentMode[7:4],`CRed,CurrentMode[0]};
				`F5:  CurrentMode={CurrentMode[7:4],`CCyan,CurrentMode[0]};
				`F6:  CurrentMode={CurrentMode[7:4],`CGreen,CurrentMode[0]};
				`F7:  CurrentMode={CurrentMode[7:4],`CBlue,CurrentMode[0]};
				`F8:  CurrentMode[`BIntensity]=CurrentMode[`BIntensity]^1;
				`F9:  CurrentMode[`BInverted]=CurrentMode[`BInverted]^1;
				`F10: CurrentMode[`BBlink]=CurrentMode[`BBlink]^1;
				default:
					if (mem_addr<11'd1120) begin
						if (Tilde) begin
							mem_data=
							(Ascii==8'h41)?{CurrentMode,8'hC1}:
							(Ascii==8'h45)?{CurrentMode,8'hC9}:
							(Ascii==8'h49)?{CurrentMode,8'hCD}:
							(Ascii==8'h4F)?{CurrentMode,8'hD3}:
							(Ascii==8'h55)?{CurrentMode,8'hDA}:
							(Ascii==8'h61)?{CurrentMode,8'hE1}:
							(Ascii==8'h65)?{CurrentMode,8'hE9}:
							(Ascii==8'h69)?{CurrentMode,8'hED}:
							(Ascii==8'h6F)?{CurrentMode,8'hF3}:
							(Ascii==8'h75)?{CurrentMode,8'hFA}:		
							{CurrentMode,Ascii};
							Tilde=1'b0;Dieresis=1'b0;
						end
						else if (Dieresis) begin
							mem_data=
							(Ascii==8'h41)?{CurrentMode,8'hC4}:
							(Ascii==8'h45)?{CurrentMode,8'hCB}:
							(Ascii==8'h49)?{CurrentMode,8'hCF}:
							(Ascii==8'h4F)?{CurrentMode,8'hD6}:
							(Ascii==8'h55)?{CurrentMode,8'hDC}:
							(Ascii==8'h61)?{CurrentMode,8'hE4}:
							(Ascii==8'h65)?{CurrentMode,8'hEB}:
							(Ascii==8'h69)?{CurrentMode,8'hEF}:
							(Ascii==8'h6F)?{CurrentMode,8'hF6}:
							(Ascii==8'h75)?{CurrentMode,8'hFC}:		
							{CurrentMode,Ascii};
							Tilde=1'b0;Dieresis=1'b0;
						end						
						else begin
							mem_data={CurrentMode,Ascii};
						end
						if (mem_addr<11'd1119) begin 
								if (Column==(`MaxColumns-1)) begin Column=0;Row=Row+1;end
								else Column=Column+6'd1; end
						State=`EraseCursor;we=1;
					end
			endcase  //Ascii			
		end
	`EraseCursor: begin
		we=0;mem_addr=Row*40 + Column;
		State=`UpdateCursor;end
	`UpdateCursor: begin
		if ((ret_data[7:0]==8'h00) || (SignalDelete)) begin  // Memory not initialized or delete character
			mem_data=({CurrentMode,`NULLCHAR} | `SetCursor);
			SignalDelete=0;end
		else mem_data=(ret_data | `SetCursor);
		we=1;State=`FinishCursor;end
	`FinishCursor: begin
		we=0;State=`WaitingKey;end	
endcase  //State
end

endmodule
