/***************************************************************************
                          sciencemode.cpp  -  description
                             -------------------
    begin                :
    copyright            : (C) 2003 Max Planck Institute for Dynamics
                                    of Complex Dynamical Systems
    Author               :  Nils-Otto Neg�rd

    email                : negaard@mpi-magdburg.mpg.de
 ***************************************************************************/
/***************************************************************************
 *                                                                         *
 *   This program is free software; you can redistribute it and/or modify  *
 *   it under the terms of the GNU General Public License as published by  *
 *   the Free Software Foundation; either version 2 of the License, or     *
 *   (at your option) any later version.                                   *
 *                                                                         *
 ***************************************************************************/

/*!
\main Science mode documentation

*/

/*!
\class stimulator 
\brief Science Mode interface 
\version 1.0
\author Nils-Otto Neg�rd

The Science Mode offers great flexibility to control the stimulator
output directly from an external device, preferably a PC, via the 
standard RS232 interface. To offer an "easy to take in use"
functionality for scientists, we have written a c++ interface class for the stimulator stimulator 
which implements the functionality described in the document "science_mode.ps". 

\date    2003
\bug No known bugs.

\warning This code is published under the GNU general public
licence GPL, which means that the code distributed here comes with no
warranty. For more details read the hole licence in the file COPYING.

*/


#include "sciencemode.h"

char run=0;

#ifdef _TTY_POSIX_
//long int mu_time()
//{
//
//  struct timeval mytime;
//  struct timezone myzone;
//
//  gettimeofday(&mytime, &myzone);
//  return (1000000*mytime.tv_sec+mytime.tv_usec);
//
//} /* mu_time */
#endif

/*!
\fn stimulator::stimulator()
Constructor 
*/

stimulator::stimulator()
{
  int i;
 this->Channel_Stim=0;
 this->Channel_Lf=0;
 this->Main_Time=0;
 this->Group_Time=0;
 this->N_Factor=0;
 this->nc=0;
 this->initialised=0;
 for(i=0;i<8;i++)
   index[i]=i;
}

/*!
\fn stimulator::~stimulator()
Destructor
*/
stimulator::~stimulator()
{

}
/*!
\fn int stimulator::Close_serial()
This function closes the serial port. If the stimulator is in use (the channel list is 
initialised), astop signal is sent to the stimulator before closing the serial
connection.

Error code:
\verbatim
Error                  Explanation
------------------    ----------------------------------------------------
0                      No error has occurred
1                      Error closing serial port
\endverbatim
*/
int stimulator::Close_serial()
{
  return this->Sport.serial_closeport();
}
/*!
\fn int stimulator::Open_serial(char *Portname)
\param Portname Name of the port, for linux this is typically /dev/ttyS0, for windows the portname is
 typically COM1.

This function opens the serial port and assigns the the file handler
to a private variable inside the stimulator object.

Error code:
\verbatim
Error                  Explanation
------------------    ----------------------------------------------------
0                      No error has occurred
1                      Error closing serial port

\endverbatim
*/
int stimulator::Open_serial(char *Portname)
{

  return this->Sport.serial_openport(Portname);

}
/*!
\fn int stimulator::Setup_serial()

This function is setting up the serial port, with the rered settings for the
stimulator, i.e 115200 Baud.

Error code:
\verbatim
Error                  Explanation
------------------    ----------------------------------------------------
0                      No error has occurred
1                      Error setting up serial port
\endverbatim
*/

int stimulator::Setup_serial()
{ unsigned char HandShake = 1; 
  unsigned char TwoStopBits = 1; 
  return this->Sport.serial_setupport(115200,HandShake,TwoStopBits);
}

/*!
\fn int stimulator::get_Init_String(char *out_Buffer)

This function returns the string of bytes sent to the stimulator  for initialisation.

Error code:
\verbatim
Error                  Explanation
------------------    ----------------------------------------------------
0                      String returned successfully
1                      Stimulator not initialised
\endverbatim
*/

int stimulator::get_Init_String(char *out_Buffer)
{
  int i;
  if (this->initialised){
    for (i=0;i<6;i++)
    out_Buffer[i]=this->Init_Buffer[i];
  }
  else
    return 1;
  return 0;
}

