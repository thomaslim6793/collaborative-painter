module dub_test_root;
import std.typetuple;
static import client;
static import deque;
static import source.guiWindow;
static import test.testPenColor;
static import test.testPenSize;
alias allModules = TypeTuple!(client, deque, source.guiWindow, test.testPenColor, test.testPenSize);

import core.runtime;

void main() {
	version (D_Coverage) {
	} else {
		import std.stdio : writeln;
		writeln("All unit tests have been run successfully.");
	}
}
shared static this() {
	version (Have_tested) {
		import tested;
		import core.runtime;
		import std.exception;
		Runtime.moduleUnitTester = () => true;
		enforce(runUnitTests!allModules(new ConsoleTestResultWriter), "Unit tests failed.");
	}
}
					