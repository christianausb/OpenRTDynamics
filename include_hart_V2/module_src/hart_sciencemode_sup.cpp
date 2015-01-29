/**-----------------------------------------------------------------------------------
 *  Copyright (C) 2008  Holger Nahrstaedt
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

/*
 * Christian Klauer 13.12.2010: Stimulation is now triggered by a state update
 */

#include <machine.h>
#include <scicos_block4.h>

#include <time.h>
#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <unistd.h>
#include <fcntl.h>
#include <math.h>
#include <termios.h>
#include <sys/ioctl.h>
#include <signal.h>

#include "sciencemode.h"

#if defined(RTAI)
  #include <rtai_lxrt.h>
 extern "C" {
#include "getstr.h"

    void rt_sciencemode_sup(scicos_block *block,int flag);
    void *get_a_name(const char *root, char *name);
   int rtRegisterScope(const char *name, int n);
   int rtRegisterLed(const char *name, int n);
   int rtRegisterMeter(const char *name, int n);
  }
#else

extern "C" {
    void rt_sciencemode_sup(scicos_block *block,int flag);
#include "getstr.h"
}


#endif


#define BLOCK 0
#define SHOWRESPONSE 0

struct oScience
{
  char devName[30];
  int PCFrequencyControl;
  int Start;
  stimulator stim;
  unsigned int nc;
  double S_Channel_Stim[8];
  double S_Main_Time;
  double S_Group_Time;
  double S_Mode;
  double S_Channel_Lf[8];
  double S_N_Factor;
  int n_lf;
  int DoStim;
  
  int fd;


};

int init_sciencemode_sup(scicos_block *block){
      struct oScience * comdev = (struct oScience *) malloc(sizeof(struct oScience));
	int fd;
      int error;
    char errorStringBuffer[200];
      int i,j,iparCount=0;
	char sName[15];
      comdev->DoStim=1;



    
    comdev->nc=block->ipar[iparCount];
    iparCount++;
    for (i=0;i<comdev->nc;i++){
      comdev->S_Channel_Stim[i]=block->ipar[iparCount];
      iparCount++;
    }
    comdev->n_lf=block->ipar[iparCount];
    iparCount++;
    for (i=0;i<comdev->n_lf;i++){
      comdev->S_Channel_Lf[i]=block->ipar[iparCount];
      iparCount++;
    }
    comdev->S_N_Factor=block->ipar[iparCount];
    iparCount++;
    


    comdev->S_Main_Time=block->rpar[0];
    comdev->S_Group_Time=block->rpar[1];


  #if defined(RTAI)
    par_getstr(sName,block->ipar,iparCount+1,block->ipar[iparCount]);
  #else
    par_getstr(sName,block->ipar,iparCount+1,block->ipar[iparCount]);
  #endif
    sprintf(comdev->devName,"/dev/%s",sName);
    printf("Opening stimulator device: %s  \n",comdev->devName);

   error=comdev->stim.Open_serial(comdev->devName);
  if (error<0){
    printf("Could not open the serial port %s\n",comdev->devName);
    // exit_on_error();
    //return 1;
    comdev->DoStim=0;
   }
  if (comdev->DoStim){
    error=comdev->stim.Setup_serial();
    if (error<0){
      printf("Error setting up port %s\n",comdev->devName);
      comdev->stim.Close_serial();
      //exit_on_error();
      comdev->DoStim=0;
      //return 1;
    }
  }
    if (comdev->DoStim) {
      error = comdev->stim.Send_Init_Param(comdev->nc,comdev->S_Channel_Stim,comdev->n_lf,comdev->S_Channel_Lf,
	  comdev->S_Main_Time,comdev->S_Group_Time,comdev->S_N_Factor);
      if (error>0)
      {
	j=sprintf(errorStringBuffer,"stim.Send_Init_Param: Could not initialise the CLM!\n");
	switch (error) {
	case 1:
	  j+=sprintf(errorStringBuffer + j,"Channel_Stim==0, no channels in the channel list\n");
	  break;
	case 2:
	  j+=sprintf(errorStringBuffer + j,"Group Time > Main_Time, Initialisation unsuccessfully\n");
	  break;
	case 3:
	  j+=sprintf(errorStringBuffer + j,"Did not receive any byte from stimulator\n");
	  j+=sprintf(errorStringBuffer + j,"Stimulator switched on, Sciencemode selected?\n");
	  j+=sprintf(errorStringBuffer + j,"To run the simulation anyway unplug the stimulator!");
	  break;
	case 4:
	  j+=sprintf(errorStringBuffer + j,"did not receive confirmation from stimulator\n");
	  break;
	case 5:
	  j+=sprintf(errorStringBuffer + j,"Group Time < nc * 1.5\n");
	  break;
	}
	printf("Closing serial port...\n");
	error=comdev->stim.Close_serial();  
	if (error >= 0) 
	  printf("done.\n");
	else 
	  printf("failed.\n");
	//ssSetErrorStatus(S,"Could not initialise the CLM!");
	//return;
	comdev->DoStim=0;
      }
      else
      {
	if (comdev->S_Main_Time==0)
	  comdev->PCFrequencyControl=1;
	else
	  comdev->PCFrequencyControl=0;
      }
    }

  *block->work=(void *)comdev;


}

