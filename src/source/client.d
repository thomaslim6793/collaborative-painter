/** Import D standard libraries */
import std.stdio;
import std.string;
import std.socket;
import std.json;
import std.conv;
import std.algorithm;
import std.array;
import std.random;

alias SocketType = std.socket.SocketType;

/** Import guiWindow and other relevant modules */
import guiWindow; 
import cairo.Context;
import cairo.ImageSurface;
import gtk.Widget;
import deque;

/** Networking stuff to work for gtk */
import glib.Timeout;
alias GSourceFunc = int function(void* userData);

/** A Client is a class that stores each person's canvas and the methods to draw on it
 * as well as recieve and send information to the server that they are connected to.
 * Implements GUIWindow class which gives visual representation of drawing area and actions.
*/
class Client : GUIWindow {
    private string address;
    private ushort port;
    private Socket socket;
    private int src;
    /++ Tells whether we received instruction to draw from server +/
    private bool serverDrawData;
    private bool serverUndoData;
    private bool serverRedoData;
    private bool executedHistory;

    /** Intializes new Client with given server address and port*/
    this(string address, ushort port) {
        /++ Call super class +/
        super("Networked Drawing App");
        this.address = address;
        this.port = port;
        /++ create a UDP socket +/
        this.socket = new Socket(AddressFamily.INET, SocketType.STREAM);
        /++ Set Non blocking +/
        this.socket.blocking(false);
        this.socket.connect(new InternetAddress(address, port));
        this.executedHistory = false;
        /++ Run checkUpdate method every 10 milliseconds. +/
        Timeout.add(1, &checkUpdateWrapper, cast(void*) this);
    }

    /** I need to wrap checkUpdateWrapper because Timeour.add takes in a 'extern(C) int function' type as argument. 
     * Need to make this a 'static' method to make '&checkUpdateWrapper' a 'function' type. Without 'static' keyword, 
     * '&checkUpdateWrapper' becomes a 'delegate' type. 
    */
    static extern(C) int checkUpdateWrapper(void* data) {
        auto client = cast(Client) data;
        client.checkUpdate();
        /++ Return 1 to keep the timeout running +/
        return 1;
    }

    /** Deconstructor */
    ~this() {
        this.socket.close();
        writeln("bye");
    }

    /** Completes and sends message to server for undo action */
    override void undoDrawingActions() {
        if (surfaceHistory.size > 0){
            /++ Send undo message to server. +/
            JSONValue undo;
            undo["src"] = this.src;
            undo["dst"] = this.address;
            undo["type"] = "undo";
            this.socket.send(undo.toString());
            /++ Perform undo drawing. +/
            auto previous = surfaceHistory.pop_back();
            undoneDrawingActions.push_back(currentState);
            currentState = previous;
        }
    }

    /** Completes and sends message to server for redo action */
    override void redoDrawingActions(){
        if (undoneDrawingActions.size > 0) {
            /++ Send redo message to server. +/
            JSONValue redo;
            redo["src"] = this.src;
            redo["dst"] = this.address;
            redo["type"] = "redo";
            this.socket.send(redo.toString());
            /++ Perform redo drawing. +/
            auto previous = undoneDrawingActions.pop_back();
            surfaceHistory.push_back(currentState);
            currentState = previous;
        }
    }

    /** Completes and sends message to server for refresh action */
    override void refreshDrawingArea() {
        JSONValue refresh;
        refresh["src"] = this.src;
        refresh["dst"] = this.address;
        refresh["type"] = "refresh";
        /++ Perform redo drawing. +/
        currentState = ImageSurface.create(cairo_format_t.ARGB32, windowDimensions[0], windowDimensions[1]);
        surfaceHistory = new Deque!(ImageSurface);
        undoneDrawingActions = new Deque!(ImageSurface);
        maxSizeUndoRedo = 500;
        this.socket.send(refresh.toString());
    }

