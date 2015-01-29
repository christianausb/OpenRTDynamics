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


/*!
\class SerialPort
\brief Serial interface class
\version 1.0
\author Nils-Otto Neg�rd, Henrik Gollee

\warning This code is published under the GNU general public
licence GPL, which means that the code distributed here comes with no
warranty. For more details read the hole licence in the file COPYING.

*/

#include <termios.h>
#include <sys/types.h>
#include <sys/time.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <string.h>
#include <sys/ioctl.h>
#include "serial_linux.h"
#include <errno.h>
#include <linux/serial.h>

extern long int mu_time();

extern int errno;

/*!
\fn SerialPort::SerialPort()
\brief Constructor
*/
SerialPort::SerialPort()
{
}

/*!
\fn SerialPort::~SerialPort()
\brief Destructor
*/
SerialPort::~SerialPort()
{
}

/*!
\fn int SerialPort::serial_openport(char *port)
\param *port Name of port

\brief Opens port and saves the file descriptor in the object.

Error code:
\verbatim
Error                  Explanation
----------------------------------------------------
>=0                    No error has occurred
-1                     Error opening serial port
\endverbatim

*/
int SerialPort::serial_openport(char *port)
{
    fd = open(port, O_RDWR | O_NOCTTY); // | O_NOCTTY //O_NDELAY

    if (fd < 0)
    {
        /* arithmetic test because the fd is regarded
        	      * as a number */
        perror("SerialPort::serial_openport() Error: Invalid int while opening port");
    }

    return fd;
}

/*!
\fn int SerialPort::serial_set_parity(short int parity)
\param parity Parity

\brief Changes parity for opened port

Error code:
\verbatim
Error                  Explanation
----------------------------------------------------
>=0                    No error has occurred
-1                     Error setting parity
\endverbatim

*/
int SerialPort::serial_set_parity(short int parity)
{
    int retval;
    struct termios tio;

    retval = tcgetattr(fd, &tio);

    if (retval < 0)
    {
        perror("SerialPort::serial_set_parity() Error getting COM state: ");
    }
    else
    {
		//set parity
		// 0 - none
		// 1   odd
		// 2   even

		tio.c_cflag &= ~(PARENB | PARODD);
		if (parity == 2) //parity even
			tio.c_cflag |= PARENB;
		else if (parity == 1) //odd
			tio.c_cflag |= (PARENB | PARODD);

		retval = tcsetattr(fd, TCSANOW, &tio);

		if (retval < 0)
		{
			perror("SerialPort::serial_openport() Error setting serial port state: ");
		}
    }

    return retval;
}

/*!
\fn int SerialPort::serial_setupport(long baudrate, unsigned char handshake, unsigned char stopbits)

\param Baud_Rate The baud rate for the communication.

\brief Setting up the serial port with the baud-rate given as parameter.

Error code:
\verbatim
Error                  Explanation
----------------------------------------------------
>=0                    No error has occurred
-1                     Error setting up serial port
\endverbatim
*/

int SerialPort::serial_setupport(long baudrate, unsigned char handshake, unsigned char stopbits)
{
    struct termios tio;

    int retval;
    long BAUD;
    /* Get the current configuration. */
    retval = tcgetattr(fd, &tio);
    if (retval < 0)
    {
        perror("SerialPort::serial_setupport() Error getting COM state: ");
    }
    else
    {
		/*
		 * Fill in the default values
		 */
		memset(&tio, 0, sizeof(tio));

        switch (baudrate)
		{
		case 460800:
			BAUD = B460800;
			break;
		case 230400:
			BAUD = B230400;
			break;
		case 115200:
			BAUD = B115200;
			break;
		case 57600:
		default:
			BAUD = B57600;
			break;
		case 38400:
			BAUD = B38400;
			break;
		case 19200:
			BAUD  = B19200;
			break;
		case 9600:
			BAUD  = B9600;
			break;
		}  //end of switch baud_rate

		cfsetospeed(&tio,(speed_t)BAUD);
		cfsetispeed(&tio,(speed_t)BAUD);

		tio.c_cflag = BAUD | CS8 | CLOCAL | CREAD;

		//hw handshake
        if (handshake==1)
			tio.c_cflag = tio.c_cflag | CRTSCTS;
		else
			tio.c_cflag &= ~CRTSCTS;

        if (stopbits == 1)
            tio.c_cflag = tio.c_cflag | CSTOPB;
		else
			tio.c_cflag &= ~CSTOPB;

		tio.c_iflag = IGNPAR | IGNBRK;
		tio.c_oflag = 0;
		tio.c_lflag = 0;
		tio.c_cc[VTIME] = 0;
		tio.c_cc[VMIN] = 1;

		tcflush(fd, TCIOFLUSH);

		retval = tcsetattr(fd, TCSANOW, &tio);
		if (retval < 0)
		{
			perror("SerialPort::serial_setupport() Error setting serial port state: ");
		}
    }

    return retval;
}


