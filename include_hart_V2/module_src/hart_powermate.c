/********************************
* powermate
*
* 
*
*(c) 2007 Holger Nahrstaedt
*
*********************************/
#include "machine.h"
#include <scicos_block4.h>
#include <stdlib.h>
#include <errno.h>
#include <stdio.h>
#include <string.h>
#include <unistd.h>
#include <fcntl.h>
#include <math.h>
#include <termios.h>
#include <linux/input.h>
//#include "rtmain.h"

#define NUM_EVENT_DEVICES 30
#define NUM_VALID_PREFIXES 3
#define BUFFER_SIZE 32

#define max(a,b) (((a) > (b)) ? (a) : (b))
#define min(a,b) (((a) < (b)) ? (a) : (b))

#ifndef MSC_PULSELED
/* this may not have made its way into the kernel headers yet ... */
#define MSC_PULSELED 0x01
#endif

#if defined(RTAI)

#else

#endif

int abs_offset = 0;

struct oMate
{
	char devName[30];
	int fd;
	int ticks_per_round;
	double min;
	double max;
	double tours;
	double start;
	double value_per_tick;
	int abs_min;
	int abs_max;
	int abs_offset;
	double value;
	int button_pressed;
	int N;
};

struct input_event ibuffer[BUFFER_SIZE];
int open_powermate(const char *dev, int mode)
{
	int fd = open(dev, mode);
	char name[255];
	int i;
	//const char *valid_id_prefix = "PowerMate";
	const char* valid_prefix[NUM_VALID_PREFIXES] = {"Griffin PowerMate","Griffin SoundKnob", "Griffin Technology PowerMate"};



	if(fd < 0){
		fprintf(stderr, "Unable to open \"%s\": %s\n", dev, strerror(errno));
		return -1;
	}

	if(ioctl(fd, EVIOCGNAME(sizeof(name)), name) < 0){
		fprintf(stderr, "\"%s\": EVIOCGNAME failed: %s\n", dev, strerror(errno));
		close(fd);
		return -1;
	}

	// it's the correct device if the prefix matches what we expect it to be:
	//if(!strncasecmp(name, valid_id_prefix, strlen(valid_id_prefix)))
	//  return fd;

	for(i=0; i<NUM_VALID_PREFIXES; i++)
		if(!strncasecmp(name, valid_prefix[i], strlen(valid_prefix[i])))
			return fd;


	close(fd);
	return -1;
}

int find_powermate(int mode)
{
	char devname[256];
	int i, r;

	for(i=0; i<NUM_EVENT_DEVICES; i++){
		sprintf(devname, "/dev/input/event%d", i);
		r = open_powermate(devname, mode);
		if(r >= 0)
			return r;
	}

	return -1;
}

void powermate_pulse_led(int fd, int static_brightness, int pulse_speed, int pulse_table, int pulse_asleep, int pulse_awake)
{
	struct input_event ev;
	memset(&ev, 0, sizeof(struct input_event));

	static_brightness &= 0xFF;

	if(pulse_speed < 0)
		pulse_speed = 0;
	if(pulse_speed > 510)
		pulse_speed = 510;
	if(pulse_table < 0)
		pulse_table = 0;
	if(pulse_table > 2)
		pulse_table = 2;
	pulse_asleep = !!pulse_asleep;
	pulse_awake = !!pulse_awake;

	ev.type = EV_MSC;
	ev.code = MSC_PULSELED;
	ev.value = static_brightness | (pulse_speed << 8) | (pulse_table << 17) | (pulse_asleep << 19) | (pulse_awake << 20);

	if(write(fd, &ev, sizeof(struct input_event)) != sizeof(struct input_event))
		//fprintf(stderr, "write(): %s\n", strerror(errno));  
		;
}


void process_event(struct input_event *ev)
{
#ifdef VERBOSE
	fprintf(stderr, "type=0x%04x, code=0x%04x, value=%d\n",
			ev->type, ev->code, (int)ev->value);
#endif

	switch(ev->type){
		case EV_MSC:
			printf("The LED pulse settings were changed; code=0x%04x, value=0x%08x\n", ev->code, ev->value);
			break;
		case EV_REL:
			if(ev->code != REL_DIAL)
				fprintf(stderr, "Warning: unexpected rotation event; ev->code = 0x%04x\n", ev->code);
			else{
				abs_offset += (int)ev->value;
				printf("Button was rotated %d units; Offset from start is now %d units\n", (int)ev->value, abs_offset);
			}
			break;
		case EV_KEY:
			if(ev->code != BTN_0)
				fprintf(stderr, "Warning: unexpected key event; ev->code = 0x%04x\n", ev->code);
			else
				printf("Button was %s\n", ev->value? "pressed":"released");
			break;
		default:
			fprintf(stderr, "Warning: unexpected event type; ev->type = 0x%04x\n", ev->type);
	}

	fflush(stdout);
}


