// 
// 
// Tutorial session: Implement the functionality described by the TODO-comments!
// 
//
// 

//
// HINTS:
//
// Use the following blocks: 
//
// For 1) and 2): ld_add, ld_ztf, ld_gain, ld_mux, ld_savefile, ld_play_simple
// For 3) and 4): ld_compare01, ld_counter or ld_modcounter, ld_not, ld_cond_overwrite
//

// The name of the program
ProgramName = 'RTmain'; // must be the filename without .sce
thispath = get_absolute_file_path(ProgramName+'.sce');
cd(thispath);

//
// To run the generated controller stored in template.[i,r]par, call from a terminal
// and within the directory that contains this sce-file:
//
// $ ortdrun
// 


function [sim, u] = ControlSystem(sim, y)
      
    
  function [sim, outlist, active_state, x_global_kp1, userdata] = state_mainfn(sim, inlist, x_global, state, statename, userdata)
  // This function is called multiple times -- once to define each state.
  // At runtime, all states will become different nested simulations of 
  // which only one is active a a time. Switching
  // between them represents state changing, thus each simulation 
  // represents a certain state.
  
  printf("Defining state %s (#%d) ...\n", statename, state);
  

  // demultiplex x_global that is a state variable shared among the different states
  [sim, x_global] = ld_demux(sim, 0, vecsize=1, invec=x_global);

  // inputs signals to the state machine
  y = inlist(1);

  // sample data for the output (actuation variable)
  [sim, u] = ld_constvec(sim, 0, vec=[0] );
  [sim, zero] = ld_const(sim, 0, 0);

  // The signals "active_state" is used to indicate state switching: A value > 0 means the 
  // the state enumed by "active_state" shall be activated in the next time step.
  // A value less or equal to zero causes the statemachine to stay in its currently active
  // state

  select state
    case 1 // state 1
      [sim] = ld_printf(sim, 0, zero, "Controller active ", 1);
      
      // The reference      
      [sim, r] = ld_const(sim, 0, 1);

     // compare the input "inlist(1)" to thresholds
//     [sim, TargetReached] = ld_compare_01(sim, 0, in=y,  thr=1); // a lower level

      // the controller TODO: 1) Implement a PI-Controller!
      [sim, u] = ld_const(sim, 0, 4);
     
      // check if the reference is reached ( r == y )
      [sim, TargetReached] = reference_reached(sim, r, y, N=40, eps=0.05);
      [sim] = ld_printf(sim, 0, TargetReached, "target reached? ", 1);

      // Store the input data into a shared memory
      [sim, one] = ld_const(sim, 0, 1);
      [sim] = ld_write_global_memory(sim, 0, data=u, index=one, ...
				ident_str="ReferenceActuation", datatype=ORTD.DATATYPE_FLOAT, ...
				ElementsToWrite=1);

      // wait for the input signal to go bejond a threshold
      [ sim, active_state ] = ld_const(sim, 0, 0);  // by default: no state switch       
      [ sim, active_state ] = ld_cond_overwrite(sim, 0, in=active_state, condition=TargetReached, setto=2); // go to state "2" if reached is true

    case 2 // state 2

      // Read the parameters
      [sim, readI] = ld_const(sim, 0, 1); // start at index 1
      [sim, ReferenceActuation] = ld_read_global_memory(sim, 0, index=readI, ident_str="ReferenceActuation", ...
					      datatype=ORTD.DATATYPE_FLOAT, 1);

      [sim] = ld_printf(sim, 0, ReferenceActuation, "The required actuation in the operation point is ", 1);
      
      // TODO: 2) Implement a system identification experiment: Excite the system with a step-wiee actuation signal!
      // TODO: 2) While the experiment is running, I/O-data must be saved to the hard disk! Use a multiplexer to
      // TODO: 2) record y and u into the same file
      // TODO: 2) This state shall be left when the experiment is over.
      u = ReferenceActuation;
      