/*!
\fn int SerialPort::serial_closeport()

\brief Closing the serial port.

Error code:
\verbatim
Error                  Explanation
--------------------------------------------------
>=0                    No error has occurred
-1                     Error closing serial port
\endverbatim
*/
int SerialPort::serial_closeport()
{
    int retval;

    retval = close(fd);

    if (retval < 0)
    {
        perror("SerialPort::serial_closeport() Error closing serial port: ");
    }

    return retval;
}


/*!
\fn int SerialPort::serial_sendstring(const char *buffer, unsigned int buflen)

\param *buffer String of chars to be sent to the serial port.
\param buflen Number of bytes to be sent to the serial port.

\brief This function is sending a bytes to the serial port.

Error code:
\verbatim
Error                  Explanation
------------------------------------------------------
>=0                    amount of bytes written successfully
1                      Error writing to the serial port
\endverbatim
*/
int SerialPort::serial_sendstring(const char *buffer, unsigned int buflen)
{
    int chrs_written = 0;

    chrs_written = write(fd, (const void *) buffer, buflen);
    if (chrs_written < 0)
        perror("SerialPort::serial_sendstring() Error writing to serial port: ");
    else if ((unsigned int)chrs_written != buflen) // hier ist der Vergleich OK, da <0 bereits abgefangen worden ist
    {
        perror("SerialPort::serial_sendstring() Daten nicht vollstaendig gesendet: ");
    }
    return chrs_written;
}


/*!
\fn  int SerialPort::serial_readstring(char *buffer, unsigned int buflen)

\param *buffer String read from serial port
\param buflen Number of bytes to be read from serial port.

\brief This function is reading a string of the length nb from the serial port.

Error code:
\verbatim
Error                  Explanation
----------------------------------------------------
>=0                    amount of bytes read successfully
-1                     Error reading serial port
\endverbatim
*/
int SerialPort::serial_read_timeout(char *buffer, unsigned int buflen)
{
    fd_set rfds;
    struct timeval tv;
    int flags;
    int chrs_read;
    unsigned int still_to_read, total_read;

    if( (flags = fcntl(fd, F_GETFL, 0)) < 0)
        perror("Flags konnten nicht gelesen werden: ");


    /*
     * O_NONBLOCK flag loeschen und file-status-flags neu setzen
     */

    if(fcntl(fd, F_SETFL, flags & ~O_NONBLOCK) < 0)
        perror("Flag NONBLOCK konnte nicht geloescht werden: ");

    FD_ZERO(&rfds);
    FD_SET(fd, &rfds);

    /* Wait up to one seconds. */
    tv.tv_sec = 1;
    tv.tv_usec = 0;

    chrs_read = 0;
    total_read = 0;
    still_to_read = buflen;
    while ( (total_read < buflen) && (select(fd + 1, &rfds, NULL, NULL, &tv) == 1) )
    {
        chrs_read = read(fd, (void *) &buffer[total_read], still_to_read);
        if (chrs_read < 0)
        {
            perror("serial_read_timeout: Error reading from serial port: ");
            total_read = chrs_read;
        }
        else
        {
            total_read = total_read + chrs_read;
            still_to_read = still_to_read - chrs_read;
        }

    }
    return total_read;
}


