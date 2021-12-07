///////////////////////////////////////////////////////////////////////////
/*
MIT License

Copyright (c) 2021 Antonio Sánchez (@TheSonders)
THE EXPERIMENT GROUP (@agnuca @Nabateo @subcriticalia)

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

 USB Layer 1
 Versión reducida pero funcional de la interfaz de teclado USB
 -No realiza comprobación del CRC
 -Soporta sólo Low Speed devices 1.1Mpbs
 -Paquetes de transmisión precalculados

 Este módulo recibe y maneja directamente las líneas de transmisión USB.
 La señal de reloj recomendada es de 48MHz
 Entrega una señal que indica si hay un dispositivo conectado y reconocido
 Además de un byte con las teclas 8 modificadoras (Alt-WIN-Ctrl-Shift)
 Y 6 bytes con las teclas pulsadas
 Antonio Sánchez (@TheSonders)
 Referencias:
 -Ben Eater Youtube Video:
     https://www.youtube.com/watch?v=wdgULBpRoXk
 -USB Specification Revision 2.0
 -https://usb.org/sites/default/files/hut1_22.pdf
 -https://crccalc.com/
 -https://www.perytech.com/USB-Enumeration.htm
*/
///////////////////////////////////////////////////////////////////////////

//Speed mode
`define LowSpeed    0 
`define FullSpeed   1 

//READING WIRE STATES
`define DIF1    (dp==1 && dm==0)
`define DIF0    (dp==0 && dm==1)
`define SE0     (dp==0 && dm==0)
`define SE1     (dp==1 && dm==1)

//DATA STATES
`define J_State ((Device_Speed==`LowSpeed && `DIF0)|| (Device_Speed==`FullSpeed && `DIF1))
`define K_State ((Device_Speed==`LowSpeed && `DIF1)|| (Device_Speed==`FullSpeed && `DIF0))

//STM STATES
`define STM_Unconnected 0 
`define STM_Idle        1
`define STM_SOP         2
`define STM_PAYLOAD     3

//SYMBOLS
`define SYM_0   2'b00
`define SYM_1   2'b11
`define SYM_K   2'b10
`define SYM_J   2'b01

//
`define LineAsInput     0
`define LineAsOutput    1

module USB_L1 
    (input wire clk,
    inout wire dp,
    inout wire dm,
    output reg [7:0]Rmodifiers=8'h00,
    output reg [7:0]R0=8'h00,
    output reg [7:0]R1=8'h00,
    output reg [7:0]R2=8'h00,
    output reg [7:0]R3=8'h00,
    output reg [7:0]R4=8'h00,
    output reg [7:0]R5=8'h00,
    output reg Device_Connected=0);
    
`define PRES_LowSpeed   31
`define PRES_FullSpeed  3

assign dp=(IO==`LineAsInput)?1'hZ:rdp;
assign dm=(IO==`LineAsInput)?1'hZ:rdm;

