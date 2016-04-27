
%{

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "symtab.c"

#define YYSTYPE  tstruct 
#define DEBUG 0
#define BUFFERLEN 75

enum datatype
{  
	dnone = 0,
	dbool = 1,
    dint = 2,
    dfloat = 4,
    dstring = 8,
    darray = 16
};

enum features
{
	incmath = 1,
	arraysafe = 2
};

typedef struct
{
 char* id;
 char* sval;
 int ival;
 float fval;
 int bval;
 enum datatype dtype;
 char* code;
}tstruct ;

struct varnode
{
	char* id;
	enum datatype dtype;
	int size; // 0 for scalars, > 0 for arrays
	int level; // block level that the variable was created in
	struct varnode* next;
};

struct varnode* headVarNode = NULL;
char strbuffer[BUFFERLEN];
int featureBits = 0;
int blockLevel = 0;

void initStr (char** str, int charCount);
void bufferXCLType (enum datatype dt);
void bufferType (enum datatype dt);
void bufferShortType (enum datatype dt);
void bufferValue (tstruct val);
char* writeHeader();

struct varnode* addVarNode(char* id, enum datatype dtype, int size) {
	struct varnode* newVar = (struct varnode*) malloc(sizeof(struct varnode));
	newVar->next = headVarNode;
	initStr(&(newVar->id), strlen(id));
	strcpy(newVar->id, id);
	newVar->dtype = dtype;
	newVar->size = size;
	newVar->level = blockLevel; // preserve what level the variable was created at

	headVarNode = newVar;
	if (DEBUG) printf("added new variable %s\n", id);
	return newVar;
}

struct varnode* addScalar(char* id, enum datatype dtype) {
	return addVarNode(id, dtype, 0);
}

struct varnode* addArray(char* id, enum datatype dtype, int size) {
	if (size <= 0) endError("Arrays must have at least one element.");
	return addVarNode(id, dtype, size);
}

struct varnode* findVar(char* id) {
	struct varnode* current = headVarNode;
	while (current) {
		if (DEBUG) printf("Does %s match %s?\n", current->id, id);
		if (!strcmp(current->id, id)) {
			return current;
		} else {
			current = current->next;
		}
	}
	return NULL;
}

struct varnode* checkVarExists(char* id) {
	struct varnode* current = findVar(id);

	if (!current) {	
		printf("\tERROR: Variable %s doesn't exist\n", id);
		exit(1);
	}
	return current;
}

struct varnode* getTempVar() {
	int num = 0;
	do {
		snprintf(strbuffer, sizeof(strbuffer), "_xcltmp%d", num);
		num++;
	} while (findVar(strbuffer) != NULL); // keep trying until a unique variable name is generated
	return addScalar(strbuffer, dint);
}

struct varnode* checkVarType(char* firstid, enum datatype secondtype) {
	struct varnode* current = findVar(firstid);

	if (!typesMatch(current->dtype, secondtype)) {
		if (!(typesMatch(current->dtype, dfloat) && typesMatch(secondtype, dint))) {
			bufferXCLType(secondtype);
			printf("\tERROR: Variable %s doesn't match type %s\n", firstid, strbuffer);
			exit(1);
		}
	}
	return current;
}

popBlock() {
	struct varnode* current = headVarNode;
	while (current && current->level == blockLevel) {
		if (DEBUG) printf("Popped off variable %s\n", current->id);
		free(current);
		current = current->next;
		headVarNode = current;
	}

	blockLevel--;
}

int typesMatch(enum datatype a, enum datatype b) {
	return ((a & (~darray)) == (b & (~darray))); // clear array bit and compare types
}

int isArray(enum datatype a) {
	return (a & darray);
}

useFeature(enum features f) {
	featureBits |= f;
}

endError(char* s) {
	printf("\tERROR: %s\n", s);
	exit(1);
}

%}

%token t_sct

%token t_progo
%token t_progc
%token t_let  
%token t_in  
%token t_out  
%token t_logico
%token t_logicc
%token t_brancho
%token t_branche
%token t_branchc
%token t_loopo
%token t_loopc

%token t_assign  
%token t_add  
%token t_sub  
%token t_pow 
%token t_mul   
%token t_intdiv  
%token t_div  
%token t_mod

%token t_eq  
%token t_noteq  
%token t_gt  
%token t_gte  
%token t_lt  
%token t_lte  
%token t_and  
%token t_or  
%token t_not

%token t_strlit  
%token t_id  
%token t_int  
%token t_float  
%token t_bool   


%%

p 
	: prog 
	;

