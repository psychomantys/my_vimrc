
if v:version < 700
	echohl WarningMsg
	echomsg "omni#cpp#complete.vim: Please install vim 7.0 or higher for omni-completion"
	echohl None
	finish
endif

let g:omni#cpp#utils#szFilterGlobalScope = "(!has_key(v:val, 'class') && !has_key(v:val, 'struct') && !has_key(v:val, 'union') && !has_key(v:val, 'namespace')"
let g:omni#cpp#utils#szFilterGlobalScope .= "&& (!has_key(v:val, 'enum') || (has_key(v:val, 'enum') && v:val.enum =~ '^\\w\\+$')))"

" Expression used to ignore comments
" Note: this expression drop drastically the performance
"let omni#cpp#utils#expIgnoreComments = 'match(synIDattr(synID(line("."), col("."), 1), "name"), '\CcComment')!=-1'
" This one is faster but not really good for C comments
let omni#cpp#utils#reIgnoreComment = escape('\/\/\|\/\*\|\*\/', '*/\')
let omni#cpp#utils#expIgnoreComments = 'getline(".") =~ g:omni#cpp#utils#reIgnoreComment'

" Characters to escape in a filename for vimgrep
"TODO: Find more characters to escape
let omni#cpp#utils#szEscapedCharacters = ' %#'

" From the C++ BNF
let s:cppKeyword = ['asm', 'auto', 'bool', 'break', 'case', 'catch', 'char', 'class', 'const', 'const_cast', 'continue', 'default', 'delete', 'do', 'double', 'dynamic_cast', 'else', 'enum', 'explicit', 'export', 'extern', 'false', 'float', 'for', 'friend', 'goto', 'if', 'inline', 'int', 'long', 'mutable', 'namespace', 'new', 'operator', 'private', 'protected', 'public', 'register', 'reinterpret_cast', 'return', 'short', 'signed', 'sizeof', 'static', 'static_cast', 'struct', 'switch', 'template', 'this', 'throw', 'true', 'try', 'typedef', 'typeid', 'typename', 'union', 'unsigned', 'using', 'virtual', 'void', 'volatile', 'wchar_t', 'while', 'and', 'and_eq', 'bitand', 'bitor', 'compl', 'not', 'not_eq', 'or', 'or_eq', 'xor', 'xor_eq']

let s:reCppKeyword = '\C\<'.join(s:cppKeyword, '\>\|\<').'\>'

" The order of items in this list is very important because we use this list to build a regular
" expression (see below) for tokenization
let s:cppOperatorPunctuator = ['->*', '->', '--', '-=', '-', '!=', '!', '##', '#', '%:%:', '%=', '%>', '%:', '%', '&&', '&=', '&', '(', ')', '*=', '*', ',', '...', '.*', '.', '/=', '/', '::', ':>', ':', ';', '?', '[', ']', '^=', '^', '{', '||', '|=', '|', '}', '~', '++', '+=', '+', '<<=', '<%', '<:', '<<', '<=', '<', '==', '=', '>>=', '>>', '>=', '>']

" We build the regexp for the tokenizer
let s:reCComment = '\/\*\|\*\/'
let s:reCppComment = '\/\/'
let s:reComment = s:reCComment.'\|'.s:reCppComment
let s:reCppOperatorOrPunctuator = escape(join(s:cppOperatorPunctuator, '\|'), '*./^~[]')


function! Complete_super()
	return "\<C-X>\<C-O>"
endfunc

" Check if we can use omni completion in the current buffer
function! s:CanUseOmnicompletion()
	" For C and C++ files and only if the omnifunc is omni#cpp#complete#Main
	return (index(['c', 'cpp'], &filetype)>=0 && !Omni_cpp_utils_IsCursorInCommentOrString())
endfunc

