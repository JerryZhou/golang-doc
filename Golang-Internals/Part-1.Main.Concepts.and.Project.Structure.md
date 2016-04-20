# 深入浅出 Golang，第一部分：工程的结构以及主要概念 [Part 1: Main Concepts and Project Structure] [1]

## 这一系列的博文主要是给那些已经对Go有基础了解后想对语言内部机制做更加深入探索的同学。在阅读完这个系列博文后读者应该能回答如下的三个问题：

1. Go源代码的工程结构是怎么样的？
2. Go的编译器是怎么工作的？
3. 基础结构**Node-tree**在Go语言里面到底是一个神马东东？

- - -

## 开始装逼

开始接触一门编程语言，我们通常会接触到很多书籍专注在语言的语法、语义甚至标准库等相关方面。但是你很难从这些书籍中去了解关于语言的内存对象模型，以及内置函数调用的时候到底编译器生成了什么样的中间代码(汇编代码或者类汇编代码)。当然对于一个开源的编程语言，你想要了解的这些相对深入的语言机制都可以从源代码里面获取到，回过头来以个人经验来说，要想从源代码理解到这些内容却也是相当困难的，所以我们这里写一个引子，和大家一起从源代码里面窥探一下golang的胴体(咔擦。。。)。

在开始真正代码之旅之前，我们需要先git一份源代码：

`git clone https://github.com/golang/go`

_注意:主干代码持续在变更，我们这里为了保持文章的一致性我们选用go1.4发布分支的代码作为本系列文章的参照_

- - -

## 工程结构
Understanding project structure

从Go的仓库src目录下，我们会看到很多子目录。大部分子目录都是Go标准库的代码。标准库里面的每个子目录的里面代码的包名和目录名保持一致，这也是go的标准命名规则。除开这部分标准库，还有一些目录，其中重要的目录有如下几个:

|目录|描述|
|-----|----|
|/src/cmd/|包含了各种golang的命令|
|/src/cmd/go|包含了命令行工具Go的实现：通过调用其他编译，链接工具，实现下载编译Go的源文件|
|/src/cmd/dist|这个工具负责编译目录下的其他命令行工具，并且负责编译Go的标准库|
|/src/cmd/gc|这是一个与架构无关的Go的编译器实现，是第一个Go的编译器|
|/src/cmd/ld|Go的链接器的实现，与平台相关的代码会放在以平台架构命名的子目录下面|
|/src/cmd/5a,6a,8a,9a|这里面是Go为各个不同平台实现的汇编指令编译器，Go的汇编指令跟本机的汇编指令不一样，这些工具负责把Go的汇编指令翻译为不同架构的汇编指令，详细信息可以在[这里](https://golang.org/doc/asm)查看。|
|/src/lib9,/src/libio,/src/liblink| 这些是编译器，链接器以及Go运行时用到的一些库|
|/src/runtime/| 最重要的Go包，会包含进所有的Go程序里面，这是整个Go的运行时：比如垃圾回收内存管理， gorountines, channel 等等|

- - -

## Go 编译器

上面表格里面呈现的一样，与架构无关的Go的编译器实现代码在/src/cmd/gc这个目录里面，程序的入口在[lex.c][4]这个文件里面，姑且跳过一些程序的类似命令行参数处理等常规处理步骤，编译器主要执行如下的一些步骤：

1. 初始化基础数据结构
2. 遍历所有Go的源文件，对每一个源文件调用`yyparse`函数。这个函数里面会执行具体的编译解析工作，Go编译器用的是[Bison][2]做解析器，Go的语法描述全部在[go.y][3](后续会详细说明这个文件)这个文件里面，经过这个步骤后，会生成完整的语法树。
3. 会对生成的语法树做几次遍历操作，为树上的每个节点推导并填充类型信息，为一些必要的地方做type-casting等。
4. 执行正在的编译操作，生成每个节点的汇编指令。
5. 然后生成object文件，以及相关符号表等。

这里我们可以对比到clang的完整步骤:

1. (source code)
2. ==> preprocessing 					==> (.i,.ii,.mi,.mii)
3. ==> parsing and semantic analysis 	==> (ast:abstract syntax tree) 
4. ==> code generation and optionzation 	==> (.s)
5. ==> assembler 						==> (.object)
6. ==> linker 							==> (.so, .dylib)

- - - 

## 深入Go的语法看看
现在我们详解前面编译流程里面的第二步。[go.y][3] 这个文件包含李golang的语义设计规则，是我们学习go的编译器并且深入理解golang语法规则的一个很好的入手点。这个文件由一系列如下的声明组成：

	xfndcl:
		LFUNC fndcl fnbody
	fndcl:
     	sym '(' oarg_type_list_ocomma ')' fnres
		| '(' oarg_type_list_ocomma ')' sym '(' oarg_type_list_ocomma ')' fnres

上面的代码段声明了两个节点xfndcl和fndcl的定义。fundcl这个节点可以有两种表现形式，第一种形式对应如下的一个构造函数：

	somefunction(x int, y int) int

第二种形式对应到如下的形式：

	(t *SomeType) somefunction(x int, y int) int

xfndcl节点由存储在LFUNC里面的关键字func以及节点fndcl、fnbody组成。

[Bison][2]或者[Yacc][5]语法解析器一个重要的特性就是允许放置一段C代码在节点的声明后面，这一小段C代码会每次在找到源文件里面匹配的代码块的时候执行，在执行的代码块里面可以通过$$引用result节点, 用$1、$2、$3... 引用子节点。
我们用一个例子(从g.y里面截取的一个简化版的节点配置)来理解我们这里提到的解析器怎么插入代码：

	fndcl:
      	sym '(' oarg_type_list_ocomma ')' fnres
        {
          t = nod(OTFUNC, N, N);
          t->list = $3;
          t->rlist = $5;

          $$ = nod(ODCLFUNC, N, N);
          $$->nname = newname($1);
          $$->nname->ntype = t;
          declare($$->nname, PFUNC);
      	}
		| '(' oarg_type_list_ocomma ')' sym '(' oarg_type_list_ocomma ')' fnres

首先创建一个节点存储函数的参数类型信息,类型信息里面会用到第3个子节点作为参数列表和第5个子节点作为返回值列表；然后攒国家一个新的节点作为result节点返回。上面的声明是伪造的一段，在go.y文件里面是找不到的。
 
- - -

## 理解节点

现在我们要花点时间来理解"node"节点是一个啥子东东。node肯定是一个struct,你可以在[这里][6]找打结构体的定义。这个结构体你会看到有灰常多的属性，节点会有不同的用途，也会分成不同的类型，不同类型node，会有他相应的属性。下面会对一些我认为对理解node比较重要的属性做说明：

|成员|说明|
|---|---|
|op|这个用来区分节点类型，前面的例子里面我们有看到OTFUNC(operation type function)和ODCLFUNC(operation declaration function)两个类型|
|type|这个是Type的制作，如果节点需要类型说明，这个变量就指向相关类型信息，当然也有一些节点是没有类型信息，比如一些控制流statements：if、switch或者for等|
|val|Val类型的变量，里面存储了节点的合法有效值|

到这里我们已经说明了基础结构[node][6]，你可以结合现在的了解去详细阅读相关源代码。在下一节，我们会用一个简单的go程序来解读go编译器具体在生成节点这个阶段做了啥子黑科技。

- - -

[1]: http://blog.altoros.com/golang-part-1-main-concepts-and-project-structure.html "Golang Internals, Part 1: Main Concepts and Project Structure"
[2]: https://www.gnu.org/software/bison/ ""
[3]: https://github.com/golang/go/blob/release-branch.go1.4/src/cmd/gc/go.y "golang1.4/src/gc/go.y"
[4]: https://github.com/golang/go/blob/release-branch.go1.4/src/cmd/gc/lex.c#L199 "main"
[5]: http://dinosaur.compilertools.net/yacc/ "yacc"
[6]: https://github.com/golang/go/blob/release-branch.go1.4/src/cmd/gc/go.h#L245 "node"
