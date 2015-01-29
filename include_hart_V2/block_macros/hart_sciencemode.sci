function [x,y,typ] = hart_sciencemode(job,arg1,arg2)
//Stimulator Interface (RehaStim - Hasomed GmbH)
//
// Block Screenshot
//
// Description
//
//     Current 
// 
//     This input should be an array of values representing the currents desired on the channels specified in the block parameters.  Thus if the specified channels are [1 5 6] then there should be 3 inputs into this port, the first being for the stimulation channel 1 the second for stimulation channel 5 and the last for stimulation channel 6.
//     
//         Pulsewidth
// 
//     Similar to the current this input should also be an array of values, representing the pulsewidths desired on the channels specified in the block parameters. 
//     
//         Mode 
// 
//   Similar to the current this input should be an array of values representing the mode desired for each channels specified in the block parameters. The value of the mode should be either 0, 1 or 2:
//       0 is for singlet stimulation pulses.
//        1 is for doublet stimulation pulses.
//       2 is for tripplet stimulation pulses.
//
//
// Dialog box
//
// Serial Port:  The serial port connected to the stimulator.
// Channels to be Stimulated:  0 An array of channel numbers to be used (e.g. [1 2 5]).
// Main Time in ms (only in steps of 0.5ms):       The stimulation period (set this to 0 for external triggering).  For example, if a stimulation frequency of 50Hz is desired then this value should be set to 20ms.  This parameter can be set to 0ms to activate the external triggering of the stimulation pulse (or pulse group).  In this case the channels listed in the "Channels to be Stimulated" parameter will all be triggered each time this block is evaluated.  There is a minimum limit on this value defined by the Group Time and by the maximum mode input.
//Group Time in ms (only in steps of 0.5ms):   This parameter is the time between pulses in a doublet or triplet group.
// Low Freq Ch:      It is possible to set some channels to use a much lower frequency than the main frequency dictated by the Main Time parameter.  This is a useful feature when applying a mixed reflex and muscle stimulation pattern. The values listed in this parameter must also be listed in the "Channels to be Stimulated" parameter
// Low Freq Fc:         Rather than send a pulse (or pulse group) every time a channel is triggered, a pulse could be sent every nth time it is triggered.  Thus n is the Low Frequency Factor.
//
// Default Properties
//
// always active: yes
// direct-feedthrough: no
// zero-crossing: no
// mode: no
// regular inputs:  port 1 : size [1,1] / type 1
// regular outputs: port 1 : size [1,1] / type 1
// number/sizes of activation inputs: 1
// number/sizes of activation outputs: 0
// continuous-time state: no
// discrete-time state: yes
// object discrete-time state: no
// name of computational function: rt_par2ser
//  
//
// Interfacing Function
// hart_sciencemode.sci
// Computational Function
// hart_sciencemode.cpp
// Authors
// Holger Nahrstaedt
//

  x=[];y=[];typ=[];
  select job
  case 'plot' then
    exprs=arg1.graphics.exprs;
    name=exprs(1);
    standard_draw(arg1)
  case 'getinputs' then
    [x,y,typ]=standard_inputs(arg1)
  case 'getoutputs' then
    [x,y,typ]=standard_outputs(arg1)
  case 'getorigin' then
    [x,y]=standard_origin(arg1)
  case 'set' then
    x=arg1
    model=arg1.model;graphics=arg1.graphics;
    exprs=graphics.exprs;
    while %t do
  try
  getversion('scilab');
      [ok,name,channels,main_time,group_time,channels_LF,lowFreqFc,exprs]=..
      scicos_getvalue('Set RTAI SCIENCEMODE block parameters',..
         ['Device (add ending): /dev/Channels:';
         'Channels to be Stimulated (e.g. [1 2 5])';
         'Main Time in ms: The stimulation period (0 for external triggering)';
         'Group Time in ms: The time between pulses in a group (doublet or triplet)';
         'Low Freq Ch:   A sub-set of the channels selected for low frequency';
          'Low Freq Fc:   Stimulation is only every n times (n=factor)'],..
      list('str',1,'vec',-1,'vec',-1,'vec',-1,'vec',-1,'vec',-1),exprs)