prog 
	: progstart taglist progend 	
		{
			printf("%s%s%s%s", writeHeader(), $1.code, $2.code, $3.code);
		}
	;

progstart 
	: t_progo		
		{
			$$.code = "void main(){\n";
		}
	;

progend 
	: t_progc 	
		{
			$$.code = "}\n";
		}
	;

taglist 
	: taglist tag 	
		{
			initStr(&$$.code, strlen($1.code)+strlen($2.code)); 
			strcpy($$.code, $1.code); 
			strcat($$.code, $2.code);
		}
	| tag 				
		{
			$$.code = $1.code;
		}
	;

tag 
	: tagtype 		
		{
			const char* end = "\n";
			initStr(&$$.code, strlen($1.code) + strlen(end));
			strcpy($$.code, $1.code);
			strcat($$.code, end);
		}
	;

tagtype 
	: statement 
		{ // single-line statement
			$$.code = $1.code;
		}
	| block 		
		{ // multi-line block
			$$.code = $1.code;
		}
	;

statement 
	: t_let assignstart assignval t_sct 
		{  // assign a float, integer, or boolean value or an array
			const char* assignStr = " = ";
			const char* assignEnd = ";";
			if(!findVar($2.id)){ // if variable/array is new
				// add new variable (whether array or scalar)
				int array = isArray($3.dtype);
				if (array) useFeature(arraysafe);
				if (array) addArray($2.id, $3.dtype, $3.ival); else addScalar($2.id, $3.dtype);

				// copy type to string
				char* typeStr;
				bufferType($3.dtype);
				initStr(&typeStr, strlen(strbuffer));
				strcpy(typeStr, strbuffer);

				if (array) { // copy array size declaration to buffer
					snprintf(strbuffer, sizeof(strbuffer), "[%d]", $3.ival);
				}

				initStr(&$$.code, strlen(typeStr) 
					+ 1 
					+ strlen($2.id) 
					+ ((array) ? strlen(strbuffer) : 0)
					+ strlen(assignStr) 
					+ ((!array || $3.ival == $3.bval) 
						? strlen($3.code) + strlen(assignEnd) 
						: strlen($3.code) + strlen($2.id) + strlen($3.id)
						)
				);

				strcpy($$.code, typeStr); // write type
				strcat($$.code, " ");
				strcat($$.code, $2.id); // write ID
				if (array) strcat($$.code, strbuffer);
				strcat($$.code, assignStr); // write assignment
				if (!array || $3.ival == $3.bval) {
					strcat($$.code, $3.code); // write value(s) being assigned
					strcat($$.code, assignEnd);
				} else { // write the initialization string, then code to fill the array
					strcat($$.code, $3.code);
					strcat($$.code, $2.id);
					strcat($$.code, $3.id);
				}
			} else { // if variable already exists
				struct varnode* var =  checkVarType($2.id, $3.dtype);
				int array = isArray(var->dtype);
				if (array && !isArray($2.dtype)) endError("Arrays cannot be assigned to like a scalar.");
				initStr(&$$.code, ((array) ? strlen($2.code) : strlen($2.id)) + strlen(assignStr) + strlen($3.code) + strlen(assignEnd));
				if (array) strcpy($$.code, $2.code); else strcpy($$.code, $2.id); // write variable
				strcat($$.code, assignStr); // write assignment
				strcat($$.code, $3.code); // write value being assigned
				strcat($$.code, assignEnd);
			}
		}
	| t_in vartypes t_sct 		
		{
			const char* scanfStart = "scanf(\"";
			const char* scanfMid = "\", &";
			const char* scanfEnd = ");";
			struct varnode* var = findVar($2.id);
			bufferShortType(var->dtype);
			initStr(&$$.code, strlen(scanfStart) + strlen(strbuffer) + strlen(scanfMid) + strlen($2.code) + strlen(scanfEnd));
			strcpy($$.code, scanfStart);
			strcat($$.code, strbuffer); // write scanf type string from buffer
			strcat($$.code, scanfMid);
			strcat($$.code, $2.code); // write variable identifier
			strcat($$.code, scanfEnd);
		}
	| t_out strexpr t_sct 	
		{
			const char* printfStart = "printf(\"";
			const char* printfMid = "\", ";
			const char* printfEnd = ");";
			bufferShortType($2.dtype);
			initStr(&$$.code, strlen(printfStart) + strlen(strbuffer) + strlen(printfMid) + strlen($2.code) + strlen(printfEnd));
			strcpy($$.code, printfStart);
			strcat($$.code, strbuffer); // write printf type string from buffer
			strcat($$.code, printfMid);
			strcat($$.code, $2.code); // write variable identifier
			strcat($$.code, printfEnd);
		}
	;

