
import std.stdio;

/** Interface for a Container class.*/
interface Container(T){
    /++ Element is added to the front of collection +/
    void push_front(T x);
    /++ Element is added to the back of the collection +/
    void push_back(T x);
    /++ Element is removed from front and returned (assert size > 0 before operation) +/
    T pop_front();
    /++ Element is removed from back and returned (assert size > 0 before operation) +/
    T pop_back();
    /++ Retrieve reference to element at position at index (assert pos is between [0 .. $] and size > 0) +/
    ref T at(size_t pos);
    /++ Retrieve reference to element at back of position (assert size > 0 before operation) +/
    ref T back();
    /++ Retrieve element at front of position (assert size > 0 before operation) +/
    ref T front();
    /++ Retrieve number of elements currently in container +/
    size_t size();
}

/** 
 * A Deque(T) is a class that stores items of type T and can have 
 * items added or removed form the front and back of the container.
 * Implements Container interface for adding, removing and reference methods. 
*/
class Deque(T) : Container!(T){
    /++ The array of items of type T held within the Deque. +/
    private T[] this_deque;
    /++ The total number of items within the Deque. +/
    private int deque_size;
    
    /** Intializes an empty Deque */
    this() {
    	deque_size = 0;
    }
    
    /** Element is added to the front of collection */
    void push_front(T x) {
		this_deque = x~this_deque;
        deque_size++;
    }

    /** Element is added to the back of the collection */
	void push_back(T x) {
 		this_deque = this_deque~x;
        deque_size++;
 	}

    /** Element is removed from front and returned which assumes the Deque is not empty */
    T pop_front() {
        T front = this_deque[0];
        this_deque = this_deque[1..deque_size];
        deque_size--;
        return front;
    }

    /** Element is removed from back and returned which assumes the Deque is not empty */
    T pop_back() {
    	T back = this_deque[deque_size-1];
        this_deque = this_deque[0..(deque_size-1)];
        deque_size--;
        return back;
    }

    /** Retrieve reference to element at position at index which assumes the pos is between [0 .. $]
     * and that the Deque is not empty */
    ref T at(size_t pos) {
        assert((0 <= pos) && (pos <= (deque_size - 1)));
        assert(deque_size > 0);
        return this_deque[pos];
    }

    /** Retrieve reference to element at back of position which assumes the Deque is not empty */
    ref T back() {
        assert(deque_size > 0);
        return this_deque[deque_size - 1];
    }

    /** Retrieve element at front of position which assumes the Deque is not empty */
    ref T front() {
        assert(deque_size > 0);
        return this_deque[0];
    }

    /** Retrieve number of elements currently in Deque */
    size_t size() {
        return this.deque_size;
    }
}
