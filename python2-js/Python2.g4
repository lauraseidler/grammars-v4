/*
 * Parser grammar taken directly from official Python 2.7.13 grammar
 * with only minor syntactical changes (instances of [X] changed to (X)?, and
 * semicolons added to ends of rules).:
 * https://docs.python.org/2/reference/grammar.html
 *
 * Added lexer rules, and code to handle INDENT's, DEDENT's,
 * line continuations, etc.
 *
 * Compiles with ANTLR 4.7, generated lexer/parser for Python 2 target.
 */

 grammar Python2;

 tokens { INDENT, DEDENT, NEWLINE, ENDMARKER }

@lexer::header {
    var Python2Parser = require('./Python2Parser').Python2Parser;
    var CommonToken = require('antlr4').CommonToken
    class IndentStack {
        constructor() {
            this._s = [];
        }
        empty() {
            return this._s.length === 0;
        }
        push(wsval) {
            this._s.push(wsval);
        }
        pop() {
            this._s.pop();
        }
        wsval() {
            if (this._s.length) return this._s[this._s.length - 1];
            else return 0;
        }
    }

    class TokenQueue {
        constructor() {
            this._q = [];
        }
        empty() {
            return this._q.length === 0;
        }
        enq(t) {
            this._q.push(t);
        }
        deq() {
            return this._q.shift();
        }
    }

    function ord(char) {
        return char.charCodeAt();
    }
}

@lexer::members {
    var old_lexer = Python2Lexer;
    Python2Lexer = function() {
        old_lexer.apply(this, arguments);
        this._openBRCount       = 0
        this._suppressNewlines  = false
        this._lineContinuation  = false
        this._tokens            = new TokenQueue();
        this._indents           = new IndentStack();
        antlr4.Lexer.prototype.reset.call(this);
    }

    Python2Lexer.prototype = Object.create(old_lexer.prototype);
    Python2Lexer.prototype.constructor = Python2Lexer;

    Python2Lexer.prototype.nextToken = function() {
        if (!this._tokens.empty()) {
            return this._tokens.deq();
        } else {
            var t = antlr4.Lexer.prototype.nextToken.call(this);
            if (t.type !== Python2Parser.EOF) return t;
            else {
                if (!this._suppressNewlines) {
                    this.emitNewline();
                }
                this.emitFullDedent();
                this.emitEndmarker();
                this.emitEndToken(t);
                return this._tokens.deq();
            }
        }

    }

    Python2Lexer.prototype.emitEndToken = function (token) {
        this._tokens.enq(token);
    }

    Python2Lexer.prototype.emitIndent = function (length = 0, text = 'INDENT') {
        var t = this.createToken(Python2Parser.INDENT, text, length);
        this._tokens.enq(t);
    }

    Python2Lexer.prototype.emitDedent = function () {
        var t = this.createToken(Python2Parser.DEDENT, 'DEDENT');
        this._tokens.enq(t);
    }

    Python2Lexer.prototype.emitFullDedent = function () {
        while (!this._indents.empty()) {
            this._indents.pop();
            this.emitDedent();
        }
    }

    Python2Lexer.prototype.emitEndmarker = function () {
        var t = this.createToken(Python2Parser.ENDMARKER, 'ENDMARKER');
        this._tokens.enq(t);
    }

    Python2Lexer.prototype.emitNewline = function () {
        var t = this.createToken(Python2Parser.NEWLINE, 'NEWLINE');
        this._tokens.enq(t);
    }

    Python2Lexer.prototype.createToken = function (type_, text="", length=0) {
        var start = this._tokenStartCharIndex;
        var stop = start + length;
        var t = new CommonToken(this._tokenFactorySourcePair,
                type_, this.DEFAULT_TOKEN_CHANNEL,
                start, stop);
        t.text = text;
        return t;
    }
}