vartypes
	: t_id
		{
			$$.dtype = $1.dtype;
			$$.id = $1.id;
			$$.code = $1.id;
		}
	| array
		{
			$$.dtype = $1.dtype;
			$$.id = $1.id;
			$$.code = $1.code;
		}
	;

assignstart 
	: t_id t_eq 		
		{ // scalar assign
			$$.dtype = dnone; 
			$$.id = $1.id;
		}
	| array t_eq 				
		{ // array assign
			$$.dtype = darray; 
			$$.id = $1.id; 
			$$.code = $1.code;
		}
	;

assignval 
	: expr 		
		{
			$$.dtype = $1.dtype; 
			$$.code = $1.code;
		}
	| condlist 			
		{
			$$.dtype = $1.dtype; 
			$$.code = $1.code;
		}
	| arraydec 			
		{
			$$.dtype = $1.dtype; 
			$$.code = $1.code; 
			$$.id = $1.id; 
			$$.ival = $1.ival; 
			$$.bval = $1.bval;
		}
	;

arraydec 
	: '{' arrayscalarlist ':' iscalar '}' 	
		{
			if ($4.ival < $2.ival) $4.ival = $2.ival; // correct for implicit array sizing error
			$$.dtype = $2.dtype | darray; // indicate type and array
			$$.ival = $4.ival; // use ival to hold array size
			$$.bval = $2.ival; // use bval to hold how many values were initialized 
			char* firstPart;
			initStr(&firstPart, 1 + strlen($2.code) + 2);
			strcpy(firstPart, "{");
			strcat(firstPart, $2.code);
			strcat(firstPart, "}");
			if ($2.ival < $4.ival) { // if there are fewer values than the array's size...
				struct varnode* tempVar = getTempVar();
				// For some reason, tempVar->id doesn't play nice with snprintf
				// so we must first copy its value to a new string
				char* varId;
				initStr(&varId, strlen(tempVar->id));
				strcpy(varId, tempVar->id);

				// first half of for loop
				snprintf(strbuffer, sizeof(strbuffer),
					";\nint %s;\nfor(%s=%d;%s<%d;%s++){",
					varId, varId, $2.ival, varId, $4.ival, varId
				);
				initStr(&$$.code, strlen(firstPart) + strlen(strbuffer));
				strcpy($$.code, firstPart);
				strcat($$.code, strbuffer); // merge firstPart with first half of for loop

				// second half of for loop (excluding array id)
				snprintf(strbuffer, sizeof(strbuffer), 
					"[%s]=%s;}",
					varId, $2.id // initialize the rest of the array with the last value in the arrayscalarlist
				); 
				initStr(&$$.id, strlen(strbuffer));
				strcpy($$.id, strbuffer); // put second half of for loop in id for merging later
			} else { // if the initialized values equals the array's size, return the initialization string
				initStr(&$$.code, strlen(firstPart));
				strcpy($$.code, firstPart);
			}
		}
	| '{' arrayscalarlist '}' 	
		{
			$$.dtype = $2.dtype | darray; // indicate type and array
			$$.ival = $2.ival; // use ival to hold array size
			$$.bval = $2.ival; // use bval to hold how many values were initialized 
			initStr(&$$.code, 1 + strlen($2.code) + 2);
			strcpy($$.code, "{");
			strcat($$.code, $2.code);
			strcat($$.code, "}");
		}
	;

arrayscalarlist 
	: arrayscalarlist ',' scalar 	
		{
			if (!typesMatch($1.dtype, $3.dtype)) endError("Array initialized values must be of same type!");
			$$.dtype = $1.dtype;
			$$.ival = $1.ival + 1; // add up array size
			const char* separator = ", ";
			initStr(&$$.code, strlen($1.code) + strlen(separator) + strlen($3.code));
			strcpy($$.code, $1.code);
			strcat($$.code, separator);
			strcat($$.code, $3.code);
			// a bit sloppy, we'll re-use the struct's id string to hold the last scalar's code
			$$.id = $3.code;
		}
	| scalar 									
		{
			$$.dtype = $1.dtype; 
			$$.code = $1.code; 
			$$.ival = 1; 
			$$.id = $1.code;
		}
	;