" May complete function for dot
function! Omni_cpp_maycomplete_Dot()
	if s:CanUseOmnicompletion() "&& g:OmniCpp_MayCompleteDot
		let g:omni#cpp#items#data = Omni_cpp_items_Get(Omni_cpp_utils_TokenizeCurrentInstruction('.'))
		if len(g:omni#cpp#items#data)
			let s:bMayComplete = 1
			return '.' . Complete_super()
		endif
	endif
	return '.'
endfunc

" May complete function for arrow
function! Omni_cpp_maycomplete_Arrow()
	if s:CanUseOmnicompletion() "&& g:OmniCpp_MayCompleteArrow
		let index = col('.') - 2
		if index >= 0
			let char = getline('.')[index]
			if char == '-'
				let g:omni#cpp#items#data = Omni_cpp_items_Get(Omni_cpp_utils_TokenizeCurrentInstruction('>'))
				if len(g:omni#cpp#items#data)
					let s:bMayComplete = 1
					return '>' . Complete_super()
				endif
			endif
		endif
	endif
	return '>'
endfunc

" May complete function for double points
function! Omni_cpp_maycomplete_Scope()
	if s:CanUseOmnicompletion() "&& g:OmniCpp_MayCompleteScope
		let index = col('.') - 2
		if index >= 0
			let char = getline('.')[index]
			if char == ':'
				let g:omni#cpp#items#data = Omni_cpp_items_Get(Omni_cpp_utils_TokenizeCurrentInstruction(':'))
				if len(g:omni#cpp#items#data)
					if len(g:omni#cpp#items#data[-1].tokens) && g:omni#cpp#items#data[-1].tokens[-1].value != '::'
						let s:bMayComplete = 1
						return ':' . Complete_super()
					endif
				endif
			endif
		endif
	endif
	return ':'
endfunc

" Build the item list of an instruction
" An item is an instruction between a -> or . or ->* or .*
" We can sort an item in different kinds:
" eg: ((MyClass1*)(pObject))->_memberOfClass1.get()     ->show()
"     |        cast        |  |    member   | | method |  | method |
" @return a list of item
" an item is a dictionnary where keys are:
"   tokens = list of token
"   kind = itemVariable|itemCast|itemCppCast|itemTemplate|itemFunction|itemUnknown|itemThis|itemScope
function! Omni_cpp_items_Get(tokens, ...)
	let bGetWordUnderCursor = (a:0>0)? a:1 : 0

	let result = []
	let itemsDelimiters = ['->', '.', '->*', '.*']

	let tokens = reverse(Omni_cpp_utils_BuildParenthesisGroups(a:tokens))

	" fsm states:
	"   0 = initial state
	"   TODO: add description of fsm states
	let state=(bGetWordUnderCursor)? 1 : 0
	let item = {'tokens' : [], 'kind' : 'itemUnknown'}
	let parenGroup=-1
	for token in tokens
		if state==0
			if index(itemsDelimiters, token.value)>=0
				let item = {'tokens' : [], 'kind' : 'itemUnknown'}
				let state = 1
			elseif token.value=='::'
				let state = 9
				let item.kind = 'itemScope'
				" Maybe end of tokens
			elseif token.kind =='cppOperatorPunctuator'
				" If it's a cppOperatorPunctuator and the current token is not
				" a itemsDelimiters or '::' we can exit
				let state=-1
				break
			endif
		elseif state==1
			call insert(item.tokens, token)
			if token.kind=='cppWord'
				" It's an attribute member or a variable
				let item.kind = 'itemVariable'
				let state = 2
				" Maybe end of tokens
			elseif token.value=='this'
				let item.kind = 'itemThis'
				let state = 2
				" Maybe end of tokens
			elseif token.value==')'
				let parenGroup = token.group
				let state = 3
			elseif token.value==']'
				let parenGroup = token.group
				let state = 4
			elseif token.kind == 'cppDigit'
				let state = -1
				break
			endif
		elseif state==2
			if index(itemsDelimiters, token.value)>=0
				call insert(result, item)
				let item = {'tokens' : [], 'kind' : 'itemUnknown'}
				let state = 1
			elseif token.value == '::'
				call insert(item.tokens, token)
				" We have to get namespace or classscope
				let state = 8
				" Maybe end of tokens
			else
				call insert(result, item)
				let state=-1
				break
			endif
		elseif state==3
			call insert(item.tokens, token)
			if token.value=='(' && token.group == parenGroup
				let state = 5
				" Maybe end of tokens
			endif
		elseif state==4
			call insert(item.tokens, token)
			if token.value=='[' && token.group == parenGroup
				let state = 1
			endif
		elseif state==5
			if token.kind=='cppWord'
				" It's a function or method
				let item.kind = 'itemFunction'
				call insert(item.tokens, token)
				let state = 2
				" Maybe end of tokens
			elseif token.value == '>'
				" Maybe a cpp cast or template
				let item.kind = 'itemTemplate'
				call insert(item.tokens, token)
				let parenGroup = token.group
				let state = 6
			else
				" Perhaps it's a C cast eg: ((void*)(pData)) or a variable eg:(*pData)
				let item.kind = Omni_cpp_utils_GetCastType(item.tokens)
				let state=-1
				call insert(result, item)
				break
			endif
		elseif state==6
			call insert(item.tokens, token)
			if token.value == '<' && token.group == parenGroup
				" Maybe a cpp cast or template
				let state = 7
			endif
		elseif state==7
			call insert(item.tokens, token)
			if token.kind=='cppKeyword'
				" It's a cpp cast
				let item.kind = Omni_cpp_utils_GetCastType(item.tokens)
				let state=-1
				call insert(result, item)
				break
			else
				" Template ?
				let state=-1
				call insert(result, item)
				break
			endif
		elseif state==8
			if token.kind=='cppWord'
				call insert(item.tokens, token)
				let state = 2
				" Maybe end of tokens
			else
				let state=-1
				call insert(result, item)
				break
			endif
		elseif state==9
			if token.kind == 'cppWord'
				call insert(item.tokens, token)
				let state = 10
				" Maybe end of tokens
			else
				let state=-1
				call insert(result, item)
				break
			endif
		elseif state==10
			if token.value == '::'
				call insert(item.tokens, token)
				let state = 9
				" Maybe end of tokens
			else
				let state=-1
				call insert(result, item)
				break
			endif
		endif
	endfor

	if index([2, 5, 8, 9, 10], state)>=0
		if state==5
			let item.kind = Omni_cpp_utils_GetCastType(item.tokens)
		endif
		call insert(result, item)
	endif

	return result
endfunc

" Build parenthesis groups
" add a new key 'group' in the token
" where value is the group number of the parenthesis
" eg: (void*)(MyClass*)
"      group1  group0
" if a parenthesis is unresolved the group id is -1      
" @return a copy of a:tokens with parenthesis group
function! Omni_cpp_utils_BuildParenthesisGroups(tokens)
	let tokens = copy(a:tokens)
	let kinds = {'(': '()', ')' : '()', '[' : '[]', ']' : '[]', '<' : '<>', '>' : '<>', '{': '{}', '}': '{}'}
	let unresolved = {'()' : [], '[]': [], '<>' : [], '{}' : []}
	let groupId = 0

	" Note: we build paren group in a backward way
	" because we can often have parenthesis unbalanced
	" instruction
	" eg: doSomething(_member.get()->
	for token in reverse(tokens)
		if index([')', ']', '>', '}'], token.value)>=0
			let token['group'] = groupId
			call extend(unresolved[kinds[token.value]], [token])
			let groupId+=1
		elseif index(['(', '[', '<', '{'], token.value)>=0
			if len(unresolved[kinds[token.value]])
				let tokenResolved = remove(unresolved[kinds[token.value]], -1)
				let token['group'] = tokenResolved.group
			else
				let token['group'] = -1
			endif
		endif
	endfor

	return reverse(tokens)
endfunc

" Determine if tokens represent a C cast
" @return
"   - itemCast
"   - itemCppCast
"   - itemVariable
"   - itemThis
function! Omni_cpp_utils_GetCastType(tokens)
	" Note: a:tokens is not modified
	let tokens = Omni_cpp_utils_SimplifyParenthesis(Omni_cpp_utils_BuildParenthesisGroups(a:tokens))

	if tokens[0].value == '('
		return 'itemCast' 
	elseif index(['static_cast', 'dynamic_cast', 'reinterpret_cast', 'const_cast'], tokens[0].value)>=0
		return 'itemCppCast'
	else
		for token in tokens
			if token.value=='this'
				return 'itemThis'
			endif
		endfor
		return 'itemVariable' 
	endif
endfunc

" Remove useless parenthesis
function! Omni_cpp_utils_SimplifyParenthesis(tokens)
	"Note: a:tokens is not modified
	let tokens = a:tokens
	" We remove useless parenthesis eg: (((MyClass)))
	if len(tokens)>2
		while tokens[0].value=='(' && tokens[-1].value==')' && tokens[0].group==tokens[-1].group
			let tokens = tokens[1:-2]
		endwhile
	endif
	return tokens
endfunc

" Check if the cursor is in comment
function! Omni_cpp_utils_IsCursorInCommentOrString()
	return match(synIDattr(synID(line("."), col(".")-1, 1), "name"),'\C\<cComment\|\<cCppString\|\<cIncluded')>=0
endfunc

" Tokenize the current instruction until the cursor position.
" @return list of tokens
function! Omni_cpp_utils_TokenizeCurrentInstruction(...)
	let szAppendText = ''
	if a:0>0
		let szAppendText = a:1
	endif

	let startPos = searchpos('[;{}]\|\%^', 'bWn')
	let curPos = getpos('.')[1:2]
	" We don't want the character under the cursor
	let column = curPos[1]-1
	let curPos[1] = (column<1)?1:column
	return Omni_cpp_tokenizer_Tokenize(Omni_cpp_utils_GetCode(startPos, curPos)[1:] . szAppendText)
endfunc

" Get a c++ code from current buffer from [lineStart, colStart] to 
" [lineEnd, colEnd] without c++ and c comments, without end of line
" and with empty strings if any
" @return a string
function! Omni_cpp_utils_GetCode(posStart, posEnd)
	let posStart = a:posStart
	let posEnd = a:posEnd
	if a:posStart[0]>a:posEnd[0]
		let posStart = a:posEnd
		let posEnd = a:posStart
	elseif a:posStart[0]==a:posEnd[0] && a:posStart[1]>a:posEnd[1]
		let posStart = a:posEnd
		let posEnd = a:posStart
	endif

	" Getting the lines
	let lines = getline(posStart[0], posEnd[0])
	let lenLines = len(lines)

	" Formatting the result
	let result = ''
	if lenLines==1
		let sStart = posStart[1]-1
		let sEnd = posEnd[1]-1
		let line = lines[0]
		let lenLastLine = strlen(line)
		let sEnd = (sEnd>lenLastLine)?lenLastLine : sEnd
		if sStart >= 0
			let result = Omni_cpp_utils_GetCodeFromLine(line[ sStart : sEnd ])
		endif
	elseif lenLines>1
		let sStart = posStart[1]-1
		let sEnd = posEnd[1]-1
		let lenLastLine = strlen(lines[-1])
		let sEnd = (sEnd>lenLastLine)?lenLastLine : sEnd
		if sStart >= 0
			let lines[0] = lines[0][ sStart : ]
			let lines[-1] = lines[-1][ : sEnd ]
			for aLine in lines
				let result = result . Omni_cpp_utils_GetCodeFromLine(aLine)." "
			endfor
			let result = result[:-2]
		endif
	endif

	" Now we have the entire code in one line and we can remove C comments
	return s:RemoveCComments(result)
endfunc

" Get code without comments and with empty strings
" szSingleLine must not have carriage return
function! Omni_cpp_utils_GetCodeFromLine(szSingleLine)
	" We set all strings to empty strings, it's safer for 
	" the next of the process
	let szResult = substitute(a:szSingleLine, '".*"', '""', 'g')

	" Removing c++ comments, we can use the pattern ".*" because
	" we are modifying a line
	let szResult = substitute(szResult, '\/\/.*', '', 'g')

	" Now we have the entire code in one line and we can remove C comments
	return s:RemoveCComments(szResult)
endfunc

" Remove C comments on a line
function! s:RemoveCComments(szLine)
	let result = a:szLine

	" We have to match the first '/*' and first '*/'
	let startCmt = match(result, '\/\*')
	let endCmt = match(result, '\*\/')
	while startCmt!=-1 && endCmt!=-1 && startCmt<endCmt
		if startCmt>0
			let result = result[ : startCmt-1 ] . result[ endCmt+2 : ]
		else
			" Case where '/*' is at the start of the line
			let result = result[ endCmt+2 : ]
		endif
		let startCmt = match(result, '\/\*')
		let endCmt = match(result, '\*\/')
	endwhile
	return result
endfunc

" Tokenize a c++ code
" a token is dictionary where keys are:
"   -   kind = cppKeyword|cppWord|cppOperatorPunctuator|unknown|cComment|cppComment|cppDigit
"   -   value = 'something'
"   Note: a cppWord is any word that is not a cpp keyword
function! Omni_cpp_tokenizer_Tokenize(szCode)
	let result = []

	" The regexp to find a token, a token is a keyword, word or
	" c++ operator or punctuator. To work properly we have to put 
	" spaces and tabs to our regexp.
	let reTokenSearch = '\(\w\+\)\|\s\+\|'.s:reComment.'\|'.s:reCppOperatorOrPunctuator
	" eg: 'using namespace std;'
	"      ^    ^
	"  start=0 end=5
	let startPos = 0
	let endPos = matchend(a:szCode, reTokenSearch)
	let len = endPos-startPos
	while endPos!=-1
		" eg: 'using namespace std;'
		"      ^    ^
		"  start=0 end=5
		"  token = 'using'
		" We also remove space and tabs
		let token = substitute(strpart(a:szCode, startPos, len), '\s', '', 'g')

		" eg: 'using namespace std;'
		"           ^         ^
		"       start=5     end=15
		let startPos = endPos
		let endPos = matchend(a:szCode, reTokenSearch, startPos)
		let len = endPos-startPos

		" It the token is empty we continue
		if token==''
			continue
		endif

		" Building the token
		let resultToken = {'kind' : 'unknown', 'value' : token}

		" Classify the token
		if token =~ '^\d\+'
			" It's a digit
			let resultToken.kind = 'cppDigit'
		elseif token=~'^\w\+$'
			" It's a word
			let resultToken.kind = 'cppWord'

			" But maybe it's a c++ keyword
			if match(token, s:reCppKeyword)>=0
				let resultToken.kind = 'cppKeyword'
			endif
		else
			if match(token, s:reComment)>=0
				if index(['/*','*/'],token)>=0
					let resultToken.kind = 'cComment'
				else
					let resultToken.kind = 'cppComment'
				endif
			else
				" It's an operator
				let resultToken.kind = 'cppOperatorPunctuator'
			endif
		endif
		" We have our token, let's add it to the result list
		call extend(result, [resultToken])
	endwhile
	return result
endfunc

au FileType c,cpp inoremap <expr> . Omni_cpp_maycomplete_Dot()
au FileType c,cpp inoremap <expr> > Omni_cpp_maycomplete_Arrow()
au FileType c,cpp inoremap <expr> : Omni_cpp_maycomplete_Scope()

