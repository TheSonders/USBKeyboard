## USBKeyboard (SPA)
Interfaz directa con teclados USB y conversión a PS/2.
Todos los módulos requieren un entrada de reloj de 48MHz.  


Soporta tanto teclados Low Speed(1.5Mbps) como Full Speed(12Mbps).  
Lista de teclados testeados y funcionando:
- POSS PSK301BK (VID:1C4F, PID:0002)
- Belkin Generic Keyboard (VID:1241, PID:1603)
- MANFALI Generic Keyboard (VID:1C4F, PID:0002)
- Dell Smartcard 06JJ08 (VID:413C, PID:2101)

## Dos opciones:
- USB_L2: Teclado USB directo y comunicación con el top mediante registros.  
  Este módulo tiene 3 entradas para controlar el estado de los leds del teclado USB, si no van a usarse, deben conectarse a 0 lógico para ahorrar LEs.
- USB_PS2: conversión directa de USB a PS/2 para aprovechar cores retro sin apenas modificarlos.  
   Para ello, el módulo se conecta a las líneas USB y, como salida, genera las señales PS/2.  
   Este módulo tiene 3 entradas para controlar el estado de los leds del teclado USB, si no van a usarse, deben conectarse a 0 lógico.
   Versión preliminar, se ha testeado con 3 teclados diferentes y funciona.
   Requiere el archivo USB_PS2_CONVERSION.txt.

## USBKeyboard (ENG)
Direct interface with USB keyboards and conversion to PS/2.
All modules require a 48MHz clock input.


Supports both Low Speed (1.5Mbps) and Full Speed (12Mbps) keyboards.  
List of keyboards tested and working:
- POSS PSK301BK (VID: 1C4F, PID: 0002)
- Belkin Generic Keyboard (VID: 1241, PID: 1603)
- MANFALI Generic Keyboard (VID: 1C4F, PID: 0002)
- Dell Smartcard 06JJ08 (VID: 413C, PID: 2101)

## Two options:
- USB_L2: Direct USB keyboard and communication with the top through registers.  
  This module has 3 inputs to control the status of the USB keyboard LEDs, if they are not going to be used, they must be connected to logical 0 to save LEs.  
- USB_PS2: direct conversion from USB to PS/2 to take advantage of retro cores without hardly modifying them.  
   To do this, the module connects to the USB lines and, as an output, generates the PS/2 signals.  
   This module has 3 inputs to control the status of the LEDs of the USB keyboard, if they are not going to be used, they must be connected to logical 0.  
   Preliminary version, it has been tested with 3 different keyboards and it works.
   Requires the USB_PS2_CONVERSION.txt file.



![DATA](data_capture.png)

.


