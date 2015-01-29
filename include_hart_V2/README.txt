Wrapper for Scicos/Xcos Blocks for including them into ORTD
-----------------------------------------------------------

Version date: 12.1.14

This is an module to ORTD (OpenRTDynamics.sf.net) for including blocks
made for Scicos/Xcos. Put the directory include_hart_V2 into the directory
"modules/" of the installation of ORTD and then do

make clean
make config
make
make install
make homeinstall

in the main ORTD-installation folder. Included in this template, there is
a block for accessing "Sciencemode" FES-stimulators and another for reading
out the Griffin Powermate-device.

To add new Scicos blocks, put all C/C++ files into the folder module_stc and
all interfacing functions (*.sci - files) into block_macros. All plain C functions
available that have a prefix rt_* will be considered to be Computational functions
of a Scicos-block.

If you need special libraries present in form of *.so files in some of the library
folders of the operating system, you may add an element -lMyLib to the file LDFLAGS,
whereby all elements must be contained in *one* line separated by spaces! 

To include a Block into ORTD-schematics, e.g.:


      cosblk = ortd_getcosblk2(blockname="hart_powermate", 'rundialog', 'powermate_block_cache.dat');

      [sim, cosoutlist] = ld_scicosblock(sim, 0, list(), cosblk);    
      pm1 = cosoutlist(1);      pm2 = cosoutlist(2);

      [sim] = ld_printf(sim, 0, pm1, "Powermate1" , 1);
      [sim] = ld_printf(sim, 0, pm2, "Powermate2" , 1);

The function call to "ortd_getcosblk2" opens up the configuration dialog for configuring
the block's parameters. Hereby, the string "hart_powermate" referes to the name of the 
computational function of the block, The given filename 'powermate_block_cache.dat' is
used to store the entered parameters to disk, thus they will appear once again the next
time the lines above is executed.

The ORTD-wrapper block "ld_scicosblock" then inludes the Scicos-block into the ORTD-simulation
using inputs that may be entered into the list() command. The outputs of the Scicos-block
are proved by the list cosoutlist and can be accessed with cosoutlist(1), ...