// Scalars
scalar 
	: bscalar 					
		{
			$$.dtype = $1.dtype; 
			$$.bval = $1.bval; 
			$$.code = $1.code;
		}
	| iscalar 						
		{
			$$.dtype = $1.dtype; 
			$$.ival = $1.ival; 
			$$.code = $1.code;
		}
	| fscalar 						
		{
			$$.dtype = $1.dtype; 
			$$.fval = $1.fval; 
			$$.code = $1.code;
		}
	;

bscalar 
	: t_bool 					
		{
			$$.dtype = $1.dtype; 
			$$.bval = $1.bval; 
			bufferValue($1); 
			initStr(&$$.code, strlen(strbuffer)); 
			strcpy($$.code, strbuffer);
		}
	;

iscalar 
	: t_int 					
		{
			$$.dtype = $1.dtype; 
			$$.ival = $1.ival; 
			bufferValue($1); 
			initStr(&$$.code, strlen(strbuffer)); 
			strcpy($$.code, strbuffer);
		}
	;

fscalar 
	: t_float 					
		{
			$$.dtype = $1.dtype; 
			$$.fval = $1.fval; 
			bufferValue($1); 
			initStr(&$$.code, strlen(strbuffer)); 
			strcpy($$.code, strbuffer);
		}
	;

// Array
array 
	: t_id '[' boolorexpr ']' 	
		{ // indexing an array
			// allow bool index just so it can be rejected by the next line:
			if (!typesMatch($3.dtype, dint)) endError("Array index must be an integer.");
			struct varnode* arrayVar = checkVarExists($1.id);
			if (!isArray(arrayVar->dtype)) endError("Cannot index scalar as an array.");
			$$.dtype = arrayVar->dtype; 
			int isIntArray = !typesMatch(arrayVar->dtype, dfloat); // includes ints and bools

			// to ensure array safety, a pointer to the array is pased to a function 
			// where the index is compared to be in range
			// and a pointer to the indexed location in the array is returned
			const char* safeStart = "*(";
			const char* intArraySafety = "xclCheckIntArray(";
			const char* floatArraySafety = "xclCheckFloatArray(";
			const char* separator = ", ";
			const char* safeEnd = "))";
			snprintf(strbuffer, sizeof(strbuffer), "%d", arrayVar->size); // buffer size of array as string

			// int** or float** array, const char* arrayName, int index, int length
			initStr(&$$.code, strlen(safeStart) 
				+ ((isIntArray) ? strlen(intArraySafety) : strlen(floatArraySafety))
				+ strlen($1.id)
				+ strlen(separator)
				+ 1 
				+ strlen($1.id) 
				+ 1
				+ strlen(separator)
				+ strlen($3.code)
				+ strlen(separator)
				+ strlen(strbuffer)
				+ strlen(safeEnd)
			);

			strcpy($$.code, safeStart);
			if (isIntArray) strcat($$.code, intArraySafety); else strcat($$.code, floatArraySafety);
			strcat($$.code, $1.id);
			strcat($$.code, separator);
			strcat($$.code, "\"");
			strcat($$.code, $1.id);
			strcat($$.code, "\"");
			strcat($$.code, separator);
			strcat($$.code, $3.code);
			strcat($$.code, separator);
			strcat($$.code, strbuffer);
			strcat($$.code, safeEnd);
			$$.id = $1.id;
		}
	;

// Expressions
strexpr 
	: t_strlit 		
		{
			$$.dtype = $1.dtype; 
			$$.code = $1.sval;
		}
	| expr 				
		{
			$$.dtype = $1.dtype; 
			$$.code = $1.code;
		}
	;

expr 
	: expr t_add term  
		{
			$$.dtype = (typesMatch($1.dtype, dfloat) || typesMatch($3.dtype, dfloat)) ? dfloat : dint;
			const char* addStr = " + ";
			initStr(&$$.code, strlen($1.code) + strlen(addStr) + strlen($3.code));
			strcpy($$.code, $1.code);
			strcat($$.code, addStr);
			strcat($$.code, $3.code);
		}
	| expr t_sub term	
		{
			$$.dtype = (typesMatch($1.dtype, dfloat) || typesMatch($3.dtype, dfloat)) ? dfloat : dint;
			const char* subStr = " - ";
			initStr(&$$.code, strlen($1.code) + strlen(subStr) + strlen($3.code));
			strcpy($$.code, $1.code);
			strcat($$.code, subStr);
			strcat($$.code, $3.code);
		}
	| term 				
		{ 
			$$.dtype = $1.dtype; 
			$$.code = $1.code; 
		}
	;

