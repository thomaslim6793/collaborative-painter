/// Run with: 'dub'

// Import D standard libraries
import std.stdio;
import std.string;
import std.socket;
import std.json;
import std.conv;
import std.algorithm;
import std.array;
import std.random;

// Load the SDL2 library
import bindbc.sdl;
import loader = bindbc.loader.sharedlib;

// Load
import sdlapp;
import deque;
alias SocketType = std.socket.SocketType;

import gtk.Main;
import gtk.Widget;
import std.concurrency;



/// client class
class Client {
    private string address;
    private ushort port;
    private Socket socket;
    private int src;
    private SDLApp myApp;
    private Tid mainThreadId;
    
    // Stack for storing drawing actions.
    private Deque!(int[]) drawingActions;
    // Add another stack for undone actions to handle redo
    private Deque!(int[]) undoneDrawingActions;

    this(string address, ushort port) {
  
        // Create sdl application
        this.myApp = new SDLApp();

        this.address = address;
        this.port = port;
    
        // create a UDP socket
        this.socket = new Socket(AddressFamily.INET, SocketType.STREAM);
        // Set Non blocking
        this.socket.blocking(false);
        this.socket.connect(new InternetAddress(address, 50001));

        drawingActions = new Deque!(int[]);
        undoneDrawingActions = new Deque!(int[]);
    }
    
    /// our main application where we will draw from here
    void MainApplicationLoop(){
        scope(exit) this.socket.close();
        // Create an SDL window
        // Flag for determing if we are running the main application loop
        bool runApplication = true;
        // Flag for determining if we are 'drawing' (i.e. mouse has been pressed
        //                                                but not yet released)
        bool drawing = false;
        // Main application loop that will run until a quit event has occurred.
        // This is the 'main graphics loop'
        while(runApplication){

            SDL_Event e;
            // Handle events
            // Events are pushed into an 'event queue' internally in SDL, and then
            // handled one at a time within this loop for as many events have
            // been pushed into the internal SDL queue. Thus, we poll until there
            // are '0' events or a NULL event is returned.
            while(SDL_PollEvent(&e) !=0){
                if (e.type == SDL_QUIT){
                    runApplication= false;
                }
                else if (e.type == SDL_MOUSEBUTTONDOWN){
                    drawing=true;
                }else if (e.type == SDL_MOUSEBUTTONUP){
                    drawing=false;
                }else if (e.type == SDL_MOUSEMOTION && drawing){
                    // retrieve the position
                    int xPos = e.button.x;
                    int yPos = e.button.y;

                    // before updating the pixel, call backupSurface
                    this.myApp.backupSurface();
                    // Store the drawing action in drawingActions
                    drawingActions.push_back([xPos,yPos]);
                    // send drawing message to server
                    this.sendDrawing(xPos,yPos);
                    this.draw(xPos, yPos);

                } else if (e.type == SDL_KEYDOWN) {
                    switch(e.key.keysym.sym) {
                        case SDLK_u:
                            this.sendUndo();
                            break;
                        case SDLK_r:
                            this.sendRedo();
                            break;
                        default:
                            break;
                    }
                }
            }

            // check update from server
            this.checkUpdate();

            // Blit the surface (i.e. update the window with another surfaces pixels
            //                       by copying those pixels onto the window).
            SDL_BlitSurface(this.myApp.getSurface(),null,SDL_GetWindowSurface(this.myApp.getWindow()),null);
            // Update the window surface
            SDL_UpdateWindowSurface(this.myApp.getWindow());
            // Delay for 16 milliseconds
            // Otherwise the program refreshes too quickly
            SDL_Delay(16);
        }

        // Destroy our window
        SDL_DestroyWindow(this.myApp.getWindow());
    }

    // paint pixel on the canvas
    void draw(int xPos, int yPos) {
        // paint the canvas with data from server
        int brushSize=4;
        for (int w=-brushSize; w < brushSize; w++){
            for (int h=-brushSize; h < brushSize; h++){
                try {
                    // update pixel
                    this.myApp.UpdateSurfacePixel(xPos+w,yPos+h);
                } catch (Exception e) {
                    // do nothing
                }
            }
        }
    }

