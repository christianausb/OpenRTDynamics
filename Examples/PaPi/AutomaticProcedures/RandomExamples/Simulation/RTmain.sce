// 
// 
// This a template for writing real-time applications using OpenRTDynamics
// (openrtdynamics.sf.net)
// 
//
// 


// The name of the program
ProgramName = 'RTmain'; // must be the filename without .sce
thispath = get_absolute_file_path(ProgramName+'.sce');
cd(thispath);
funcprot(0);

//
// To run the generated controller stored in template.[i,r]par, call from a terminal the 
//
// ortd --baserate=1000 --rtmode 1 -s template -i 901 -l 0
// 
// If you want to use harder real-time capabilities, run as root: 
// 
// sudo ortd --baserate=1000 --rtmode 1 -s template -i 901 -l 0
// 


deff('[x]=ra(from,to,len)','x=linspace(from,to,len)'' ');
deff('[x]=co(val,len)','x=val*ones(1,len)'' ');
deff('[x]=cosra(from,to,len)','  x=0.5-0.5*cos(linspace(0,%pi,len)); x=x*(to-from)+from; x=x'';  ');


exec('../Procedure.sce');


function [sim, u]=controller_I2(sim, ev, r, y, kg)
    // lambda integral controller
    // kg is variable

    z = poly(0, 'z');

    u = r;
    [sim, e] = ld_add(sim, ev, list(r, y), [1, -1] );
    [sim, e_] = ld_mult(sim, ev, list(e, kg), [0,0] ); //

    [sim, u] = ld_limited_integrator2(sim, ev, e_, min__=0.1, max__=1, Ta=1)
endfunction









// The main real-time thread
function [sim, outlist, userdata] = Thread_MainRT(sim, inlist, userdata)
    // This will run in a thread
    //    [sim, Tpause] = ld_const(sim, ev, 1/27);  // The sampling time that is constant at 27 Hz in this example
    [sim, Tpause] = ld_const(sim, ev, 1/27);  // The sampling time that is constant at 27 Hz in this example
    [sim, out] = ld_ClockSync(sim, ev, in=Tpause); // synchronise this simulation





    //
    // Add you own control system here
    //
    [sim, one] = ld_const(sim, 0, 1);

    // feedback of the actuation variable without the disturbing_signal
    [sim, y_fb] = libdyn_new_feedback(sim); 
    [sim, y] = ld_gain(sim, 0, y_fb, 1);

    [sim, ang_fb] = libdyn_new_feedback(sim); 
    [sim, ang] = ld_gain(sim, 0, ang_fb, 1);

    // TODO
    TODO = 2;

    select TODO
    case 1

        // controller
        [sim, u] = ControlSystem(sim, y);
    case 2    
        [sim, zero] = ld_const(sim, 0, 0);

        
        [sim, u] = Auto_Experiment_Test1(sim, lam=y, ang, rlam=zero, gam=one, pm1=zero, pm2=zero);
    end

    // print the controller output
    [sim] = ld_printf(sim, 0, u, "u ", 1);

    // Simulation of a system to control
    z = poly(0, 'z');

    RecCurve = 5*[co(0,50); cosra(0,1,200); co(1,50) ];
    scf(1); clf; plot(linspace(0,1,300), RecCurve);
    [sim,u__] = ld_lookup(sim, 0, u, 0, 1, RecCurve, interpolation=1);
    [sim,y_kp1] = ld_ztf(sim, 0, u__, 1/z ); // lambda
    
    


    // model for the joint angle dynamics
    [sim, ang] = ld_ztf(sim, 0, y_kp1, 100/180*%pi  * 1/5  *(1-0.9)/(z-0.9) );
    
    // noise and ofs caused by the measurement of lambda
    [sim, y_kp1] = ld_add_ofs(sim, 0, y_kp1, 0.01434); // add some measurement ofs to lambda
    [sim, Rand] = ld_Random(sim, 0, Method=0, Seed=1);
    [sim, y_kp1_meas] = ld_add(sim, 0, list(y_kp1, Rand), [1,0.15] );
                    
//    [sim] = ld_printf(sim, 0, Rand, "Rand ", 1);

    // print the lambda
    [sim] = ld_printf(sim, 0, y, "y ", 1);
    [sim, bar_] = ld_gain(sim, 0, y, 80/5); 
    [sim] = ld_printfbar(sim, 0, in=bar_, str="y ");

    // print the angle
    [sim, ang_] = ld_gain(sim, 0, ang, 180/%pi);
    [sim] = ld_printf(sim, 0, ang_, "ang ", 1);
    [sim, bar_] = ld_gain(sim, 0, ang_, 80/90); 
    [sim] = ld_printfbar(sim, 0, in=bar_, str="ang ");

    // Feed back u
    [sim] = libdyn_close_loop(sim, y_kp1_meas, y_fb);
    [sim] = libdyn_close_loop(sim, ang, ang_fb);


    outlist = list();
endfunction




// This is the main top level schematic
function [sim, outlist] = schematic_fn(sim, inlist)  

    // 
    // Create a thread that runs the control system
    // 

    ThreadPrioStruct.prio1=ORTD.ORTD_RT_NORMALTASK; // or  ORTD.ORTD_RT_REALTIMETASK
    ThreadPrioStruct.prio2=0; // for ORTD.ORTD_RT_REALTIMETASK: 1-99 as described in   man sched_setscheduler
    // for ORTD.ORTD_RT_NORMALTASK this is the nice-value (higher value means less priority)
    ThreadPrioStruct.cpu = -1; // The CPU on which the thread will run; -1 dynamically assigns to a CPU, 
    // counting of the CPUs starts at 0

    [sim, StartThread] = ld_initimpuls(sim, ev); // triggers your computation only once
    [sim, outlist, computation_finished] = ld_async_simulation(sim, ev, ...
    inlist=list(), ...
    insizes=[], outsizes=[], ...
    intypes=[], outtypes=[], ...
    nested_fn = Thread_MainRT, ...
    TriggerSignal=StartThread, name="MainRealtimeThread", ...
    ThreadPrioStruct, userdata=list() );


    //    NOTE: for rt_preempt real-time you can use e.g. the following parameters:
    // 
    //         // Create a RT thread on CPU 0:
    //         ThreadPrioStruct.prio1=ORTD.ORTD_RT_REALTIMETASK; // rt_preempt FIFO scheduler
    //         ThreadPrioStruct.prio2=50; // Highest priority
    //         ThreadPrioStruct.cpu = 0; // CPU 0


    // output of schematic (empty)
    outlist = list();
endfunction










//
// Set-up (no detailed understanding necessary)
//

tic();

thispath = get_absolute_file_path(ProgramName+'.sce');
cd(thispath);
z = poly(0,'z');

// defile ev
ev = [0]; // main event

// set-up schematic by calling the user defined function "schematic_fn"
insizes = []; outsizes=[];
[sim_container_irpar, sim]=libdyn_setup_schematic(schematic_fn, insizes, outsizes);

// pack the simulation into a irpar container
parlist = new_irparam_set();
parlist = new_irparam_container(parlist, sim_container_irpar, 901); // pack simulations into irpar container with id = 901
par = combine_irparam(parlist); // complete irparam set
save_irparam(par, ProgramName+'.ipar', ProgramName+'.rpar'); // Save the schematic to disk

// clear
par.ipar = []; par.rpar = [];


t=toc();
disp(t);