catch
      [ok,name,channels,main_time,group_time,channels_LF,lowFreqFc,exprs]=..
      getvalue('Set RTAI SCIENCEMODE block parameters',..
         ['Device (add ending): /dev/Channels:';
         'Channels to be Stimulated (e.g. [1 2 5])';
         'Main Time in ms: The stimulation period (0 for external triggering)';
         'Group Time in ms: The time between pulses in a group (doublet or triplet)';
         'Low Freq Ch:   A sub-set of the channels selected for low frequency';
          'Low Freq Fc:   Stimulation is only every n times (n=factor)'],..
      list('str',1,'vec',-1,'vec',-1,'vec',-1,'vec',-1,'vec',-1),exprs)
end;
     if ~ok then break,end
      in=[ones(3,1)*length(channels)]
      out=[model.out]
      evtin=[1]
      evtout=[]
      [model,graphics,ok]=check_io(model,graphics,in,out,evtin,evtout);
      if ok then
        graphics.exprs=exprs;
        model.ipar=[length(channels);
channels';
length(channels_LF);
channels_LF';
lowFreqFc;
length(name);
ascii(name)'
];
        model.rpar=[main_time;
group_time
];
   model.dstate=[];
        x.graphics=graphics;x.model=model
        break
      end
    end
  case 'define' then
     name='stimulator';
     channels=[1 2];
     main_time=0;
     group_time=10;
     channels_LF=[];
     lowFreqFc=0;
   model=scicos_model()
   model.sim=list('rt_sciencemode',4)
   model.in=[ones(3,1)*length(channels)]
   model.out=[]
   model.evtin=[1]
   model.evtout=[]
   model.ipar=[length(channels);
channels';
length(channels_LF);
channels_LF';
lowFreqFc;
length(name);
ascii(name)'
];
   model.rpar=[main_time;
group_time
];
 model.dstate=[];
 model.blocktype='d';
 model.dep_ut=[%f %f];
    exprs=[name;sci2exp(channels);sci2exp(main_time);sci2exp(group_time);sci2exp(channels_LF);sci2exp(lowFreqFc)]
    gr_i=['xstringb(orig(1)+sz(1)/2,orig(2),[''Sciencemode'';name],sz(1)/2,sz(2),''fill'');',           'xstringb(orig(1)+sz(1)/6,orig(2)+sz(2)/4,[''pulse width'';],sz(1)/10,sz(2),''fill'');',         'xstringb(orig(1)+sz(1)/6,orig(2),[''current''],sz(1)/10,sz(2),''fill'');',         'xstringb(orig(1)+sz(1)/6,orig(2)-sz(2)/4,[''mode''],sz(1)/10,sz(2),''fill'');' ];
    x=standard_define([5 4],model,exprs,gr_i)
