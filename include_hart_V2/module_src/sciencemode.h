/***************************************************************************
                          motionstim8.cpp  -  description
                             -------------------
    begin                :
    copyright            : (C) 2003 Max Planck Institute for Dynamics
                                    of Complex Dynamical Systems
    Author               :  Nils-Otto Negård

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
#ifndef SCIENCEMODE_H
#define SCIENCEMODE_H

#include "serialport.h"
#include <math.h>
#ifdef _TTY_POSIX_
#include <sys/time.h>
#else
#include <windows.h>
#include <stdio.h>
#define _CRT_DISABLE_PERFCRIT_LOCKS
//#include <ctype.h>
//#include <string.h>
#endif
#define BLOCK 0
#define SHOWRESPONSE 0


class stimulator
{
 public:
 stimulator();
 ~stimulator();

int Open_serial(char *Portname);

int Setup_serial();

int Close_serial();

int Send_Init_Param(unsigned int nc,
		    double *S_Channel_Stim,
		    unsigned int n_lf,
		    double *S_Channel_Lf,
		    double  S_Main_Time, 
		    double  S_Group_Time, 
		    double  S_N_Factor);

int Send_Init_Param(unsigned int nc,
		    unsigned int Channel_Stim,
		    unsigned int Channel_Lf,
		    unsigned int Main_Time, 
		    unsigned int Group_Time, 
		    unsigned int N_Factor);

int Send_Update_Parameter(double *S_Pulse_Width, 
			  double *S_Pulse_Current, 
			  double *S_Mode,
			  unsigned int nc);


int Send_Update_Parameter(unsigned int *Pulse_Width, 
			  unsigned int *Pulse_Current, 
			  unsigned int *Mode,
			  unsigned int nc);



int Send_Single_Pulse(unsigned int Channle_Number,
		      unsigned int Pulse_Width,
		      unsigned int Pulse_Current);

int Send_Stop_Signal();



int get_Init_String(char *out_Buffer);

int get_Update_String(char *out_Buffer,
		      unsigned int *nb);


private:
 //global parameter
 unsigned int Mode_Update; //calculate this from group and main time  
 unsigned int initialised;
 unsigned int Channel_Stim;
 unsigned int Channel_Lf;
 unsigned int Main_Time;
 unsigned int Group_Time;
 unsigned int N_Factor;
 unsigned int index[8]; //for use with simulink
 unsigned int nc; 
 char Init_Buffer[6];
 char Write_Buffer[25];
 unsigned int Number_Bytes;
 unsigned int Pulse_Width[8];
 unsigned int Pulse_Current[8];
 unsigned int Mode[8]; 
 SerialPort Sport;
 unsigned int sent_updates;
 unsigned int successful_updates;
 unsigned int unsuccessful_updates; 

 //private functions
void Make_Index(double *S_Channel_Stim,int nc);

unsigned int Encode_Mode(double S_Mode);

unsigned int Encode_Pulse_Current(double Dou_Current);


unsigned int Encode_Pulse_Width(double Dou_Pulse_Width);


unsigned int Encode_Channel_Stim(unsigned int *Channel_Stim,
					     double  *S_Channel_Stim, 
					     int nc           );



unsigned int Encode_Channel_Lf(unsigned int *Channel_Lf,
					   double  *S_Channel_Lf,
					   int n_lf );


};

#endif
