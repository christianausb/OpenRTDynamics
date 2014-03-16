// 
// 
//   A packet based communication interface from ORTD using UDP datagrams to e.g.
//   nodejs. 
//   webappUDP.js is the counterpart that provides a web-interface to control 
//   a oscillator-system in this example.
// 
// 


function [PacketFramework,SourceID] = ld_PF_addsource(PacketFramework, NValues_send, datatype, SourceName)
  SourceID = PacketFramework.SourceID_counter;

  Source.SourceName = SourceName;
  Source.SourceID = SourceID;
  Source.NValues_send = NValues_send;
  Source.datatype =  datatype;
  
  // Add new source to the list
  PacketFramework.Sources($+1) = Source;
  
  // inc counter
  PacketFramework.SourceID_counter = PacketFramework.SourceID_counter + 1;
endfunction

function [PacketFramework,ParameterID,MemoryOfs] = ld_PF_addparameter(PacketFramework, NValues, datatype, ParameterName)
  ParameterID = PacketFramework.Parameterid_counter;

  Parameter.ParameterName = ParameterName;
  Parameter.ParameterID = ParameterID;
  Parameter.NValues = NValues;
  Parameter.datatype =  datatype;
  Parameter.MemoryOfs = PacketFramework.ParameterMemOfs_counter;
  
  // Add new source to the list
  PacketFramework.Parameters($+1) = Parameter;
  
  // inc counters
  PacketFramework.Parameterid_counter = PacketFramework.Parameterid_counter + 1;
  PacketFramework.ParameterMemOfs_counter = PacketFramework.ParameterMemOfs_counter + NValues;

  // return values
  ParameterID = Parameter.ParameterID; 
  MemoryOfs = Parameter.MemoryOfs;
endfunction

function [sim, PacketFramework, Parameter]=ld_PF_Parameter(sim, PacketFramework, NValues, datatype, ParameterName)
    [PacketFramework,ParameterID,MemoryOfs] = ld_PF_addparameter(PacketFramework, NValues, datatype, ParameterName);
   
//     [sim, readI] = ld_const(sim, ev, MemoryOfs); // start at index 1
//     [sim, Parameter] = ld_read_global_memory(sim, ev, index=readI, ident_str=PacketFramework.InstanceName+"Memory_"+ParameterName, ...
// 						datatype, NValues);

    [sim, readI] = ld_const(sim, ev, MemoryOfs); // start at index 1
    [sim, Parameter] = ld_read_global_memory(sim, ev, index=readI, ident_str=PacketFramework.InstanceName+"Memory", ...
						datatype, NValues);


endfunction

function [sim, PacketFramework]=ld_SendPacket(sim, PacketFramework, Signal, NValues_send, datatype, SourceName)

    // Send a signal via UDP, a simple protocoll is defined
    function [sim]=SendUDP(sim, Signal, InstanceName, NValues_send, datatype, SourceID)
      [sim,one] = ld_const(sim, 0, 1);

      // Packet counter, so the order of the network packages can be determined
      [sim, Counter] = ld_modcounter(sim, ev, in=one, initial_count=0, mod=100000);
      [sim, Counter_int32] = ld_ceilInt32(sim, ev, Counter);

      // Source ID
      [sim, SourceID] = ld_const(sim, ev, SourceID);
      [sim, SourceID_int32] = ld_ceilInt32(sim, ev, SourceID);

      // Sender ID
      [sim, SenderID] = ld_const(sim, ev, 1295793); // random number
      [sim, SenderID_int32] = ld_ceilInt32(sim, ev, SenderID);


      // print data
