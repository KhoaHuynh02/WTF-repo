# WTF: Walkie-Talkie on FPGA
*by Khoa Huynh, Khang Le, and Keawe Mann*

*6.205 Fall 2023 Final Project*

An AES-encrypted walkie-talkie system that is capable of two-way communications.

### *It works so darn good that it makes you go WTF???*

The *Walkie-Talkie on FPGA*, or WTF for short (and for hilarity), is a project aimed to replicate the functionalities of a walkie-talkie...but using FPGAs instead.

Instead of transmitting data through radiowaves or Bluetooth (both archaic methods for 2023), the WTF uses **lasers**, because what else is cooler than lasers?

*12/16/23 update: the lasers did not work because Khang sucks at electrical stuff, but it works with regular wires  ¯\\_(ツ)_/¯, but it should work??*

Before we forget, did we tell you that all transmitted sound is encrypted with *128-bit AES*? Spill all the tea possible, what happens on the FPGA, *stays* on the FPGA.

## Setup
* Flash **/obj/final.bit** onto your FPGA (preferrably a RealDigital Urbana FPGA)
* Connect the transmission wire onto the **PMODB[2]** port
* Connect the reception wire onto the **PMODA[2]** port
* Connect the transmission end of FPGA A to the reception end of FPGA B, and vice versa.
* Connect the grounds of both FPGAs together (will not work if not done)
* Multiple FPGAs (2+) *should* work, just make sure they are connected to each other correctly
* Connect headphones or speakers to the 3.5mm aux on the FPGA, and enjoy the unnecessarily complex encrypted walkie-talkie system

Here's a little ASCII drawing to identify which ports to connect to:

*PMODB on the left, PMODA on the right*

□□□■□□□□□□□□■□□

□□□□□□□□□□□□□□□



## Usage

On default, *microphone mode* will be activated on startup. Microphone mode will pass through whatever sound picked up by the on-board microphone (no transmitted sound will be picked up)

Pressing **BTN[2]** will switch it to *walkie-talkie mode*, which will transition the FPGA into a true walkie-talkie. Passively, it will play any transmitted sound received.

Knowing which mode the FPGA is on is easy: if the left blue LED between the button bank lights up, the FPGA is on *walkie-talkie mode*, if the right red LED lights up instead, the FPGA is on *microphone mode*.

To transmit sound, press **BTN[1]** and the FPGA will send it automatically. Should work on both *microphone mode* and *walkie-talkie mode*.

## License
does anyone know copyright laws?

## Endnote
a picture of the group that brought you the WTF (plus joe, he's the real homie.)

![Los Pingüinos Me La Van a Mascar](https://i.kym-cdn.com/entries/icons/facebook/000/047/271/los_penguins.jpg)

"i would never do this project again even if i had to"

-k