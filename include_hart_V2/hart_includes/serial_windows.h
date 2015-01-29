/***************************************************************************
                          serial_windows.h  -  description
                             -------------------
    begin                :
    copyright            : (C) 2003 Max Planck Institute for Dynamics
                                    of Complex Dynamical Systems
    Author               :  Nils-Otto Neg�rd
                            Ralph Stephan

    email                : negaard@mpi-magdburg.mpg.de

    Modified by Henrik Gollee <henrik@mech.gla.ac.uk> Nov 2006:
    *    Added more COM port (up to 20)
    *    include <iostream> instead of <iostream.h> for compatibility with
    *    VC++ 2003 (also compatible with BCC, no check with gcc)
 ***************************************************************************/
/***************************************************************************
 *                                                                         *
 *   This program is free software; you can redistribute it and/or modify  *
 *   it under the terms of the GNU General Public License as published by  *
 *   the Free Software Foundation; either version 2 of the License, or     *
 *   (at your option) any later version.                                   *
 *                                                                         *
 ***************************************************************************/
#ifndef SERIALWINDOWS_H
#define SERIALWINDOWS_H

#include <windows.h>
#include <stdio.h>
#include <iostream>

#define HANDSHAKE 1
#define NOHANDSHAKE 0
#define ONESTOPBIT 0
#define TWOSTOPBITS 2
#define BAUD_460800 460800
#define NONE 0
#define ODD 1
#define EVEN 2

class SerialPort
{
	public:
		SerialPort();
  		~SerialPort();

		int serial_openport (char *Portname);
		int serial_setupport (long baudrate, unsigned char handshake, unsigned char stopbits, unsigned char parity);
		int serial_closeport();

		int serial_sendstring(char *buffer, unsigned int nb);
		int serial_readstring(char *buffer, unsigned int nb);

	private:
		HANDLE hCom;
};
#endif

