# collaborative-painter
A light-weight drawing application that allows multiple users to draw synchronously on a server.
This application was written in D language (a modern language similar to C++). 
And it was built using the Gtk and Cairo API.


[![ezgif-com-video-to-gif.gif](https://i.postimg.cc/jStjJ2Ry/ezgif-com-video-to-gif.gif)](https://postimg.cc/VdZwxYrN)



To run, in your terminal, first go to the ./src directory and run the following:

1. Optional: If you are using MacOS, run the following first: 
~~~
export MACOSX_DEPLOYMENT_TARGET=13
export DYLD_FALLBACK_LIBRARY_PATH=/opt/homebrew/lib
~~~
2.  Then
~~~
dub run
~~~

3. In the prompt "Enter Server Address: ", enter the name of the server you wish to join. <br>
    -   In the following promtp "Enter server port: ", enter the port id of the process of the server executable.
    -   If you wish to run this program without joining a server, simply type in **"without server"** in the prompt.

* Collaborators: Shibin Cai, Jay Gombar, Hui Juan.