    /// send pixel data to server
    void sendDrawing(int xPos, int yPos) {
        int[] pixel = [xPos, yPos];
        JSONValue data;
        data["src"] = this.src;
        data["dst"] = this.address;
        data["type"] = "data";
        data["pixel"] = pixel;
        this.socket.send(data.toString());
    }

    /// check if there's any update from server
    void checkUpdate() {
        // Message buffer will be 1024 bytes for now
        char[65536] buffer;
        // receive from server
        auto received = socket.receive(buffer);
        // if there's data
        if (received > 0) {
            auto msgStr = to!string(buffer);
            try{
                auto msgJson = parseJSON( msgStr);
                // check if it's a data package
                if (msgJson["type"].str == "data"){
                    writeln( "Receiving data packaga from server");
                    int xPos = cast(int)msgJson["pixel"].array[0].integer;
                    int yPos = cast(int)msgJson["pixel"].array[1].integer;
                    // Back up surface. 
                    this.myApp.backupSurface();
                    // Store the drawing action in drawingActions
                    drawingActions.push_back([xPos,yPos]);
                    // paint the canvas with data from server and push drawing action onto drawingActions stack.
                    this.draw(xPos, yPos);
                } 
                else if (msgJson["type"].str == "undo"){
                    writeln( "Receiving data packaga from server");
                    this.undoDrawingActions();
                }  
                else if (msgJson["type"].str == "redo"){
                    writeln( "Receiving data packaga from server");
                    // redo drawing action
                    this.redoDrawingActions();
                }
                else if (msgJson["type"].str == "history") {
                    writeln( "Receiving history packaga from server");
                    // update client id
                    this.src = cast(int)msgJson["dst"].integer;
                    int[][] history;
                    foreach (jsonValue; msgJson["history"].array) {
                        int[] subArray;
                        foreach (value; jsonValue.array())
                        {
                            subArray ~= cast(int)value.integer;
                        }
                        // Back up surface.
                        this.myApp.backupSurface();
                        // Store the drawing action in drawingActions
                        drawingActions.push_back([subArray[0],subArray[1]]);
                        // paint the canvas with data from server and push drawing action onto drawingActions stack.
                        this.draw(subArray[0],subArray[1]);
                    }
                }
            }catch(Exception e) {

            }
        }
    }

    // send undo msg to server
    void sendUndo() {
        if (drawingActions.size() != 0) {

            JSONValue undo;
            undo["src"] = this.src;
            undo["dst"] = this.address;
            undo["type"] = "undo";

            this.socket.send(undo.toString());
            this.undoDrawingActions();
        }
    }

    //part Send redo package to server
    void sendRedo() {
        if (undoneDrawingActions.size() != 0) {
            JSONValue redo;
            redo["src"] = this.src;
            redo["dst"] = this.address;
            redo["type"] = "redo";

            this.socket.send(redo.toString());
            this.redoDrawingActions();
        }
    }

    // Implement undo for drawing actions. Pop from top of drawingActions and push to undoneActions
    // to keep track of which action was undone. 
    // Actually undo whatever drawing action was performed on the canvas by calling undo method from myApp,
    // which restores the previous version of the canvas.
    void undoDrawingActions() {
        if (drawingActions.size() != 0) {
            auto action = drawingActions.pop_back();
            myApp.undo();
            undoneDrawingActions.push_back(action);
        }
    }

    // Re-do drawing actions. By drawing on the canvas whatever is
    // on top of undoneActions stack, and pushing the popped value 
    // back into the drawingActions stack. 
    void redoDrawingActions() {
        if (undoneDrawingActions.size() != 0) {
            auto action = undoneDrawingActions.pop_back();
            int xPosNew = action[0];
            int yPosNew = action[1];

            this.myApp.backupSurface();

            drawingActions.push_back(action);
            this.draw(xPosNew, yPosNew);
        }
    }
}






