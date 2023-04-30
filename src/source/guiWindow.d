
import gtk.MainWindow;
import gtk.Main;
import gtk.Button;
import gtk.DrawingArea;
import gtk.Widget;
import gtk.VBox;
import gtk.HBox;
import gdk.RGBA;
import gtk.Box;
import gtk.ComboBoxText;
import gtk.ListStore;

import gdk.cairo;
import cairo.ImageSurface;
import cairo.c.types;

import cairo.Context;
import cairo.Pattern;
import std.random;
import std.stdio;
import std.conv;
import std.math;
import std.format;
import std.regex;
import deque;

/** The visual components that represent the canvas and alterations done to it for drawing. */
class GUIWindow : MainWindow {
    /++ Window fields. +/
    int[] windowDimensions;
    /++ Buttons and and related fields +/
    protected Button buttonRefreshDrawingArea, buttonUndo, buttonRedo;
    protected ComboBoxText penSizeBox, penColorBox;
    /**
     * A special widget where any drawing events will update this area, via cairo Context
     * which represents the graphical aspect of this DrawingArea. 
     * Think of DrawingArea as the "canvas", and Context as the "painting elements of the canvas"
     */
    protected DrawingArea drawingArea;
    /++ Drawing area and related fields +/
    protected RGBA backGroundColor;
    /++ Tells whether we are drawing on the surface right now. +/
    protected bool isDrawing;
    /++ Threshold of the change in pixel coordinates to be met to draw. +/
    protected int mouseSensitivityThreshold;
    /++ Coordinates of pixel to draw. +/
    protected int x, y, prevX, prevY; 
    /++ Pixel width and height. +/
    protected int pixelWidth, pixelHeight;
    /++ Paint color rgb values. +/
    protected int r, g, b;
    /++ Server color +/
    protected int serverR, serverG, serverB;
    /++ Server Pixel width and height. +/
    protected int serverPixelWidth, serverPixelHeight;
    /++ Storage of drawing actions data. +/
    /++ Current state of drawing area. +/
    protected ImageSurface currentState;
    /++ Keeps history of surface. +/
    protected Deque!(ImageSurface) surfaceHistory;
     /++ Keeps track of undone drawing actions.  +/
    protected Deque!(ImageSurface) undoneDrawingActions;
    /++ Limit number of undo/redo actions +/
    protected int maxSizeUndoRedo;
 
