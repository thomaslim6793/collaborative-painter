
import std.stdio;

interface Container(T){
    // Element is on the front of collection
    void push_front(T x);
    // Element is on the back of the collection
    void push_back(T x);
    // Element is removed from front and returned
    // assert size > 0 before operation
    T pop_front();
    // Element is removed from back and returned
    // assert size > 0 before operation
    T pop_back();
    // Retrieve reference to element at position at index
    // assert pos is between [0 .. $] and size > 0
    ref T at(size_t pos);
    // Retrieve reference to element at back of position
    // assert size > 0 before operation
    ref T back();
    // Retrieve element at front of position
    // assert size > 0 before operation
    ref T front();
    // Retrieve number of elements currently in container
    size_t size();
}

class Deque(T) : Container!(T){
    private T[] this_deque;
    private int deque_size;
    
    this() {
    	deque_size = 0;
    }
    
    void push_front(T x) {
		this_deque = x~this_deque;
        deque_size++;
    }
	void push_back(T x) {
 		this_deque = this_deque~x;
        deque_size++;
 	}
    T pop_front() {
        T front = this_deque[0];
        this_deque = this_deque[1..deque_size];
        deque_size--;
        return front;
    }
    T pop_back() {
    	T back = this_deque[deque_size-1];
        this_deque = this_deque[0..(deque_size-1)];
        deque_size--;
        return back;
    }
    ref T at(size_t pos) {
        assert((0 <= pos) && (pos <= (deque_size - 1)));
        assert(deque_size > 0);
        return this_deque[pos];
    }
    ref T back() {
        assert(deque_size > 0);
        return this_deque[deque_size - 1];
    }
    ref T front() {
        assert(deque_size > 0);
        return this_deque[0];
    }
    size_t size() {
        return this.deque_size;
    }
}
