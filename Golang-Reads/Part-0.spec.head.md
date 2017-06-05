**万物之始，大道至简，衍化至繁**

一直特别欣赏Golang的简洁，简洁之美由里而外，亦发现这种纷繁之后的简更是贯穿在Rob pike的整个职业生涯中：Unix, Inferno, Regex,  UTF8，Golang。

拿Golang的Spec和[C++那个卖133刀的Spec](http://www.open-std.org/jtc1/sc22/wg21/docs/papers/2014/n4296.pdf)坐下对比，就可以深刻理解Golang为什么是下一代系统级语言。

Golang-Reading: 笔记
===
一遍读源码一遍记录，想了解Golang, 必须从历史的源码中去找他的实现。先回到用C实现的版本，再回到自举的版本。
所以这里的计划大概如此.

在深入细节之前，对Golang语言来一个整体的认知：
先读一遍他的那一坨[spec](https://golang.org/ref/spec#Introduction)

## Introduction
这是一个Golang的语言规格手册, 更详细的内容可以在[golang.org](https://golang.org/)查询。
Go是设计用来可以做系统级开发的通用语言。他是强类型，具备垃圾回收并且在语言级别对并发编程提供支持的开发语言。在Go的世界里面，应用程序由packages组成，并且通过package来进行依赖管理，并且通过传统的编译/链接模式生成最终的可执行二进制。

Go的语法遵从紧凑和不怪异的原则，让工具可以很容易对Golang进行语法分析。

## Notation
用[扩展巴科斯范式](https://en.wikipedia.org/wiki/Extended_Backus%E2%80%93Naur_form "EBNF")的形式来对语法部分进行阐述。

## Source code representation
源码是采用[UTF-8](http://en.wikipedia.org/wiki/UTF-8)编码的Unicode文本。文本没有经过规范化，所以带重音的符号和不带重音的符号是不一样的, 解析的时候也就会对应到两个code-point。在本文中，用简单的方法来处理这类问题，用unqualified term character 来对应一个Unicode code point。

实现层面的限制：为了兼容其他工具，编译器禁止NUL字符(U+0000)出现在源代码中。

实现层面的限制：为了兼容其他工具，编译器会忽略以(U+FEFF)开头的UTF-8编码字符。

### Characters
用如下的规则来对Unicode字符进行分类：
    newline        = /* the Unicode code >point U+000A */ .
    unicode_char   = /* an arbitrary Unicode code point except newline */ .
    unicode_letter = /* a Unicode code point classified as "Letter" */ .
    unicode_digit  = /* a Unicode code point classified as "Number, decimal digit" */ .  
在[The Unicode Standard 8.0](http://www.unicode.org/versions/Unicode8.0.0/), 第4.5小节<通用分类>里面定义了一组字符类别。Go把其中Lu,Ll, Lt,Lm 和Lo这些类别的字符为Go中的普通的字符, Nd类别为数字。

### Letters and digits
下划线_(U+005F)被视为字母.
    letter        = unicode_letter | "_" .
    decimal_digit = "0" … "9" .
    octal_digit   = "0" … "7" .
    hex_digit     = "0" … "9" | "A" … "F" | "a" … "f" .

## Lexical elements
### Comments
注释就是程序的文档，支持两种形式的注释：
1. 行注释 以// 开头，到行的结尾
2. 多行注释，以字符/*开头，到第一个*/结尾

### Tokens
Tokens是Go语言的基本组成词汇，其中有四种类型的token：标识符，关键字, 操作符-分隔符，以及字符常量。除了合理分割tokens的空白符会被保留外，其他源代码中的以下空白字符会被忽略：空格(U+0020),水平制表符(U+0009), 回车(U+000D) 和换行(U+000A)。同时换行或者到达文件结尾会在代码流插入一个[分号](#jump_lexical_elements_semicolons)。

### Semicolons <span id="jump_lexical_elements_semicolons"/>
用分号作为production的分隔符。当然Go的开发者可以根据如下的规则省略掉分隔符的输入：
    1. 如下行结束符出现的时候回自动插入一个分号
    2. 复杂语句独占一行在 ')' 和 '}'后可以省略分号
### Identifiers
第一个字符必须是字母letter包括下划线
    identifier = letter { letter | unicode_digit } .

### Keywords 关键字
    break        default      func      interface    select
    case         defer        go        map          struct
    chan         else         goto      package      switch
    const        fallthrough  if        range        type
    continue     for          import    return       var

### Operators and Delimiters
>    `+    &     +=    &=     &&      ==      !=      (    )
>    `-    |     -=    |=     ||      <       <=      [    ]
>    `*    ^     *=    ^=     <-      >       >=      {    }
>    `/    <<    /=    <<=    ++      =       :=      ,    ;
>    `%    >>    %=    >>=    --      !       ...     .    :
>    `     &^          &^=

### Integer literals
0开头8进制，0x或者0X开头十六进制

### Floating-point literals
	float_lit = decimals "." [ decimals ] [ exponent ] |
				decimals exponent |
				"." decimals [ exponent ] .
	decimals  = decimal_digit { decimal_digit } .
	exponent  = ( "e" | "E" ) [ "+" | "-" ] decimals .

### Imaginary literals
	imaginary_lit = (decimals | float_lit) "i" .

### Rune literals
	rune_lit         = "'" ( unicode_value | byte_value ) "'" .
	unicode_value    = unicode_char | little_u_value | big_u_value | escaped_char .
	byte_value       = octal_byte_value | hex_byte_value .
	octal_byte_value = `\` octal_digit octal_digit octal_digit .
	hex_byte_value   = `\` "x" hex_digit hex_digit .
	little_u_value   = `\` "u" hex_digit hex_digit hex_digit hex_digit .
	big_u_value      = `\` "U" hex_digit hex_digit hex_digit hex_digit
							   hex_digit hex_digit hex_digit hex_digit .
	escaped_char     = `\` ( "a" | "b" | "f" | "n" | "r" | "t" | "v" | `\` | "'" | `"` ) .

### String literals
	string_lit             = raw_string_lit | interpreted_string_lit .
	raw_string_lit         = "`" { unicode_char | newline } "`" .
	interpreted_string_lit = `"` { unicode_value | byte_value } `"` .

下面的例子全部都是同一个字符串
	"日本語"                                 // UTF-8 input text
	`日本語`                                 // UTF-8 input text as a raw literal
	"\u65e5\u672c\u8a9e"                    // the explicit Unicode code points
	"\U000065e5\U0000672c\U00008a9e"        // the explicit Unicode code points
	"\xe6\x97\xa5\xe6\x9c\xac\xe8\xaa\x9e"  // the explicit UTF-8 bytes


## Constants
## Variables
## Types
	Type      = TypeName | TypeLit | "(" Type ")" .
	TypeName  = identifier | QualifiedIdent .
	TypeLit   = ArrayType | StructType | PointerType | FunctionType | InterfaceType |
			SliceType | MapType | ChannelType .

### Method sets
一个类型除了成员变量以外还会有一组方法与之关联。对于interface类型的方法集合就代表的是类型本身。 每个类型都有一个underlying-type与之对应，对于是前置类型，他的underlying-type就是本身。

类型`T`的方法集合是所有申明接受类型为T的函数, 相应的指针`*T`的方法集合是多余申明接受类型为`T`和`*T`的所有函数(没看错，这个集合包括了接受类型为`T`的函数)。

### Boolean types
### Numeric types
	uint8       the set of all unsigned  8-bit integers (0 to 255)
	uint16      the set of all unsigned 16-bit integers (0 to 65535)
	uint32      the set of all unsigned 32-bit integers (0 to 4294967295)
	uint64      the set of all unsigned 64-bit integers (0 to 18446744073709551615)

	int8        the set of all signed  8-bit integers (-128 to 127)
	int16       the set of all signed 16-bit integers (-32768 to 32767)
	int32       the set of all signed 32-bit integers (-2147483648 to 2147483647)
	int64       the set of all signed 64-bit integers (-9223372036854775808 to 9223372036854775807)

	float32     the set of all IEEE-754 32-bit floating-point numbers
	float64     the set of all IEEE-754 64-bit floating-point numbers

	complex64   the set of all complex numbers with float32 real and imaginary parts
	complex128  the set of all complex numbers with float64 real and imaginary parts

	byte        alias for uint8
	rune        alias for int32

还有一组依赖具体实现具备如下规约的数字类型
	uint     either 32 or 64 bits
	int      same size as uint
	uintptr  an unsigned integer large enough to store the uninterpreted bits of a pointer value

### String types
String 是immutable, 一旦创建，就不可修改其内容。len()函数返回的是字符串占用的字节数，可以通过取地址符号`&`获取字符串中任意一位字符的地址。

### Array types
	ArrayType   = "[" ArrayLength "]" ElementType .
	ArrayLength = Expression .
	ElementType = Type .

数组索引从0到len(array)-1。

### Slice types
切片描述的是与之关联的数组的一个连续片段。未初始化的slice值为nil。
	SliceType = "[" "]" ElementType .
slice 始终与底下的array关联，slice和array一样通过下标索引，但slice有一个cap，这个cap与array有关联。用过make(T[], length, capacity)创建新的slice的时候会在背后创建一个array。如下的两个表达式等价：
	make([]int, 50, 100)
	new([100]int)[0:50]

### Struct types
	StructType     = "struct" "{" { FieldDecl ";" } "}" .
	FieldDecl      = (IdentifierList Type | AnonymousField) [ Tag ] .
	AnonymousField = [ "*" ] TypeName .
	Tag            = string_lit .
允许有匿名的成员出现。匿名成员会携带promoted成员和方法，提升的合法成员和方法与普通成员是一致的。
给定一个struct-type S 和一个匿名的成员类型T，promoted的成员方法以如下形式出现：
* 如果S包含一个匿名的T成员，则类型`S`和`*S`的方法集合会包含所有接受类型为T的方法。类型`*S`的方法结合还会包含接受类型为`*T`的所有方法
* 如果S包含一个匿名的`*T`成员, 则类型`S`和`*S`都会同时携带上`T`和`*T`的方法集合
(方法集合类似成员函数, 只是一个类型的成员函数会根据指针类型和非指针类型分为两类，同时在Golang里面指针类型会继承非指针类型的成员函数集合)

### Pointer types
未初始化的pointer是nil

### Function types
一个函数类型是拥有同样参数和返回值类型的函数, 未初始化的函数类型是nil
	FunctionType   = "func" Signature .
	Signature      = Parameters [ Result ] .
	Result         = Parameters | Type .
	Parameters     = "(" [ ParameterList [ "," ] ] ")" .
	ParameterList  = ParameterDecl { "," ParameterDecl } .
	ParameterDecl  = [ IdentifierList ] [ "..." ] Type .

### Interface types
一个Interface-type 主要制定一组方法的合集，一个Interface的实例变量会存储任意类型的实例和一个当前Interface-type的方法合集的超集。
	InterfaceType      = "interface" "{" { MethodSpec ";" } "}" .
	MethodSpec         = MethodName Signature | InterfaceTypeName .
	MethodName         = identifier .
	InterfaceTypeName  = TypeName .
interface可以把另外一个interface当普通方法定义一样放入自己的定义体里面，这样就可以把这个interface的所有导出和不导出方法加入到当前的interface。

### Channel types
channel 提供一种并发通信机制，通过发送和接受特定类型的值进行通信的通道，未初始化的channel为nil。
	ChannelType = ( "chan" | "chan" "<-" | "<-" "chan" ) ElementType .
操作符<-指定了channel的数据的流动方向：发送还是接受，如果没有指定方向就是双向的channel。
	chan T          // can be used to send and receive values of type T
	chan<- float64  // can only be used to send float64s
	<-chan int      // can only be used to receive ints
channel 创建的时候可以指定capacity, 这样channel的工作就会以一种buffed的方式运转。如果没有指定capacity或者指定为0，则channel的通信成功只有sender和receiver都准备好的情况下才是。

## Properties of types and values
不同包名下的私有类型和函数都是不等的。

### Assignability
一个值x可以赋值到一个类型为`T`的变量("x可以赋值到T")必须符合如下的几种情况之一：
* x的类型就是`T`
* x的类型是`V`，但是`V`和`T`是同样的underlying-types，并且`V`和`T`至少有一个不是named-type。
* `T`是一个interface类型，并且x实现了`T`
* x 是一个双向的channel， T 是 channel-type, 并且x的类型V和T有一样的element-type，并且V和T至少有一个不是named-type
* x 是nil并且T是指针类型，函数类型, slice, map, channel 或者 interface 类型之一、
* x 是一个隐含的T类型的未定义类型的常量

## Blocks
	Block = "{" StatementList "}" .
	StatementList = { Statement ";" } .
隐含的Blocks
* 全局的block 包含所有的源代码
* 每一个package 有一个block，包含package下面的所有代码
* 每一个文件有一个block，包含file下面的所有source-text
* 每一个`if`,`for` 和 `switch`语句有一个隐含的block
* 每一个`switch`和`select`里面的分支的条件执行体都有一个block

## Declarations and scope
### Label scopes
label 定义后可以不适用，相对于其他identifiers, label不是针对block的，是在函数作用域内有效
### Blank identifier
### Predeclared identifiers
如下的标识符是全局scope的
	Types:
		bool byte complex64 complex128 error float32 float64
		int int8 int16 int32 int64 rune string
		uint uint8 uint16 uint32 uint64 uintptr

	Constants:
		true false iota

	Zero value:
		nil

	Functions:
		append cap close complex copy delete imag len
		make new panic print println real recover

### Exported identifiers
导出的标识符具备如下两个条件：
* 标识符的第一个字符是大写的
* 标识符定义在package-block, 或者他是一个成员名或者方法名
所有其他的标识符都是不导出的

### Uniqueness of identifiers

### Constant declarations
	ConstDecl      = "const" ( ConstSpec | "(" { ConstSpec ";" } ")" ) .
	ConstSpec      = IdentifierList [ [ Type ] "=" ExpressionList ] .

	IdentifierList = identifier { "," identifier } .
	ExpressionList = Expression { "," Expression } .
如果指定了类型，那么常量就是当前指定的类型，并且右边必须是可以assignable的。如果类型省略了，那么常量就会用赋值表达式的类型。如果表达式的值是一个untyped-constants，那么声明的常量依然是untyped。
	const Pi float64 = 3.14159265358979323846
	const zero = 0.0         // untyped floating-point constant
	const (
		size int64 = 1024
		eof        = -1  // untyped integer constant
	)
	const a, b, c = 3, 4, "foo"  // a = 3, b = 4, c = "foo", untyped integer and string constants
	const u, v float32 = 0, 3    // u = 0.0, v = 3.0

### Iota
iota代码的是一个连续的untyped-integer常量，只要遇到const关键字出现就会reset到0，这个可以用来构造一系列有关联的常量。
	const ( // iota is reset to 0
		c0 = iota  // c0 == 0
		c1 = iota  // c1 == 1
		c2 = iota  // c2 == 2
	)

	const ( // iota is reset to 0
		a = 1 << iota  // a == 1
		b = 1 << iota  // b == 2
		c = 3          // c == 3  (iota is not used but still incremented)
		d = 1 << iota  // d == 8
	)

	const ( // iota is reset to 0
		u         = iota * 42  // u == 0     (untyped integer constant)
		v float64 = iota * 42  // v == 42.0  (float64 constant)
		w         = iota * 42  // w == 84    (untyped integer constant)
	)

	const x = iota  // x == 0  (iota has been reset)
	const y = iota  // y == 0  (iota has been reset)

在同一个表达式里面itoa的值是一样的，因为只有到下一个ConstSpec后才会进行自增：
const (
    bit0, mask0 = 1 << iota, 1<<iota - 1  // bit0 == 1, mask0 == 0
    bit1, mask1                           // bit1 == 2, mask1 == 1
    _, _                                  // skips iota == 2
    bit3, mask3                           // bit3 == 8, mask3 == 7
)

## Type declarations
类型声明会把一个标识符保定类型名字上，让标识符成为一个新的类型，两个类型都会有一个相同的underlying-type, 对现有的类型操作也会适用于新定义的类型。但声明的新类型和原来的类型是不同的类型。
	TypeDecl     = "type" ( TypeSpec | "(" { TypeSpec ";" } ")" ) .
	TypeSpec     = identifier Type .

	type IntArray [16]int

	type (
		Point struct{ x, y float64 }
		Polar Point
	)

	type TreeNode struct {
		left, right *TreeNode
		value *Comparable
	}

	type Block interface {
		BlockSize() int
		Encrypt(src, dst []byte)
		Decrypt(src, dst []byte)
	}
	// A Mutex is a data type with two methods, Lock and Unlock.
	type Mutex struct         { /* Mutex fields */ }
	func (m *Mutex) Lock()    { /* Lock implementation */ }
	func (m *Mutex) Unlock()  { /* Unlock implementation */ }

	// NewMutex has the same composition as Mutex but its method set is empty.
	type NewMutex Mutex

	// The method set of the base type of PtrMutex remains unchanged,
	// but the method set of PtrMutex is empty.
	type PtrMutex *Mutex

	// The method set of *PrintableMutex contains the methods
	// Lock and Unlock bound to its anonymous field Mutex.
	type PrintableMutex struct {
		Mutex
	}

	// MyBlock is an interface type that has the same method set as Block.
	type MyBlock Block


### Variable declarations
变量声明
	VarDecl = "var" ( VarSpec | "(" { VarSpec ";" } ")" ) .
	VarSpec     = IdentifierList ( Type [ "=" ExpressionList ] | "=" ExpressionList ) .
实现层面的限制：
在函数体内部声明的变量，如果没有被用到，编译器会单做一个编译错误抛出

### Short variable declarations
	ShortVarDecl = IdentifierList ":=" ExpressionList .
在自动推导的变量声明语句里面，可以对以前已经声明过的变量以相同的类型再重新声明一次，但必须是多变量的声明式里面，并且多声明变量里面至少有一个是真正没有声明过的新变量，这个时候的变量重新声明和赋值等价。如下所示：
	field1, offset := nextField(str, 0)
	field2, offset := nextField(str, offset)  // redeclares offset
	a, a := 1, 2                              // illegal: double declaration of a or no new variable if a was declared elsewhere

### Function declarations
	FunctionDecl = "func" FunctionName ( Function | Signature ) .
	FunctionName = identifier .
	Function     = Signature FunctionBody .
	FunctionBody = Block .
如果函数的声明里面声明了函数的返回值，那么函数的实现体必须以返回语句结束
函数声明可以缺失实现，这种声明的函数，他的实现体可以在其他地方，比如汇编里面。

### Method declarations
方法是一类具备接受者的函数。 方法声明会把一个标识符作为方法名字，并且把方法关联到接受者的基础类型上。
在方法实现里面，如果没有引用到receiver, 那么这个receiver的标识符可以省略


## Expressions
### Operands
	Operand     = Literal | OperandName | MethodExpr | "(" Expression ")" .
	Literal     = BasicLit | CompositeLit | FunctionLit .
	BasicLit    = int_lit | float_lit | imaginary_lit | rune_lit | string_lit .
	OperandName = identifier | QualifiedIdent.

### Qualified identifiers
	QualifiedIdent = PackageName "." identifier .
一个QunalifiedIdenent 是用包名定位的具体标识符, 要访问这个标识符必须先导入相关的包。

### Composite literals
对结构体，数组，切片，字典等的字面初始化, 每次执行的时候都会创建一个新的相应实例，每一个相应的元素都可以用一个Key做前缀说明：
	CompositeLit  = LiteralType LiteralValue .
	LiteralType   = StructType | ArrayType | "[" "..." "]" ElementType |
					SliceType | MapType | TypeName .
	LiteralValue  = "{" [ ElementList [ "," ] ] "}" .
	ElementList   = KeyedElement { "," KeyedElement } .
	KeyedElement  = [ Key ":" ] Element .
	Key           = FieldName | Expression | LiteralValue .
	FieldName     = identifier .
	Element       = Expression | LiteralValue .
对于结构体的初始化遵循如下的原则：
* key必须是结构体的成员名
* 如果不用key去指定初始化的成员，那么变量的顺序必须与结构体成员的声明顺序一致
* 如果其中一个元素用key指定了，那么初始化列表里面的其他元素就都需要指定key
* 用成员名来初始化结构体的时候，不需要再初始化列表里面对所有成员都进行显式的初始化，那些没有特殊需求的可以让他用默认的零值进行初始化
* 在其他package里面，不能再初始化列表里面通过成员名来初始化那些没有导出的成员

对于数组，切片等遵从如下的规则：
* 每一个元素都需要用一个索引来指定相应的位置
* 索引的key必须是一个常量表达式
* 当前元素的默认index，是前面一个元素指定的index+1，如果是第一个元素则index等于0

对于指定了长度的数组类型，如果初始化列表里面的元素个数少于指定的长度，那么余下的元素会用相应类型的零值来初始化。
	buffer := [10]string{}             // len(buffer) == 10
	intSet := [6]int{1, 2, 3, 5}       // len(intSet) == 6
	days := [...]string{"Sat", "Sun"}  // len(days) == 2
对于数组，切片，字典等复杂类型的初始化里面，如果元素类型或者map的key本身也是一个复杂类型，那么在字面初始化里面，我们可以省略这个元素类型。对于复杂类型的指针也是一样的，我们可以省略这个取地址的操作。
	[...]Point{{1.5, -3.5}, {0, 0}}     // same as [...]Point{Point{1.5, -3.5}, Point{0, 0}}
	[][]int{{1, 2, 3}, {4, 5}}          // same as [][]int{[]int{1, 2, 3}, []int{4, 5}}
	[][]Point{{{0, 1}, {1, 2}}}         // same as [][]Point{[]Point{Point{0, 1}, Point{1, 2}}}
	map[string]Point{"orig": {0, 0}}    // same as map[string]Point{"orig": Point{0, 0}}

	[...]*Point{{1.5, -3.5}, {0, 0}}    // same as [...]*Point{&Point{1.5, -3.5}, &Point{0, 0}}

	map[Point]string{{0, 0}: "orig"}    // same as map[Point]string{Point{0, 0}: "orig"}

### Function literals
字面函数也就是匿名函数：
	FunctionLit = "func" Function .
字面函数本质上是一个闭包, 闭包里面会引用上下文里面相关的变量，也就是这些变量会在闭包函数和上下文函数里面进行共享。

### Primary expressions
	PrimaryExpr =
		Operand |
		Conversion |
		PrimaryExpr Selector |
		PrimaryExpr Index |
		PrimaryExpr Slice |
		PrimaryExpr TypeAssertion |
		PrimaryExpr Arguments .

	Selector       = "." identifier .
	Index          = "[" Expression "]" .
	Slice          = "[" [ Expression ] ":" [ Expression ] "]" |
					 "[" [ Expression ] ":" Expression ":" Expression "]" .
	TypeAssertion  = "." "(" Type ")" .
	Arguments      = "(" [ ( ExpressionList | Type [ "," ExpressionList ] ) [ "..." ] [ "," ] ] ")" .
这里提到的主要表达式是关于一元表达式和二元表达式的复合操作

### Selectors
选择表达式的主要表现为 `x.f` ， 其中x不是包名，标示的是成员和函数f。
选择表达式遵从如下的规则：
* 对于类型`T`或者`*T`的变量`x`, 其中 `x.f`标示的集成体系下的某一个成员变量或者成员方法(这里的集成体系是指匿名类型成员或者匿名interface带入的相关成员)。
* 对于I类型的变量x，如果I是一个interface-type, `x.f`标示的是具体的关于`I.f`方法的实现
* 如果x是一个具名的指针类型，而且 `(*x).f`是一个有效的选择表达式，那么 `x.f`其实是`(*x).f`的简写
* 其他任何的`x.f`都是非法的
* 如果`x`是指针类型，并且值为nil，那么`x.f`的求值会导致run-time-panic
* 如果`x`是一个interface-type,并且值为nil, 那么`x.f`的求值也会导致run-time-panic

### Method expressions
	MethodExpr    = ReceiverType "." MethodName .
	ReceiverType  = TypeName | "(" "*" TypeName ")" | "(" ReceiverType ")" .
如果M是类型T的method-set, 那么T.M是一个可以被像常规函数一样调用的函数，只是这个函数接受的第一个参数是类型T的receiver。
	t.Mv(7)
	T.Mv(t, 7)
	(T).Mv(t, 7)
	f1 := T.Mv; f1(t, 7)
	f2 := (T).Mv; f2(t, 7)

### Method values
如果`x`是类型T的实例，其中M是T的method-set。那么x.M是一个可以被调用的函数，接受M需要的普通参数，这个函数其实已经保存了x的引用，在调用这个函数的时候回自动把x这个receiver放到执行参数里面。
	f := t.Mv; f(7)   // like t.Mv(7)
	f := pt.Mp; f(7)  // like pt.Mp(7)
	f := pt.Mv; f(7)  // like (*pt).Mv(7)
	f := t.Mp; f(7)   // like (&t).Mp(7)
	f := makeT().Mp   // invalid: result of makeT() is not addressable


### Index expressions
数组，数组的指针，切片，字典可以被索引。索引表达式的形式如下：
	a[x]

如果a不是字典：
* index:x 必须是整数类型或者untyped，并且落在区间[0, len(a)]
* 常量index: x 必须是一个非负的整数
对于数组类型A:
* index 必须在 range范围内部
* 如果超出range, 会抛出run-time-panic
* a[x] 是索引位置x的元素
对于指向数组的指针
* a[x] 是 `(*a)[x]`的简写
对于切片类型S:
* 如果x超出range, 会抛run-time panic
* a[x] 是切片位于索引x的元素
对于字符串类型
* a[x] 是索引x位置的byte
对于字典类型M:
* x 必须是可以assignable到字典的key类型的
* 如果字典与key:x 对应的value, 那么a[x] 就是想要的键值
* 如果a是nil或者不包含相应的x对于的键值，那么a[x]是想要键值类型的零值

### Slice expressions
#### Simple slice expressions
	a[low : high]

	a := [5]int{1, 2, 3, 4, 5}
	s := a[1:4]

上述的切片s类型为 []int, 长度是3, 容量是4, 切片的元素如下：
	s[0] == 2
	s[1] == 3
	s[2] == 4
对于切片操作，默认的low是0，默认的high是当前切片的长度
如果a是指向数组的指针，那么`a[low:high]`是`(*a)[low:high]`的简写

#### Full slice expressions
	a[low : high : max]
这样产生的slice的length=high-low, capacity=max-low, 对于Full-slice-expressions, 只有第一个low参数可以缺省为0.

### Type assertions
对于interface-type的变量x，以及类型T, 可以有如下的表达式：
	x.(T)
上面的表达式叫做类型断言表达式。断言x不是nil，同时x里面存储的是类型T的实例。
更精确一些说是，如果T不是interface-type, 那么 x.(T) 断言的是x的确定类型句是T。如果T是一个interface-type, 那么断言表达式断言的是x实现了interface-T定义的那些方法。

#### Calls
	f(a1, a2, … an)
函数里面的参数按照usal-order求值，求值以后按照passed-by-value的方式传递到函数里面，函数的返回参数也是通过passed-by-value的方式返回,调用nil的函数会导致run-time-panic

#### Passing arguments to ... parameters
如果f是variadic的最后一个参数，用...T来表示，那么f等价于传递 []T, 如果没有任何参数，那么f==nil, 如果有参数则创建一个数组，并对其进行切片处理。也可以以value...的方式明确的传递一个slice给到最后一个参数, 这样就不用再额外的创建。
	s := []string{"James", "Jasmine"}
	Greeting("goodbye:", s...)

#### Operators
	Expression = UnaryExpr | Expression binary_op Expression .
	UnaryExpr  = PrimaryExpr | unary_op UnaryExpr .

	binary_op  = "||" | "&&" | rel_op | add_op | mul_op .
	rel_op     = "==" | "!=" | "<" | "<=" | ">" | ">=" .
	add_op     = "+" | "-" | "|" | "^" .
	mul_op     = "*" | "/" | "%" | "<<" | ">>" | "&" | "&^" .

	unary_op   = "+" | "-" | "!" | "^" | "*" | "&" | "<-" .

对于二元操作符，两步的操作类型必须一致，除非这个操作涉及到shifts或者untyped-constants. 关于常量表达式，可以参照这个[const-expressions小节](#jump__todos___)
对于shift操作，如果其中一个参数是untyped-constant,那么这个参数会被转到另外一个参数的类型。在shift操作表达式里面右操作数必须是一个unsigned-integer-type或者可以转到unsigned-integer-type的untyped-constant, 如果左操作数是一个untyped-constant,那么它会被首先进行隐藏的上下文推导转换。

>    `var s uint = 33`
>    `var i = 1<<s           // 1 has type int`
>    `var j int32 = 1<<s     // 1 has type int32; j == 0`
>    `var k = uint64(1<<s)   // 1 has type uint64; k == 1<<33`
>    `var m int = 1.0<<s     // 1.0 has type int; m == 0 if ints are 32bits in size`
>    `var n = 1.0<<s == j    // 1.0 has type int32; n == true`
>    `var o = 1<<s == 2<<s   // 1 and 2 have type int; o == true if ints are 32bits in size`
>    `var p = 1<<s == 1<<33  // illegal if ints are 32bits in size: 1 has type int, but 1<<33 overflows int`
>    `var u = 1.0<<s         // illegal: 1.0 has type float64, cannot shift`
>    `var u1 = 1.0<<s != 0   // illegal: 1.0 has type float64, cannot shift`
>    `var u2 = 1<<s != 1.0   // illegal: 1 has type float64, cannot shift`
>    `var v float32 = 1<<s   // illegal: 1 has type float32, cannot shift`
>    `var w int64 = 1.0<<33  // 1.0<<33 is a constant shift expression`


#### Operator precedence
一元操作符有最高的优先级，但是`++`和`--`他们是statements,不是expressions,他们不属于操作符优先级里面，因此`*p++`和`(*p)++`等价
对于二元操作符有5个层级的优先级划分，如下所示：
	Precedence    Operator
		5             *  /  %  <<  >>  &  &^
		4             +  -  |  ^
		3             ==  !=  <  <=  >  >=
		2             &&
		1             ||
对于同一个优先级的二元操作符，他们的结合顺序是从左至右。

#### Arithmetic operators
	+    sum                    integers, floats, complex values, strings
	-    difference             integers, floats, complex values
	*    product                integers, floats, complex values
	/    quotient               integers, floats, complex values
	%    remainder              integers

	&    bitwise AND            integers
	|    bitwise OR             integers
	^    bitwise XOR            integers
	&^   bit clear (AND NOT)    integers

	<<   left shift             integer << unsigned integer
	>>   right shift            integer >> unsigned integer

#### Integer operators
x/y 从0的方向进行截断["truncated division"](#jump__todos__)
	x     y     x / y     x % y
	 5     3       1         2
	-5     3      -1        -2
	 5    -3      -1         2
	-5    -3       1        -2

#### Integer overflow
整数溢出问题，区分符号整数和无符号整数

#### Floating-point operators
浮点数或者虚数被0除的时候，其结果在IEEE-754中是未定义的，是否会有run-time-panic也是依赖具体的浮点实现。

#### String concatenation
可以用`+`或者`+=`进行连接操作
	s := "hi" + string(c)
	s += " and good bye"

### Comparison operators
比较操作符操作两个操作数，并产生一个untyped-boolean值
	==    equal
	!=    not equal
	<     less
	<=    less or equal
	>     greater
	>=    greater or equal
所有比较操作，都基于一个前提条件，第一个操作数必须assignable到第二个操作数的类型, 反之亦然。
满足操作符`==`和`!=`的操作数叫做comparable, 满足`<,<=,>,>=`的操作数叫做ordered，比较操作符遵循如下的条件：
* Boolean 值是 comparable的。
* Integer 值是 comparable和ordered。
* Floating-point 遵循 IEEE-754标准也是 comparable和ordered。
* 复数也是 comparable的。两个复数相等的条件是他们的实数和虚数都相等
* String values 是 comparable 和 ordered的，准信字典比较
* Pointer 值是 comparable, 两个指针相等如果他们指向同一个变量或者他们都是nil
* Channel是 comparable的。如果两个channel是同一个make语句生成的或者都是nil,那么两个channel是相等的
* interface 值是 comparable的。两个interface值相等是他们有一样的动态类型和一样的动态值, 或者都是nil. （一个interface实例会存储他的宿主和方法合集）
* 一个non-interface类型X的实例x和interface类型T的实例t两者是comparable。当X本身是comparable，并且X实现了inteface-T的接口。两种相等的条件是t的宿主是x，并且t的动态类型是X
* Struct-values 如果他的每一个成员是comparable, 那么他是comparable, 两个struct values 相等的前提条件是所以non-blank都相等
* 对于Array-values是comparalbe, 如果他的元素类型是comparable的，每一个元素都相等的情况下数组相等
两个拥有一样类型的inteface， 如果他们的值本身是不可比较的，那么比较的时候会导致run-time-panic.
slice, map 和 函数变量是不可比较的，但一个列外是他们都可以跟nil比较。
	const c = 3 < 4            // c is the untyped boolean constant true

	type MyBool bool
	var x, y int
	var (
		// The result of a comparison is an untyped boolean.
		// The usual assignment rules apply.
		b3        = x == y // b3 has type bool
		b4 bool   = x == y // b4 has type bool
		b5 MyBool = x == y // b5 has type MyBool
	)

#### Logical operators
	&&    conditional AND    p && q  is  "if p then q else false"
	||    conditional OR     p || q  is  "if p then true else q"
	!     NOT                !p      is  "not p"

#### Address operators
	&x
	&a[f(2)]
	&Point{2, 3}
	*p
	*pf(x)

	var x *int = nil
	*x   // causes a run-time panic
	&*x  // causes a run-time panic

#### Receive operator
从一个nil的channel里面接受对象会导致blocks-forever。从一个已经关闭的channel里面接受对象会立刻返回，并得到一个相应元素类型的零值或者是前面遗留在channel里面的值。
	x, ok = <-ch
	x, ok := <-ch
	var x, ok = <-ch
后面的untyped-boolean值ok，这个值会表明当前的delivered是否是成功来之send, false 代表的是从一个已经close或者empty的channel里面得到的零值。

#### Conversions
	Conversion = Type "(" Expression [ "," ] ")" .
在类型转换表达式里面，如果类型操作数以符号`*`或者`<-`开始，或者是以关键字func开头并且这个func没有返回值，这两个情况下必须采取一些必要的措施，添加必要的括号来避免ambiguity。
	*Point(p)        // same as *(Point(p))
	(*Point)(p)      // p is converted to *Point
	<-chan int(c)    // same as <-(chan int(c))
	(<-chan int)(c)  // c is converted to <-chan int
	func()(x)        // function signature func() x
	(func())(x)      // x is converted to func()
	(func() int)(x)  // x is converted to func() int
	func() int(x)    // x is converted to func() int (unambiguous)


一个constant变量x可以转到类型T，只要满足如下的条件之一:
* x 本身就是类型T的实例
* x 是一个floating-point 常量， T是浮点类型，这里采用的是IEEE-754的round-to-even规则，T(x)代表的就是rounded-value
* x 是整形常量，T是string-type，对于非常量的整数也是适应这条规则的，这里的整数代码的是unicode-code-point。
	uint(iota)               // iota value of type uint
	float32(2.718281828)     // 2.718281828 of type float32
	complex128(1)            // 1.0 + 0.0i of type complex128
	float32(0.49999999)      // 0.5 of type float32
	float64(-1e-1000)        // 0.0 of type float64
	string('x')              // "x" of type string
	string(0x266c)           // "♬" of type string
	MyString("foo" + "bar")  // "foobar" of type MyString
	string([]byte{'a'})      // not a constant: []byte{'a'} is not a constant
	(*int)(nil)              // not a constant: nil is not a constant, *int is not a boolean, numeric, or string type
	int(1.2)                 // illegal: 1.2 cannot be represented as an int
	string(65.0)             // illegal: 65.0 is not an integer constant

对于一个非常量x转换到类型T，需要满足如下条件之一：
* x 对于类型T来说是assignable的
* x的类型和T拥有一样的underlying-types
* x和T都是匿名的pointer-types, 并且他们的指针背后都是一样的underlying-types. 这个地方使用指针转换
* x的类型和T一样都是整数或者浮点数
* x是整数或者字节切片或者runes，T是字符类型
* x是字符串，T是字节切片或者runes

对于整数者指针的转换需要用到package-unsafe下面的功能

#### Conversions between numeric types
#### Conversions to and from a string type
* 一个有符号或者无符号的整数初始化一个字符串的时候，这个字符串代表的是整数表达的Unicode-code-point，会想要的编码到UTF-8的值，超出有效的Unicode-code-points的值都会被转到"\uFFFD"
	string('a')       // "a"
	string(-1)        // "\ufffd" == "\xef\xbf\xbd"
	string(0xf8)      // "\u00f8" == "ø" == "\xc3\xb8"
	type MyString string
	MyString(0x65e5)  // "\u65e5" == "日" == "\xe6\x97\xa5"
* 把一个字节切片转到string的时候，字符串里面的bytes就是提供的切片里面的bytes
	string([]byte{'h', 'e', 'l', 'l', '\xc3', '\xb8'})   // "hellø"
	string([]byte{})                                     // ""
	string([]byte(nil))                                  // ""

	type MyBytes []byte
	string(MyBytes{'h', 'e', 'l', 'l', '\xc3', '\xb8'})  // "hellø"
* 把一个rune切片转到字符串的时候，每一个独立的rune代表的unicode-code-point都会加入字符串
	string([]rune{0x767d, 0x9d6c, 0x7fd4})   // "\u767d\u9d6c\u7fd4" == "白鵬翔"
	string([]rune{})                         // ""
	string([]rune(nil))                      // ""

	type MyRunes []rune
	string(MyRunes{0x767d, 0x9d6c, 0x7fd4})  // "\u767d\u9d6c\u7fd4" == "白鵬翔"
* 可以直接把字符串转到rune的切片，这样切片里面就是想要字符串的unicode-code-point了
	[]rune(MyString("白鵬翔"))  // []rune{0x767d, 0x9d6c, 0x7fd4}
	[]rune("")                 // []rune{}

	MyRunes("白鵬翔")           // []rune{0x767d, 0x9d6c, 0x7fd4}

#### Constant expressions
#### Order of evaluation (TODOS)

## Statements
	Statement =
		Declaration | LabeledStmt | SimpleStmt |
		GoStmt | ReturnStmt | BreakStmt | ContinueStmt | GotoStmt |
		FallthroughStmt | Block | IfStmt | SwitchStmt | SelectStmt | ForStmt |
		DeferStmt .

	SimpleStmt = EmptyStmt | ExpressionStmt | SendStmt | IncDecStmt | Assignment | ShortVarDecl .

### Terminating statements
如下的几种情况可以称为结束语句：
* "return" 或者 "goto"语句
* 调用内置的函数 `panic`
* 一个block里面的语句列表的最后一个
* 对于 "if"语句
	* 有 "else" 分支，并且
	* 两个括号已经结束
* 对于 "for"语句
	* 没有 "break"语句，并且
	* 达到了循环条件
* 对于 "switch"语句
	* 没有"break"语句
	* 有一个default-case 并且
	* 所有case语句包括default-case, 都以terminating语句结束或者哟一个标签的"fallthrough"语句
* 对于 "select"语句
	* 没有"break" 语句，并且
	* 状态列表里面所有状态语句都以terminating语句结束
* 一个labeled-statement，标记为一个结束语句

### Empty statements
	EmptyStmt = .

### Labeled statements
一个标记语句是goto, break 和 continue语句的跳转目标
	LabeledStmt = Label ":" Statement .
	Label       = identifier .

### Expression statements
	ExpressionStmt = Expression .
如下的内置函数不能出现在语句上下文中：
	append cap complex imag len make new real
	unsafe.Alignof unsafe.Offsetof unsafe.Sizeof

### Send statements
	SendStmt = Channel "<-" Expression .
	Channel  = Expression .

### IncDec statements
	IncDecStmt = Expression ( "++" | "--" ) .
对目标操作数执行untyped-constant-1的加减操作

### Assignments
	Assignment = ExpressionList assign_op ExpressionList .

	assign_op = [ add_op | mul_op ] "=" .

左边的操作数是可以取地址操作的，或者是一个map-index表达式，或者是一个blank-identifier(`_`)， 操作数可以用括号括起来。
	x = 1
	*p = f()
	a[i] = 23
	(k) = <-ch  // same as: k = <-ch
`x op= y` ，其中`op`是二元算术运算符，这个表达式与 `x = x op (y)` 等价, 只是对于表达式 x 只会求值一次。

对于tuple-assignment，会分两步来进行求值，第一步先对左边的操作数进行index-expressions以及pointer-indirections，然后对右边的值按照usual-order的顺序进行求值；第二部就是从左到右进行赋值操作。
	a, b = b, a  // exchange a and b

	x := []int{1, 2, 3}
	i := 0
	i, x[i] = 1, 2  // set i = 1, x[0] = 2

	i = 0
	x[i], i = 2, 1  // set x[0] = 2, i = 1

	x[0], x[0] = 1, 2  // set x[0] = 1, then x[0] = 2 (so x[0] == 2 at end)

	x[1], x[3] = 4, 5  // set x[1] = 4, then panic setting x[3] = 5.

	type Point struct { x, y int }
	var p *Point
	x[2], p.x = 6, 7  // set x[2] = 6, then panic setting p.x = 7

	i = 2
	x = []int{3, 5, 7}
	for i, x[i] = range x {  // set i, x[2] = 0, x[0]
		break
	}
	// after this loop, i == 0 and x == []int{3, 5, 3}

### If statements
	IfStmt = "if" [ SimpleStmt ";" ] Expression Block [ "else" ( IfStmt | Block ) ] .
在条件表达式里面可以加一个简单的前置语句，这个前置语句会在条件表达式求值之前preceded。

### Switch statements
switch提供多路执行语句。类型匹配或者表达式求值匹配来决定具体执行哪个分支。
	SwitchStmt = ExprSwitchStmt | TypeSwitchStmt .

#### Expression switchs
在这类switch里面，switch表达式会被求值，然后与case里面的常量从左到右和从上到下进行匹配，第一个匹配的表达式就会执行触发想要的case，其他case就会被忽略，如果没有case被匹配到，"default"-case会被执行，至多一个default-case可以加到switch里面。默认的switch-expression等于boolean-value值true
	ExprSwitchStmt = "switch" [ SimpleStmt ";" ] [ Expression ] "{" { ExprCaseClause } "}" .
	ExprCaseClause = ExprSwitchCase ":" StatementList .
	ExprSwitchCase = "case" ExpressionList | "default" .
如果switch-expression被求值为untyped-constant, 这个值会被转到相应的default-type。nil 不能作为switch-expression。
如果一个case-expression是untyped, 他会开始被转到switch-expression的type，并且每一个case里面的case-expression：x，必须与switch-expression:t 符合 comparison规则

	switch tag {
	default: s3()
	case 0, 1, 2, 3: s1()
	case 4, 5, 6, 7: s2()
	}

	switch x := f(); {  // missing switch expression means "true"
	case x < 0: return -x
	default: return x
	}

	switch {
	case x < y: f1()
	case x < z: f2()
	case x == 4: f3()
	}

实现层面的限制：限制的编译器会禁止多个case-expression出现求值后值相等的情况。列如限制的编译器禁止出现重复的integer, floating-point 和 string-constant在case-expressions。

#### Type-switches
	switch x.(type) {
	// cases
	}

	TypeSwitchStmt  = "switch" [ SimpleStmt ";" ] TypeSwitchGuard "{" { TypeCaseClause } "}" .
	TypeSwitchGuard = [ identifier ":=" ] PrimaryExpr "." "(" "type" ")" .
	TypeCaseClause  = TypeSwitchCase ":" StatementList .
	TypeSwitchCase  = "case" TypeList | "default" .
	TypeList        = Type { "," Type } .

### For statements
	ForStmt = "for" [ Condition | ForClause | RangeClause ] Block .
	Condition = Expression .

	ForClause = [ InitStmt ] ";" [ Condition ] ";" [ PostStmt ] .
	InitStmt = SimpleStmt .
	PostStmt = SimpleStmt .

	RangeClause = [ ExpressionList "=" | IdentifierList ":=" ] "range" Expression .

Range expression                          1st value          2nd value

	array or slice  a  [n]E, *[n]E, or []E    index    i  int    a[i]       E
	string          s  string type            index    i  int    see below  rune
	map             m  map[K]V                key      k  K      m[k]       V
	channel         c  chan E, <-chan E       element  e  E

对于Range操作遵循如下的几条规则：
* 对于数组，数组指针，或者切片，index是从0开始递增到len(a)-1, 对于nil的range操作会产生0次遍历操作
* 对于string, range会遍历从index==0的位置开始的unicode-code-points。如果成功产生遍历行为，index值会第一个有效的UTF-8编码的位置，value的值是相应的rune，如果遇到一个无效的UTF-8序列，第二个rune会是0xFFFD(默认的无效字符)，下一个前进一个byte, 直到下一个有效的UTF-8编码的rune。
* 遍历map的顺序是不确定的，如果遍历的过程中，还没有被遍历到的项目被移除了，那么在后续的遍历过程中这个项也不会再遇到了。如果新增加了项，后续的遍历过程有可能可以遍历到这个项目，也有可能遍历不到这个项目。如果map==nil, 则会跳过遍历过程。
* 对于channel来说，range 会等待知道接受到值或者channel被关闭，在channel==nil的通道上进行range操作会导致blocks-forever。


### Goto statements
	GotoStmt = "goto" Label .
goto 语句不能导致任何变量成为跳转地block的上下文
goto 语句只能再同一个block或者上层的级别进行跳转，不能往其他兄弟或者兄弟的孩子block跳转


### Fallthrough statements
	FallthroughStmt = "fallthrough" .

### Defer statements
	DeferStmt = "defer" Expression .
函数体结束的时候，或者相应的goroutine-panicking的时候会执行defer

defer的表达式必须是一个函数或者成员方法调用，并且不能加括号行程复杂表达式。defer的函数中的参数等会跟普通调用一样被求值，但函数不会立刻调用，会保存起来一个相应的快照，这个求值过程如果遇到function是nil的情况，在执行defer的时候也不会触发run-time-panic，只有真正执行defer序列的时候才会触发。

## Built-in functions
内建函数是预定义的，跟其他普通没有太多区别，只是有一些内建函数第一个参数接受一个类型作为参数，因为内建函数没有普通的Go-types, 所以内建函数只能出现在call-expressions里面，他们不能作为普通的函数变量一样使用。

### Close
往一个已经closing的channel发送消息或者再次close一个已经closed的channel会导致run-time panic。关闭一个nil-channel也会导致run-time panic. 关闭channel后，所有在缓冲区的元素也被消耗掉后，所有往这个channel读取的阻塞操作都会立刻返回，并且得到一个相应类型的零值对象。

### Length and capacity
	Call      Argument type    Result

	len(s)    string type      string length in bytes
			  [n]T, *[n]T      array length (== n)
			  []T              slice length
			  map[K]T          map length (number of defined keys)
			  chan T           number of elements queued in channel buffer

	cap(s)    [n]T, *[n]T      array length (== n)
			  []T              slice capacity
			  chan T           channel buffer capacity
对于nil的slice, array, map 去len操作得到长度为0

### Allocation
`new(T)` 返回 `*T`


### Making slices, maps and channels
内建函数`make`的第一个类型参数必须是slice, map 或者 channel-type, 加上一个类型相关的表达式列表，`make`函数返回类型`T`的值，这需要注意，他返回的不是`*T`, 创建的变量会根据[initial values](#jump_todos)小节描述的初始化。
	Call             Type T     Result

	make(T, n)       slice      slice of type T with length n and capacity n
	make(T, n, m)    slice      slice of type T with length n and capacity m

	make(T)          map        map of type T
	make(T, n)       map        map of type T with initial space for n elements

	make(T)          channel    unbuffered channel of type T
	make(T, n)       channel    buffered channel of type T, buffer size n

	s := make([]int, 10, 100)       // slice with len(s) == 10, cap(s) == 100
	s := make([]int, 1e3)           // slice with len(s) == cap(s) == 1000
	s := make([]int, 1<<63)         // illegal: len(s) is not representable by a value of type int
	s := make([]int, 10, 0)         // illegal: len(s) > cap(s)
	c := make(chan int, 10)         // channel with a buffer size of 10
	m := make(map[string]int, 100)  // map with initial space for 100 elements

### Appending to and copying slices
	append(s S, x ...T) S  // T is the element type of S

	s0 := []int{0, 0}
	s1 := append(s0, 2)                // append a single element     s1 == []int{0, 0, 2}
	s2 := append(s1, 3, 5, 7)          // append multiple elements    s2 == []int{0, 0, 2, 3, 5, 7}
	s3 := append(s2, s0...)            // append a slice              s3 == []int{0, 0, 2, 3, 5, 7, 0, 0}
	s4 := append(s3[3:6], s3[2:]...)   // append overlapping slice    s4 == []int{3, 5, 7, 2, 3, 5, 7, 0, 0}

	var t []interface{}
	t = append(t, 42, 3.1415, "foo")   //                             t == []interface{}{42, 3.1415, "foo"}

	var b []byte
	b = append(b, "bar"...)            // append string contents      b == []byte{'b', 'a', 'r' }

内建的拷贝函数处理slice:
	copy(dst, src []T) int
	copy(dst []byte, src string) int
拷贝的元素的数量为minimum(len(src), len(dst))
	var a = [...]int{0, 1, 2, 3, 4, 5, 6, 7}
	var s = make([]int, 6)
	var b = make([]byte, 5)
	n1 := copy(s, a[0:])            // n1 == 6, s == []int{0, 1, 2, 3, 4, 5}
	n2 := copy(s, s[2:])            // n2 == 4, s == []int{2, 3, 4, 5, 4, 5}
	n3 := copy(b, "Hello, World!")  // n3 == 5, b == []byte("Hello")


### Deletion of map elements
	delete(m, k)  // remove element m[k] from map m

### Manipulating complex numbers
内建的操作复数的函数：
	complex(realPart, imaginaryPart floatT) complexT
	real(complexT) floatT
	imag(complexT) floatT

操作的例子：
	var a = complex(2, -2)             // complex128
	const b = complex(1.0, -1.4)       // untyped complex constant 1 - 1.4i
	x := float32(math.Cos(math.Pi/2))  // float32
	var c64 = complex(5, -x)           // complex64
	const s uint = complex(1, 0)       // untyped complex constant 1 + 0i can be converted to uint
	_ = complex(1, 2<<s)               // illegal: 2 has floating-point type, cannot shift
	var rl = real(c64)                 // float32
	var im = imag(a)                   // float64
	const c = imag(b)                  // untyped constant -1.4
	_ = imag(3 << s)                   // illegal: 3 has complex type, cannot shift

### Handling panics
两个内建的函数处理运行时异常，并做异常恢复
	func panic(interface{})
	func recover() interface{}
执行函数F的时候，一个显式的`panic`调用, 或者发生run-time-panic的时候机会结束函数F的执行，同时开始执行函数F的deferred序列，然后返回到上一层调用并执行相应的deferred序列直到当前执行goroutine的top-level函数。回到这个点的时候程序被结束并且报告相关的错误，这个结束的序列我们把他称为`panicking`。
内建函数`recover`函数允许操纵前面提到的`panicking`序列的执行。加入一个函数G，defer函数D，在函数D里面我们调用了recover，然后在当前的goroutine的后续的执行中发生了panic，这个时候会启动`panicking`的执行序列，当执行序列来到函数D的时候，D中的recover函数返回值就是当时`panic`函数的参数，如果函数D在调用`recover`后如果没有再发生panic, 那么`panicking`的执行序列就结束了，就会按照正常的执行序列秩序D以后的defer函数，并正常的结束函数G的执行，让goroutine继续正常执行。

内建函数`recover`在如下几种情况下返回nil:
* panic函数的参数本身就是nil
* 当前的goroutine 没有发生 panicking
* recover没有直接在deferred-function调用

下面的`protect`函数会以一种安全的方式运行函数`g`，保障不会因为g引起的`panic`导致执行`panicking`而结束运行
	func protect(g func()) {
		defer func() {
			log.Println("done")  // Println executes normally even if there is a panic
			if x := recover(); x != nil {
				log.Printf("run time panic: %v", x)
			}
		}()
		log.Println("start")
		g()
	}

### Bootstrapping

## Packages
Go程序的基础组成部门是package, 一个package由很多的source-file组成，这些source-file 共享常量，类型，变量以及函数的声明域

### Source file organization
	SourceFile       = PackageClause ";" { ImportDecl ";" } { TopLevelDecl ";" } .

### Package clause
	PackageClause  = "package" PackageName .
	PackageName    = identifier .

### Import declarations
	ImportDecl       = "import" ( ImportSpec | "(" { ImportSpec ";" } ")" ) .
	ImportSpec       = [ "." | PackageName ] ImportPath .
	ImportPath       = string_lit .
在包的导入语句里面如果前面的导入名是`.`，那么导入包里面的所有符号都会直接合并到当前包的当前源代码文件里面，这个时候在当前源码文件里面就不在需要通过包名去访问导入包里面的符号了。
	Import declaration          Local name of Sin

	import   "lib/math"         math.Sin
	import m "lib/math"         m.Sin
	import . "lib/math"         Sin
另外一个包导入声明就是依赖关系的带入，导入包但不显式调用包里面的内容，但需要报进行初始化就可以用balnk-identifier代替包名导入，如下：
	import _ "lib/math"

### An example package
	package main

	import "fmt"

	// Send the sequence 2, 3, 4, … to channel 'ch'.
	func generate(ch chan<- int) {
		for i := 2; ; i++ {
			ch <- i  // Send 'i' to channel 'ch'.
		}
	}

	// Copy the values from channel 'src' to channel 'dst',
	// removing those divisible by 'prime'.
	func filter(src <-chan int, dst chan<- int, prime int) {
		for i := range src {  // Loop over values received from 'src'.
			if i%prime != 0 {
				dst <- i  // Send 'i' to channel 'dst'.
			}
		}
	}

	// The prime sieve: Daisy-chain filter processes together.
	func sieve() {
		ch := make(chan int)  // Create a new channel.
		go generate(ch)       // Start generate() as a subprocess.
		for {
			prime := <-ch
			fmt.Print(prime, "\n")
			ch1 := make(chan int)
			go filter(ch, ch1, prime)
			ch = ch1
		}
	}

	func main() {
		sieve()
	}

## Program initialization and execution

### The zero value
每一个类型都有他相应的零值，类型分配内存后会通过递归的方式进行零值的初始化。

### Package initialization
包级别的变量会根据在包里面的声明顺序进行初始化(当然这里会考虑依赖关系).
不同文件里面的变量的顺序以编译器编译的顺序为准。当然变量也可以显示的放在没有参数没有返回值的init函数里面进行显示的初始化，可以定义很多init函数。包的初始化是先变量，然后再调用init, 而且所有包的初始化都在一个goroutine里面书序的执行。
为了保障初始化顺序的确定性，编译器在编译包内源文件的时候统筹按照字典顺序来编译源文件。

### Program execution
一个完整的应用程序，就是把与包名为main的以及与他依赖的所有包全部链接起来。包main的入口函数`main`没有参数，没有返回值

## Errors
预定义的错误类型如下:
	type error interface {
		Error() string
	}

## Run-time panics
系统错误类型定义:
	package runtime

	type Error interface {
		error
		// and perhaps other methods
	}

## System considerations

### Package unsafe
这个內建的包`unsafe`，提供了一些低级别的工具，这些工具会穿越类型系统等。注意使用了`unsafe`包的程序可能是不能移植的。这个包里面提供如下的interface:
	package unsafe

	type ArbitraryType int  // shorthand for an arbitrary Go type; it is not a real type
	type Pointer *ArbitraryType

	func Alignof(variable ArbitraryType) uintptr
	func Offsetof(selector ArbitraryType) uintptr
	func Sizeof(variable ArbitraryType) uintptr

### Size and alignment guarantees
Golang的数字类型，对于字节有如下的保证：
	type                                 size in bytes

	byte, uint8, int8                     1
	uint16, int16                         2
	uint32, int32, float32                4
	uint64, int64, float64, complex64     8
	complex128                           16
对于字节对其有如下保证：
1. 任意类型的变量`x`: unsafe.Alignof(x) 大于等于1
2. 任意类型的变量`x`: unsafe.Alignof(x) 是他所有成员的变量 unsafe.Alignof(x.f) 的最大值
3. 对于任何数组类型 `x`: unsafe.Alignof(x) 与 unsafe.Alignof(x[0]) 一致

一个结构体或者数组类型可能不包含任何成员，但他的变量大小也不会是0，这种变量有一个叫法做`zero-size`变量，两个不同的`zero-size`变量再内存里面也可能是共享的同一个内存区域，他们拥有相同的内存地址。

Build version go1.7.3