static void init(scicos_block *block)
{
	struct oMate * comdev = (struct  oMate*) malloc(sizeof(struct oMate));

	int fd=-1;

	fd = find_powermate(O_RDWR);
	//powermate = open_powermate(argv[1], O_RDONLY);

	if(fd < 0){
		fprintf(stderr, "Unable to locate powermate\n");
		//exit_on_error();
	}

	comdev->fd=fd;
	comdev->ticks_per_round=90;

	comdev->min=block->rpar[0];
	comdev->max=block->rpar[1];
	comdev->tours=block->rpar[2];
	comdev->start=block->rpar[3];

	comdev->value_per_tick = (comdev->max - comdev->min)/(comdev->tours*comdev->ticks_per_round);
	comdev->abs_min=(int)( (comdev->min - comdev->start)/comdev->value_per_tick );
	comdev->abs_max=(int)( (comdev->max - comdev->start)/comdev->value_per_tick );
	comdev->abs_offset=0;

	comdev->value=comdev->start;
	comdev->button_pressed=block->rpar[4];

	comdev->N=0;


	powermate_pulse_led(comdev->fd,128+(128*comdev->button_pressed),255,0,1,0);


	*block->work=(void *)comdev;
}








static void inout(scicos_block *block)
{
	struct oMate * comdev = (struct  oMate*) (*block->work);

	static int click_too_quick=0;//whenever a button press-release happens within one sample time

	int r, events, i;
	fcntl(comdev->fd,F_SETFL,O_NONBLOCK);
	r = read(comdev->fd, ibuffer, sizeof(struct input_event) * BUFFER_SIZE);

	if (click_too_quick) {
		comdev->button_pressed=0;
		click_too_quick=0;
	}

	if( r > 0 ){
		events = r / sizeof(struct input_event);
		for(i=0; i<events; i++) {
#ifdef VERBOSE
			fprintf(stderr, "type=0x%04x, code=0x%04x, value=%d\n",
					ibuffer[i].type, ibuffer[i].code, (int)ibuffer[i].value);
#endif


			switch(ibuffer[i].type){
				case EV_REL:
					if(ibuffer[i].code != REL_DIAL)
						fprintf(stderr, "Warning: unexpected rotation event; ibuffer[i].code = 0x%04x\n", ibuffer[i].code);
					else{
						comdev->abs_offset += (int)ibuffer[i].value;

						comdev->abs_offset = min(max(comdev->abs_min, comdev->abs_offset), comdev->abs_max);

						comdev->value = comdev->abs_offset*comdev->value_per_tick + comdev->start;

						//tcflush(comdev->fd, TCIOFLUSH);      

						//powermate_pulse_led(comdev->fd,255*((double)comdev->abs_offset/(double)comdev->ticks_per_round/comdev->tours),255,0,0,0);         

						//printf("Button was rotated %d units; value from start is now %f \n", (int)ibuffer[i].value, comdev->value);
					}
					break;
				case EV_KEY:
					if(ibuffer[i].code != BTN_0) {
						fprintf(stderr, "Warning: unexpected key event; ibuffer[i].code = 0x%04x\n", ibuffer[i].code);
					}
					else {
						
						//printf("Button was %s\n", ibuffer[i].value? "pressed":"released");

						if (block->rpar[4]) {	// Toggle Button
							if(ibuffer[i].value && comdev->N>2){
								comdev->button_pressed=!comdev->button_pressed;
							}
						}
						else {					// Press-Release
							if(comdev->N == 0) {
								click_too_quick=1;
							}
							else {
								comdev->button_pressed=ibuffer[i].value;
							}
						}
						comdev->abs_offset=0;
						comdev->value=comdev->start;
						powermate_pulse_led(comdev->fd,128+(128*comdev->button_pressed),255,0,1,0);
						// printf("Button_pressed %d\n", comdev->button_pressed);
						comdev->N=0;
					}
					break;
				//default:
					//fprintf(stderr, "Warning: unexpected event type; ibuffer[i].type = 0x%04x\n", ibuffer[i].type);
			}
		}
	}else{
		// fprintf(stderr, "read() failed: %s\n", strerror(errno));
		//exit_on_error();

	}

	double *y0 = block->outptr[0];
	double *y1 = block->outptr[1];
	y0[0]=comdev->value;
	y1[0]=comdev->button_pressed;
	comdev->N++;
}


static void end(scicos_block *block)
{
	struct oMate * comdev = (struct oMate *) (*block->work);

	int fSuccess;
	fSuccess = close(comdev->fd);
	if (fSuccess > 0) {
		printf("Error closing serial port: \n");
	}
	free(comdev);
}




void rt_powermate(scicos_block *block,int flag)
{
	if (flag==1){          /* set output */
		inout(block);
	}
	else if (flag==5){     /* termination */ 
		end(block);
	}
	else if (flag ==4){    /* initialisation */
		init(block);
	}
}