term 
	: term t_mul expo 	
		{
			$$.dtype = (typesMatch($1.dtype, dfloat) || typesMatch($3.dtype, dfloat)) ? dfloat : dint;
			const char* mulStr = " * ";
			initStr(&$$.code, strlen($1.code) + strlen(mulStr) + strlen($3.code));
			strcpy($$.code, $1.code);
			strcat($$.code, mulStr);
			strcat($$.code, $3.code);
		}
	| term t_div expo 	
		{
			$$.dtype = (typesMatch($1.dtype, dfloat) || typesMatch($3.dtype, dfloat)) ? dfloat : dint;
			const char* divStr = " / ";
			initStr(&$$.code, strlen($1.code) + strlen(divStr) + strlen($3.code));
			strcpy($$.code, $1.code);
			strcat($$.code, divStr);
			strcat($$.code, $3.code);
		}
	| term t_intdiv expo 	
		{
			$$.dtype = dint;
			const char* divStr = " / ";
			const char* intCast = "(int)";
			initStr(&$$.code, strlen(intCast) + strlen($1.code) + strlen(divStr) + strlen(intCast) + strlen($3.code));
			if (typesMatch($1.dtype, dfloat)) strcpy($$.code, intCast); else strcpy($$.code, "");
			strcat($$.code, $1.code);
			strcat($$.code, divStr);
			if (typesMatch($3.dtype, dfloat)) strcat($$.code, intCast);
			strcat($$.code, $3.code);
		}
	| term t_mod expo 		
		{
			$$.dtype = dint;
			const char* modStr = " % ";
			const char* intCast = "(int)";
			initStr(&$$.code, strlen(intCast) + strlen($1.code) + strlen(modStr) + strlen(intCast) + strlen($3.code));
			if (typesMatch($1.dtype, dfloat)) strcpy($$.code, intCast); else strcpy($$.code, "");
			strcat($$.code, $1.code);
			strcat($$.code, modStr);
			if (typesMatch($3.dtype, dfloat)) strcat($$.code, intCast);
			strcat($$.code, $3.code);
		}
	| expo 				
		{ 
			$$.dtype = $1.dtype; 
			$$.code = $1.code; 
		}
	;

expo 
	: factor t_pow expo 	
		{
			useFeature(incmath); // be sure to include math.h for the pow() function
			$$.dtype = (typesMatch($1.dtype, dfloat) || typesMatch($3.dtype, dfloat)) ? dfloat : dint;
			const char* powStr = "pow(";
			const char* powMid = ", ";
			const char* floatCast = "(float)";
			const char* intCast = "(int)";
			initStr(&$$.code, strlen(floatCast) + strlen(powStr) + strlen($1.code) + strlen(powMid) + strlen($3.code) + 1);
			if (typesMatch($$.dtype, dfloat)) strcpy($$.code, floatCast); else strcpy($$.code, intCast);
			strcat($$.code, powStr);
			strcat($$.code, $1.code);
			strcat($$.code, powMid);
			strcat($$.code, $3.code);
			strcat($$.code, ")");
		}
	| factor 				
		{ 
			$$.dtype = $1.dtype; 
			$$.code = $1.code; 
		}
	;

factor 
	: value 				
		{ 
			$$.dtype = $1.dtype; 
			$$.code = $1.code; 
		}
	| '(' expr ')'			
		{
			$$.dtype = $2.dtype;
			initStr(&$$.code, 1 + strlen($2.code) + 1);
			strcpy($$.code, "(");
			strcat($$.code, $2.code);
			strcat($$.code, ")");
		}
	;

value 
	: t_id 	
		{
			$$.dtype = checkVarExists($1.id)->dtype; 
			$$.code = $1.id;
		}
	| iscalar 	
		{
			$$.dtype = $1.dtype; 
			$$.code = $1.code; 
		}
	| fscalar 	
		{
			$$.dtype = $1.dtype; 
			$$.code = $1.code; 
		}
	| array 	
		{
			$$.dtype = $1.dtype; 
			$$.code = $1.code; 
		}
	;

// Conditions
condlist 
	: condlist t_and cond 	
		{
			$$.dtype = dbool;
			const char* andStr = " && ";
			initStr(&$$.code, strlen($1.code) + strlen(andStr) + strlen($3.code));
			strcpy($$.code, $1.code);
			strcat($$.code, andStr);
			strcat($$.code, $3.code);
		}
	| condlist t_or cond 		
		{
			$$.dtype = dbool;
			const char* orStr = " || ";
			initStr(&$$.code, strlen($1.code) + strlen(orStr) + strlen($3.code));
			strcpy($$.code, $1.code);
			strcat($$.code, orStr);
			strcat($$.code, $3.code);
		}
	| cond 						
		{
			$$.dtype = $1.dtype; 
			$$.code = $1.code;
		}
	;

