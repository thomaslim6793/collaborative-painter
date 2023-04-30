/**
 * If you need to kill the current server's run process and restart it:
 * >> lsof -i :50001     # Get PID
 * >> kill <PID>         # Kill process of PID
 */

import std.stdio;
import std.socket;
import std.conv;
import std.array;
import std.json;
import std.string;
import std.algorithm;
import core.thread;
import std.datetime;
import core.thread;
import deque;

/** A Server is the location to which multiple clients connect and broadcasts the information
 * shared between them all.
*/
class Server {
    /++ Host is a string which is the server's address. +/
    private string host;
    /++ Port is the number which is the server's port. +/
    private ushort port;
    /++ 
     + NumOfClient is the number of clients currently connected 
     + and each client is assigned the number they joined to be used as Client ID.
    +/ 
    private int numOfClient;
    /++ ConnectedClientsList is the list of clients currently connected to server. +/
    private Socket[int] connectedClientsList;
    /++ DrawingActions is a stack for storing drawing actions. +/
    private Deque!(int[]) drawingActions;
    /++ UndoneDrawingActions is a stack for stroing the undone actions allowing for redo function. +/
    private Deque!(int[]) undoneDrawingActions;

    /** Intializes new empty server with given address and port. */
    this(string host, ushort port) {
        this.host = host;
        this.port = port;
        this.numOfClient = 0;
        this.drawingActions = new Deque!(int[]);
        this.undoneDrawingActions = new Deque!(int[]);
    }

/**
 * Function which runs functions needed to connect all clients
 * and broadcasts messages/data among all currently connected clients.
*/
    void run() {
        writeln("Server running on ", host, ":", port);
        char[65536] buffer;
        /++ Socket set containing sockets that are available to read +/
        auto readSet = new SocketSet();
        /++ Server listener +/
        auto listener = new Socket(AddressFamily.INET, SocketType.STREAM);
        scope(exit) listener.close();
        listener.bind(new InternetAddress(host,port));
        /++ Allows up to 4 sockets sending at the same time +/
        listener.listen(4);

        while (true) {
            /++ Clear the readSet +/
            readSet.reset();
		    /++ Add the server +/
            readSet.add(listener);
            /++ Add each client +/
            foreach(client ; connectedClientsList.byValue()){
                readSet.add(client);
            }
            /+ Handle each clients message +/
            if(Socket.select(readSet, null, null)){
                foreach(client; connectedClientsList.byValue()){
                    /** Check to ensure that the client
                     * is in the readSet before receving
                     * a message from the client.
                     */
                    if(readSet.isSet(client)){
                        /** Server effectively is blocked
                         * until a message is received here.
                         * When the message is received, then
                         * we send that message from the
                         * server to the client
                         */
                        auto got = client.receive(buffer);
                        if (got > 0){
			  try {
                            auto msg = to!string(buffer);
                            auto msgJson = parseJSON( msg);
                            /** Message being delivered is drawing action */
                            if (msgJson["type"].str == "data") {
                                /++ Broadcast the message to all clients except the sender +/
                                auto senderID = cast(int)msgJson["src"].integer;
                                writeln("Receiving draw Data from Client ",senderID);
                                auto pixel = msgJson["pixel"];

                                int xPos = cast(int)msgJson["pixel"].array[0].integer;
                                int yPos = cast(int)msgJson["pixel"].array[1].integer;
                                int w = cast(int)msgJson["pixel"].array[2].integer;
                                int h = cast(int)msgJson["pixel"].array[3].integer;
                                int r = cast(int)msgJson["pixel"].array[4].integer;
                                int g = cast(int)msgJson["pixel"].array[5].integer;
                                int b = cast(int)msgJson["pixel"].array[6].integer;

                                drawingActions.push_back([xPos, yPos, w, h, r, g, b]);
                                /++ Sends data packet to all other clients except sender +/
                                foreach (clientMap; connectedClientsList.byKeyValue()) {
                                    if (senderID != clientMap.key) {
                                        JSONValue data;
                                        data["src"] = this.host;
                                        data["dst"] = clientMap.key;
                                        data["type"] = "data";
                                        data["pixel"] = pixel;
                                        clientMap.value.send(data.toString());
                                        writeln("Sending draw Data to Client ", clientMap.key);
                                    }
                                }
                            }
                            /** Message being delivered is undo action */
                            else if (msgJson["type"].str == "undo") {
                                /++ Broadcasts the message to all clients except the sender +/
                                auto senderID = cast(int)msgJson["src"].integer;
                                writeln("Receiving undo from Client ",senderID);
                            
                                auto action = drawingActions.pop_back();
                                undoneDrawingActions.push_back(action);
                                
                                /++ Sends data packet to all other clients except sender +/
                                foreach (clientMap; connectedClientsList.byKeyValue()) {
                                    if (senderID != clientMap.key) {
                                        JSONValue data;
                                        data["src"] = this.host;
                                        data["dst"] = clientMap.key;
                                        data["type"] = "undo";
                                        clientMap.value.send(data.toString());
                                        writeln("Sending undo to Client ", clientMap.key);
                                    }
                                }
                            }
                            /** Message being delivered is redo action */
                            else if (msgJson["type"].str == "redo") {
                                /++ Broadcast the message to all clients except the sender +/
                                auto senderID = cast(int)msgJson["src"].integer;
                                writeln("Receiving redo from Client ",senderID);
                            
                                auto action = undoneDrawingActions.pop_back();
                                drawingActions.push_back(action);
                                
                                /++ Sends data packet to all other clients except sender +/
                                foreach (clientMap; connectedClientsList.byKeyValue()) {
                                    if (senderID != clientMap.key) {
                                        JSONValue data;
                                        data["src"] = this.host;
                                        data["dst"] = clientMap.key;
                                        data["type"] = "redo";
                                        clientMap.value.send(data.toString());
                                        writeln("Sending redo to Client ", clientMap.key);
                                    }
                                }
                            }
                            /** Message being delivered is refresh action */
                            else if (msgJson["type"].str == "refresh") {
                                /++ Broadcast the message to all clients except the sender +/
                                auto senderID = cast(int)msgJson["src"].integer;
                                writeln("Receiving refresh from Client ",senderID);

                                this.drawingActions = new Deque!(int[]);
                                this.undoneDrawingActions = new Deque!(int[]);

                                /++ Sends data packet to all other clients except sender +/
                                foreach (clientMap; connectedClientsList.byKeyValue()) {
                                    if (senderID != clientMap.key) {
                                        JSONValue data;
                                        data["src"] = this.host;
                                        data["dst"] = clientMap.key;
                                        data["type"] = "refresh";
                                        clientMap.value.send(data.toString());
                                        writeln("Sending refresh to Client ", clientMap.key);
                                    }
                                }
                            }
			  }catch(Exception e) {}
                        }
                    }
                }
                /++ The listener is ready to read and client wants to connect so we accept here. +/
                if(readSet.isSet(listener)){
                    auto newSocket = listener.accept();
                    /** Based on how our client is setup,
                     * we need to send them an 'history'
                     * message, so that the client can
                     * update his src id and receive the
                     * canvas others are drawing
                     */
                    JSONValue data;
                    data["src"] = this.host;
                    data["dst"] = numOfClient;
                    data["type"] = "history";
                    /++ Add a new client to the list +/
                    connectedClientsList[numOfClient] = newSocket;
                    /++ Send whole history as once +/
                    writeln("Sending History package to Client ", numOfClient);
                    int[][] arrayOfActions;
                    for (int i = 0; i < drawingActions.size(); i++) {
                        auto pixel = drawingActions.at(i);
                        arrayOfActions ~= pixel;
                    }
                    data["history"] = arrayOfActions;
                    newSocket.send(data.toString());
                    // increment client number
                    numOfClient ++;
                }
            }
        }
    }
}


