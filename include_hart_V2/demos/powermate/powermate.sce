thispath = get_absolute_file_path('powermate.sce');
cd(thispath);

z = poly(0,'z');


//
// Set up simulation schematic
//


// This is the main top level schematic
function [sim, outlist] = schematic_fn(sim, inlist)
  // this is the default event
  ev = 0;



  [sim, zero] = ld_const(sim, ev, 0);

      // Include the scicosblock for the powermate
      cosblk = ortd_getcosblk2(blockname="hart_powermate", 'rundialog', 'powermate_block_cache.dat');

      [sim, cosoutlist] = ld_scicosblock(sim, ev, list(), cosblk);    
      pm1 = cosoutlist(1);      pm2 = cosoutlist(2);

      [sim] = ld_printf(sim, ev, pm1, "Powermate1" , 1);
      [sim] = ld_printf(sim, ev, pm2, "Powermate2" , 1);

      // calc a stimulation intensity
      [sim, pw1] = ld_gain(sim, ev, pm1, 500);
      [sim, pw2] = ld_constvec(sim, ev, vec=[100]);

      // stimulator
      [sim, pw] = ld_mux(sim, ev, vecsize=2, inlist=list(pw1,pw2) );
      [sim, I] = ld_constvec(sim, ev, vec=[20,20]);
      [sim, modus] = ld_constvec(sim, ev, vec=[0,0]);

      // include the scicos-block for the stimulator
      stim_cosblk = ortd_getcosblk2(blockname="hart_sciencemode_rt", 'rundialog', 'stimulator_block_cache.dat');

      [sim, cosoutlist] = ld_scicosblock(sim, ev, list(pw, I, modus), stim_cosblk);    
  
  
  
  // output of schematic
  [sim, out] = ld_const(sim, ev, 0);
  outlist = list(out); // Simulation output #1
endfunction


  
//
// Set-up
//

// defile events
defaultevents = [0]; // main event

// set-up schematic by calling the user defined function "schematic_fn"
insizes = [1,1]; outsizes=[1];
[sim_container_irpar, sim]=libdyn_setup_schematic(schematic_fn, insizes, outsizes);



//
// Save the schematic to disk (possibly with other ones or other irpar elements)
//

parlist = new_irparam_set();

// pack simulations into irpar container with id = 901
parlist = new_irparam_container(parlist, sim_container_irpar, 901);

// irparam set is complete convert to vectors
par = combine_irparam(parlist);

// save vectors to a file
save_irparam(par, 'controller.ipar', 'controller.rpar');

// clear
par.ipar = [];
par.rpar = [];




// optionally execute
messages=unix_g(ORTD.ortd_executable+ ' -s controller -i 901 -l 100');

//
//// load results
//A = fscanfMat('result.dat');
//
//scf(1);clf;
//plot(A(:,1), 'k');