/*!
\fn int stimulator::get_Update_String(char *out_Buffer,unsigned int *nb)

\param out_Buffer The last update bytes which were sent to stimulator.
\param nb Number of bytes in the string.

This function returns the last stimulator update created by the Send_Update_Param(*), which were 
sent to the stimulator.

Error Code:
\verbatim
Error                  Explanation
------------------    ----------------------------------------------------
0                      No error has occurred
1                      stimulator not initialised or no parameter update 
                       is performed.

\endverbatim
*/

int stimulator::get_Update_String(char *out_Buffer,unsigned int *nb)
{
  unsigned int i;
  if (this->Number_Bytes==0)
    return 1;
  else{
    *nb=this->Number_Bytes;
  for (i=0;i<this->Number_Bytes;i++)
    out_Buffer[i]=this->Write_Buffer[i];
  }
  return 0;
}

/*!
\fn int stimulator::Send_Init_Param(unsigned int nc, // Number of channels
				double *S_Channel_Stim, // List of channels
			        unsigned int n_lf,// Number in Channel_Lf
				double *S_Channel_Lf, //
				double  S_Main_Time,  
				double  S_Group_Time, 
				double  S_N_Factor)


\param nc Numbers of channels in the S_Channel_Stim
\param S_Channel_Stim The channel list as a vector.
\param n_lf Numbers of channels in the S_Channel_Lf
\param S_Channel_Lf The Channel_Lf list as a vector
\param S_Main_Time The Main Time in the real values
\param S_Group_Time The Group Time in real value
\param S_N_Factor The N_Factor setting the frequency of the channels in the
S_Channel_Lf

this function differs from the int stimulator::Send_Init_Param(unsigned int nc,
				unsigned int Channel_Stim, 
				unsigned int Channel_Lf,
				unsigned int Main_Time, 
				unsigned int Group_Time, 
				unsigned int N_Factor) 
in that the parameters are all in real values, and the vectors S_Channel_Stim and S_Channel_Lf are real vectors. Make sure when the parameters are updated the pulse 
width and current have to appear in the same order as the channels in the 
S_Channel_Stim vector.


Error code:
\verbatim
Error                  Explanation
------------------    ----------------------------------------------------
0                      No error has occurred
1                      Channel_Stim==0, no channels in the channel list
2                      Group Time > Main_Time Initialisation unsuccessfully
3                      did not receive any byte from stimulator
4                      did not receive confirmation from stimulator
5                      Group Time < nc * 1.5

\endverbatim
*/

int stimulator::Send_Init_Param(unsigned int nc, // Number of channels
				double *S_Channel_Stim, // List of channels
			        unsigned int n_lf,// Number in Channel_Lf
				double *S_Channel_Lf, //
				double  S_Main_Time,  
				double  S_Group_Time, 
				double  S_N_Factor)

{

  unsigned int Channel_Stim;
  unsigned int Channel_Lf;
  unsigned int Group_Time;
  unsigned int Main_Time;

  this->Make_Index(S_Channel_Stim,nc);
  this->Encode_Channel_Stim(&Channel_Stim,S_Channel_Stim, nc);
  this->Encode_Channel_Lf(&Channel_Lf,S_Channel_Lf, n_lf);


 if (S_Main_Time==0)
   Main_Time=0;
 else
   Main_Time=(unsigned int)((S_Main_Time-1)*2);
 

 Group_Time=(unsigned int)((S_Group_Time-1.5)*2);
 N_Factor=(unsigned int)S_N_Factor; 

 


 return this->Send_Init_Param(nc,Channel_Stim,Channel_Lf,Main_Time,Group_Time,
			      N_Factor);

}
/*!
\fn int stimulator::Send_Init_Param(unsigned int nc,
				unsigned int Channel_Stim, 
				unsigned int Channel_Lf,
				unsigned int Main_Time, 
				unsigned int Group_Time, 
				unsigned int N_Factor)

\param nc Number of channels in the channel list
\param Channel_Stim The channel list coded in bits. LSB is channel 1, bit 7 is channel 8. 
\param Channel_Lf The low frequency channel list. Then channels in this list will be
stimulated with a lower frequency.
\param Main_Time This time is the time between the main pulses. The coding is as
following 1.0 + 0.5* Main_Time. 
\param Group_Time This time is the time in between the doublets and triplets. The coding is as following:1.5 +0.5*Group_Time.
\param N_Factor The N_Factor is deciding the frequency of the channels in the Channel_Lf list.

This function codes the information and sends this information to the stimulator to initialise the
"Channel List Mode". Before opening the channel list mode, the serial port must be opened 
by using Open_serial(char *Portname). Channel_Stim is the list of channels to be set up in the 
channel list. The channels are coded in the bits starting with LSB is channel 1 to MSB is channel 8. The corresponding channels 
in Channel_Lf will be stimulated with a lower frequency defined by N_Factor.

Returns code:
\verbatim
Error                  Explanation
------------------    ----------------------------------------------------
0                      No error has occurred. Stimulator successfully initialised
1                      Channel_Stim==0, no channels in the channel list
2                      Group Time > Main_Time. 
3                      Stimulator is not responding. Check your cable
4                      The stimulator returns that initialisation is unsuccessfully.
5                      Group time is less than nc * 1.5.

\endverbatim
*/

