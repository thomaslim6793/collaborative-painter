// Import D standard libraries
import std.stdio;
import std.string;

// Load the SDL2 library
import bindbc.sdl;
import loader = bindbc.loader.sharedlib;

/// surface struct 
struct Surface{
  SDL_Surface* surface;
  private int m_width;
  private int m_height;
  this(int flags, int width, int height, int depth,
     int Rmask, int Gmask, int Bmask, int Amask) {
    // Create a surface...
    m_width = width;
    m_height = height;
    surface = SDL_CreateRGBSurface(flags, width, height, depth, Rmask, Gmask, Bmask, Amask);
  }
  ~this(){
    // Free a surface...
    SDL_FreeSurface(surface);
  }

  /// Function for updating the pixels in a surface to a 'blue-ish' color.
  void UpdateSurfacePixel(int xPos, int yPos){

    if (xPos < 0 || xPos > m_width || yPos < 0 || yPos > m_height)
      throw new Exception("Position out of scope");

    // When we modify pixels, we need to lock the surface first
    SDL_LockSurface(surface);
    // Make sure to unlock the surface when we are done.
    scope(exit) SDL_UnlockSurface(surface);

    // Retrieve the pixel array that we want to modify
    ubyte* pixelArray = cast(ubyte*)surface.pixels;
    // Change the 'blue' component of the pixels
    pixelArray[yPos*surface.pitch + xPos*surface.format.BytesPerPixel+0] = 255;
    // Change the 'green' component of the pixels
    pixelArray[yPos*surface.pitch + xPos*surface.format.BytesPerPixel+1] = 128;
    // Change the 'red' component of the pixels
    pixelArray[yPos*surface.pitch + xPos*surface.format.BytesPerPixel+2] = 32;
  }

  /// return the current surface
  SDL_Surface* getSurface() {
    return this.surface;
  }

  // Check a pixel color
  ubyte[] PixelAt(int xPos, int yPos) {
    ubyte[] pixel = new ubyte[3];
    ubyte* pixelArray = cast(ubyte*)surface.pixels;
    pixel[0] = pixelArray[yPos*surface.pitch + xPos*surface.format.BytesPerPixel+0];
    pixel[1] = pixelArray[yPos*surface.pitch + xPos*surface.format.BytesPerPixel+1];
    pixel[2] = pixelArray[yPos*surface.pitch + xPos*surface.format.BytesPerPixel+2];
    return pixel;
  }
}
