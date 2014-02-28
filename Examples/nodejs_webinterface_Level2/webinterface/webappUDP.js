/*

  Sample communication interface to ORTD using UDP datagrams.
  A web-interface is provided, go to http://localhost:8090
  UDPio.sce is the counterpart whose simulation can be controlled
  via the web-interface.
  The web-interface is defined in html/main.html
  
*/

// http-server config
var HTTPPORT = 8091;
// var HiddenWebDir = "pwd63856";

// UDP config
var PORT = 20000;
var HOST = '127.0.0.1';
var ORTD_HOST = '127.0.0.1'; // the IP and port of the ORTD simulator running UDPio.sce
var ORTD_PORT = 20001;

var NValues = 7; // must be the same as NValues_send defined in UDPio.sce when calling UDPSend
var DataBufferSize = 20000; // Number of elementes stored in the ringbuffer
var NParameters = 6;





// 
// Includes
// 

http = require('http');
url = require("url"),
path = require("path"),
fs = require("fs")

var fs = require('fs');
var dgram = require('dgram');


// 
//    Load configuration
// 

var ProtocollConfig = require('../ProtocollConfig.json');
console.log(ProtocollConfig);

// $.getJSON("SourcesConfig.json", function(json) {
//     console.log(json); // this will show the info it in firebug console
// });


// 
// RingBuffer
// 

var RingBuffer = new RingBuffer(DataBufferSize, NValues);
console.log("RingBuffer created");


// 
// http-server
// 

// got from stackoverflow: 
// http://stackoverflow.com/questions/6084360/node-js-as-a-simple-web-server
var httpserver = http.createServer(function(request, response) {

  var uri = url.parse(request.url).pathname
    , filename = path.join(process.cwd(), 'html', uri);

  path.exists(filename, function(exists) {
    if(!exists) {
      response.writeHead(404, {"Content-Type": "text/plain"});
      response.write("404 Not Found\n");
      response.end();
      return;
    }

    if (fs.statSync(filename).isDirectory()) filename += '/index.html';

    fs.readFile(filename, "binary", function(err, file) {
      if(err) {        
        response.writeHead(500, {"Content-Type": "text/plain"});
        response.write(err + "\n");
        response.end();
        return;
      }

      response.writeHead(200);
      response.write(file, "binary");
      response.end();
    });
  });
}).listen(HTTPPORT);

// set-up socket.io
var io = require('socket.io').listen(httpserver);
io.set('log level', 1); // reduce logging


 
  
//  
// UDP interface
// 
var server = dgram.createSocket('udp4');
server.on('listening', function () {
    var address = server.address();
    console.log('UDP Server listening on ' + address.address + ":" + address.port);
});

// Buffer for sending UDP packets
var UDPSendPacketBuffer = new Buffer(2000); // size is propably bigger than every UDP-Packet


server.on('message', function (message, remote) {
    // received new packet from ORTD via UDP
    //console.log(remote.address + ':' + remote.port);  


    var i;
    
    try {
      // disassemble header
      var SenderID = message.readInt32LE( 0 );
      var PacketCounter = message.readInt32LE( 4 );
      var SourceID = message.readInt32LE( 8 );

      // check wheter the sender ID is correct
      if (SenderID != 1295793)
        throw 1;

      // get popoerties of this packet source
      SourceProperties = ProtocollConfig.SourcesConfig[SourceID]
      console.log( 'SourceProperties: ');
      console.log(  SourceProperties );
      
      if (SourceProperties.datatype != 257) // ORTD.DATATYPE_FLOAT
	throw 2;

      
      
      // check if the recved packet has the correct size
      if ( message.length != 12+8*SourceProperties.NValues_send) 
        throw 2;

      console.log('Disasm data '+ SourceProperties.NValues_send);
      
      // disassemble data-values
      var ValuesBuffer = message.slice(12, 12+8*SourceProperties.NValues_send);
      var Values = new Array(SourceProperties.NValues_send);
      
      for (i=0; i<SourceProperties.NValues_send; ++i)
        Values[i] = ValuesBuffer.readDoubleLE( i*8 );


      
      // new format
      try { io.sockets.emit('Update', { "SourceID" : SourceID, "Data" : Values } ); } catch(err) { }

      if ( SourceID == 0) {
	// send to all web browser
	try { io.sockets.emit('Values', Values ); } catch(err) { }
	
	
	// buffer the vales
	RingBuffer.addElement(Values);
      }
    } catch(e) {
      console.log("Received a malformed UDP-packet");
    }
  
  
  
  
});
 
// bind UDP-port
server.bind(PORT, HOST);


// 
// websockets connection to the web browser(s) 
// 
io.sockets.on('connection', function (socket) {
  console.log('iosocket init ok');
  
  // initially send to configuration
  socket.emit('ProtocollConfig', ProtocollConfig );
  
  // 
  socket.on('GetBuffer', function (data) {
//    io.sockets.emit('GetBufferReturn', [ RingBuffer.WriteIndex , RingBuffer.DataBuffer ] );
    socket.emit('GetBufferReturn', [ RingBuffer.WriteIndex , RingBuffer.DataBuffer ] );
  });
  


  
 // wait for a parameter upload by the client
  socket.on('ChangeParam_Set', function (data) {
    //
    // assemble the binary udp-packet
    //
    
    var i;
    
    // the required message length
    var MessageLength = 12+NParameters*8;
    
    // write the header of the UDP-packet
    UDPSendPacketBuffer.writeInt32LE( 1, 0 );
    UDPSendPacketBuffer.writeInt32LE( 1234, 4 );
    UDPSendPacketBuffer.writeInt32LE( 6468235, 8 );
    
    // add the parameters given in data[i]
    for (i=0; i<NParameters; ++i) {
      UDPSendPacketBuffer.writeDoubleLE(  data[i], 12+i*8 );
    }
                    
    // send this packet to ORTD
    server.send(UDPSendPacketBuffer, 0, MessageLength, ORTD_PORT, ORTD_HOST, function(err, bytes) {
      if (err) throw err;
      console.log('UDP message sent to ' + ORTD_HOST +':'+ ORTD_PORT);
    });    
  });
  
});



// 
// data ringbuffer
// 


// ring buffer class
function RingBuffer(DataBufferSize,NumElements)
{
  this.DataBufferSize=DataBufferSize;
  this.NumElements=NumElements;

  this.DataBuffer = CreateDataBufferMultidim(DataBufferSize, NumElements);
  this.WriteIndex = 0;
  
  function CreateDataBufferMultidim(DataBufferSize, NumElements) {
    var DataBuffer = new Array(DataBufferSize);
    var i, j;
    
    for (i=0; i<DataBufferSize; ++i) {
      DataBuffer[i] = new Array(NumElements);
      
      for (j=0; j<NumElements; ++j) {
	  DataBuffer[i][j] = 0;
      }
    }
    return DataBuffer;
  }
  
  this.addElement=addElement;
  function addElement(Values)  {
    // console.log("adding element at index " + this.WriteIndex);
    var i;
    for (i = 0; i<this.NumElements; ++i) {
	this.DataBuffer[this.WriteIndex][i] = Values[i]; // copy data 	
    }
    
    // inc counter
    this.WriteIndex++;
    
    // wrap counter
    if (this.WriteIndex >= this.DataBufferSize) {
      this.WriteIndex = 0;
    }
  }
  
//   this.ReturnBuffer=ReturnBuffer;
//   function ReturnBuffer() {
//     return DataBuffer;
//   }
}