int stimulator::Send_Init_Param(unsigned int nc,
				unsigned int Channel_Stim, 
				unsigned int Channel_Lf,
				unsigned int Main_Time, 
				unsigned int Group_Time, 
				unsigned int N_Factor)
{
  int i;
  char  tmp;
  unsigned int Check;
  unsigned int Mode_Update=0;
  double Dou_Main_Time;
  double Dou_Group_Time;
  int error=0;
  int Receive;
  char Read_Buffer[10];
  int norb;
  int nb=6;
  /*
  this->Channel_Stim=Channel_Stim;
  this->Channel_Lf=Channel_Lf;
  this->Main_Time=Main_Time;
  this->Group_Time=Group_Time;
  this->N_Factor=N_Factor;
  this->nc=nc;
  */
  /*
    Defining error return
    0 Successfully
    1 Channel_Stim==0 No channels in the channel list
    2 Group Time > Main_Time Initialisation unsuccessfully
    3 did not receive any byte from stimulator
    4 did not receive confirmation from stimulator
    5 Group time < nc * 1.5

  */

   //debugginh
  /*
   printf("Main Time: %d\n",Main_Time);
   printf("Group Time: %d\n",Group_Time);
   printf("N_Factor: %d\n",N_Factor);
   printf("Channel_Lf: %d\n",Channel_Lf);
   printf("Channel_Stim: %d\n",Channel_Stim);
  */
  

  /* Testing if more than one channel is used */
  if (Channel_Stim==0)
    return 1;
  /*
    Tesing Main time and Group Time to find Mode_update. d.h if it is
    possible to send doublets and triplets. 
  */
  if (Main_Time==0)
    Dou_Main_Time=0;
  else
    Dou_Main_Time=Main_Time*0.5+1.0;
  
  Dou_Group_Time=Group_Time*0.5+1.5;
  if(Main_Time!=0){
    if(Dou_Main_Time>=Dou_Group_Time){
      this->Mode_Update=0; // Only singles allowed
      if(Dou_Main_Time>=2*Dou_Group_Time)
	this->Mode_Update=1; // Doublets allowed
      if(Dou_Main_Time>=3*Dou_Group_Time)
	this->Mode_Update=2; // Triplets allowed
      if (Dou_Group_Time<1.5*nc)
	return 5;
    }  
    else
      return 2;
  }
  else
    this->Mode_Update=2; /* Triples allowed, frequency decided by user */


  /*
    Mask out Channel_Lf to  only those channels in the Channel_Stim list
  */
  Channel_Lf&=Channel_Stim;
  
  /* If N_Factor==0 must the Channel_Lf list contain no channel */
  if (N_Factor==0)
    Channel_Lf=0;
  

  Check=(N_Factor & 0x07)+(Main_Time & 0x7ff)+(Group_Time & 0x1f)+
    (Channel_Lf & 0xff)+(Channel_Stim &0xff)+(Mode_Update & 0x03); 
  

  Check=Check&0x07;  /* Modulo 32 */    
                     
  /***** Byte 0 *********/                     
  tmp=0;               
  tmp=N_Factor>>1; /* Setting 2 MSB to first byte */
  tmp|=(char)0x80; /* set first bit 1 */
  tmp|=Check<<2;      
  tmp&=0x9F;          
                        
  this->Init_Buffer[0]=tmp; 
                    
  /***** Byte 1 *********/
  tmp=0;             
  tmp=N_Factor<<6;  
  tmp|=Channel_Stim>>2;
  tmp&=0x7F;        
  this->Init_Buffer[1]=tmp;
  /* byte 2  */     
  tmp=0;             
  tmp=Channel_Stim<<5;
  tmp&=0xE0;       
  tmp&=0x7F;        
  tmp|=Channel_Lf>>3;    
  this->Init_Buffer[2]=tmp;
  /*  byte 3 */
  tmp=0;
  tmp|=Channel_Lf<<4;
  tmp&=0x7F;  
  tmp|=Mode_Update<<2;
  tmp|=Group_Time>>3;
   this->Init_Buffer[3]=tmp;
  /*  byte 4 */
  tmp=0;
  tmp|=Group_Time<<4;
  tmp|=Main_Time>>7; 
  tmp&=0x7F;  
  
  this->Init_Buffer[4]=tmp;
  /*  byte 5 */
  tmp=0; 
  tmp=Main_Time;
  tmp&=0x7F;  
  this->Init_Buffer[5]=tmp;
  
  /*flush receive and send buffers*/
   #ifdef _TTY_POSIX_
	norb=this->Sport.serial_read_nonblocking(Read_Buffer,1);  
	this->Sport.serial_flush();
  #else
     norb=this->Sport.serial_readstring(Read_Buffer, 1);
  #endif


  norb=this->Sport.serial_sendstring(this->Init_Buffer, nb); 

  if (norb>0)
    {
      //printf("Received initialisation byte: %02x\n",(unsigned char) Read_Buffer[0]);
    }
  else {
    printf("Did not send  inititalisation byte:\n ");
    return 3;
  }

#ifdef _TTY_POSIX_
   norb=this->Sport.serial_read_timeout(Read_Buffer, 1);
#else
  norb=this->Sport.serial_readstring(Read_Buffer, 1);
#endif

  /*norb=0;
  while (norb<1) 
    {
      norb=this->Sport.serial_read_nonblocking(Read_Buffer, 1);
    }

  printf("norb %d\n",norb);
  */
  if (norb>0)
    {
      //printf("Received initialisation byte: %02x\n",(unsigned char) Read_Buffer[0]);
    }
  else {
    printf("Did not receive any inititalisation byte:\n ");
    return 3;
  }

  Receive=(0xFF&Read_Buffer[0]);
  #if SHOWRESPONSE  
      printf("Quittung %02x\n",(unsigned char) Read_Buffer[0]);
  #endif
  
  if ((norb>0)&&(Receive==0x01)){
    printf("Initialisation successfully\n");
    error=0;
    }
  else{
    printf("Initialisation failed\n");  
    error=4;
  }

  if (error==0)
    {
      this->initialised=1;
     }
     
   this->sent_updates=0;
   this->successful_updates=0;
   this->unsuccessful_updates=0;
   

  return error;
}

