# 深入浅出 Golang，第三部分：链接，重定向以及Object文件 [Part 3: The Linker, Object Files, and Relocations][1]

今天我们聊聊Go的链接器，Object文件，以及重定向。

好，为什么我们需要关心上述的这些概念呢，这个道理其实也很简单，比如你要了解一个大项目，那么你首先肯定得把大项目分解成很多小的模块；然后你再搞清楚模块与模块之间的依赖关系，一起他们之间项目调用的约定。对于Go这个大项目来说，他可以分解成：编译器，链接器，运行时；然后编译器生成Object文件，链接器在这个基础上工作。我们今天这里主要讨论就是这一部分。

- - -

## 怎么生成Go的Object文件
我们来做一个实验，我们写一个超级简单的示例程序，看Go的编译器会生成什么样的Object文件。我们用如下的程序来做实验：
```
package main

func main() {
	print(1)
}
```

是不是简单到你怀疑人生！好我们编译这个简单程序：
```
go tool 6g test.go
```
如果是Go1.5或者以上的版本可以执行：
```
go tool compile test.go
```
上面的命令会生成test.6的Object文件(如果是Go1.5以上会生成test.o的Object文件)，为了刺探这个Object文件的内部结构我们需要用到[goobj][2]库，这个库随着Go的源代码一起发布，主要用来检查Object文件格式是否正确。为了解释内部结构，笔者基于这个库写了一个小工具，用来打印Object文件内部结构信息，小工具的源代码可以在[这里][3]找到。
我们先下载和安装这里需要用到的这个小工具：

	go get github.com/s-matyukevich/goobj_explorer

然后执行如下命令：

	goobj_explorer -o test.6

好，你将在控制台里面看到`goob.Package`结构体。

- - -

## 详解Object文件
Object文件比较有意义的部分是Sym数组，这其实是一个符号表。应用程序里面定义所有符号信息都在这个表里面，包括定义的函数，全局表里，类型，常量等等。我们看一下关于main函数的符号(我们这里暂时把`Reloc`和`Func`这两个部分先省略，我们后续对这两部分再详细讨论)。
```
&goobj.Sym{
            SymID: goobj.SymID{Name:"main.main", Version:0},
            Kind:  1,
            DupOK: false,
            Size:  48,
            Type:  goobj.SymID{},
            Data:  goobj.Data{Offset:137, Size:44},
            Reloc: ...,
            Func:  ...,
}
```
我们用一个表格对goobj.Sym的各个字段做一个说明：

|字段|描述|
|---|---|
|SumID|全局唯一的符号ID，由符号名和版本组成，版本用来区分同名的不同符号|
|Kind|表明符号属于什么类型，后续会进一步说明这个字段|
|DupOK|表明这个符号是否可以存在多个同名的|
|Size|符号的内存大小|
|Type|可以指向另外一个详细说明类型信息的符号，可以是空|
|Data|包含符号的二进制信息，不同类型的符号这个字段的内容解释是不一样的，如果是函数类型的符号，这里存储的是汇编代码，如果是字符串类型的符号，这个字段存储的是字符串的值|
|Reloc|包含重定向信息，后面详细说明...|
|Func|如果是函数类型的符号，这里存储的是函数的元信息|

所有不同类型的符号都以常量的形式定义在`goobj`包里面，可以在[这里][4]找到。这里我们截取一部分：
```
const (
	_ SymKind = iota

	// readonly, executable
	STEXT
	SELFRXSECT

	// readonly, non-executable
	STYPE
	SSTRING
	SGOSTRING
	SGOFUNC
	SRODATA
	SFUNCTAB
	STYPELINK
	SSYMTAB // TODO: move to unmapped section
	SPCLNTAB
	SELFROSECT
```
从前面的代码段我们看到`main.main`符号的Kind是1，对应到`STEXT`符号类型，这个类型的符号包含的是可执行代码。好让我们来看一下`Reloc`数组，我们先列一下数组成员的结构体：
```
type Reloc struct {
	Offset int
	Size   int
	Sym    SymID
	Add    int
	Type int
}
```
上面的结构体的代表的操作是：把符号所在地址加上偏移量Add这个地方的内存复制到内存地址范围[Offset, Offset+Size]的地方,
也就是[memmove][5]: `memmove(Offset, sym_addr+Add, Size)`


## 理解 relocations

接下来我们用一个例子来说明relocations。首先我们在编译的时候带上一个`-S`的选项，让编译器帮我们打印出生成的相关汇编代码。
	go tool 6g -S test.go
我们找到生成的汇编代码关于main函数的那一段：

```
"".main t=1 size=48 value=0 args=0x0 locals=0x8
	0x0000 00000 (test.go:3)	TEXT	"".main+0(SB),$8-0
	0x0000 00000 (test.go:3)	MOVQ	(TLS),CX
	0x0009 00009 (test.go:3)	CMPQ	SP,16(CX)
	0x000d 00013 (test.go:3)	JHI	,22
	0x000f 00015 (test.go:3)	CALL	,runtime.morestack_noctxt(SB)
	0x0014 00020 (test.go:3)	JMP	,0
	0x0016 00022 (test.go:3)	SUBQ	$8,SP
	0x001a 00026 (test.go:3)	FUNCDATA	$0,gclocals·3280bececceccd33cb74587feedb1f9f+0(SB)
	0x001a 00026 (test.go:3)	FUNCDATA	$1,gclocals·3280bececceccd33cb74587feedb1f9f+0(SB)
	0x001a 00026 (test.go:4)	MOVQ	$1,(SP)
	0x0022 00034 (test.go:4)	PCDATA	$0,$0
	0x0022 00034 (test.go:4)	CALL	,runtime.printint(SB)
	0x0027 00039 (test.go:5)	ADDQ	$8,SP
	0x002b 00043 (test.go:5)	RET	,
```

在后续的博文里面我们会再次详解这一段汇编，并且尝试通过解析理解Go的运行时是怎么工作的。这个阶段我们对上述的汇编我们只关心这一句就可以了：

	0x0022 00034 (test.go:4)	CALL	,runtime.printint(SB)
	
这一条指令位于函数区偏移量为0x0022(十六进制)的位置,或者说是偏移量为00034(十进制)的位置，这一行指令他实际上的作用是调用运行时的函数`runtime.printint`，这里的问题是编译器在编译期间其实是不知道运行时函数`runtime.printint`的真正地址的，这个函数是位于运行时的Object文件里面，当前编译的文件肯定是不知道这个函数地址，在这种情况下我们就用到了重定向技术，接下来的代码段正是对函数`runtime.printint`这个的重定向，笔者从oobj_explorer工具的汇编里面拷贝过来的。

```
				{
                    Offset: 35,
                    Size:   4,
                    Sym:    goobj.SymID{Name:"runtime.printint", Version:0},
                    Add:    0,
                    Type:   3,
                },
```









[1] http://blog.altoros.com/golang-internals-part-3-the-linker-and-object-files.html "The Linker, Object Files, and Relocations"
[2] https://github.com/golang/go/tree/master/src/cmd/internal/goobj "goobj"
[3] https://github.com/s-matyukevich/goobj_explorer "goobj_explorer"
[4] https://github.com/golang/go/blob/master/src/cmd/internal/goobj/read.go#L30 "Sym Kind"
[5] http://man7.org/linux/man-pages/man3/memmove.3.html "memmove"