//long int mu_time();

void inout_sciencemode_sup(scicos_block *block){

 // printf("scmd %ld\n", mu_time()); // print stimulation timestamp
  
 struct  oScience* comdev = (struct oScience *) (*block->work);
#if defined(RTAI)
  int ntraces=GetNin(block);
#else
  int ntraces=3*comdev->nc;
#endif
  int i,ret;
  double *S_Pulse_Width=GetRealInPortPtrs(block,1);
  double *S_Pulse_Current=GetRealInPortPtrs(block,2); 
  double *S_Mode=GetRealInPortPtrs(block,3);

  double sum_cur=0;
  double sum_pw=0;
   double max_mode;

      

  if (comdev->DoStim) {
    max_mode=1;
    for (i=0;i<comdev->nc;i++)
    {
      sum_cur=sum_cur+S_Pulse_Current[i];
      sum_pw=sum_pw+S_Pulse_Width[i];
      if ((S_Mode[i]+1)>max_mode)
	max_mode=(S_Mode[i]+1);
    }


    //if frequency is controlled by the pc then only send updates if realy stimulation in on
    if (comdev->PCFrequencyControl==1){
      if ((sum_cur>0)&&(sum_pw>0))
      {
	ret=comdev->stim.Send_Update_Parameter(S_Pulse_Width,S_Pulse_Current,S_Mode,comdev->nc);
	//* mute_period = (real_T) (double) (S_Group_Time * max_mode);
      }
      //else
	//* mute_period = 0;
    }
    else
    {
      //should be revised so that updates are only sent if something changes
      ret=comdev->stim.Send_Update_Parameter(S_Pulse_Width,S_Pulse_Current,S_Mode,comdev->nc);
      //* mute_period = (real_T) (double) (S_Group_Time * max_mode);
    }
  }

}

void end_sciencemode_sup(scicos_block *block){
  struct  oScience* comdev = (struct oScience *) (*block->work);
  int error;


  if (comdev->DoStim) {
      error=comdev->stim.Send_Stop_Signal();


      printf("Closing serial port...\n");

      error=comdev->stim.Close_serial();  
      if (error >= 0) 
      {
	printf("done.\n");
      }
      else 
      {
	printf("failed.\n");
      }
  } // end DoStim

  free(comdev);
}




void rt_sciencemode_sup(scicos_block *block,int flag)
{
  if ((flag==2)&&(block->nevprt==1)){          /* stimulate on state update */
    inout_sciencemode_sup(block);
  }
  else if (flag==5){     /* termination */
    end_sciencemode_sup(block);
  }
  else if (flag ==4){    /* initialisation */
    init_sciencemode_sup(block);
  }
}