//      [sim] = ld_savefile(sim, events, fname, source, vlen);
      [sim] = ld_savefile(sim, 0, fname="y.dat", source=y, vlen=1);

      // wait 3 simulation steps and then switch to back to state 1
      [sim, active_state] = ld_steps(sim, 0, activation_simsteps=[100], values=[-1,3]);
      
    case 3 // state 3
      [sim] = ld_printf(sim, 0, zero, "Experiment finished ", 1);
      
      // TODO: 3) (Maybe homework ;-): Reduce the actuation variable u from ReferenceActuation to zero in
      // TODO: 3) steps of size 0.05 for every sample. Note that this may take a variable numer of controller
      // TODO: 3) steps to perform! 
      // TODO: 4) Then the system should go to a fourth state (pause), that you inserted into this state machine,
      // TODO: 4) when zero actuation is reached.

      u = zero;

      // wait 3 simulation steps and then switch to back to state 1
      [sim, active_state] = ld_steps(sim, 0, activation_simsteps=[27*4], values=[-1,1]);
      
      // TODO: 4) Insert state pause
  end

  // multiplex the new global states
  [sim, x_global_kp1] = ld_mux(sim, 0, vecsize=1, inlist=x_global);
  
  // the user defined output signals of this nested simulation
  outlist = list(u);
  endfunction
    
    
  // initialise a global memory for storing the actuation variable in the working point
  [sim] = ld_global_memory(sim, 0, ident_str="ReferenceActuation", ... 
			  datatype=ORTD.DATATYPE_FLOAT, len=1, ...
			  initial_data=[0], ... 
			  visibility='global', useMutex=1);
    
  // set-up three states represented by three nested simulations
  [sim, outlist, x_global, active_state,userdata] = ld_statemachine(sim, 0, ...
      inlist=list(y), ..
      insizes=[1], outsizes=[1], ... 
      intypes=[ORTD.DATATYPE_FLOAT  ], outtypes=[ORTD.DATATYPE_FLOAT], ...
      nested_fn=state_mainfn, Nstates=3, state_names_list=list("elevating", "measuring", "exp_finished"), ...
      inittial_state=1, x0_global=[0], userdata=list()  );  // TODO: 4) insert a state "pause"

    
  u = outlist(1);    
endfunction


// The main real-time thread
function [sim, outlist, userdata] = Thread_MainRT(sim, inlist, userdata)
  // This will run in a thread
  [sim, Tpause] = ld_const(sim, 0, 1/7);  // The sampling time that is constant at 27 Hz in this example
  [sim, out] = ld_ClockSync(sim, 0, in=Tpause); // synchronise this simulation

  //
  // Add you own control system here
  //

  // remote control interface
  Configuration.UnderlyingProtocoll = "UDP";
  Configuration.DestHost = "127.0.0.1";
  Configuration.DestPort = 20000;
  Configuration.LocalSocketHost = "127.0.0.1";
  Configuration.LocalSocketPort = 20001;
  PacketFramework.Configuration.debugmode = %t;
  [sim, PacketFramework] = ld_PF_InitInstance(sim, InstanceName="RemoteControl1", Configuration)

  // Add a parameter for controlling the oscillator
  [sim, PacketFramework, Input]=ld_PF_Parameter(sim, PacketFramework, NValues=1, datatype=ORTD.DATATYPE_FLOAT, ParameterName="Parameter 1");
  [sim] = ld_printf(sim, 0, Input, "P1 ", 1);


  // feedback of the actuation variable without the disturbing_signal
  [sim, y_fb] = libdyn_new_feedback(sim); [sim, y] = ld_gain(sim, 0, y_fb, 1);
  
    // controller
    [sim, u] = ControlSystem(sim, y);

    // print the controller output
    [sim] = ld_printf(sim, 0, u, "u ", 1);
  
    // Simulation of a system to control
    z = poly(0, 'z');
    [sim,y_kp1] = ld_ztf(sim, 0, u, 0.25*(1-0.97)/(z-0.97)  );  
    
    
    
    // print the systems output
    [sim] = ld_printf(sim, 0, y, "y ", 1);
    [sim, bar_] = ld_gain(sim, 0, y, 50); [sim] = ld_printfbar(sim, 0, in=bar_, str="y ");

  // Transfer data to PaPi
  [sim, PacketFramework]=ld_SendPacket(sim, PacketFramework, Signal=bar_, NValues_send=1, datatype=ORTD.DATATYPE_FLOAT, SourceName="y")

  // Feed back u
  [sim] = libdyn_close_loop(sim, y_kp1, y_fb);
  
  
  // finalise the communication interface
  [sim,PacketFramework] = ld_PF_Finalise(sim,PacketFramework);
  ld_PF_Export_js(PacketFramework, fname="ProtocolConfig.json");
  
  
  
  
  
  
  outlist = list();
endfunction


// Helper function
function [sim, reached] = reference_reached(sim, r, y, N, eps)
// 
// check wheter the controller reached the constant reference
// 

  [sim, e] = ld_add(sim, 0, list(r,y), [1,-1] );
  [sim, i1] = ld_ztf(sim, 0, e, 1/(3+1) * (1 + z^(-1) + z^(-2) + z^(-3) ) );
//   [sim, i2] = ld_ztf(sim, ev, u_Theta, (1-0.8)*(z-1)/(z-0.8) ) );

  [sim, i3] = ld_abs(sim, 0, i1);
  [sim, i4] = ld_compare_01(sim, 0, in=i3,  thr=eps);
  [sim, i5] = ld_not(sim, 0, in=i4);
  
  [sim, resetto] = ld_const(sim, 0, 0);
  [sim, count] = ld_counter(sim, 0, count=i5, reset=i4, resetto, initial=0);

  [sim, reached] = ld_compare_01(sim, 0, in=count,  thr=N);
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

        [sim, StartThread] = ld_initimpuls(sim, 0); // triggers your computation only once
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