// Header included from Python site:
/*
 * Grammar for Python
 *
 * Note:  Changing the grammar specified in this file will most likely
 *        require corresponding changes in the parser module
 *        (../Modules/parsermodule.c).  If you can't make the changes to
 *        that module yourself, please co-ordinate the required changes
 *        with someone who can; ask around on python-dev for help.  Fred
 *        Drake <fdrake@acm.org> will probably be listening there.
 *
 * NOTE WELL: You should also follow all the steps listed in PEP 306,
 * "How to Change Python's Grammar"
 *
 * Start symbols for the grammar:
 *       single_input is a single interactive statement;
 *       file_input is a module or sequence of commands read from an input file;
 *       eval_input is the input for the eval() and input() functions.
 * NB: compound_stmt in single_input is followed by extra NEWLINE!
 */

single_input: NEWLINE | simple_stmt | compound_stmt NEWLINE
    ;
file_input: (NEWLINE | stmt)* ENDMARKER
    ;
eval_input: testlist NEWLINE* ENDMARKER
    ;


decorator: '@' dotted_name ( '(' (arglist)? ')' )? NEWLINE
    ;
decorators: decorator+
    ;
decorated: decorators (classdef | funcdef)
    ;
funcdef: 'def' NAME parameters ':' suite
    ;
parameters: '(' (varargslist)? ')'
    ;
varargslist: ((fpdef ('=' test)? ',')*
              ('*' NAME (',' '**' NAME)? | '**' NAME) |
              fpdef ('=' test)? (',' fpdef ('=' test)?)* (',')?)
    ;
fpdef: NAME | '(' fplist ')'
    ;
fplist: fpdef (',' fpdef)* (',')?
    ;


stmt: simple_stmt | compound_stmt
    ;
simple_stmt: small_stmt (';' small_stmt)* (';')? NEWLINE
    ;
small_stmt: (expr_stmt | print_stmt  | del_stmt | pass_stmt | flow_stmt |
             import_stmt | global_stmt | exec_stmt | assert_stmt)
    ;
expr_stmt: testlist (augassign (yield_expr|testlist) |
                     ('=' (yield_expr|testlist))*)
    ;
augassign: ('+=' | '-=' | '*=' | '/=' | '%=' | '&=' | '|=' | '^=' |
            '<<=' | '>>=' | '**=' | '//=')
// For normal assignments, additional restrictions enforced by the interpreter
    ;
//print_stmt: 'print' ( ( test (',' test)* (',')? )? |
//                      '>>' test ( (',' test)+ (',')? )? )
//    ;
print_stmt: {this._input.LT(1).text=='print'}?
            // tt: this change allows print to be treated as a NAME
            //     while preserving the print statement syntax.
            NAME ( ( test (',' test)* (',')? )? |
                 '>>' test ( (',' test)+ (',')? )? )
    ;
del_stmt: 'del' exprlist
    ;
pass_stmt: 'pass'
    ;
flow_stmt: break_stmt | continue_stmt | return_stmt | raise_stmt | yield_stmt
    ;
break_stmt: 'break'
    ;
continue_stmt: 'continue'
    ;
return_stmt: 'return' (testlist)?
    ;
yield_stmt: yield_expr
    ;
raise_stmt: 'raise' (test (',' test (',' test)?)?)?
    ;
import_stmt: import_name | import_from
    ;
import_name: 'import' dotted_as_names
    ;
import_from: ('from' ('.'* dotted_name | '.'+)
              'import' ('*' | '(' import_as_names ')' | import_as_names))
    ;
import_as_name: NAME ('as' NAME)?
    ;
dotted_as_name: dotted_name ('as' NAME)?
    ;
import_as_names: import_as_name (',' import_as_name)* (',')?
    ;
dotted_as_names: dotted_as_name (',' dotted_as_name)*
    ;
dotted_name: NAME ('.' NAME)*
    ;
global_stmt: 'global' NAME (',' NAME)*
    ;
exec_stmt: 'exec' expr ('in' test (',' test)?)?
    ;
