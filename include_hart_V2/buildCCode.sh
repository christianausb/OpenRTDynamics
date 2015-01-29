# Read a list of function names from stdin
# and return C-Code on stdout

read -d '' list


cat <<"EOF"

#include <malloc.h>

extern "C" {
#include "libdyn.h"
//#include "libdyn_scicos_macros.h"

#include "scicos_block4.h"
}

// This function is provided by the ORTD scicos_blocks module through libortd.[a,so]
extern "C" void ORTD_scicos_compfn_list_register(char *name, void *compfnptr);

// These functions come from the compfn/ subdirectory and are the scicos blocks/schematics FIXME: Autogenerate

EOF



for i in $list
do
  echo 'extern "C" int  '$i'(scicos_block *block, int flag);'
done

# 
# 
# 
# #MIDDLE=$(cat <<EOF
cat <<"EOF"

// This function is called by rtmain.c
void register_hart_scicosblocks() { 
  printf("ORTD_register_scicosblocks was called\n");

EOF


for i in $list
do
  echo 'ORTD_scicos_compfn_list_register("'$i'", (void*) &'$i');'
done

# 
# #FOOTER=$(cat <<EOF
cat <<"EOF"

} // close fn register_hart_scicosblocks

// Export to C so the libdyn simulator finds this function
extern "C" {
    // ADJUST HERE: must match to the function name in the end of this file
    int libdyn_module_include_hart_siminit(struct dynlib_simulation_t *sim, int bid_ofs);
}

// CHANGE HERE: Adjust this function name to match the name of your module
extern "C" int libdyn_module_include_hart_V2_siminit(struct dynlib_simulation_t *sim, int bid_ofs)
{

//     // Register my blocks to the given simulation
    register_hart_scicosblocks();

    printf("libdyn module include_hart initialised\n");

}



  
EOF