cond 
	: boolorexpr t_eq boolorexpr 	
		{
			$$.dtype = dbool;
			const char* symbStr = " == ";
			initStr(&$$.code, strlen($1.code) + strlen(symbStr) + strlen($3.code));
			strcpy($$.code, $1.code);
			strcat($$.code, symbStr);
			strcat($$.code, $3.code);
		}
	| boolorexpr t_noteq boolorexpr 
		{
			$$.dtype = dbool;
			const char* symbStr = " != ";
			initStr(&$$.code, strlen($1.code) + strlen(symbStr) + strlen($3.code));
			strcpy($$.code, $1.code);
			strcat($$.code, symbStr);
			strcat($$.code, $3.code);
		}
	| expr t_lt expr 				
		{
			$$.dtype = dbool;
			const char* symbStr = " < ";
			initStr(&$$.code, strlen($1.code) + strlen(symbStr) + strlen($3.code));
			strcpy($$.code, $1.code);
			strcat($$.code, symbStr);
			strcat($$.code, $3.code);
		}
	| expr t_lte expr 				
		{
			$$.dtype = dbool;
			const char* symbStr = " <= ";
			initStr(&$$.code, strlen($1.code) + strlen(symbStr) + strlen($3.code));
			strcpy($$.code, $1.code);
			strcat($$.code, symbStr);
			strcat($$.code, $3.code);
		}
	| expr t_gt expr 				
		{
			$$.dtype = dbool;
			const char* symbStr = " > ";
			initStr(&$$.code, strlen($1.code) + strlen(symbStr) + strlen($3.code));
			strcpy($$.code, $1.code);
			strcat($$.code, symbStr);
			strcat($$.code, $3.code);
		}
	| expr t_gte expr 				
		{
			$$.dtype = dbool;
			const char* symbStr = " >= ";
			initStr(&$$.code, strlen($1.code) + strlen(symbStr) + strlen($3.code));
			strcpy($$.code, $1.code);
			strcat($$.code, symbStr);
			strcat($$.code, $3.code);
		}
	| condvalue 					
		{
			$$.dtype = $1.dtype; 
			$$.code = $1.code;
		}
	;

boolorexpr 
	: expr 					
		{
			$$.dtype = $1.dtype; 
			$$.code = $1.code;
		}
	| boolvalue 					
		{
			$$.dtype = $1.dtype; 
			$$.code = $1.code;
		}
	;

condvalue 
	: boolvalue 				
		{
			$$.dtype = $1.dtype; 
			$$.code = $1.code;
		}
	| '(' condlist ')' 				
		{
			$$.dtype = $2.dtype;
			initStr(&$$.code, 1 + strlen($2.code) + 1);
			strcpy($$.code, "(");
			strcat($$.code, $2.code);
			strcat($$.code, ")");
		}
	| t_not '(' condlist ')' 		
		{
			$$.dtype = $3.dtype;
			const char* symbStr = "!(";
			initStr(&$$.code, strlen(symbStr) + strlen($3.code) + 1);
			strcpy($$.code, symbStr);
			strcat($$.code, $3.code);
			strcat($$.code, ")");
		}
	;

boolvalue 
	: bscalar 				
		{
			$$.dtype = $1.dtype; 
			$$.code = $1.code;
		}
	| t_not boolvalue 				
		{
			$$.dtype = dbool;
			const char* symbStr = "!";
			initStr(&$$.code, strlen(symbStr) + strlen($2.code));
			strcpy($$.code, symbStr);
			strcat($$.code, $2.code);
		}
	;