//       [sim] = ld_printf(sim, ev, Signal, "Signal to send = ", NValues_send);

      // make a binary structure
      [sim, Data, NBytes] = ld_ConcateData(sim, ev, ...
			    inlist=list(SenderID_int32, Counter_int32, SourceID_int32, Signal ), insizes=[1,1,1,NValues_send], ...
			    intypes=[ ORTD.DATATYPE_INT32, ORTD.DATATYPE_INT32, ORTD.DATATYPE_INT32, datatype ] );

      printf("The size of the UDP-packets will be %d bytes.\n", NBytes);

      // send to the network 
      [sim, NBytes__] = ld_constvecInt32(sim, ev, vec=NBytes); // the number of bytes that are actually send is dynamic, but must be smaller or equal to 
      [sim] = ld_UDPSocket_SendTo(sim, ev, SendSize=NBytes__, ObjectIdentifyer=InstanceName+"aSocket", ...
				  hostname="127.0.0.1", UDPPort=20000, in=Data, ...
				  insize=NBytes);

    endfunction




  [PacketFramework,SourceID] = ld_PF_addsource(PacketFramework, NValues_send, datatype, SourceName);
  [sim]=SendUDP(sim, Signal, PacketFramework.InstanceName, NValues_send, datatype, SourceID);
  
endfunction




function [sim, PacketFramework] = ld_PF_InitInstance(sim, InstanceName, Configuration)

      
//   Nvalues_recv = Configuration.Nvalues_recv;

  // initialise structure for sources
  PacketFramework.InstanceName = InstanceName;
//   PacketFramework.Nvalues_recv = list(Nvalues_recv); // number of parameters TODO remove
  PacketFramework.Configuration = Configuration;
  
  // sources
  PacketFramework.SourceID_counter = 0;
  PacketFramework.Sources = list();
  
  
  // parameters
  PacketFramework.Parameterid_counter = 0;
  PacketFramework.ParameterMemOfs_counter = 1; // start at the first index in the memory
  PacketFramework.Parameters = list();

endfunction

function [sim,PacketFramework] = ld_PF_Finalise(sim,PacketFramework)


      // The main real-time thread
      function [sim] = ld_PF_InitUDP(sim, InstanceName, ParameterMemory)

	  function [sim, outlist, userdata] = UDPReceiverThread(sim, inlist, userdata)
	    // This will run in a thread. Each time a UDP-packet is received 
	    // one simulation step is performed. Herein, the packet is parsed
	    // and the contained parameters are stored into a memory.

	    // Sync the simulation to incomming UDP-packets
	    [sim, Data, SrcAddr] = ld_UDPSocket_Recv(sim, 0, ObjectIdentifyer=InstanceName+"aSocket", outsize=PacketSize );

	    // disassemble packet's structure
	    [sim, DisAsm] = ld_DisassembleData(sim, ev, in=Data, ...
				  outsizes=[1,1,1,TotalElemetsPerPacket], ...
				  outtypes=[ ORTD.DATATYPE_INT32, ORTD.DATATYPE_INT32, ORTD.DATATYPE_INT32, ORTD.DATATYPE_FLOAT ] );



            DisAsm_ = list();
            DisAsm_(4) = DisAsm(4);
	    [sim, DisAsm_(1)] = ld_Int32ToFloat(sim, ev, DisAsm(1) );
	    [sim, DisAsm_(2)] = ld_Int32ToFloat(sim, ev, DisAsm(2) );
	    [sim, DisAsm_(3)] = ld_Int32ToFloat(sim, ev, DisAsm(3) );

	    // print the contents
	    [sim] = ld_printf(sim, ev, DisAsm_(1), "DisAsm(1) (SenderID)       = ", 1);
	    [sim] = ld_printf(sim, ev, DisAsm_(2), "DisAsm(2) (Packet Counter) = ", 1);
	    [sim] = ld_printf(sim, ev, DisAsm_(3), "DisAsm(3) (SourceID)       = ", 1);
	    [sim] = ld_printf(sim, ev, DisAsm_(4), "DisAsm(4) (Signal)         = ", TotalElemetsPerPacket);



            [sim, memofs] = ld_ArrayInt32(sim, 0, array=ParameterMemory.MemoryOfs, in=DisAsm(3) );
            [sim, Nelements] = ld_ArrayInt32(sim, 0, array=ParameterMemory.Sizes, in=DisAsm(3) );

 	    [sim, memofs_] = ld_Int32ToFloat(sim, ev, memofs );
 	    [sim, Nelements_] = ld_Int32ToFloat(sim, ev, Nelements );
  	    [sim] = ld_printf(sim, ev, memofs_ ,  "memofs                    = ", 1);
  	    [sim] = ld_printf(sim, ev, memofs_ ,  "Nelements                 = ", 1);




	    // Store the input data into a shared memory
