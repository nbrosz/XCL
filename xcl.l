
%{

enum datatype
{
	dnone = 0,
  	dbool = 1,
  	dint = 2,
  	dfloat = 4,
  	dstring = 8
};

typedef struct
{
 char* id;
 char* sval;
 int ival;
 float fval;
 int bval;
 enum datatype dtype;
}tstruct ;

#define YYSTYPE  tstruct
#define DEBUGREAD 0
#define DEBUGTYPE 0

#include "xcl.tab.h"

int lineno = 1;

%}

DIGIT  [0-9]
UC     [A-Z]
LC     [a-z]
L      [A-Za-z]

%%

[<][!][-][-][^-]*[-]+([^-->][^-]*[--]+)*[>]     /* comments  */   

 /* tag parts */
"/>"     { if (DEBUGREAD) printf("  -%s\n",yytext); return t_sct;} /* self-closing tag */

 /* tags */
"<"\s*(?i:PROGRAM)\s*">"     { if (DEBUGREAD) printf("  -%s\n",yytext); return t_progo;}
"</"\s*(?i:PROGRAM)\s*">"     { if (DEBUGREAD) printf("  -%s\n",yytext); return t_progc;}
"<"\s*(?i:LET)     { if (DEBUGREAD) printf("  -%s\n",yytext); return t_let;}
"<"\s*(?i:IN)     { if (DEBUGREAD) printf("  -%s\n",yytext); return t_in;}
"<"\s*(?i:OUT)     { if (DEBUGREAD) printf("  -%s\n",yytext); return t_out;}
"<"\s*(?i:LOGIC)\s*">"     { if (DEBUGREAD) printf("  -%s\n",yytext); return t_logico;}
"</"\s*(?i:LOGIC)\s*">"     { if (DEBUGREAD) printf("  -%s\n",yytext); return t_logicc;}
"<"\s*(?i:BRANCH)     { if (DEBUGREAD) printf("  -%s\n",yytext); return t_brancho;}
"<"\s*(?i:BRANCH)\s*">"     { if (DEBUGREAD) printf("  -%s\n",yytext); return t_branche;}
"</"\s*(?i:BRANCH)\s*">"     { if (DEBUGREAD) printf("  -%s\n",yytext); return t_branchc;}
"<"\s*(?i:LOOP)     { if (DEBUGREAD) printf("  -%s\n",yytext); return t_loopo;}
"</"\s*(?i:LOOP)\s*">"     { if (DEBUGREAD) printf("  -%s\n",yytext); return t_loopc;}

 /* arithmetic */
"+"     { if (DEBUGREAD) printf("  -%s\n",yytext); return t_add;}
"-"     { if (DEBUGREAD) printf("  -%s\n",yytext); return t_sub;}
"**"     { if (DEBUGREAD) printf("  -%s\n",yytext); return t_pow;}
"*"     { if (DEBUGREAD) printf("  -%s\n",yytext); return t_mul;}
"//"     { if (DEBUGREAD) printf("  -%s\n",yytext); return t_intdiv;}
"/"     { if (DEBUGREAD) printf("  -%s\n",yytext); return t_div;}
"%"     { if (DEBUGREAD) printf("  -%s\n",yytext); return t_mod;}

 /* logic */
"="     { if (DEBUGREAD) printf("  -%s\n",yytext); return t_eq;}
"~="     { if (DEBUGREAD) printf("  -%s\n",yytext); return t_noteq;}
"gt"     { if (DEBUGREAD) printf("  -%s\n",yytext); return t_gt;}
"gte"     { if (DEBUGREAD) printf("  -%s\n",yytext); return t_gte;}
"lt"     { if (DEBUGREAD) printf("  -%s\n",yytext); return t_lt;}
"lte"     { if (DEBUGREAD) printf("  -%s\n",yytext); return t_lte;}
"^"     { if (DEBUGREAD) printf("  -%s\n",yytext); return t_and;}
"v"     { if (DEBUGREAD) printf("  -%s\n",yytext); return t_or;}
"~"     { if (DEBUGREAD) printf("  -%s\n",yytext); return t_not;}

 /* values */
 ("-")?{DIGIT}+     { if (DEBUGREAD) printf("  -%s\n",yytext); if (DEBUGTYPE) printf("   int: %s\n",yytext); yylval.ival = atoi(yytext); yylval.dtype = dint; return t_int; }
("-")?{DIGIT}*\.{DIGIT}+		{ if (DEBUGREAD) printf("  -%s\n",yytext); if (DEBUGTYPE) printf("   float: %s\n",yytext); yylval.fval = atof(yytext); yylval.dtype = dfloat; return t_float; }
(?i:FALSE)     { if (DEBUGREAD) printf("  -%s\n",yytext); if (DEBUGTYPE) printf("   bool(f): %s\n",yytext); yylval.bval = 0; yylval.dtype = dbool; return t_bool;}
(?i:TRUE)     { if (DEBUGREAD) printf("  -%s\n",yytext); if (DEBUGTYPE) printf("   bool(t): %s\n",yytext); yylval.bval = 1; yylval.dtype = dbool; return t_bool;}
\"([^"]*)\"  { if (DEBUGREAD) printf("  -%s\n",yytext); yylval.sval = malloc(sizeof(char) * strlen(yytext)); strcpy(yylval.sval,yytext); yylval.dtype = dstring; return t_strlit;}
{L}({L}|{DIGIT}|"_")*     { if (DEBUGREAD) printf("  -%s\n",yytext); yylval.id = malloc(sizeof(char) * strlen(yytext)); strcpy(yylval.id,yytext); return t_id; }

[ \t]     /* ignore whitespace */

\n|\r\n     { lineno++; /*yylloc.first_line = lineno;*/}

<<EOF>>   yyterminate();  /* signal end of dialogue */

.        return yytext[0];

%%