/*!
\fn int stimulator::Send_Update_Parameter(double *S_Pulse_Width, 
				      double *S_Pulse_Current, 
				      double *S_Mode,
				      unsigned int nc)

\param S_Pulse_Width Vector of Pulse Width
\param S_Pulse_Current Vector of Current
\param S_Mode 0 single pulse, 1 double pulse ,2 triple pulse.
\param nc  Number of channels

This function sends information to the stimulator to update the
stimulation parameters set up in "Channel List Mode". Pulse_Width and
Pulse_Current and Mode are vector with the length of number of
channels set up in the initialisation. The vectors S_Pulse_With, S_Pulse_Current and
S_Mode must appear in the same order as in the S_Channel_Stim in the initialisation done by
int stimulator::Send_Init_Param(unsigned int nc, // Number of channels
				double *S_Channel_Stim, // List of channels
			        unsigned int n_lf,// Number in Channel_Lf
				double *S_Channel_Lf, //
				double  S_Main_Time,  
				double  S_Group_Time, 
				double  S_N_Factor)


Returns code:
\verbatim
Error                  Explanation
------------------    ----------------------------------------------------
0                      No error has occurred
1                      Motionstim not initialised
\endverbatim
*/


int stimulator::Send_Update_Parameter(double *S_Pulse_Width, 
				      double *S_Pulse_Current, 
				      double *S_Mode,
				      unsigned int nc)
{
  unsigned int Pulse_Width[8];
  unsigned int Pulse_Current[8];
  unsigned int Mode[8];
  unsigned int i;

  for(i=0;i<nc;i++){
    Pulse_Width[i]=this->Encode_Pulse_Width(S_Pulse_Width[this->index[i]]);
    Pulse_Current[i]=this->Encode_Pulse_Current(S_Pulse_Current[this->index[i]]);
    Mode[i]=this->Encode_Mode(S_Mode[this->index[i]]);
  }
  return this->Send_Update_Parameter(Pulse_Width,Pulse_Current,Mode,nc);
 

}