// 	    [sim, one] = ld_const(sim, ev, 1);
// 	    [sim] = ld_write_global_memory(sim, 0, data=DisAsm(4), index=memofs_, ...
// 					  ident_str=InstanceName+"Memory", datatype=ORTD.DATATYPE_FLOAT, ...
// 					  ElementsToWrite=Nvalues_recv);

	    [sim] = ld_WriteMemory2(sim, 0, data=DisAsm(4), index=memofs, ElementsToWrite=Nelements, ...
					  ident_str=InstanceName+"Memory", datatype=ORTD.DATATYPE_FLOAT, MaxElements=TotalElemetsPerPacket );



	    // output of schematic
	    outlist = list();
	  endfunction

	
	
	// start the node.js service from the subfolder webinterface
	//[sim, out] = ld_startproc2(sim, 0, exepath="./webappUDP.sh", chpwd="webinterface", prio=0, whentorun=0);
	
        TotalMemorySize = sum(PacketFramework.ParameterMemory.Sizes);
        TotalElemetsPerPacket = floor((1400-3*4)/8); // number of doubles values that fit into one UDP-packet with maximal size of 1400 bytes
        PacketSize = TotalElemetsPerPacket*8 + 3*4;

	// Open an UDP-Port in server mode
	[sim] = ld_UDPSocket_shObj(sim, ev, ObjectIdentifyer=InstanceName+"aSocket", Visibility=0, hostname="127.0.0.1", UDPPort=20001);

	// initialise a global memory for storing the input data for the computation
	[sim] = ld_global_memory(sim, ev, ident_str=InstanceName+"Memory", ... 
				datatype=ORTD.DATATYPE_FLOAT, len=TotalMemorySize, ...
				initial_data=[zeros(TotalMemorySize,1)], ... 
				visibility='global', useMutex=1);

	// Create thread for the receiver
	ThreadPrioStruct.prio1=ORTD.ORTD_RT_NORMALTASK, ThreadPrioStruct.prio2=0, ThreadPrioStruct.cpu = -1;
	[sim, startcalc] = ld_const(sim, 0, 1); // triggers your computation during each time step
	[sim, outlist, computation_finished] = ld_async_simulation(sim, 0, ...
			      inlist=list(), ...
			      insizes=[], outsizes=[], ...
			      intypes=[], outtypes=[], ...
			      nested_fn = UDPReceiverThread, ...
			      TriggerSignal=startcalc, name=InstanceName+"Thread1", ...
			      ThreadPrioStruct, userdata=list() );


      endfunction





  // calc memory
  MemoryOfs = [];
  Sizes = [];
  // go through all parameters and create memories for all
  for i=1:length(PacketFramework.Parameters)
     P = PacketFramework.Parameters(i);

     Sizes = [Sizes; P.NValues];
     MemoryOfs = [MemoryOfs; P.MemoryOfs];
  end
  
  PacketFramework.ParameterMemory.MemoryOfs = MemoryOfs;
  PacketFramework.ParameterMemory.Sizes = Sizes;


  [sim] = ld_PF_InitUDP(sim, PacketFramework.InstanceName, PacketFramework.ParameterMemory);





// TODO: remove below

  // go through all parameters and create memories for all
  for i=1:length(PacketFramework.Parameters)
    
    
    ParameterID = PacketFramework.Parameters(i).ParameterID;
    ParameterName =  PacketFramework.Parameters(i).ParameterName;
    NValues = PacketFramework.Parameters(i).NValues;
    datatype = PacketFramework.Parameters(i).datatype;
    
    printf("Creating memory for parameter %s \n",ParameterName );
    disp(ParameterID );
    disp(ParameterName);
  

    
    	// initialise a global memory for storing the input data for the computation
    ident_str=PacketFramework.InstanceName+"Memory_"+ParameterName;
    
	[sim] = ld_global_memory(sim, ev, ident_str, ... 
				datatype, len=NValues, ...
				initial_data=[zeros(NValues,1)], ... 
				visibility='global', useMutex=1);
				
  end
endfunction

