XCL
======
by Nic Brosz
------
Spring, 2016

[![XCL Final Presentation](http://img.youtube.com/vi/20Nr72PMOdY/0.jpg)](http://www.youtube.com/watch?v=20Nr72PMOdY)

# Compiling and Using XCL:
1. Run make
2. Direct input into the resulting go file, like so:
	./go < testprog1
3. Pipe output into an output file, like so:
	./go < testprog1 > testprog1.c
4. Run gcc on resulting .c file (requires -lm flag if exponents are used):
	gcc testprog1.c -lm
5. Run the program like any other:
	./a.out

# About XCL:
XCL (pronounced "excel") stands for Extensible Coding Language and was designed to be a logical equivalent to the XML data language. The intent was to create a language that, as much as possible, would follow XML syntactical rules, ideally even to the point that it could function as XML.

The goals of the language were only partially met in regards to maintaining XML's syntax. The language itself is able to be dropped into an editor like Sublime Text or Notepad++ and given helpful highlighting when the XML syntax is selected, and Notepad++ even offers automatic block collapsing. However, the language does not parse as valid XML because XML is very picky about the attributes of its language. Namely, XML attributes should be surrounded by quotations. I felt that having a language where all expressions had to be surrounded by quotations would become confusing, especially since XCL offers outputting of string literals (which are also surrounded by quotations), opening the possibilty to confusion when using the language.

Basics of XCL:
In addition to following XML's syntactic structure, I wanted to build XCL with a simplified syntax wherever possible. Most functionality has been narrowed down to a small handful of tags that convert to different resulting C code depending on the circumstance. For instance, there is a singular LOOP tag that serves as an if or a while loop depending on whether a numeric expression or boolean condition is given as the parameter. Likewise, there is a LOGIC tag with BLOCK sub-tags that serve as if, else if, else, or any combination depending on how many there are. This will be discussed in further detail later.

When it came down to symbols, particularly arithmetic symbols, I favored some conventions picked up from Discrete. For instance, logical and and or, rather than being && and ||, are presented as intersection and union, designated by ^ and v, respectively (a carrot and a lower-case letter v). Likewise, logical not is ~, inspired by languages such as Lua, to more closely resemble the mathematical logical not symbol. XCL diverges from C's convention of == for equivalence comparison and instead just uses a single = sign. On the other hand, following in the convention of C's ! for not leading to != for "not equal", the operator for a lack of equality in XCL is ~=.

Due to XCL resembling XML, the < and > symbols were necessities to identifying the start and end of tags. I had a lot of difficulty getting greater than and less than symbols to serve both as the book-ends of tags as well as for comparison operators, so finally I decided to abandon >, <, >=, and <= for gt, lt, gte, and lte, respectively. I consider this a weakness of the language because it is uncommon to rely on terms like "gt" or "lt" in programming languages and I frequently find myself making mistakes when writing programs in XCL from using the wrong symbols. If I had the time, I would have liked to continue searching for a way to incorporate > and < symbols into comparison operations.

XCL has two primary data types: integers and floats. Implicit typing based on the initial value determines whether a variable will be a float or an integer. Integers are simply numbers without decimal points, while floats are numbers with decimal points. Typing is strictly enforced, though there is implicit coersion from integers to floats. In order to get from a float to an integer, an operation that deals only in integers, such as modulus or integer division, must be used.

XCL supports booleans as second-class citizens. Although variables can be of a boolean type and used in conditional expressions, there is no support for an implicit equivalence between boolean variables and the values they hold. That is, while in C one could have a boolean (or rather, integer) x and then write something like "if (x) ...", this is not supported in XCL. In order to use a boolean in a condition, it must be compared to true or false (which are represented in the language as "true" and "false", lower-case, without the quotations), such as x = true. If I had more time, I would go back and re-integerate booleans as being just a form of a number (any value that does not equal 0), rather than as its own type. I believe that combining the two concepts would allow me to avoid the shift/reduce or reduce/reduce errors that occur when I try to add direct support for variables to boolean conditionals.

String literals are supported only for outputting. Strings cannot be concatenated or modified in the language, but by using multiple OUT statements, one can string together combinations of string literals and output values in order to create the appearance natural strings in the resulting program.

Like HTML and XML, XCL supports multi-line comments through <!-- ... -->. Unfortunately, Lex proved to be very difficult when it came to actually supporting proper multi-line comments. The regular expression I finally used was one found online for C-style comments and modified to suit my needs. The presumed regular expression solution of "<!--".*"-->" would not suffice because the . operator doesn't consume new line characters. Likewise, "<!--"(.|\n|\r\n)*"-->" wouldn't work because the regular expression would consume TOO much. It would work as long as there was only a single comment on-screen, but if there was a second comment, the regular expression would consume from the starting <!-- of the first comment to the ending --> of the latest comment in the program. The working solution requires a complicated combination of consuming characters but negating the premature consumption of a closing -->.

# Tags and Structure in XCL:
XCL has only seven tags: program, let, loop, logic, branch, in, and out. All operations are performed with these tags, and sometimes serveral operations can be performed with the same tag. As is common for markup languages like HTML, XCL tags can be UPPER CASE, lower case, or any combination. Although the tags are case-insensitive, other symbols, variables, etc. are not.

Tags look like XML or HTML tags, surrounded by < and > on both sides, like so: <PROGRAM>. Since XCL is a largel block-based language, most tags have a paired closing tag that ends the block. In the case of the PROGRAM tag, the closing tag would be: </PROGRAM>. The LET, IN, and OUT tags are self-closing, which is indicated by a forward slash before the > symbol at the end of the tag, like so: <OUT "Hello, World!\n" />

Some tags in XCL are flexible in their structure (as in, any number and type of statements or blocks may be present), while others are more strict in how they must be used. For example, there must be one and only one set of PROGRAM tags that encompass all non-commented tags of the program. Likewise, all sets of BRANCH tags must be surrounded by a pair of LOGIC tags, with nothing in-between, like so: <LOGIC><BRANCH x gt 3>...</BRANCH><BRANCH>...</BRANCH></LOGIC>, and there can be no tags inside the LOGIC tags but outside of the BRANCH tags. This is not allowed: <LOGIC><LET x = 4 /><BRANCH> ... </BRANCH></LOGIC>. LOOP blocks have no particular structural requirements beyond ending with a paired </LOOP> tag.

While the decision to surround all BRANCH tags with a LOGIC tag set may seem tedious (and it is), it was necessary in order to avoid shift/reduce errors resulting from the implicit pairing of BRANCH tags. Even when using a root tag in a structure such as <trunk>..</trunk><branch>...</branch><branch>...</branch> to indicate the ordering, shift/reduce errors still occurred. Looking online, it sounded like a common logical problem even for C-style languages, though if I had more time, I would have liked to experiment further in an attempt to eliminate the cumbersome LOGIC tag and instead go for a "trunk" tag with several paired "branch" tags, both to reduce extra tags and to eliminate the possiblity of the programmer making a mistake by attempting to place other tags between the LOGIC and BRANCH tags.

# Features of XCL:
XCL comes with several features designed to make the language convenient and easy to use. I have mentioned implicit typing (determined at declaration-time), implicit loops (whether a loop becomes a for or a while loop), and implicit branching (sets of branches automatically become "if", "else if", and "else", based on their ordering). In addition, there is implicit variable declaration using the LET tag. The first time a variable is referenced with LET, its type is locked in and it results in C-code that reflects its type. Future references of the variable will not include the initialization code. Additionally, XCL has local blocking levels, so a variable initialized in a block will be discarded after the block is exited. Child blocks have access to their parent's variables, but sibling blocks do not have access to one another's variables. For instance, take this example:
```xml
<PROGRAM>
	<LOOP 10>
		<LET x = 15 />
		<LOGIC>
			<BRANCH x gte 10><LET x = 5 /><LET y = x /></BRANCH>
		</LOGIC>
		<LOGIC>
			<BRANCH x lte 10><LET y = 3.5 /></BRANCH>
		</LOGIC>
	</LOOP>
</PROGRAM>
```
Ignoring the pointlessness of the logic, if the three LET tags were all in the same scope, this would result in an error. Since y is implicitly declared as an integer (because it is getting a value from an integer variable, x), it normally would cause an error when attempting to assign a float in the second usage of y. Instead, the second y is independent from the first, because they aren't in the same scope. This is reflected in the resulting translated C code:
```cpp
#include <stdlib.h>
#include <stdio.h>
// Program starts here:
void main(){
	int _xcltmp0;
	for (_xcltmp0 = 0; _xcltmp0 < 10; _xcltmp0++) {
		int x = 10;
		if (x >= 10) {
			x = 5;
			int y = x;
		}
		if (x <= 10) {
			float y = 3.500000f;
		}
	}
}
```
Notice that a temporary variable is declared to perform the for loop. The temporary variables created by XCL append a string, "_xcltmp", to an integer and continues to increment the integer until a unique variable name is found, so there is virtually no chance of a conflict between temporary variable names. However, the process of selecting a unique name is certainly open for optimization, such as by using an incrementing global variable to be appended, rather than searching through the linked list of declared variables until a name is found that hasn't already been declared.

XCL also provides support for integer, float, and boolean arrays. The means of declaring in array in XCL is very flexible and ensures that arrays always have values. Arrays may be declared by specifying a list of values surrounded by curly braces (which will result in an array of the exact size to hold the provided values), or by specifying one or more values, a colon, and an integer literal specifying the declared size of the array, like so:
```xml
<PROGRAM>
	<LET x = {1, 2, 3} />
	<LET y = {1.0, 2.0, 3.0 : 10} />
</PROGRAM>
```
In this case, y will be a float array of size 10. The final value in the list before the colon will be repeated to fill the entire list, so the final contents of y will be: (1.0, 2.0, 3.0, 3.0, 3.0, 3.0, 3.0, 3.0, 3.0, 3.0). Initializing an array of 50 elements to the integer 0 would look like so: <LET a = {0 : 50} />. You can see the filling of the array in the resulting C code:
```cpp
void main(){
	int x[3] = {1, 2, 3};
	float y[10] = {1.000000f, 2.000000f, 3.000000f};
	int _xcltmp0;
	for(_xcltmp0=3;_xcltmp0<10;_xcltmp0++){y[_xcltmp0]=3.000000f;}
}
```
In addition to arrays being implicitly typed and easy to initialize, a degree of safety is automatically provided as well. When an array has been declared in a program, XCL will automatically include a couple of helper functions that check to make sure that an index to an array does not exceed the array's bounds. This protection is provided at run-time, not compile-time. I would have liked to allow literal values in XCL to be calculated down as much as possible to allow for some compiler-time array safety as well, but there wasn't enough time to implement it. Observe the XCL code and the resulting compiled C code below:
```xml
<PROGRAM>
	<LET x = {1, 2, 3} />
	<LET y = {1.0, 2.0, 3.0 : 10} />
	<LET y[x[2]] = x[0] />
</PROGRAM>
```
```cpp
	void main(){
		int x[3] = {1, 2, 3};
		float y[10] = {1.000000f, 2.000000f, 3.000000f};
		int _xcltmp0;
		for(_xcltmp0=3;_xcltmp0<10;_xcltmp0++){y[_xcltmp0]=3.000000f;}
		*(xclCheckFloatArray(y, "y", *(xclCheckIntArray(x, "x", 2, 3)), 10)) = *(xclCheckIntArray(x, "x", 0, 3));
	}
```
Note that no error is thrown from trying to assign an integer value to an array of floats. This is an example of the supported integer to float implicit typing. If an attempt was made to assign a value from y to x, an typing error would be thrown (likewise if one tried to index an array using a float).

# XCL Basic Syntax:

## Tags:
PROGRAM - block that defines the beginning/end of the program
LOGIC - block that defines the beginning/end of set of branching logic
BRANCH - block that provides a "branch" of the logic depending on the conditional parameters provided and serves as an if, else if, or else statement depending on the conditions and placement relative to other BRANCH tags
LOOP - block that provides either a conditional (while), fixed (for), or counting (for) loop depending on whether a conditional statement, numeric literal, or numeric expression is given as the loop's parameter
LET - statement that serves as both a declaration and assignment statement, depending on whether the variable has been used before or not, and enforces strict typing except for allowing integers to be coerced into floats
IN - statement that translates to a simple scanf C function that inserts the inputted value into the given variable
OUT - statement that prints a variable, expression, or string literal to the screen

## Arithmetic: (mostly follows C-rules of integers being the resulting type unless a float is involved, except as otherwise specified)
* + - addition
* - - subtraction
* * - multiplication
* / - division
* // - integer division (returns only integers)
* % - modulus (returns only integers)
* ** - powers

## Comparison:
* gt - greater than
* lt - less than
* gte - greater than or equal to
* lte - less than or equal to
* = - equal to
* ~= - not equal to

## Boolean Logic:
* ^ - logical and
* v - logical or
* ~ - logical not

# Example Programs:

## Calculator (Demonstrates logic, input/output, and arithmetic):
```xml
<!-- Calculator Program -->
<program>
	<let total = 0.0 />
	<let x = 0 />
	<loop x gte 0 ^ x lte 7>
		<out "Current value: " />
		<out total />
		<out "\n" />
		<out "Select your function (0 = +, 1 = -, 2 = *, 3 = /, 4 = //, 5 = %, 6 = **, 7 = clear) or -1 to quit.\n" />
		<in x />
		<logic>
			<branch x lt 0 v x gt 7>
				<out "Thanks for using!\n" />
			</branch>
			<branch>
				<logic>
					<branch x = 0>
						<out "\taddition\n" />
					</branch>
					<branch x = 1>
						<out "\tsubtraction\n" />
					</branch>
					<branch x = 2>
						<out "\tmultiplication\n" />
					</branch>
					<branch x = 3>
						<out "\tdivision\n" />
					</branch>
					<branch x = 4>
						<out "\tint division\n" />
					</branch>
					<branch x = 5>
						<out "\tmodulus\n" />
					</branch>
					<branch x = 6>
						<out "\tpowers\n" />
					</branch>
					<branch x = 7>
						<out "\tclear\n" />
					</branch>
				</logic>
				<let y = 0.0 />
				<logic>
					<branch x lte 6>
						<!-- all options but clear -->
						<out "Enter a value to perform the function with.\n" />
						<in y />
						<logic>
							<branch x = 0>
								<out "\t+ " />
								<out "\n" />
								<let total = total + y />
							</branch>
							<branch x = 1>
								<out "\t- " />
								<let total = total - y />
							</branch>
							<branch x = 2>
								<out "\t* " />
								<let total = total * y />
							</branch>
							<branch x = 3>
								<out "\t/ " />
								<let total = total / y />
							</branch>
							<branch x = 4>
								<out "\t// " />
								<let total = total // y />
							</branch>
							<branch x = 5>
								<out "\t% " />
								<let total = total % y />
							</branch>
							<branch x = 6>
								<out "\t** " />
								<let total = total ** y />
							</branch>
						</logic>
						<out y />
						<out "\n" />
					</branch>
					<branch>
						<let total = 0 />
					</branch>
					<!-- clear option -->
				</logic>
			</branch>
		</logic>
	</loop>
</program>
```
## Multi-input (Demonstrates loops, input/output, and arrays):
```xml
<program>
	<let array = {1, 2, 3, 4, 5, 0 : 10} />
	<let x = 0 />
	<out "Current array values:\n" />
	<loop x lt 10>
		<out array[x] /><out "\n" />
		<let x = x + 1 />
	</loop>
	<loop x gt 0>
		<let y = x - 1 />
		<out "Insert a value for array[" /><out y /><out "]: " />
		<in array[y] />
		<let x = y />
	</loop>
	<out "Current array values:\n" />
	<loop x lt 10>
		<out array[x] /><out "\n" />
		<let x = x + 1 />
	</loop>
</program>
```
## Conditional Output (Demonstrates branching logic and boolean conditions):
```xml
<PROGRAM>
	<LET x = true />
	<LET y = false />
	<OUT "x is true and y is false\n" />

	<!-- Unfortunately, the language doesn't support variable stand-in for boolean values due to reduce errors -->
	<OUT "x v y is " />
	<LOGIC>
		<BRANCH x = true v y = true >
			<OUT "true\n" />
		</BRANCH>
		<BRANCH>
			<OUT "false\n" />
		</BRANCH>
	</LOGIC>
	<OUT "x ^ y is " />
	<LOGIC>
		<BRANCH x = true ^ y = true >
			<OUT "true\n" />
		</BRANCH>
		<BRANCH>
			<OUT "false\n" />
		</BRANCH>
	</LOGIC>
	<OUT "~x v y is " />
	<LOGIC>
		<BRANCH ~(x = true) v y = true >
			<OUT "true\n" />
		</BRANCH>
		<BRANCH>
			<OUT "false\n" />
		</BRANCH>
	</LOGIC>
	<OUT "x ^ ~y is " />
	<LOGIC>
		<BRANCH x = true v ~(y = true) >
			<OUT "true\n" />
		</BRANCH>
		<BRANCH>
			<OUT "false\n" />
		</BRANCH>
	</LOGIC>
</PROGRAM>
	```