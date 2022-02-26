## USBKeyboard (SPA)
Interfaz directa con teclados USB y conversión a PS/2.  
Todos los módulos requieren un entrada de reloj de 48MHz.  
El módulo ULPI funciona con el reloj suministrado por el PHY.     


Soporta tanto teclados Low Speed(1.5Mbps) como Full Speed(12Mbps).  
Lista de teclados testeados y funcionando (la versión ULPI actualmente sólo soporta Low Speed):
- POSS PSK301BK (VID:1C4F, PID:0002)
- Belkin Generic Keyboard (VID:1241, PID:1603)
- MANFALI Generic Keyboard (VID:1C4F, PID:0002)
- Dell Smartcard 06JJ08 (VID:413C, PID:2101)
- Logitech Unifying Receiver (VID:046D, PID:C52B)

## Tres opciones:
- USB_L2: Teclado USB directo y comunicación con el top mediante registros.  
  Este módulo tiene 3 entradas para controlar el estado de los leds del teclado USB, si no van a usarse, deben conectarse a 0 lógico para ahorrar LEs.
- USB_PS2: conversión directa de USB a PS/2 para aprovechar cores retro sin apenas modificarlos.  
   Para ello, el módulo se conecta a las líneas USB y, como salida, genera las señales PS/2.  
   Este módulo tiene 3 entradas para controlar el estado de los leds del teclado USB, si no van a usarse, deben conectarse a 0 lógico.
   Requiere el archivo USB_PS2_CONVERSION.txt. 
- ULPI_PS2: interfaz con teclados USB a través de chip que use protocolo ULPI.  
  Testado en una placa Deca, actualmente, funciona sólo con teclados Low-Speed.  
  Atención: debido a las características de la placa Deca, el reloj de entrada necesita  
  un desfase de -30º (menos treinta grados) con respecto al reloj suministrado por el PHY.

## USBKeyboard (ENG)
Direct interface with USB keyboards and conversion to PS/2.  
All modules require a 48MHz clock input.   
The ULPI module works with the clock provided by the PHY.   


Supports both Low Speed (1.5Mbps) and Full Speed (12Mbps) keyboards.  
List of keyboards tested and working (the ULPI version currently only supports Low Speed):
- POSS PSK301BK (VID: 1C4F, PID: 0002)
- Belkin Generic Keyboard (VID: 1241, PID: 1603)
- MANFALI Generic Keyboard (VID: 1C4F, PID: 0002)
- Dell Smartcard 06JJ08 (VID: 413C, PID: 2101)
- Logitech Unifying Receiver (VID:046D, PID:C52B)

## Three options:
- USB_L2: Direct USB keyboard and communication with the top through registers.  
  This module has 3 inputs to control the status of the USB keyboard LEDs, if they are not going to be used, they must be connected to logical 0 to save LEs.  
- USB_PS2: direct conversion from USB to PS/2 to take advantage of retro cores without hardly modifying them.  
   To do this, the module connects to the USB lines and, as an output, generates the PS/2 signals.  
   This module has 3 inputs to control the status of the LEDs of the USB keyboard, if they are not going to be used, they must be connected to logical 0.  
   Requires the USB_PS2_CONVERSION.txt file.
- ULPI_PS2: interface with USB keyboards through a chip that uses the ULPI protocol.   
  Tested on a Deca board, it currently works only with Low-Speed keyboards.    
  Attention: Due to the characteristics of the Deca board, the input clock needs  
  an offset of -30º (minus thirty degrees) with respect to the clock supplied by the PHY.   
  


![DATA](data_capture.png)

.


