/**-----------------------------------------------------------------------------------
 *  Copyright (C) 2003  Nils-Otto Neg�rd Max Planck Institute for Dynamic sof Complex Dynamical Systems
 *  Copyright (C) 2008  Holger Nahrstaedt
 *  Copyright (C) 2012  Ralph Stephan
 *
 *  This file is part of HART, the Hardware Access in Real Time Toolbox for Scilab/Scicos.
 *
 *  HART is free software; you can redistribute it and/or modify
 *  it under the terms of the GNU Lesser General Public License as published by
 *  the Free Software Foundation; either version 2 of the License, or
 *  (at your option) any later version.
 *
 *  HART is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU Lesser General Public License
 *  along with HART; if not, write to the Free Software
 *  Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA  02110-1301  USA
 *--------------------------------------------------------------------------------- */


#ifndef SERIALLINUX_H
#define SERIALLINUX_H

#define HANDSHAKE 1
#define NOHANDSHAKE 0
#define ONESTOPBIT 0
#define TWOSTOPBITS 1
#define BAUD_460800 460800
#define BAUD_115200 115200
#define BAUD_38400 38400
#define BAUD_4800 4800
#define NONE 0
#define ODD 1
#define EVEN 2

#include <unistd.h>
#include <stdio.h>
class SerialPort
{
public:
    SerialPort();
    ~SerialPort();

    int serial_openport(char *port);
    int serial_setupport(long baudrate, unsigned char handshake, unsigned char stopbits);
    int serial_set_parity(short int parity);
    int serial_closeport();

    void serial_flush();
    void serial_toggleDTR();
    void serial_setRTSlow();
    void serial_setRTShigh();
    void serial_setCTSlow();
    void serial_setCTShigh();

    int serial_sendstring(const char *buffer, unsigned int buflen);
    int serial_read_timeout(char *buffer, unsigned int buflen);
    int serial_read_nonblocking(char *buffer, unsigned int buflen);
    int serial_readstring(char *buffer, unsigned int buflen);

private:
    int fd;

};
#endif