reg Device_Speed=0;
reg rdp=0;
reg rdm=0;
reg IO=`LineAsInput;

////////////////////////////////////////////////////////////
//                     SYNC LAYER                         //
////////////////////////////////////////////////////////////
// Esta capa recibe directamente los datos de las líneas.
// Determina la velocidad del device y
// se sincroniza con los flancos en las líneas de datos
// Entrega a la capa superior los símbolos ya muestreados
////////////////////////////////////////////////////////////
reg [$clog2(`PRES_LowSpeed)-1:0]Prescaler_Reload=0;
reg [$clog2(`PRES_LowSpeed)-1:0]RX_Prescaler=0;
reg INSYNC_STM=0;
reg NewSymbol=0;
reg [1:0]RX_SYM=0;
reg Prev_Dp=0;
reg Prev_Dm=0;

always @(posedge clk) begin INSYNC:
    if (NewSymbol==1)NewSymbol<=0;
    Prev_Dp<=dp;
    Prev_Dm<=dm;
    if (MACHINE_RESET==1)begin
        INSYNC_STM<=`STM_Unconnected;
    end
    else begin
        case (INSYNC_STM)
            `STM_Unconnected:begin
            if (IO==`LineAsInput)begin
                if (`DIF0) begin 
                    Prescaler_Reload<=`PRES_LowSpeed;
                    Device_Speed<=`LowSpeed;
                    INSYNC_STM<=`STM_Idle;end
                else if (`DIF1) begin
                    Prescaler_Reload<=`PRES_FullSpeed;
                    Device_Speed<=`FullSpeed;
                    INSYNC_STM<=`STM_Idle;end
            end
            end
            `STM_Idle:begin Synchronizer_and_Sample:
                if (Prev_Dp!=dp || Prev_Dm!=dm) begin
                    RX_Prescaler<=(Prescaler_Reload>>1);
                end
                else if (RX_Prescaler==0)begin
                    RX_Prescaler<=Prescaler_Reload;
                    NewSymbol<=1;
                    if (`J_State) RX_SYM<=`SYM_J;
                    else if (`K_State)RX_SYM<=`SYM_K;
                    else if (`SE1)RX_SYM<=`SYM_1;
                    else if (`SE0)RX_SYM<=`SYM_0;
                end
                else RX_Prescaler<=RX_Prescaler-1;
            end
        endcase
    end
end

////////////////////////////////////////////////////////////
//                    SYMBOL LAYER                        //
////////////////////////////////////////////////////////////
// Esta capa recibe los cuatro símbolos ya muestrados.
// Recorta las tramas SYNC, SOP y EOP y filtra el bit stuff.
// Entrega a la capa superior los bits equivalentes 
// del payload, y las señales Start of Packet y End of Packet
////////////////////////////////////////////////////////////
reg [1:0]Prev_SYM=0;
reg [1:0]Prev_Prev_SYM=0;
reg [3:0]Aux_Counter=0;
reg NewBit=0;
reg SOP=0;
reg EOP=0;
reg LatchEOP=0;
reg BIT=0;
reg [1:0]INSYMBOL_STM=0;
always @(posedge clk) begin INSYMBOL:
    if (NewBit==1)NewBit<=0;
    if (SOP==1)SOP<=0;
    if (EOP==1)EOP<=0;
    if (MACHINE_RESET==1)begin
        INSYMBOL_STM<=`STM_Unconnected;
        Aux_Counter<=0;
    end
    else begin
    if (NewSymbol) begin
        if (LatchEOP==1) begin
            EOP<=1;
            LatchEOP<=0;
        end
        Prev_SYM<=RX_SYM;
        Prev_Prev_SYM<=Prev_SYM;
        if (Prev_Prev_SYM==`SYM_0 && Prev_SYM==`SYM_0 && RX_SYM==`SYM_J) begin EndOfPacket:
            LatchEOP<=1;
            INSYMBOL_STM<=`STM_Idle;
        end
        case (INSYMBOL_STM)
            `STM_Unconnected,
            `STM_Idle:begin
                if (RX_SYM==`SYM_K)begin
                    INSYMBOL_STM<=`STM_SOP;
                    Aux_Counter<=0;
                end
            end
            `STM_SOP:begin SYNC_PATTERN:
                if (Aux_Counter==6 && RX_SYM==`SYM_K)begin
                    INSYMBOL_STM<=`STM_PAYLOAD;
                    Aux_Counter<=0;
                    SOP<=1;
                end
                else if ((RX_SYM==`SYM_K && Prev_SYM==`SYM_J)
                        || (RX_SYM==`SYM_J && Prev_SYM==`SYM_K))
                     Aux_Counter<=Aux_Counter+1;   
            end
            `STM_PAYLOAD:begin NRZI:
                if ((RX_SYM==`SYM_K && Prev_SYM==`SYM_J)
                    || (RX_SYM==`SYM_J && Prev_SYM==`SYM_K))begin BIT_STUFF:
                    if (Aux_Counter==6)begin
                        Aux_Counter<=0;
                    end
                    else begin
                        BIT<=0;
                        NewBit<=1;
                        Aux_Counter<=0;
                    end
                end    
                else if ((RX_SYM==`SYM_J && Prev_SYM==`SYM_J)
                    || (RX_SYM==`SYM_K && Prev_SYM==`SYM_K))begin
                    BIT<=1;
                    NewBit<=1;
                    Aux_Counter<=Aux_Counter+1;
                end    
            end
        endcase
    end
    end
end

////////////////////////////////////////////////////////////
//                    DECODE LAYER                        //
////////////////////////////////////////////////////////////
// Esta capa recibe los bits del payload y
// las señales SOP y EOP.
// Decodifica los paquetes y calcula el CRC.
////////////////////////////////////////////////////////////
`define PID_Out         8'hE1
`define PID_In          8'h69
`define PID_Setup       8'h2D
`define PID_Data0       8'hC3
`define PID_Data1       8'h4B
`define PID_ACK         8'hD2
`define PID_NAK         8'h5A

`define STM_IDLE        0
`define STM_PID         1
`define STM_DATAFIELD   2

reg [6:0]BitCounter=0;
reg [1:0]INDECODE_STM=0;
reg [7:0]RECEIVED_PID=0;
reg [95:0]RECEIVED_DATA=0;
reg NewInPacket=0;

always @(posedge clk) begin INDECODE:
    if (NewInPacket==1)NewInPacket<=0;
    if (MACHINE_RESET==1)begin
        INDECODE_STM<=`STM_IDLE;
        NewInPacket<=0;
        BitCounter<=0;
        RECEIVED_PID<=0;
        RECEIVED_DATA<=0;
    end
    else begin
    if (IO==`LineAsInput)begin
        if (SOP) begin
            BitCounter<=0;
            INDECODE_STM<=`STM_PID;
            RECEIVED_PID<=0;
            RECEIVED_DATA<=0;
        end
        if (EOP) begin
            INDECODE_STM<=`STM_IDLE;
            NewInPacket<=1;
        end
        case (INDECODE_STM)
            `STM_PID: begin
                if (NewBit) begin
                    RECEIVED_PID<={BIT,RECEIVED_PID[7:1]};
                    BitCounter<=BitCounter+1;
                end
                if (BitCounter==8) begin
                    INDECODE_STM<=`STM_DATAFIELD;
                end
            end
            `STM_DATAFIELD: begin
                if (NewBit) begin
                    RECEIVED_DATA<={BIT,RECEIVED_DATA[95:1]};
                    BitCounter<=BitCounter+1;
                end
            end
        endcase
    end
    end
end

////////////////////////////////////////////////////////////
//                      TOP LAYER                         //
////////////////////////////////////////////////////////////
// Máquina de estados general.
// -Detectar la presencia de un device y determinar su velocidad.
// -Reiniciar el Device
// -Setup de la dirección del device
// -Forzar el device a modo BOOT
// -Solicitar (paquete IN) periódicamente el estado de las teclas
// -Un device en modo BOOT devuelve NAK si dicho estado no ha cambiado
// 
////////////////////////////////////////////////////////////
// Estados del dispositivo:
// Detached->Powered->Default->Address->Configured
//          Attach   Reset   SetAddress  SetConfig
// En cualquier momento, por inactividad del bus (3ms) entra en Suspended
// Para evitar el Suspended mandar KA (Keep Alive)
`define TL_Unconnected          0
`define TL_Reset                1
`define TL_SetConfig            2
`define TL_SendSETUPConfig      3
`define TL_KeepAlive            4
`define TL_SendSETUPAddress     5
`define TL_SetAddress           6
`define TL_ACK_CONFIG           7
`define TL_ACK_ADDRESS          8
`define TL_IN00                 9
`define TL_ACK_IN00            10
`define TL_SEND_ACK00          11
`define TL_ACK_IN20            12
`define TL_IN20                13
`define TL_SEND_ACK20          14
`define TL_READ_DATA           15
`define TL_IN21                16
`define TL_VerifyData          17
`define TL_SendSETUPProtocol   18
`define TL_SetProtocol         19
`define TL_ACK_PROTOCOL        20
`define TL_IN20_PROTOCOL       21
`define TL_ACK_IN20_PROTOCOL   22
`define TL_SEND_ACK20_PROTOCOL 23

//Suprimimos los CRC
//Usamos device address y endpoint fijos para
//emplear paquetes precalculados
reg [4:0]TL_STM=`TL_Unconnected;
reg [$clog2(`PRES_LowSpeed)-1:0]TX_Prescaler=0;
reg [95:0]TX_Shift=0;
reg [95:0]  Packet_IN20 ={5'h15,4'h0,7'h02,`PID_In};
reg [95:0]  Packet_IN21 ={5'h03,4'h1,7'h02,`PID_In};
reg [95:0]  Packet_IN00 ={5'h02,4'h0,7'h00,`PID_In};
reg [95:0]Packet_SETUP  ={5'h02,4'h0,7'h00,`PID_Setup};
reg [95:0]Packet_SETUP2 ={5'h15,4'h0,7'h02,`PID_Setup};
reg [95:0]Packet_SET_ADDRESS ={16'h16EB,64'h0000000000020500,`PID_Data0};
reg [95:0]Packet_SET_CONFIG  ={16'h2527,64'h0000000000010900,`PID_Data0};
reg [95:0]Packet_SET_PROTOCOL={16'hE0C6,64'h0000000000000B21,`PID_Data0};
reg [95:0]Packet_ACK = {`PID_ACK};

reg [8:0] TXLeftBits=0;
reg MACHINE_RESET=0;
reg TimeOut=0;

always @(posedge clk)begin
    if (StartTimer==1) StartTimer<=0;
    if (MACHINE_RESET==1) MACHINE_RESET<=0;
    if (TXLeftBits==0 && (TimerEnd==1 || NewInPacket==1))begin
    case (TL_STM)
        `TL_Unconnected:begin ListenIfConnected:
            IO<=`LineAsInput;
            Device_Connected<=0;
            TimeOut<=0;
            if (INSYNC_STM==`STM_Idle)begin
                TL_STM<=`TL_Reset;
                IO<=`LineAsOutput;
            end        
        end
        `TL_Reset:begin SendRESETToDevice:
                SendReset;
                TL_STM<=`TL_SendSETUPAddress;
                SetTimer(10);
        end
        `TL_SendSETUPAddress:begin 
                SetLinesToIdle;
                SendPacket(Packet_SETUP,24);
                TL_STM<=`TL_SetAddress;
        end
        `TL_SetAddress:begin 
                SendPacket(Packet_SET_ADDRESS,88);
                TL_STM<=`TL_ACK_ADDRESS;
        end
        `TL_ACK_CONFIG,`TL_ACK_ADDRESS,`TL_ACK_IN00,`TL_ACK_IN20_PROTOCOL,
        `TL_ACK_IN20,`TL_READ_DATA,`TL_ACK_PROTOCOL :begin ReceiveData: 
                IO<=`LineAsInput;
                SetTimer(1);
                if (TL_STM==`TL_ACK_ADDRESS)TL_STM<=`TL_IN00;
                else if (TL_STM==`TL_ACK_IN00)TL_STM<=`TL_SEND_ACK00;
                else if (TL_STM==`TL_ACK_IN20)TL_STM<=`TL_SEND_ACK20;
                else if (TL_STM==`TL_ACK_IN20_PROTOCOL)TL_STM<=`TL_SEND_ACK20_PROTOCOL;
                else if (TL_STM==`TL_READ_DATA)TL_STM<=`TL_VerifyData;
                else if (TL_STM==`TL_ACK_PROTOCOL)TL_STM<=`TL_IN20_PROTOCOL;
                else TL_STM<=`TL_IN20;
        end
        `TL_SEND_ACK00,`TL_SEND_ACK20,`TL_SEND_ACK20_PROTOCOL:begin
            if (TimerEnd==1) begin
                TL_STM<=`TL_Unconnected;
                MACHINE_RESET<=1;
            end
            else begin
                if (RECEIVED_PID==`PID_Data1) begin
                    SetTimer(0);
                    SendPacket(Packet_ACK,8);
                    if (TL_STM==`TL_SEND_ACK00)TL_STM<=`TL_SendSETUPConfig;
                    else if (TL_STM==`TL_SEND_ACK20) TL_STM<=`TL_SendSETUPProtocol;
                    else begin
                        TL_STM<=`TL_IN21;
                        Device_Connected<=1;
                    end
                end
                else begin
                    SetTimer(0);
                    if (TL_STM==`TL_SEND_ACK00)TL_STM<=`TL_IN00;
                    else if (TL_STM==`TL_SEND_ACK20) TL_STM<=`TL_IN20;
                    else TL_STM<=`TL_IN20_PROTOCOL;
                end
            end
        end
        `TL_IN00:begin
                SetTimer(0);
                SendPacket(Packet_IN00,24);
                TL_STM<= `TL_ACK_IN00;
        end
        `TL_SendSETUPConfig,`TL_SendSETUPProtocol:begin 
                SendPacket(Packet_SETUP2,24);
                if (TL_STM==`TL_SendSETUPProtocol)TL_STM<=`TL_SetProtocol;
                else TL_STM<=`TL_SetConfig;
        end
        `TL_SetConfig:begin 
                SendPacket(Packet_SET_CONFIG,88);
                TL_STM<=`TL_ACK_CONFIG;
        end
        `TL_SetProtocol:begin 
                SendPacket(Packet_SET_PROTOCOL,88);
                TL_STM<=`TL_ACK_PROTOCOL;
        end
        `TL_IN20,`TL_IN20_PROTOCOL:begin
            SendPacket(Packet_IN20,24);
            SetTimer(0);
            if (TL_STM==`TL_IN20_PROTOCOL)TL_STM<=`TL_ACK_IN20_PROTOCOL;
            else TL_STM<=`TL_ACK_IN20;
        end
        `TL_IN21:begin
                TL_STM<=`TL_READ_DATA;
                SendPacket(Packet_IN21,24);
                SetTimer(0);
        end
        `TL_KeepAlive:begin
            TL_STM<=`TL_IN21;
            SendKeepAlive;
            SetTimer(2);
        end
        `TL_VerifyData: begin
            if (TimerEnd==1) begin
                if (TimeOut==1)begin
                    TL_STM<=`TL_Unconnected;    
                    MACHINE_RESET<=1;
                end
                else begin
                    TimeOut<=1;
                    SetTimer(2); 
                    TL_STM<=`TL_KeepAlive;
                end
            end
            else begin
                TimeOut<=0;
                SetTimer(2); 
                TL_STM<=`TL_KeepAlive;
                if (RECEIVED_PID==`PID_Data0 || RECEIVED_PID==`PID_Data1) begin
                    SendPacket(Packet_ACK,8);
                    R5<=RECEIVED_DATA[79:72];
                    R4<=RECEIVED_DATA[71:64];
                    R3<=RECEIVED_DATA[63:56];
                    R2<=RECEIVED_DATA[55:48];
                    R1<=RECEIVED_DATA[47:40];
                    R0<=RECEIVED_DATA[39:32];
                    Rmodifiers<=RECEIVED_DATA[23:16];
                end
            end
        end
    endcase
    end //TXLeftBits==0,TimerEnd==1,NewInPacket==1
////////////////////////////////////////////////////////////
//                 SYMBOL TRANSMISION                     //
////////////////////////////////////////////////////////////  
    if (TX_Prescaler==0) begin
        TX_Prescaler<=Prescaler_Reload;    
        if (TXLeftBits!=0)begin
            TXLeftBits<=TXLeftBits-1;
            if (TXLeftBits<4) SetLinesToIdle;
            else if (TXLeftBits==5 || TXLeftBits==4) SetLinesToEOP;
            else begin
                if (TX_Shift[0]==0)begin
                    rdp<=~rdp;
                    rdm<=~rdm;
                end
                TX_Shift<={1'b0,TX_Shift[95:1]};
            end
        end
    end
    else TX_Prescaler<=TX_Prescaler-1;
end

////////////////////////////////////////////////////////////
//                     TAREAS (TASK)                      //
//////////////////////////////////////////////////////////// 
task SendReset;
    begin
        IO<=`LineAsOutput;
        rdp<=0;
        rdm<=0;
        TXLeftBits<=0;
    end
endtask

task SendKeepAlive;
    begin
        IO<=`LineAsOutput;
        TXLeftBits<=5;
    end
endtask

`define SYNC    8'h80
task SendPacket(input [95:0]Packet,input [9:0] PacketSize);
    begin
        IO<=`LineAsOutput;
        TX_Shift<={Packet,`SYNC};
        TXLeftBits<=PacketSize+8+5;
    end
endtask

task SetLinesToEOP;
    begin
        rdp<=1'b0;
        rdm<=1'b0;
    end
endtask

task SetLinesToIdle;
    begin
        rdp<=1'b0 ^ Device_Speed;
        rdm<=1'b1 ^ Device_Speed;
    end
endtask


////////////////////////////////////////////////////////////
//                Temporizador auxiliar                   //
//////////////////////////////////////////////////////////// 
reg [19:0] TimerPreload=0;
reg StartTimer=0;
wire TimerEnd;
Timer Timer(
    .clk(clk),
    .TimerPreload(TimerPreload),
    .StartTimer(StartTimer),
    .TimerEnd(TimerEnd));
task SetTimer(input integer milliseconds);
    begin
        TimerPreload<=48000*milliseconds;
        StartTimer<=1;
    end
endtask
endmodule

module Timer (
    input wire clk,
    input wire [19:0]TimerPreload,
    input wire StartTimer,
    output wire TimerEnd);
    
    assign TimerEnd=(rTimerEnd & ~StartTimer);
    
    reg rTimerEnd=0;
    reg PrevStartTimer=0;
    reg [19:0]Counter=0;
    always @(posedge clk)begin
        PrevStartTimer<=StartTimer;
        if (StartTimer && !PrevStartTimer)begin
            Counter<=TimerPreload;
            rTimerEnd<=0;
        end
        else if (Counter==0) begin
            rTimerEnd<=1;
        end
        else Counter<=Counter-1;
    end    
endmodule 