case 'readout' then
      BLOCK.version=020;
      BLOCK.name='hart_sciencemode';
      BLOCK.comp_name='rt_sciencemode';
      BLOCK.desr_short='Set RTAI SCIENCEMODE block parameters';
      BLOCK.dep_u=%f;
      BLOCK.dep_t=%f;
      BLOCK.blocktype='d';
      BLOCK.dstate='';
      BLOCK.IOmatrix=%f;
      BLOCK.inset=%t;
      BLOCK.in='ones(3,1)*length(channels)';
      BLOCK.outset=%f;
      BLOCK.out='';
      BLOCK.evtin='1';
      BLOCK.evtout='';
      BLOCK.size='5 4';
      BLOCK.completelabel=%t;
      BLOCK.label=[39,120,115,116,114,105,110,103,98,40,111,114,105,103,40,49,41,43,115,122,40,49,41,47,50,..
         44,111,114,105,103,40,50,41,44,91,39,39,83,99,105,101,110,99,101,109,111,100,101,39,39,..
         59,110,97,109,101,93,44,115,122,40,49,41,47,50,44,115,122,40,50,41,44,39,39,102,105,108,..
         108,39,39,41,59,39,44,10,32,32,32,32,32,32,32,32,32,32,39,120,115,116,114,105,110,103,98,..
         40,111,114,105,103,40,49,41,43,115,122,40,49,41,47,54,44,111,114,105,103,40,50,41,43,115,..
         122,40,50,41,47,52,44,91,39,39,112,117,108,115,101,32,119,105,100,116,104,39,39,59,93,44,..
         115,122,40,49,41,47,49,48,44,115,122,40,50,41,44,39,39,102,105,108,108,39,39,41,59,39,44,..
         10,32,32,32,32,32,32,32,32,39,120,115,116,114,105,110,103,98,40,111,114,105,103,40,49,41,..
         43,115,122,40,49,41,47,54,44,111,114,105,103,40,50,41,44,91,39,39,99,117,114,114,101,110,..
         116,39,39,93,44,115,122,40,49,41,47,49,48,44,115,122,40,50,41,44,39,39,102,105,108,108,..
         39,39,41,59,39,44,10,32,32,32,32,32,32,32,32,39,120,115,116,114,105,110,103,98,40,111,..
         114,105,103,40,49,41,43,115,122,40,49,41,47,54,44,111,114,105,103,40,50,41,45,115,122,40,..
         50,41,47,52,44,91,39,39,109,111,100,101,39,39,93,44,115,122,40,49,41,47,49,48,44,115,122,..
         40,50,41,44,39,39,102,105,108,108,39,39,41,59,39,10];
      BLOCK.ipar=[108,101,110,103,116,104,40,99,104,97,110,110,101,108,115,41,59,10,99,104,97,110,110,101,..
         108,115,39,59,10,108,101,110,103,116,104,40,99,104,97,110,110,101,108,115,95,76,70,41,59,..
         10,99,104,97,110,110,101,108,115,95,76,70,39,59,10,108,111,119,70,114,101,113,70,99,59,..
         10,108,101,110,103,116,104,40,110,97,109,101,41,59,10,97,115,99,105,105,40,110,97,109,..
         101,41,39,10];
      BLOCK.rpar=[109,97,105,110,95,116,105,109,101,59,10,103,114,111,117,112,95,116,105,109,101,10];
      BLOCK.opar=[];
      BLOCK.parameter=list();
      BLOCK.parameter($+1)=[];
      BLOCK.parameter(1).name='name';
      BLOCK.parameter(1).text='Device (add ending): /dev/Channels:';
      BLOCK.parameter(1).type='str';
      BLOCK.parameter(1).size='1';
      BLOCK.parameter(1).init='stimulator';
      BLOCK.parameter(1).visible_plot=%t;
      BLOCK.parameter($+1)=[];
      BLOCK.parameter(2).name='channels';
      BLOCK.parameter(2).text='Channels to be Stimulated (e.g. [1 2 5])';
      BLOCK.parameter(2).type='vec';
      BLOCK.parameter(2).size='-1';
      BLOCK.parameter(2).init='[1 2]';
      BLOCK.parameter(2).visible_plot=%f;
      BLOCK.parameter($+1)=[];
      BLOCK.parameter(3).name='main_time';
      BLOCK.parameter(3).text='Main Time in ms: The stimulation period (0 for external triggering)';
      BLOCK.parameter(3).type='vec';
      BLOCK.parameter(3).size='-1';
      BLOCK.parameter(3).init='0';
      BLOCK.parameter(3).visible_plot=%f;
      BLOCK.parameter($+1)=[];
      BLOCK.parameter(4).name='group_time';
      BLOCK.parameter(4).text='Group Time in ms: The time between pulses in a group (doublet or triplet)';
      BLOCK.parameter(4).type='vec';
      BLOCK.parameter(4).size='-1';
      BLOCK.parameter(4).init='10';
      BLOCK.parameter(4).visible_plot=%f;
      BLOCK.parameter($+1)=[];
      BLOCK.parameter(5).name='channels_LF';
      BLOCK.parameter(5).text='Low Freq Ch:   A sub-set of the channels selected for low frequency';
      BLOCK.parameter(5).type='vec';
      BLOCK.parameter(5).size='-1';
      BLOCK.parameter(5).init='';
      BLOCK.parameter(5).visible_plot=%f;
      BLOCK.parameter($+1)=[];
      BLOCK.parameter(6).name='lowFreqFc';
      BLOCK.parameter(6).text='Low Freq Fc:   Stimulation is only every n times (n=factor)';
      BLOCK.parameter(6).type='vec';
      BLOCK.parameter(6).size='-1';
      BLOCK.parameter(6).init='0';
      BLOCK.parameter(6).visible_plot=%f;
      x=BLOCK;
  end
endfunction
