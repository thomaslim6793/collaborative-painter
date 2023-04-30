/**
 * Authors: Shibin Cai, Jay Gombar, Hyun Seung Lim and Huijuan Wang
 *
 * To run the program input into your terminal: 
 * 1. export MACOSX_DEPLOYMENT_TARGET=13
 * 2. export DYLD_FALLBACK_LIBRARY_PATH=/opt/homebrew/lib
 * 3. dub run
 */

import guiWindow;
import gtk.Main;
import std.stdio;
import client; 
import std.string;
import std.algorithm;
import std.conv;
/** Constructs a finalized */
void main(string[] args) {
     /++ Initialize environment for gtk application. +/
    Main.init(args); {
        write("Enter server address: ");
        auto address = readln().strip();
        if (address == "without server") {
            auto client = new GUIWindow("without server");
            Main.run();
        }
        else {
        write("Enter server port: ");
        auto port = to!ushort(readln().strip());
        /++ Create a guiWindow object which is a MainWindow.+/
        auto client = new Client(address, port);
        /++ Run the main application loop that listens to events happening in our application window.+/
        Main.run();
        /++ Client will then go out of scope and its destructor will be called.+/
        }
    } 
}