/*!
\fn int stimulator::Send_Update_Parameter(unsigned int *Pulse_Width, 
				      unsigned int *Pulse_Current, 
				      unsigned int *Mode,
				      unsigned int nc)


\param Pulse_Width Vector of Pulse Width
\param Pulse_Current Vector of Current
\param Mode 0 single pulse, 1 double pulse ,2 triple pulse.
\param nc  Number of channels

This function sends information to the stimulator to update the
stimulation parameters set up in "Channel List Mode". Pulse_Width and
Pulse_Current and Mode are vector with the length of number of
channels set up in the initialisation. The vectors are so arranged, so that 
the first entry in the vectors correspond with the channel with the lowest channel 
number. 


Returns code:
\verbatim
Error                  Explanation
------------------    ----------------------------------------------------
0                      No error has occurred
1                      Stimulator not initialised
2                      Number of channel is not the same as initialised.
\endverbatim
*/

int stimulator::Send_Update_Parameter(unsigned int *Pulse_Width, 
				      unsigned int *Pulse_Current, 
				      unsigned int *Mode,
				      unsigned int nc)
{
  int error=0;
  int nb=nc*3+1; 
  char tmp;
  unsigned int i;
  int ind;
  unsigned int Check;
  int norb;
  char Read_Buffer[10];
  int Receive;
  int time1,time2;


  if (!this->initialised)
    return 1;

  /*
  printf("index:");
  for(i=0;i<nc;i++)
    printf("%u ",this->index[i]);
  printf("\n");
  */

  this->Number_Bytes=nb;

  for(i=0;i<nc;i++) {
    this->Pulse_Width[i]=(0xFF&Pulse_Width[i]);
    this->Pulse_Current[i]=(0xFF&Pulse_Current[i]);
    this->Mode[i]=Mode[this->index[i]];
  }


  tmp=0xA0; 
  Check=0; 
   for(i=0;i<nc;i++)
    Check+=Pulse_Width[i]+Pulse_Current[i]+Mode[i]; 

  Check&=0x1F;
  tmp|=Check;  
  this->Write_Buffer[0]=tmp;
  for(i=0;i<nc;i++){        
      ind=3*i+1;
      tmp=0;
      tmp|=Mode[i]<<5;
      tmp|=Pulse_Width[i]>>7;
      this->Write_Buffer[ind]=tmp;
      tmp=0;
      tmp|=(Pulse_Width[i] &0x7F); 
      this->Write_Buffer[ind+1]=tmp;
      tmp=0;
      tmp|=(Pulse_Current[i]& 0x7F);
      this->Write_Buffer[ind+2]=tmp;
    }

  //SENDING
  this->Sport.serial_sendstring(Write_Buffer, Number_Bytes); 
  //increse counter for sent updates
  this->sent_updates++;
  
  //READING RESPONSES

#ifdef _TTY_POSIX_
   #if BLOCK
   	norb=this->Sport.serial_read_timeout(Read_Buffer,1);
   #else
  	norb=this->Sport.serial_read_nonblocking(Read_Buffer,10);
   #endif
#else
   norb=this->Sport.serial_readstring(Read_Buffer,1);
#endif

  if (norb>0){
    for (i=0;i<norb;i++){
  #if SHOWRESPONSE  
      printf("Quittung %02x\n",(unsigned char) Read_Buffer[i]);
  #endif
      if ((norb>0)&&(((unsigned char) Read_Buffer[i])==0x41))
	this->successful_updates++;
      else
	this->unsuccessful_updates++;
    }
  }
  
  //  if (run==0)
  //     {
  //       run=1; 
  //       error=1;
  //     }
  //   else
  //     {
  //       time1=mu_time();
  //       //norb=0;
  //       //while (norb<1) {
  //       //	norb=this->Sport.serial_read_nonblocking(Read_Buffer, 1);
  //       //}
  //       norb=this->Sport.serial_read_timeout(Read_Buffer, 1);
  //       Receive=Read_Buffer[0];
  //       if ((norb>0)&&(Receive==0x41)){
  // 	error=0;
  //       }
  //       else{
  // 	error=1;
  //       }
  //       time2=mu_time(); 
  //       printf("Response Time %d\n",time2-time1);
  //}
  return error; 
}