    /** Intializes new visual for canvas */
    this(string title) {
        super(title);
        windowDimensions = [1000, 1000];
        mouseSensitivityThreshold = 2;
        prevX = -1;
        prevY = -1;
        pixelWidth = 6;
        pixelHeight = 6; 
        r = 0; g = 0; b = 0;
        currentState = ImageSurface.create(cairo_format_t.ARGB32, windowDimensions[0], windowDimensions[1]);
        surfaceHistory = new Deque!(ImageSurface);
        undoneDrawingActions = new Deque!(ImageSurface);
        maxSizeUndoRedo = 1000000; 

        /++ Create and add to MainWindow a container that stacks child Widgets vertically. +/
        auto vbox = new VBox(false, 0);
        this.add(vbox);

        /++ Create a horizontal box for buttons and stack child widgets horizontally. +/
        auto buttonsHBox = new HBox(false, 0);
        /++ Put the horizontal box inside vertical box. +/
        vbox.packStart(buttonsHBox, false, false, 0);
        /++ Make buttons and add to h-box. +/
        buttonRefreshDrawingArea = new Button("refresh drawing area");
        /** When button clicking event is triggered, the delegate function will be called. 
         * the delegate function here is a callback function. 
         * The anonymous function - i.e. delegate (just consider it a lambda) - is created where the lambda 
         * is 'void lambda(Button b) {<lambda body>}'. The argument of lambda is provided when lambda is called. 
        */
        buttonRefreshDrawingArea.addOnClicked(delegate void(Button b) {
            this.refreshDrawingArea();
        });
        buttonUndo = new Button("undo");
        buttonUndo.addOnClicked(delegate void(Button b) {
            this.undoDrawingActions();
        });
        buttonRedo = new Button("redo");
        buttonRedo.addOnClicked(delegate void(Button b) {    
            this.redoDrawingActions();
        });
    
        buttonsHBox.packStart(buttonRefreshDrawingArea, false, true, 0);
        buttonsHBox.packStart(buttonUndo, false, true, 0);
        buttonsHBox.packStart(buttonRedo, false, true, 0);

        /++ Create drawing area widget and stack it to vertical box. +/
        drawingArea = new DrawingArea();
        vbox.packStart(drawingArea, true, true, 0);

        /** Call the delegate whenever (re)drawing event is triggered. 
         * e.g. Simply moving my cursor is considered an event. Furthermore this cursor motion event 
         * has the weird effect of triggering addOnDraw. 
        */
        drawingArea.addOnDraw(delegate bool(Context cr, Widget drawingArea) {
            this.onDraw(cr); 
            return false;
        });

        /++ Enable mouse button press and motion events for the drawing area +/
        drawingArea.addEvents(EventMask.BUTTON_PRESS_MASK | EventMask.BUTTON_RELEASE_MASK | EventMask.POINTER_MOTION_MASK);
        /++ Add event handlers for mouse button press, release, and motion +/
        drawingArea.addOnButtonPress(&onButtonPress);
        drawingArea.addOnButtonRelease(&onButtonRelease);
        drawingArea.addOnMotionNotify(&onMotionNotify);

        /++ Extra feature 1: Add a dropdown menu button for selecting size of pen with 3 options. +/
        penSizeBox = new ComboBoxText();
        buttonsHBox.packStart(penSizeBox, false, true, 0);

        penSizeBox.appendText("small pen");
        penSizeBox.appendText("medium pen");
        penSizeBox.appendText("large pen");
        /++ Set the second item (index 1) as the active option +/
        penSizeBox.setActive(1);
        // Add event handler for choosing option.
        penSizeBox.addOnChanged(&onPenSizeChanged);

        /++ Extra feature 2: Add a dropdown menu button for selecting color of brush with 4 default options. +/
        penColorBox = new ComboBoxText();
        buttonsHBox.packStart(penColorBox, true, true, 0);
        penColorBox.appendText("For custom value, enter in this format: (r, g, b)");
        penColorBox.appendText("pen color: black");
        penColorBox.appendText("pen color: red");
        penColorBox.appendText("pen color: green");
        penColorBox.appendText("pen color: blue");
        penColorBox.setActive(0);
        // Add event handler for choosing option.
        penColorBox.addOnChanged(&onPenColorChanged);


        /++ Some default settings of window, and finally show the window. +/
        backGroundColor = new RGBA(0.5, 0.5, 0.5, 1);
        /++ Set minimum dimensions of of HBox widget. +/
        buttonsHBox.setSizeRequest(windowDimensions[0], 50);
        setDefaultSize(windowDimensions[0], windowDimensions[1]);
        showAll();

        /++ Whenever "detroy" event has occurred, call the delegate. Note Widget is the base class for all UI elements meaning MainWindow is a Widget. +/ 
        this.addOnDestroy(delegate void(Widget) {
            Main.quit();
        });
    }

    /** */
    void undoDrawingActions() {
        if (surfaceHistory.size > 0){
            auto previous = surfaceHistory.pop_back();
            undoneDrawingActions.push_back(previous);
            currentState = previous;
        }

    }

    /** */
    void redoDrawingActions() {
        if (undoneDrawingActions.size > 0) {
            auto previous = undoneDrawingActions.pop_back();
            surfaceHistory.push_back(previous);
            currentState = previous; 
        }
        
    }

    /** */
    void refreshDrawingArea() {
        writeln("refresh drawing area!");
        currentState = ImageSurface.create(cairo_format_t.ARGB32, windowDimensions[0], windowDimensions[1]);
    }

