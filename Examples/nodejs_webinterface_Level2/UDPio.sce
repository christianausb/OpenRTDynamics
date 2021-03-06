// 
// 
//   Example for a communication interface from ORTD using UDP datagrams to e.g.
//   nodejs. 
//   The file webinterface/webappUDP.js is the counterpart that provides a 
//   web-interface to control a oscillator-system in this example.
//   
//   For more details, please consider the readme-file.
// 
//   Rev 1
// 







// The name of the program
ProgramName = 'UDPio'; // must be the filename without .sce

// The following code is integrated into ORTD since rev 494.
// Thus the following line is commented.

// exec('webinterface/PacketFramework.sce');


// And example-system that is controlled via UDP and one step further with the Web-gui
// Superblock: A more complex oscillator with damping
function [sim, x,v] = damped_oscillator(sim, u)
    // create feedback signals
    [sim,x_feedback] = libdyn_new_feedback(sim);

        [sim,v_feedback] = libdyn_new_feedback(sim);

            // use this as a normal signal
            [sim,a] = ld_add(sim, ev, list(u, x_feedback), [1, -1]);
            [sim,a] = ld_add(sim, ev, list(a, v_feedback), [1, -1]);
    
            [sim,v] = ld_ztf(sim, ev, a, 1/(z-1) * T_a ); // Integrator approximation
    
            // feedback gain
            [sim,v_gain] = ld_gain(sim, ev, v, 0.1);
    
            // close loop v_gain = v_feedback
        [sim] = libdyn_close_loop(sim, v_gain, v_feedback);
    
    
        [sim,x] = ld_ztf(sim, ev, v, 1/(z-1) * T_a ); // Integrator approximation  
    
        // feedback gain
        [sim,x_gain] = ld_gain(sim, ev, x, 0.6);
    
    // close loop x_gain = x_feedback
    [sim] = libdyn_close_loop(sim, x_gain, x_feedback);
endfunction







// The main real-time thread
function [sim, outlist, userdata] = Thread_MainRT(sim, inlist, userdata)
  // This will run in a thread
  [sim, Tpause] = ld_const(sim, ev, 1/20);  // The sampling time that is constant at 20 Hz in this example
  [sim, out] = ld_ClockSync(sim, ev, in=Tpause); // synchronise this simulation

  //
  // Add you own control system here
  //


   Configuration.UnderlyingProtocoll = "UDP";
   Configuration.DestHost = "127.0.0.1";
   Configuration.DestPort = 20000;
   Configuration.LocalSocketHost = "127.0.0.1";
   Configuration.LocalSocketPort = 20001;
   PacketFramework.Configuration.debugmode = %t;
   [sim, PacketFramework] = ld_PF_InitInstance(sim, InstanceName="TrockenofenRemoteControl", Configuration)

   // Add a parameter for controlling the oscillator
   [sim, PacketFramework, Input]=ld_PF_Parameter(sim, PacketFramework, NValues=1, datatype=ORTD.DATATYPE_FLOAT, ParameterName="Oscillator input");

   // some some more parameters
   [sim, PacketFramework, AParVector]=ld_PF_Parameter(sim, PacketFramework, NValues=10, datatype=ORTD.DATATYPE_FLOAT, ParameterName="A vectorial parameter");
   [sim, PacketFramework, par2]=ld_PF_Parameter(sim, PacketFramework, NValues=2, datatype=ORTD.DATATYPE_FLOAT, ParameterName="Test");

   // printf these parameters
   [sim] = ld_printf(sim, ev, Input, "Oscillator input ", 1);
   [sim] = ld_printf(sim, ev, par2, "Test ", 2);
   [sim] = ld_printf(sim, ev, AParVector, "A vectorial parameter", 10);



  // The system to control
  T_a = 0.1; [sim, x,v] = damped_oscillator(sim, Input);

  // Stream the data of the oscillator
  [sim, PacketFramework]=ld_SendPacket(sim, PacketFramework, Signal=x, NValues_send=1, datatype=ORTD.DATATYPE_FLOAT, SourceName="X")
  [sim, PacketFramework]=ld_SendPacket(sim, PacketFramework, Signal=v, NValues_send=1, datatype=ORTD.DATATYPE_FLOAT, SourceName="V")
  
  // finalise the communication interface
  [sim,PacketFramework] = ld_PF_Finalise(sim,PacketFramework);
  ld_PF_Export_js(PacketFramework, fname="ProtocollConfig.json");


  outlist = list();
endfunction




// This is the main top level schematic
function [sim, outlist] = schematic_fn(sim, inlist)  

// 
// Create a thread that runs the control system
// 
   
        ThreadPrioStruct.prio1=ORTD.ORTD_RT_NORMALTASK; // or  ORTD.ORTD_RT_NORMALTASK
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