/*!
\fn int stimulator::Send_Stop_Signal()
Sending stop signal to the stimulator
*/

int stimulator::Send_Stop_Signal()
{
  unsigned int i;
  char tmp;
  int error;
  int norb;
  unsigned int  Number_Bytes=1;
  int read_byte;
  char Read_Buffer[1000];
  // unsigned int index[8];
  /* b y t e  0*/
  tmp=0xC0; /* Setting bit B7 and B6 */
  Write_Buffer[0]=tmp;

#ifdef _TTY_POSIX_
     norb=this->Sport.serial_read_timeout(Read_Buffer, 
		    this->sent_updates-this->successful_updates-this->unsuccessful_updates);
 #else
   norb=this->Sport.serial_readstring(Read_Buffer,
 		    this->sent_updates-this->successful_updates-this->unsuccessful_updates);
 #endif

  if (norb>0){
    for (i=0;i<norb;i++){
  	#if SHOWRESPONSE
      	printf("Quittung %02x\n",(unsigned char) Read_Buffer[i]);
  	#endif
      if ((norb>0)&&(((unsigned char) Read_Buffer[i])==0x41))
	this->successful_updates++;
      else
	this->unsuccessful_updates++;
    }
  }

  this->Sport.serial_sendstring(Write_Buffer, Number_Bytes); 
  
#ifdef _TTY_POSIX_
   norb=this->Sport.serial_read_timeout(Read_Buffer, 1);
#else
  norb=this->Sport.serial_readstring(Read_Buffer, 1);
#endif

  #if SHOWRESPONSE  
      printf("Quittung %02x\n",(unsigned char) Read_Buffer[0]);
  #endif
  if ((norb==1)&&(((unsigned char) Read_Buffer[0])==0x81)){
    printf("Stopped Stimulation successfully\n");
    printf("Updates: %d, Successful Updates %d, Unsuccessful Updates %d, Missing Responses %d \n",
	   this->sent_updates,this->successful_updates,this->unsuccessful_updates,this->sent_updates-
	   this->successful_updates-this->unsuccessful_updates);
    error=0;
    this->initialised=0;
  }
  else{
    printf("Stopped Stimulation failed: %d \n",norb);
    printf("Updates: %d, Successful Updates %d, Unsuccessful Updates %d, Missing Responses %d \n",
	   this->sent_updates,this->successful_updates,this->unsuccessful_updates,this->sent_updates-
	   this->successful_updates-this->unsuccessful_updates);
    printf("Quittung %02x\n",(unsigned char) Read_Buffer[0]);
    error=1;
  }


  for (i=0;i<8;i++)
    this->index[i]=i; //resetting the index
  
  if (error==0)
    this->initialised=0;
    
  return error;  
} 

/*!
\fn int stimulator::Send_Single_Pulse(unsigned int Channel_Number,
                                      unsigned int Pulse_Width,
		                      unsigned int Pulse_Current)


\param Channel_Number The number of the channel to be activated
\param Pulse_Width Pulse Width
\param Pulse_Current Current


This function is for a single pulse. 

Error code:
\verbatim
Error                  Explanation
------------------    ----------------------------------------------------
0                      No error has occurred
1                      stimulator not initialised

\endverbatim
*/

int stimulator::Send_Single_Pulse(unsigned int Channel_Number,
		      unsigned int Pulse_Width,
		      unsigned int Pulse_Current)
{

  
  int nb=4;
  char tmp;
  int norb;
  char Read_Buffer[10];
  int Receive;
  int error;
  unsigned int Check;
  int Number_Bytes=nb;
  int i;
  

  /* B Y T E  0 */
  tmp=0xE0; /* Setting bit B7 ,B6 and B5 */
  Check=Pulse_Width+Pulse_Current+Channel_Number; /* Adding all current and 
					       pulse with */
  Check&=0x1F; /* Take the 5 first bits of checksum (modulo 32)*/
 
  tmp|=Check;  
  this->Write_Buffer[0]=tmp;
      
  /* B Y T E 1 */     
  tmp=0;
  tmp|=Channel_Number<<4;
  tmp|=Pulse_Width>>7;
  this->Write_Buffer[1]=tmp;
  /* B Y T E 2 */
  tmp=0;
  tmp|=(Pulse_Width&0x7F) ; /* 7LSB of pulse width */
  this->Write_Buffer[2]=tmp;
  /* B Y T E 3 */  
  tmp=0;
  tmp|=(Pulse_Current&0x7F);
  this->Write_Buffer[3]=tmp;

  this->Sport.serial_sendstring(this->Write_Buffer, Number_Bytes); 
  

  /*
  printf("Number Bytes: %u\n",Number_Bytes);
  printf("Write Buffer: "); 
  for(i=0;i<Number_Bytes;i++)
    printf(" %X",Write_Buffer[i]);
  printf("\n");
  */
  

#ifdef _TTY_POSIX_
   norb=this->Sport.serial_read_timeout(Read_Buffer, 1);
 #else
   norb=this->Sport.serial_readstring(Read_Buffer, 1);
#endif
  Receive=(0XFF&Read_Buffer[0]);
 
   if (norb>0& (0xFF&Receive)==0xC1){
     //     printf("Updating parameters succsessfull\n");
     error=0;
   }
   else{
     //  printf("Updating parameter failed\n");
     error=1;
   }
   return error;
}

