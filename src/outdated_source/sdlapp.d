// Import D standard libraries
import std.stdio;
import std.string;

// Load the SDL2 library
import bindbc.sdl;
import loader = bindbc.loader.sharedlib;

// Load
import surface;
import deque;

/// At the module level we perform any initialization before our program
/// executes. Effectively, what I want to do here is make sure that the SDL
/// library successfully initializes.  
class SDLApp{
 
  // global variable for sdl;
  const SDLSupport ret;
  SDL_Window* window;
  Surface surface;
  private Deque!(SDL_Surface*) surfaceHistory;
  this(){
    // Handle initialization...
    // SDL_Init
    // Load the SDL libraries from bindbc-sdl
    // on the appropriate operating system
    version(Windows){
      writeln("Searching for SDL on Windows");
      ret = loadSDL("SDL2.dll");
    }
    version(OSX){
      writeln("Searching for SDL on Mac");
      ret = loadSDL();
    }
    version(linux){ 
      writeln("Searching for SDL on Linux");
      ret = loadSDL();
    }

    // Error if SDL cannot be loaded
    if(ret != sdlSupport){
      writeln("error loading SDL library");
      
      foreach( info; loader.errors){
        writeln(info.error,':', info.message);
      }
    }
    if(ret == SDLSupport.noLibrary){
      writeln("error no library found");    
    }
    if(ret == SDLSupport.badLibrary){
      writeln("Eror badLibrary, missing symbols, perhaps an older or very new version of SDL is causing the problem?");
    }

    // Initialize SDL
    if(SDL_Init(SDL_INIT_EVERYTHING) !=0){
      writeln("SDL_Init: ", fromStringz(SDL_GetError()));
    }

    window = SDL_CreateWindow("D SDL Painting",
                                        SDL_WINDOWPOS_UNDEFINED,
                                        SDL_WINDOWPOS_UNDEFINED,
                                        640,
                                        480, 
                                        SDL_WINDOW_SHOWN);
    surface = Surface(0,640,480,32,0,0,0,0);

    surfaceHistory = new Deque!(SDL_Surface*);
  }

  /// At the module level, when we terminate, we make sure to 
  /// terminate SDL, which is initialized at the start of the application.
  ~this(){
    // Handle SDL_QUIT
    // Quit the SDL Application 
    SDL_Quit();
	  writeln("Ending application--good bye!");
  }

  /// return the current surface
  SDL_Surface* getSurface() {
    return this.surface.getSurface();
  }

  SDL_Window* getWindow() {
    return this.window;
  }

  /// Function for updating the pixels in a surface to a 'blue-ish' color.
  void UpdateSurfacePixel(int xPos, int yPos) {
    this.surface.UpdateSurfacePixel(xPos, yPos);
  }

  // Create a (deep) copy and push it on the stack surfaceHistory stack. 
  void backupSurface() {
      SDL_Surface* backup = SDL_CreateRGBSurface(0,640,480,32,0,0,0,0);
      SDL_BlitSurface(this.surface.surface, null, backup, null); 
      surfaceHistory.push_back(backup);
  }

  // Pop surfaceHistory stack, and set current surface to the popped value,
  // which is previous surface. 
  void undo() {
      if (surfaceHistory.size() != 0) {
          SDL_Surface* prevSurface = surfaceHistory.pop_back();
          this.surface.surface = prevSurface;
      }
  }
}