/*!
\fn  int SerialPort::serial_read(char *buffer, unsigned int buflen)

\param *buffer String read from serial port
\param buflen Number of bytes to be read from serial port.

\brief This function is reading a string of the length nb from the serial port.

Error code:
\verbatim
Error                  Explanation
----------------------------------------------------
>=0                    amount of bytes read successfully
-1                     Error reading serial port
\endverbatim
*/
int SerialPort::serial_read_nonblocking(char *buffer, unsigned int buflen)
{
    int chrs_read;
    fcntl(fd, F_SETFL, O_NONBLOCK);
    chrs_read = read(fd, (void *) buffer, buflen);
    if (chrs_read < 0)
        perror("serial_read_nonblocking: Error reading from serial port: ");
    return chrs_read;
}

/*!
\fn  int SerialPort::serial_readstring(char *buffer, unsigned int buflen)

\param *buffer String read from serial port
\param buflen Number of bytes to be read from serial port.

\brief This function is reading a string of the length nb from the serial port.

Error code:
\verbatim
Error                  Explanation
----------------------------------------------------
>=0                    amount of bytes read successfully
-1                     Error reading serial port
\endverbatim
*/
int SerialPort::serial_readstring(char *buffer, unsigned int buflen)
{
    fd_set rfds;
    struct timeval tv;
    int input_available;

    int chrs_read = 0;

    FD_ZERO(&rfds);
    FD_SET(fd, &rfds);

    /* Wait up to five seconds. */
    tv.tv_sec = 1;
    tv.tv_usec = 0;

    input_available = select(fd + 1, &rfds, NULL, NULL, &tv);
    //input_available=1;
    /* Don't rely on the value of tv now! */
    if (input_available)
    {
        chrs_read = read(fd, (void *) buffer, buflen);
        if (chrs_read < 0)
        {
            perror("serial_readstring: Error reading from serial port: ");
        }
    }

    return chrs_read;

}

/*!
\fn void SerialPort::serial_flush()

\brief This function flushes all buffers.
*/
void SerialPort::serial_flush()
{
    tcflush(fd, TCIOFLUSH);
}

/*!
\fn  int SerialPort::serial_toggleDTR()

\brief This function toggles the DTR-signal.
*/
void SerialPort::serial_toggleDTR()
{
    int status;
    ioctl(fd, TIOCMGET, &status);
    status^=TIOCM_DTR;
    ioctl(fd, TIOCMSET, &status);
}

/*!
\fn  int SerialPort::serial_toggleDTR()

\brief This function resets the RTS-signal.

*/
void SerialPort::serial_setRTSlow()
{
    int status;
    ioctl(fd, TIOCMGET, &status);
    status &= ~TIOCM_RTS;
    ioctl(fd, TIOCMSET, &status);
}

/*!
\fn  int SerialPort::serial_toggleDTR()

\brief This function sets the RTS-signal.

*/
void SerialPort::serial_setRTShigh()
{
    int status;
    ioctl(fd, TIOCMGET, &status);
    status &= ~TIOCM_RTS;
    ioctl(fd, TIOCMSET, &status);
}

/*!
\fn  int SerialPort::serial_toggleDTR()

\brief This function resets the CTS-signal.

*/
void SerialPort::serial_setCTSlow()
{
    int status;
    ioctl(fd, TIOCMGET, &status);
    status &= ~TIOCM_CTS;
    ioctl(fd, TIOCMSET, &status);
}

/*!
\fn  int SerialPort::serial_toggleDTR()

\brief This function sets the CTS-signal.

*/
void SerialPort::serial_setCTShigh()
{
    int status;
    ioctl(fd, TIOCMGET, &status);
    status |= TIOCM_CTS;
    ioctl(fd, TIOCMSET, &status);
}