// Blocks
block 
	: startlogic ifbranch t_logicc 						
		{ // single if
			$$.dtype = $2.dtype; 
			$$.code = $2.code; popBlock();
		}
	| startlogic ifbranch elseiflist t_logicc 			
		{ // if with elseif
			$$.dtype = $2.dtype; 
			initStr(&$$.code, strlen($2.code) + strlen($3.code));
			strcpy($$.code, $2.code);
			strcat($$.code, $3.code);
			popBlock();
		} 
	| startlogic ifbranch elsebranch t_logicc 			
		{ // if with else
			$$.dtype = $2.dtype; 
			initStr(&$$.code, strlen($2.code) + strlen($3.code));
			strcpy($$.code, $2.code);
			strcat($$.code, $3.code);
			popBlock();
		} 
	| startlogic ifbranch elseiflist elsebranch t_logicc 	
		{ // if with elseif and else
			$$.dtype = $2.dtype; 
			initStr(&$$.code, strlen($2.code) + strlen($3.code) + strlen($4.code));
			strcpy($$.code, $2.code);
			strcat($$.code, $3.code);
			strcat($$.code, $4.code);
			popBlock();
		} 
	| startloop expr '>' taglist t_loopc 					
		{ // for loop
			$$.dtype = dnone; 
			const char* forDec = "int ";
			const char* forDecEnd = ";\n";
			const char* forStart = "for (";
			struct varnode* tempVar = getTempVar();
			const char* forMed = " = 0; ";
			const char* forMed2 = " < ";
			const char* typeCast = "(int)(";
			const char* castClose = ")";
			const char* forMed3 = "; ";
			const char* forMed4 = "++) {\n";
			const char* forEnd = "}";
			
			initStr(&$$.code, strlen(forDec)
				+ strlen(tempVar->id)
				+ strlen(forDecEnd)
				+ strlen(forStart) 
				+ strlen(tempVar->id) 
				+ strlen(forMed) 
				+ strlen(tempVar->id) 
				+ strlen(forMed2) 
				+ strlen(typeCast)
				+ strlen($2.code) 
				+ strlen(castClose)
				+ strlen(forMed3) 
				+ strlen(tempVar->id) 
				+ strlen(forMed4) 
				+ strlen($4.code)
				+ strlen(forEnd)); 

			strcpy($$.code, forDec); 
			strcat($$.code, tempVar->id);
			strcat($$.code, forDecEnd); 
			strcat($$.code, forStart); 
			strcat($$.code, tempVar->id);
			strcat($$.code, forMed); 
			strcat($$.code, tempVar->id);
			strcat($$.code, forMed2);
			if (!typesMatch($2.dtype, dint)) strcat($$.code, typeCast);
			strcat($$.code, $2.code);
			if (!typesMatch($2.dtype, dint)) strcat($$.code, castClose);
			strcat($$.code, forMed3);
			strcat($$.code, tempVar->id);
			strcat($$.code, forMed4);
			strcat($$.code, $4.code);
			strcat($$.code, forEnd);
			popBlock();
		}
	| startloop condlist '>' taglist t_loopc 			
		{ // while loop
			$$.dtype = dnone; 
			const char* whileStart = "while (";
			const char* whileMed = ") {\n";
			const char* whileEnd = "}";
			
			initStr(&$$.code, strlen(whileStart) 
				+ strlen($2.code) 
				+ strlen(whileMed) 
				+ strlen($4.code)
				+ strlen(whileEnd)); 
			
			strcpy($$.code, whileStart); 
			strcat($$.code, $2.code);
			strcat($$.code, whileMed); 
			strcat($$.code, $4.code);
			strcat($$.code, whileEnd);
			popBlock();
		}
	;

// Block starts (to ensure that blockLevel is incremented before the block is actually entered)
startlogic 
	: t_logico 	
		{
			blockLevel++;
		}
	;

startloop 
	: t_loopo 	
		{
			blockLevel++;
		}
	;

ifbranch 
	: t_brancho condlist '>' taglist t_branchc 	
		{
			$$.dtype = dnone; 
			const char* ifStart = "if (";
			const char* ifMed = ") {\n";
			const char* ifEnd = "}";
			initStr(&$$.code, strlen(ifStart) + strlen($2.code) + strlen(ifMed) + strlen($4.code) + strlen(ifEnd)); 
			strcpy($$.code, ifStart); 
			strcat($$.code, $2.code);
			strcat($$.code, ifMed);
			strcat($$.code, $4.code);
			strcat($$.code, ifEnd);
		}
	;

elseiflist 
	: elseiflist elseifbranch 					
		{
			$$.dtype = $1.dtype; 
			initStr(&$$.code, strlen($1.code) + strlen($2.code)); 
			strcpy($$.code, $1.code); 
			strcat($$.code, $2.code);
		}
	| elseifbranch 										
		{
			$$.dtype = $1.dtype; 
			$$.code = $1.code;
		}
	;

elseifbranch 
	: t_brancho condlist '>' taglist t_branchc 
		{
			$$.dtype = dnone; 
			const char* elseifStart = "else if (";
			const char* elseifMed = ") {\n";
			const char* elseifEnd = "}";
			initStr(&$$.code, strlen(elseifStart) + strlen($2.code) + strlen(elseifMed) + strlen($4.code) + strlen(elseifEnd)); 
			strcpy($$.code, elseifStart); 
			strcat($$.code, $2.code);
			strcat($$.code, elseifMed);
			strcat($$.code, $4.code);
			strcat($$.code, elseifEnd);
		}
	;

