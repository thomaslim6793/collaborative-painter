1. To run, in your terminal run the following:
    [ If you are using MacOS, run the following first:
     1) export MACOSX_DEPLOYMENT_TARGET=13
     2) export DYLD_FALLBACK_LIBRARY_PATH=/opt/homebrew/lib]

    1) dub run
    2) In the prompt "Enter Server Address: ", enter the name of the server you wish to join. 
       In the following promtp "Enter server port: ", enter the port id of the process of the server executable.
    *** If you wish to run this program without joining a server, simply type in "without server" in the prompt.

2. To create ddoc, do it manually, using the following ldc command:

    - For files in the src/source folder:
    ldc2 -c -D -Dd=./source/docs -Isource/ -I~/.dub/packages/gtk-d-3.10.0/gtk-d/generated/gtkd -wi source/app.d source/client.d source/deque.d source/guiWindow.d

    - For files in the src/server folder:
    ldc2 -c -D -Dd=./server/docs -Isource/ -I~/.dub/packages/gtk-d-3.10.0/gtk-d/generated/gtkd -wi server/server.d

    (The issue with trying to create ddoc with dub is that it dub tries to make ddocs for all the dependencies, so it tries to generate
    ddoc of the entire gtkd package, which is not what we want. 
    We need to specify the files which are the only files that we want to generate ddoc of. And furthermore since the gtk package is not
    in our project, but rather imported from our local machines, we need to specify its path in our local machines.)