/*!
\fn void stimulator::Make_Index(double *S_Channel_Stim, int nc)

*/

void stimulator::Make_Index(double *S_Channel_Stim, int nc)
{
  int i,j,n;

  n=0;
  for (i=1;i<9;i++)
    for(j=0;j<nc;j++)
      {
	if ((int)S_Channel_Stim[j]==i)
	  {
	    this->index[n]=j;
	    n++;
	  }
      }
  /*
  printf("index:");
  for(i=0;i<nc;i++)
    printf("%u ",this->index[i]);
  printf("\n");
  */

}

/*!
\fn unsigned int stimulator::Encode_Mode(double S_Mode)

*/


unsigned int stimulator::Encode_Mode(double S_Mode)
{

  unsigned int Mode;
  
  
  if(S_Mode>2)
    Mode=2;
  else if (S_Mode<0)
    Mode=0;
  else
    Mode=(unsigned int)S_Mode;
  
  return Mode&0x03;
  
}
/*!
\fn unsigned int stimulator::Encode_Pulse_Current(double Dou_Current)

*/

unsigned int stimulator::Encode_Pulse_Current(double Dou_Current)
{

  unsigned int Int_Current;
    
  if(Dou_Current>127)
    Int_Current=127;
  else if (Dou_Current<0)
    Int_Current=0;
  else
    Int_Current=(unsigned int)Dou_Current;
  
  return Int_Current&0x7F;
  
}

/*!
\fn unsigned int stimulator::Encode_Pulse_Width(double Dou_Pulse_Width)

*/

unsigned int stimulator::Encode_Pulse_Width(double Dou_Pulse_Width)
{

  unsigned int Int_Pulse_Width;
  
  if(Dou_Pulse_Width>500)
    Int_Pulse_Width=500;
  else if (Dou_Pulse_Width<0)
    Int_Pulse_Width=0;
  else
    Int_Pulse_Width=(unsigned int)  Dou_Pulse_Width;
 
  return Int_Pulse_Width&0x1FF; 

}
/*!
\fn unsigned int stimulator::Encode_Channel_Stim(unsigned int *Channel_Stim, 
			double  *S_Channel_Stim, 
		 	int nc                   
			 )

*/

unsigned int stimulator::Encode_Channel_Stim(unsigned int *Channel_Stim, /* OV - Bit pattern of stimulation channels  */
			double  *S_Channel_Stim,    /* array of nominal channels, 1..8 */
			int nc                     /* Number of channels  */
			 )
{
  int i;
  *Channel_Stim=0;
  
  for(i=0;i<nc;i++) 	
    *Channel_Stim|=(unsigned int)pow(2,S_Channel_Stim[i]-1);
  //  printf("Test %f \n",pow(2.0,2.0));
  return 0;
}

/*!
\fn unsigned int stimulator::Encode_Channel_Lf(unsigned int *Channel_Lf, 
			double  *S_Channel_Lf,     
			int n_lf                    
			 ) 


*/

unsigned int stimulator::Encode_Channel_Lf(unsigned int *Channel_Lf,   /* OV - Bit pattern of low frequency channels */
			double  *S_Channel_Lf,      /* array of channel for low frequency  */
			int n_lf                    /* Number in the S_Channel_Lf vector */
			 )
{
  int i;
  *Channel_Lf=0;
  for(i=0;i<n_lf;i++)
    *Channel_Lf|=(unsigned int)pow(2,S_Channel_Lf[i]-1);
	return 0;  
}