function ld_PF_Export_js(PacketFramework, fname)
   fd = mopen(fname,'wt');
  
   mfprintf(fd,' {""SourcesConfig"" : {\n');

  for i=1:length(PacketFramework.Sources)
    
    
    SourceID = PacketFramework.Sources(i).SourceID;
    SourceName =  PacketFramework.Sources(i).SourceName;
    disp(SourceID );
    disp( SourceName );
      
      
//      line=sprintf("%s : ""%s"", \n", string(PacketFramework.Sources(i).SourceID), string(PacketFramework.Sources(i).SourceName) );
//      line=sprintf("%s : { ""%s"" , ""%s"", ""%s""  }, \n", string(PacketFramework.Sources(i).SourceID), ...
//                string(PacketFramework.Sources(i).SourceName), ...
//                string(PacketFramework.Sources(i).NValues_send), ...
//                string(PacketFramework.Sources(i).datatype) );
     line=sprintf(" ""%s"" : { ""SourceName"" : ""%s"" , ""NValues_send"" : ""%s"", ""datatype"" : ""%s""  } \n", ...
               string(PacketFramework.Sources(i).SourceID), ...
               string(PacketFramework.Sources(i).SourceName), ...
               string(PacketFramework.Sources(i).NValues_send), ...
               string(PacketFramework.Sources(i).datatype) );
      
     
     if i==length(PacketFramework.Sources)
       // finalise
       printf('%s \n' , line);
       mfprintf(fd,'%s', line);
     else
       printf('%s, \n' , line);
       mfprintf(fd,'%s,', line);
     end
    
//     pause;
//      mprintf(fd, '%s', string(line) );
//      mfprintf(fd,'%s', line);
  end
  
  

  
   mfprintf(fd,'} , \n ""ParametersConfig"" : {\n');
   
  // go through all parameters and create memories for all
  for i=1:length(PacketFramework.Parameters)
    
    
//     ParameterID = PacketFramework.Parameters(i).ParameterID;
//     ParameterName =  PacketFramework.Parameters(i).ParameterName;
//     NValues = PacketFramework.Parameters(i).NValues;
//     datatype = PacketFramework.Parameters(i).datatype;
    
    printf("export of parameter %s \n",PacketFramework.Parameters(i).ParameterName );
//     disp(ParameterID );
//     disp(ParameterName);

     line=sprintf(" ""%s"" : { ""ParameterName"" : ""%s"" , ""NValues"" : ""%s"", ""datatype"" : ""%s""  } \n", ...
               string(PacketFramework.Parameters(i).ParameterID), ...
               string(PacketFramework.Parameters(i).ParameterName), ...
               string(PacketFramework.Parameters(i).NValues), ...
               string(PacketFramework.Parameters(i).datatype) );
      
     
     if i==length(PacketFramework.Sources)
       // finalise
       printf('%s \n' , line);
       mfprintf(fd,'%s', line);
     else
       printf('%s, \n' , line);
       mfprintf(fd,'%s,', line);
     end
    
    
  end  
  
  mfprintf(fd,'}\n}');
  
  mclose(fd);
endfunction







// OBSOLETE
function [sim, ParameterList] = ld_PF_GetParameters(sim, PacketFramework, Np)
  // Read the parameters
  
  ParameterList = list();
  
  for i=1:Np
  
    [sim, readI] = ld_const(sim, ev, i); // start at index 1
    [sim, Parameter] = ld_read_global_memory(sim, ev, index=readI, ident_str=PacketFramework.InstanceName+"Memory", ...
						datatype=ORTD.DATATYPE_FLOAT, 1);

//     [sim, readI] = ld_const(sim, ev, 2); // start at index 2
//     [sim, Parameter2] = ld_read_global_memory(sim, ev, index=readI, ident_str="ParameterMemory", ...
// 						datatype=ORTD.DATATYPE_FLOAT, 1);
// 
    
    [sim] = ld_printf(sim, ev, Parameter, "Parameter " + string(i) + " ", 1);
//     [sim] = ld_printf(sim, ev, Parameter2, "Parameter2 ", 1);

    ParameterList(i) = Parameter
  end
  
  //ParameterList = list(Parameter1, Parameter2);

endfunction





