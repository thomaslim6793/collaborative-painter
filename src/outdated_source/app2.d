/*
import std.stdio;
import client;
import std.concurrency;
import core.thread;
import gui;
import gtk.Main;

// Do the following in cml before 'dub run':
// export MACOSX_DEPLOYMENT_TARGET=13
// export DYLD_FALLBACK_LIBRARY_PATH=/opt/homebrew/lib

void main(string[] args)
{
  // create client and run main application loop for drawing. 
  Client client = new Client("localhost", 0);

  // Spawn our GUI Window
	immutable string[] args2=args.dup;
	RunGUI(args2);

  //client.MainApplicationLoop();
}

*/