    /** Completes and sends message to server for drawing action */
    override bool onDraw(Context cr) {
        if (isDrawing){
            JSONValue data;
            data["src"] = this.src;
            data["dst"] = this.address;
            data["type"] = "data";

            cr.setSourceRgb(r, g, b);
            cr.rectangle(x, y, pixelWidth, pixelHeight);
            cr.fill();

            surfaceHistory.push_back(deepCopyImageSurface(currentState));

            auto crState = Context.create(currentState);
            crState.setSourceRgb(r, g, b);
            crState.rectangle(x, y, pixelWidth, pixelHeight);
            crState.fill();
            data["pixel"] = [x, y, pixelWidth, pixelHeight, r, g, b]; // Get the drawn area
            this.socket.send(data.toString()); // send data to server
            if (surfaceHistory.size == maxSizeUndoRedo){
                surfaceHistory.pop_front();
            }
        }
        else if (serverDrawData){
            cr.setSourceRgb(serverR, serverG, serverB);
            cr.rectangle(x, y, this.serverPixelWidth, this.serverPixelHeight);
            cr.fill();
            surfaceHistory.push_back(deepCopyImageSurface(currentState));
            auto crState = Context.create(currentState);
            crState.setSourceRgb(serverR, serverG, serverB);
            crState.rectangle(x, y, this.serverPixelWidth, this.serverPixelHeight);
            crState.fill();
            if (surfaceHistory.size == maxSizeUndoRedo){
                surfaceHistory.pop_front();
            }
            /++ Set serverDrawData back to false after finished drawing. +/
            serverDrawData = false;
        }
        else {
            /++ If not drawing, make cr reflect the current state of the drawing area. +/
            cr.setSourceSurface(currentState, 0, 0);
            cr.paint();
        }
        return false;
    }

    /** Checks if there's any update from server */
    void checkUpdate() {
        /++ Message buffer will be 1024 bytes for now +/
        char[65536] buffer;
        /++ Receive from server +/
        auto received = socket.receive(buffer);
        /++ If there is data to parse +/
        if (received > 0) {
            auto msgStr = to!string(buffer);
            try{
                    auto msgJson = parseJSON( msgStr);
                    if (msgJson["type"].str == "history") {
                        writeln( "Receiving history package from server");
                        /++ Update client id +/
                        this.src = cast(int)msgJson["dst"].integer;
                        writeln("my src id", src);
                        int[][] history;

                        drawingArea.addOnDraw(delegate bool(Context cr, Widget drawingArea) {
                            if (!this.executedHistory) {
                                foreach (jsonValue; msgJson["history"].array) {
                                    int[] subArray;
                                    foreach (value; jsonValue.array())
                                    {
                                        subArray ~= cast(int)value.integer;
                                    }
                                    this.x = subArray[0];
                                    this.y = subArray[1];
                                    this.serverPixelWidth = subArray[2];
                                    this.serverPixelHeight = subArray[3];
                                    this.serverR = subArray[4];
                                    this.serverG = subArray[5];
                                    this.serverB = subArray[6];
                                    this.serverDrawData = true;
                                    this.onDraw(cr);
                                }
                                this.serverDrawData = false;
                                this.executedHistory = true;
                            }
                            /++ Return false to indicate that the drawing is complete +/
                            return false;
                        });

                    }
                    /++ Check if it the message in the package is a drawing action +/
                    else if (msgJson["type"].str == "data"){
                        writeln( "Receiving data package from server");
                        /++ Perform drawing action. +/   
                        x = cast(int)msgJson["pixel"].array[0].integer;
                        y = cast(int)msgJson["pixel"].array[1].integer;
                        this.serverPixelWidth = cast(int)msgJson["pixel"].array[2].integer;
                        this.serverPixelHeight = cast(int)msgJson["pixel"].array[3].integer;
                        this.serverR = cast(int)msgJson["pixel"].array[4].integer;
                        this.serverG = cast(int)msgJson["pixel"].array[5].integer;
                        this.serverB = cast(int)msgJson["pixel"].array[6].integer;
                        serverDrawData = true; 
                        drawingArea.queueDrawArea(x, y, this.serverPixelWidth, this.serverPixelHeight); 
                    } 
                    /++ Check if it the message in the package is a undo action +/
                    else if (msgJson["type"].str == "undo"){
                        if (surfaceHistory.size > 0){
                            /++ Perform undo action. +/   
                            auto previous = surfaceHistory.pop_back();
                            undoneDrawingActions.push_back(previous);
                            currentState = previous;
                            drawingArea.queueDraw();
                        }
                    } 
                    /++ Check if it the message in the package is a redo action +/
                    else if (msgJson["type"].str == "redo"){
                        if (undoneDrawingActions.size > 0) {
                            /++ Perform redo action. +/   
                            auto previous = undoneDrawingActions.pop_back();
                            surfaceHistory.push_back(previous);
                            currentState = previous;
                            drawingArea.queueDraw();
                        }
                    }
                     /++ Check if it the message in the package is a refresh action +/
                    else if (msgJson["type"].str == "refresh"){
                        /++ Perform refresh action. +/
                        currentState = ImageSurface.create(cairo_format_t.ARGB32, windowDimensions[0], windowDimensions[1]);
                        surfaceHistory = new Deque!(ImageSurface);
                        undoneDrawingActions = new Deque!(ImageSurface);
                        maxSizeUndoRedo = 500;
                        drawingArea.queueDraw();
                    }
            }
            catch(Exception e) {
            }
        }
    }
}