elsebranch 
	: t_branche taglist t_branchc 				
		{
			$$.dtype = dnone; 
			const char* elseStart = "else {\n";
			const char* elseEnd = "}";
			initStr(&$$.code, strlen(elseStart) + strlen($2.code) + strlen(elseEnd)); 
			strcpy($$.code, elseStart); 
			strcat($$.code, $2.code);
			strcat($$.code, elseEnd);
		}
	;

%%

main ()
{
  yyparse ();
  if (DEBUG) printf("---------------------\n");
  showtab();
}

yyerror (char *s)  /* Called by yyparse on error */
{
  printf ("\terror: %s\n", s);
  printf ("ERROR: %s at line %d\n", s, 123);
}

void initStr (char** str, int charCount) {
	*str = malloc(sizeof(char) * (charCount + 1));
}

void bufferXCLType (enum datatype dt) {
	switch(dt & (~darray)) {
		case dbool: snprintf(strbuffer, sizeof(strbuffer), "boolean"); break;
		case dfloat: snprintf(strbuffer, sizeof(strbuffer), "float"); break;
		case dint: snprintf(strbuffer, sizeof(strbuffer), "integer"); break;
		case dstring: snprintf(strbuffer, sizeof(strbuffer), "string"); break;
	}
}

void bufferType (enum datatype dt) { // write C-style datatype
	switch(dt & (~darray)) {
		case dbool: snprintf(strbuffer, sizeof(strbuffer), "int"); break;
		case dfloat: snprintf(strbuffer, sizeof(strbuffer), "float"); break;
		case dint: snprintf(strbuffer, sizeof(strbuffer), "int"); break;
		case dstring: snprintf(strbuffer, sizeof(strbuffer), "char*"); break;
	}
}

void bufferShortType (enum datatype dt) { // write printf/scanf placeholder type
	switch(dt & (~darray)) {
		case dbool: snprintf(strbuffer, sizeof(strbuffer), "%%d"); break;
		case dfloat: snprintf(strbuffer, sizeof(strbuffer), "%%f"); break;
		case dint: snprintf(strbuffer, sizeof(strbuffer), "%%d"); break;
		case dstring: snprintf(strbuffer, sizeof(strbuffer), "%%s"); break;
	}
}

void bufferValue (tstruct val) { // write value
	switch(val.dtype & (~darray)) {
		case dbool: snprintf(strbuffer, sizeof(strbuffer), "%d", val.bval); break;
		case dfloat: snprintf(strbuffer, sizeof(strbuffer), "%ff", val.fval); break;
		case dint: snprintf(strbuffer, sizeof(strbuffer), "%d", val.ival); break;
		//case dstring: snprintf(strbuffer, sizeof(strbuffer), "%s", val.sval); break; // never happens
	}
}

char* writeHeader() {
	char* const commonLibs = "#include <stdlib.h>\n#include <stdio.h>\n";
	char* const mathLib = "#include <math.h> // You must compile using the -lm flag in order for the math library to work!\n";
	char* const intArraySafe = "// Functions for array safety:\nint* xclCheckIntArray(int* array, const char* arrayName, int index, const int length){\nif (index < 0 || index >= length) {\nprintf(\"ERROR: index %d out of range %d for array %s.\\n\", index, length, arrayName);\nexit(1);\n} else {\nreturn &(array[index]);}\n}\n";
	char* const floatArraySafe = "float* xclCheckFloatArray(float* array, const char* arrayName, int index, const int length){\nif (index < 0 || index >= length) {\nprintf(\"ERROR: index %d out of range %d for array %s.\\n\", index, length, arrayName);\nexit(1);\n} else {\nreturn &(array[index]);}\n}\n";
	char* const progStartHere = "// Program starts here: \n";
	char* returnStr;
	int includeMath = featureBits & incmath;
	int arraySafe = featureBits & arraysafe;
	initStr(&returnStr, strlen(commonLibs) + ((includeMath) ? strlen(mathLib) : 0) + ((arraySafe) ? strlen(intArraySafe) + strlen(floatArraySafe) : 0) + strlen(progStartHere));
	strcpy(returnStr, commonLibs);
	if (includeMath) strcat(returnStr, mathLib);
	if (arraySafe) {strcat(returnStr, intArraySafe); strcat(returnStr, floatArraySafe);}
	strcat(returnStr, progStartHere);
}