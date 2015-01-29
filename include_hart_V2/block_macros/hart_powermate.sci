function [x,y,typ] = hart_powermate(job,arg1,arg2)

  x=[];y=[];typ=[];
  select job
  case 'plot' then
    exprs=arg1.graphics.exprs;
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
      [ok,min_value,max_value,rounds,start,btn_mode,exprs]=..
      scicos_getvalue('Set POWERMATE block parameters',..
         ['Min. Value:';
         'Max Value:';
         'Tours between min and  max:';
         'Start Value:';
          '2nd Output - Press(0)/Toggle(1):'],..
      list('vec',-1,'vec',-1,'vec',-1,'vec',-1,'vec',-1),exprs)
catch
      [ok,min_value,max_value,rounds,start,btn_mode,exprs]=..
      getvalue('Set POWERMATE block parameters',..
         ['Min. Value:';
         'Max Value:';
         'Tours between min and  max:';
         'Start Value:';
          '2nd Output - Press(0)/Toggle(1):'],..
      list('vec',-1,'vec',-1,'vec',-1,'vec',-1,'vec',-1),exprs)
end;
     if ~ok then break,end
      in=[model.in]
      out=[model.out]
      evtin=[1]
      evtout=[]
      [model,graphics,ok]=check_io(model,graphics,in,out,evtin,evtout);
      if ok then
        graphics.exprs=exprs;
        model.ipar=[];
        model.rpar=[min_value;
max_value;
rounds;
start;
btn_mode
];
   model.dstate=[1];
        x.graphics=graphics;x.model=model
        break
      end
    end
  case 'define' then
     min_value=0;
     max_value=1;
     rounds=5;
     start=0;
     btn_mode=1;
   model=scicos_model()
   model.sim=list('rt_powermate',4)
   model.in=[]
   model.out=[ones(2,1)]
   model.evtin=[1]
   model.evtout=[]
   model.ipar=[];
   model.rpar=[min_value;
max_value;
rounds;
start;
btn_mode
];
 model.dstate=[1];
 model.blocktype='d';
 model.dep_ut=[%t %f];
    exprs=[sci2exp(min_value);sci2exp(max_value);sci2exp(rounds);sci2exp(start);sci2exp(btn_mode)]
    gr_i=['xstringb(orig(1),orig(2),[''POWERMATE'' ],sz(1),sz(2),''fill'');'];
    x=standard_define([3 2],model,exprs,gr_i)
case 'readout' then
      BLOCK.version=020;
      BLOCK.name='hart_powermate';
      BLOCK.comp_name='rt_powermate';
      BLOCK.desr_short='Set POWERMATE block parameters';
      BLOCK.dep_u=%t;
      BLOCK.dep_t=%f;
      BLOCK.blocktype='d';
      BLOCK.dstate='1';
      BLOCK.IOmatrix=%f;
      BLOCK.inset=%f;
      BLOCK.in='';
      BLOCK.outset=%f;
      BLOCK.out='ones(2,1)';
      BLOCK.evtin='1';
      BLOCK.evtout='';
      BLOCK.size='3 2';
      BLOCK.completelabel=%f;
      BLOCK.label=[39,39,80,79,87,69,82,77,65,84,69,39,39,10];
      BLOCK.ipar=[];
      BLOCK.rpar=[109,105,110,95,118,97,108,117,101,59,10,109,97,120,95,118,97,108,117,101,59,10,114,111,..
         117,110,100,115,59,10,115,116,97,114,116,59,10,98,116,110,95,109,111,100,101,10];
      BLOCK.opar=[];
      BLOCK.parameter=list();
      BLOCK.parameter($+1)=[];
      BLOCK.parameter(1).name='min_value';
      BLOCK.parameter(1).text='Min. Value:';
      BLOCK.parameter(1).type='vec';
      BLOCK.parameter(1).size='-1';
      BLOCK.parameter(1).init='0';
      BLOCK.parameter(1).visible_plot=%f;
      BLOCK.parameter($+1)=[];
      BLOCK.parameter(2).name='max_value';
      BLOCK.parameter(2).text='Max Value:';
      BLOCK.parameter(2).type='vec';
      BLOCK.parameter(2).size='-1';
      BLOCK.parameter(2).init='1';
      BLOCK.parameter(2).visible_plot=%f;
      BLOCK.parameter($+1)=[];
      BLOCK.parameter(3).name='rounds';
      BLOCK.parameter(3).text='Tours between min and  max:';
      BLOCK.parameter(3).type='vec';
      BLOCK.parameter(3).size='-1';
      BLOCK.parameter(3).init='5';
      BLOCK.parameter(3).visible_plot=%f;
      BLOCK.parameter($+1)=[];
      BLOCK.parameter(4).name='start';
      BLOCK.parameter(4).text='Start Value:';
      BLOCK.parameter(4).type='vec';
      BLOCK.parameter(4).size='-1';
      BLOCK.parameter(4).init='0';
      BLOCK.parameter(4).visible_plot=%f;
      BLOCK.parameter($+1)=[];
      BLOCK.parameter(5).name='btn_mode';
      BLOCK.parameter(5).text='2nd Output - Press(0)/Toggle(1):';
      BLOCK.parameter(5).type='vec';
      BLOCK.parameter(5).size='-1';
      BLOCK.parameter(5).init='1';
      BLOCK.parameter(5).visible_plot=%f;
      x=BLOCK;
  end
endfunction