    /** When triggered by queueDrawArea, only re-draw on the specified area.
     * Else if triggered by queueArea, re-draw on the entire drawing area.
    */
    bool onDraw(Context cr) {
        if (isDrawing){
            /++ Draw a pixel. +/
            writeln(format("drawing at (x: %d, y: %d)", x, y));
            cr.setSourceRgb(r, g, b);
            cr.rectangle(x, y, pixelWidth, pixelHeight);
            cr.fill();

            /** Update the current state after drawing the pixel
             * But before, backup the current state by creating a deep copy and pushing back to surfaceHistory.
            */
            surfaceHistory.push_back(deepCopyImageSurface(currentState));
            auto crState = Context.create(currentState);
            crState.setSourceRgb(r, g, b);
            crState.rectangle(x, y, pixelWidth, pixelHeight);
            crState.fill();
            if (surfaceHistory.size == maxSizeUndoRedo){
                surfaceHistory.pop_front();
            }
        }
        /++ If not drawing, make cr reflect the current state of the drawing area. +/
        else {
            cr.setSourceRgb(r, g, b);
            cr.setSourceSurface(currentState, 0, 0);
            cr.paint();
        }
        return false;
    }

    /++ Callee of callback for when an event button (e.g. left mouse button) is pressed +/
    bool onButtonPress(GdkEventButton* event, Widget w) { 
        /++ Check if the left mouse button is pressed +/
        if (event.button == 1) {
            /++ Start drawing +/
            isDrawing = true;
        }
        return false;
    }

    /** Callee of callback for when an event button (e.g. left mouse button) is released */
    bool onButtonRelease(GdkEventButton* event, Widget w) { 
        if (event.button == 1) {// Check if the left mouse button is pressed
            isDrawing = false; // Start drawing
        }
        return false;
    }

    /** Callee of callback for when mouse cursor is hovering over a pixel of the widget whose listner is the caller of the callback. */
    bool onMotionNotify(GdkEventMotion* motion, Widget w) {
        if (isDrawing) {
            x = to!int(motion.x);
            y = to!int(motion.y);
            if ((abs(x - prevX) >= mouseSensitivityThreshold || abs(y - prevY) >= mouseSensitivityThreshold)) {
                prevX = x;
                prevY = y;
                drawingArea.queueDrawArea(x, y, pixelWidth, pixelHeight);                                                         
            }
        }
        return false;
    }

    /** Callee of callback for when option for changing pen size has been selected. */
    void onPenSizeChanged(ComboBoxText penSizeBox)
    {
        string selectedSize = penSizeBox.getActiveText();
        if (selectedSize == "small pen")
        {
            pixelWidth = 3;
            pixelHeight = 3;
        }
        else if (selectedSize == "medium pen")
        {
            pixelWidth = 6;
            pixelHeight = 6;
        }
        else if (selectedSize == "large pen")
        {
            pixelWidth = 9;
            pixelHeight = 9;
        }
    }

    /** Callee of callback for when option for changing pen color has been selected. */
    void onPenColorChanged(ComboBoxText penColorBox)
    {
        string selectedColor = penColorBox.getActiveText();
        if (selectedColor == "For custom value, enter in this format: (r, g, b)")
        {
            // do nothing
        }
        else if (selectedColor == "pen color: black")
        {
            r = 0;
            g = 0;
            b = 0;
        }
        else if (selectedColor == "pen color: red")
        {
            r = 10;
            g = 0;
            b = 0;
        }
        else if (selectedColor == "pen color: green")
        {
            r = 0;
            g = 10;
            b = 0;
        }
        else if (selectedColor == "pen color: blue")
        {
            r = 0;
            g = 0;
            b = 10;
        }
        else 
        {
            auto pattern = regex(r"\((\d+),\s+(\d+),\s+(\d+)\)");
            auto match = matchFirst(selectedColor, pattern);
            if (!match.empty()){
                r = to!int(match.captures[1]);
                g = to!int(match.captures[2]);
                b = to!int(match.captures[3]);
            }
        }
    }

    /**  Helper functions that makes a copy of the entire canvas allowing for manipulation */
    ImageSurface deepCopyImageSurface(ImageSurface original) {
        /++ Get the original surface format, width, and height +/
        auto format = original.getFormat();
        auto width = original.getWidth();
        auto height = original.getHeight();

        /++ Create a new ImageSurface with the same format, width, and height +/
        auto newSurface = ImageSurface.create(format, width, height);

        /++ Create a new Context for the new surface +/
        auto cr = Context.create(newSurface);

        /++ Set the source surface to the original surface +/
        cr.setSourceSurface(original, 0, 0);

        /++ Paint the original surface onto the new surface +/
        cr.paint();

        /++ Clean up the Context +/
        cr.destroy();

        /++ Return the new surface +/
        return newSurface;
    }
}