unittest
{
    // Start server in a separate thread

    auto server = new Server("localhost", 50001);
    auto serverThread = new Thread(&server.run);
    // scope(exit) server.stop();
    // enforce(server.start() == true);

    // Connect a client to the server
    auto client = new Socket(AddressFamily.INET, SocketType.STREAM);
    scope(exit) client.close();
    client.connect(new InternetAddress("localhost", 50001));
    writeln("Connected to server");

    // Send a "data" message from the client to the server
    JSONValue dataMsg;
    dataMsg["src"] = server.host;
    dataMsg["type"] = "data";
    dataMsg["pixel"] = [10, 20, 30, 40, 50, 60, 70];
    auto dataStr = dataMsg.toString();
    // auto dataBytes = dataStr.to!ubyte[];
    client.send(dataStr);
    writeln("Sent data message from client");

    // Wait for the server to receive the message
    Thread.sleep(1000.msecs);

    // Check that the server received the message
    auto receivedMsg = server.drawingActions.front();
    writeln("Received message from client: ", receivedMsg);
    auto expectedMsg = [10, 20, 30, 40, 50, 60, 70];
    assert(receivedMsg == expectedMsg);

    // Send an "undo" message from the client to the server
    JSONValue undoMsg;
    undoMsg["src"] = server.host;
    undoMsg["type"] = "undo";
    auto undoStr = undoMsg.toString();
    // auto undoBytes = undoStr.to!ubyte[];
    client.send(undoStr);
    writeln("Sent undo message from client");

    // Wait for the server to receive the message
    Thread.sleep(1000.msecs);

    // Check that the server received the message
    receivedMsg = server.undoneDrawingActions.front();
    writeln("Received undo message from client: ", receivedMsg);
    expectedMsg = [10, 20, 30, 40, 50, 60, 70];

    assert(receivedMsg == expectedMsg);

    // Send a "redo" message from the client to the server
    JSONValue redoMsg;
    redoMsg["src"] = server.host;
    redoMsg["type"] = "redo";
    auto redoStr = redoMsg.toString();
    // auto redoBytes = redoStr.to!ubyte[];
    client.send(redoStr);
    writeln("Sent redo message from client");

    // Wait for the server to receive the message
    Thread.sleep(1000.msecs);

    // Check that the server received the message
    receivedMsg = server.drawingActions.front();
    writeln("Received redo message from client: ", receivedMsg);
    expectedMsg = [10, 20, 30, 40, 50, 60, 70];
    assert(receivedMsg == expectedMsg);
}

/** 
 * Main intializing function that creates and starts running server based 
 * on user input for address and port meaning it's not hard-coded.
*/
void main() {
    /++ Prompts the user for the server address and port.+/
    write("Enter server address: ");
    auto address = readln().strip();
    write("Enter server port: ");
    auto port = to!ushort(readln().strip());
    auto server = new Server(address, port);
    /++ Starts server which has been created from user inputs.+/
    server.run();
}