assert_stmt: 'assert' test (',' test)?
    ;


compound_stmt: if_stmt | while_stmt | for_stmt | try_stmt | with_stmt | funcdef | classdef | decorated
    ;
if_stmt: 'if' test ':' suite ('elif' test ':' suite)* ('else' ':' suite)?
    ;
while_stmt: 'while' test ':' suite ('else' ':' suite)?
    ;
for_stmt: 'for' exprlist 'in' testlist ':' suite ('else' ':' suite)?
    ;
try_stmt: ('try' ':' suite
           ((except_clause ':' suite)+
            ('else' ':' suite)?
            ('finally' ':' suite)? |
           'finally' ':' suite))
    ;
with_stmt: 'with' with_item (',' with_item)*  ':' suite
    ;
with_item: test ('as' expr)?
// NB compile.c makes sure that the default except clause is last
    ;
except_clause: 'except' (test (('as' | ',') test)?)?
    ;
suite: simple_stmt | NEWLINE INDENT stmt+ DEDENT
    ;
// Backward compatibility cruft to support:
// [ x for x in lambda: True, lambda: False if x() ]
// even while also allowing:
// lambda x: 5 if x else 2
// (But not a mix of the two)
testlist_safe: old_test ((',' old_test)+ (',')?)?
    ;
old_test: or_test | old_lambdef
    ;
old_lambdef: 'lambda' (varargslist)? ':' old_test
    ;


test: or_test ('if' or_test 'else' test)? | lambdef
    ;
or_test: and_test ('or' and_test)*
    ;
and_test: not_test ('and' not_test)*
    ;
not_test: 'not' not_test | comparison
    ;
comparison: expr (comp_op expr)*
    ;
comp_op: '<'|'>'|'=='|'>='|'<='|'<>'|'!='|'in'|'not' 'in'|'is'|'is' 'not'
    ;
expr: xor_expr ('|' xor_expr)*
    ;
xor_expr: and_expr ('^' and_expr)*
    ;
and_expr: shift_expr ('&' shift_expr)*
    ;
shift_expr: arith_expr (('<<'|'>>') arith_expr)*
    ;
arith_expr: term (('+'|'-') term)*
    ;
term: factor (('*'|'/'|'%'|'//') factor)*
    ;
factor: ('+'|'-'|'~') factor | power
    ;
power: atom trailer* ('**' factor)?
    ;
atom:  ('(' (yield_expr|testlist_comp)? ')' |
        '[' (listmaker)? ']' |
        '{' (dictorsetmaker)? '}' |
        '`' testlist1 '`' | '.' '.' '.' | // tt: added elipses.
        NAME | NUMBER | STRING+)
    ;
listmaker: test ( list_for | (',' test)* (',')? )
    ;
testlist_comp: test ( comp_for | (',' test)* (',')? )
    ;
lambdef: 'lambda' (varargslist)? ':' test
    ;
trailer: '(' (arglist)? ')' | '[' subscriptlist ']' | '.' NAME
    ;
subscriptlist: subscript (',' subscript)* (',')?
    ;
subscript: '.' '.' '.' | test | (test)? ':' (test)? (sliceop)?
    ;
sliceop: ':' (test)?
    ;
exprlist: expr (',' expr)* (',')?
    ;
testlist: test (',' test)* (',')?
    ;
dictorsetmaker: ( (test ':' test (comp_for | (',' test ':' test)* (',')?)) |
                  (test (comp_for | (',' test)* (',')?)) )
    ;


classdef: 'class' NAME ('(' (testlist)? ')')? ':' suite
    ;


arglist: (argument ',')* (argument (',')?
                         |'*' test (',' argument)* (',' '**' test)?
                         |'**' test)
// The reason that keywords are test nodes instead of NAME is that using NAME
// results in an ambiguity. ast.c makes sure it's a NAME.
    ;
argument: test (comp_for)? | test '=' test
    ;


