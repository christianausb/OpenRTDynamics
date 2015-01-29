
# Change this to the folder where you installed ORTD
# if you plan to use this as a module, just put "../..".
ORTDFOLDER=../..


ifeq ($(main_makefile_invoked),yes)

else
	# If this makefile is just run within this directory

	CC = cc
	CPP = c++
	LD = ld

	# detect system type
	host-type := $(shell arch)

	ifeq ($(host-type),x86_64)
	# 64 Bit
	CFLAGS = -fPIC -O2 -g -I$(ORTDFOLDER)
	INCLUDE = -I$(ORTDFOLDER)
	LDFLAGS = -shared
	else
	# 32 Bit
	CFLAGS = -O2 -I$(ORTDFOLDER) -g
	INCLUDE = -I$(ORTDFOLDER)
	LDFLAGS = -shared 
	endif

endif # ifeq ($(main_makefile_invoked),yes)


program_C_SRCS := $(wildcard module_src/*.c)
program_CXX_SRCS := $(wildcard module_src/*.cpp)
program_C_OBJS := ${program_C_SRCS:.c=.o}
program_CXX_OBJS := ${program_CXX_SRCS:.cpp=.o}
program_OBJS := $(program_C_OBJS) $(program_CXX_OBJS)
program_INCLUDE_DIRS :=
program_LIBRARY_DIRS :=
program_LIBRARIES :=

INCLUDE += -Ihart_includes -Imodule_src

CFLAGS += $(INCLUDE) -D_TTY_POSIX_
CPPFLAGS =  $(CFLAGS)


all: lib macros
	@echo "Module include_hart done" #"Objects" $(program_OBJS)

lib: include_hart.o $(program_OBJS)
#	cp libhart.a module.a
#	ar q module.a include_hart.o   # Will always be included


	ar rvs module.a include_hart.o $(program_OBJS)  # Only include for "Linux" Target

.PHONY: macros
macros:
	cat block_macros/*.sci > scilab_loader.sce

clean:
	rm -f *.o module.a module_Linux.a module_src/*.o scilab_loader.sce FnList include_hart.cpp

config:	
	@echo "***********************************************************"
	@echo " HART inclusion module needs several libraries  "
	@echo " Maybe you need to install them, if they are not already"
	@echo " available"
	@echo ""
	@echo " Required LDFLAGS are"
	@echo ""
	@cat LDFLAGS
	@echo ""
	@echo "***********************************************************"
#	sudo apt-get install libblas-dev libgsl0-dev libgfortran3

include_hart.cpp: FnList
	cat FnList | bash buildCCode.sh > include_hart.cpp

include_hart.o: include_hart.cpp
	$(CC) $(CFLAGS) $(INCLUDE) -I$(ortd_root)/modules/scicos_blocks/scicos_include -c include_hart.cpp

FnList: $(program_OBJS)
	@echo "Creating list of computational functions"
	@echo "collection of every function in module_src/ matching rt_*"
	sh BuildFnList.sh

	#nm module_src/*.o | grep rt_ | awk '{print $3}' | awk '/^rt/ { print $1 }'

	#cp FnList_COPY FnList


# module_src/%.o: module_src/%.c% $(DEPS)
# 	$(CC) d -c -o $@ $< $(CFLAGS)














#all: lib
#	@echo "Module Template done." "Objects" $(program_OBJS)
	
# 
# plugin: lib pluginLoader.o 
# 	g++ -shared Template_blocks.o pluginLoader.o -o ortd_plugin.so
# #	g++ -shared module.a pluginLoader.o -o ortd_plugin.so
# 
# lib: Template_blocks.o 
# 	ar rvs module.a Template_blocks.o 
# 
# clean:
# 	rm -f *.o module.a module_Linux.a
# 
# 
# Template_blocks.o: Template_blocks.cpp
# 	$(CC) $(CFLAGS) $(INCLUDE) -c Template_blocks.cpp
# 
# #Template_SharedObjects.o: Template_SharedObjects.cpp	
# #	$(CC) $(CFLAGS) $(INCLUDE) -c Template_SharedObjects.cpp
# 	
# pluginLoader.o: pluginLoader.cpp
# 	$(CC) $(CFLAGS) $(INCLUDE) -c pluginLoader.cpp