list_iter: list_for | list_if
    ;
list_for: 'for' exprlist 'in' testlist_safe (list_iter)?
    ;
list_if: 'if' old_test (list_iter)?
    ;


comp_iter: comp_for | comp_if
    ;
comp_for: 'for' exprlist 'in' or_test (comp_iter)?
    ;
comp_if: 'if' old_test (comp_iter)?
    ;


testlist1: test (',' test)*
    ;

// not used in grammar, but may appear in "node" passed from Parser to Compiler
encoding_decl: NAME
    ;

yield_expr: 'yield' 'from'? (testlist)?
    ;

/*****************************************************************************
 *                               Lexer rules
 *****************************************************************************/

NAME: [a-zA-Z_] [a-zA-Z0-9_]*
    ;

NUMBER
    :   '0' ([xX] [0-9a-fA-F]+         ([lL]  | [eE] [+-]? [0-9]+)?
    |        [oO] [0-7]+                [lL]?
    |        [bB] [01]+                 [lL]?)
    | ([0-9]+ '.' [0-9]* | '.' [0-9]+)         ([eE] [+-]? [0-9]+)?       [jJ]?
    |  [0-9]+                          ([lL]  | [eE] [+-]? [0-9]+ [jJ]? | [jJ])?
    ;

STRING
    : ([uUbB]? [rR]? | [rR]? [uUbB]?)
    ( '\''     ('\\' (([ \t]+ ('\r'? '\n')?)|.) | ~[\\\r\n'])*  '\''
    | '"'      ('\\' (([ \t]+ ('\r'? '\n')?)|.) | ~[\\\r\n"])*  '"'
    | '"""'    ('\\' .                          | ~'\\'     )*? '"""'
    | '\'\'\'' ('\\' .                          | ~'\\'     )*? '\'\'\''
    )
    ;

LINENDING:             (('\r'? '\n')+ {this._lineContinuation=false}
    |      '\\'  [ \t]* ('\r'? '\n')  {this._lineContinuation=true})
{
if (this._openBRCount == 0 && !this._lineContinuation) {
    if (!this._suppressNewlines) {
        this.emitNewline()
        this._suppressNewlines = true
    }
    var la = this._input.LA(1)
    if ([ord(' '), ord('\t'), ord('#')].indexOf(la) === -1) {
        this._suppressNewlines = false
        this.emitFullDedent()
    }
}
} -> channel(HIDDEN)
   ;

WHITESPACE: ('\t' | ' ')+
{
if (this._tokenStartColumn == 0 && this._openBRCount == 0
    && !this._lineContinuation) {

    var la = this._input.LA(1);
    if ([ord('\r'), ord('\n'), ord('#'), -1].indexOf(la)===-1)
        this._suppressNewlines = false
        var wsCount = 0;
        for (var ch in this.text) {
            ch = this.text[ch];
            if (ch == ' ') wsCount += 1
            else if (ch == '\t') wsCount += 8
        }

        if (wsCount > this._indents.wsval()) {
            this.emitIndent(this.text.length)
            this._indents.push(wsCount)
        }
        else {
            while (wsCount < this._indents.wsval()) {
                this.emitDedent()
                this._indents.pop()
            }
            if (wsCount != this._indents.wsval()) {
                // throw new Error('wsCount')
            }
        }
    }
}  -> channel(HIDDEN)
    ;

COMMENT:        '#' ~[\r\n]* -> channel(HIDDEN);

OPEN_PAREN:     '(' {this._openBRCount  += 1};
CLOSE_PAREN:    ')' {this._openBRCount  -= 1};
OPEN_BRACE:     '{' {this._openBRCount  += 1};
CLOSE_BRACE:    '}' {this._openBRCount  -= 1};
OPEN_BRACKET:   '[' {this._openBRCount  += 1};
CLOSE_BRACKET:  ']' {this._openBRCount  -= 1};

UNKNOWN: . -> skip;

