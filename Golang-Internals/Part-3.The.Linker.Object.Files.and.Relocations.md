# 深入浅出 Golang，第三部分：链接，重定向以及Object文件 [Part 3: The Linker, Object Files, and Relocations][1]

今天我们聊聊Go的链接器，Object文件，以及重定向。

好，为什么我们需要关心上述的这些概念呢，这个道理其实也很简单，比如你要了解一个大项目，那么你首先肯定得把大项目分解成很多小的模块；然后你再搞清楚模块与模块之间的依赖关系，以及他们之间项目调用的约定。对于Go这个大项目来说，他可以分解成：编译器，链接器，运行时；然后编译器生成Object文件，链接器在这个基础上工作。我们今天这里主要讨论就是这一部分。

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
我们先下载和安装这里需要用到的这个小工具(go1.4后加了[internal机制][6]，这个工具不能直接这样编译了)：

	go get github.com/s-matyukevich/goobj_explorer

然后执行如下命令：

	goobj_explorer -o test.6

好，你将在控制台里面看到`goob.Package`结构体。

- - -

## 详解Object文件
Object文件比较有意义的部分是Sym数组，这其实是一个符号表。应用程序里面定义所有符号信息都在这个表里面，包括定义的函数，全局变量，类型，常量等等。我们看一下关于main函数的符号(我们这里暂时把`Reloc`和`Func`这两个部分先省略，我们后续对这两部分再详细讨论)。
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
	go tool compile -S test.go // Go1.5 or greater
	
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
	
这一条指令位于函数区偏移量为0x0022(十六进制)的位置,或者说是偏移量为00034(十进制)的位置，这一行指令他实际上的作用是调用运行时的函数`runtime.printint`，这里的问题是编译器在编译期间其实是不知道运行时函数`runtime.printint`的真正地址的，这个函数是位于运行时的Object文件里面，当前编译的文件肯定是不知道这个函数地址，在这种情况下我们就用到了重定向技术，接下来的代码段正是对函数`runtime.printint`这个的重定向，笔者从goobj_explorer工具的汇编里面拷贝过来的。

```
				{
                    Offset: 35,
                    Size:   4,
                    Sym:    goobj.SymID{Name:"runtime.printint", Version:0},
                    Add:    0,
                    Type:   3,
                },
```
上面的重定向告诉链接器，用符号`Sym:    goobj.SymID{Name:"runtime.printint", Version:0}`的地址加上偏移量`Add:    0` 替换当前Object文件偏移量为`Offset: 35`开始的`Size:   4`的内容，这里是35而不是前面跳到的34的偏移量是，因为第34字节是一个字节的call指令，第35字节才是call的函数地址。

- - -

## 链接器怎么执行重定向呢

经过上面的解析，我们基本理解了重定向这个。这里我们对整个过程做一下梳理：

1. 链接器从main包开始收集所有关联到的相关代码里面的需要重定向的符号，把这个放入一个巨大的二进制的数组结构里面
2. 链接器计算每一个符号在当前镜像里面的偏移量
3. 执行重定向操作，把符号里面相关真正的地址和数据复制到响应的位置
4. 链接器准备pe头需要的所有信息，然后生成可执行的二进制镜像文件


## 理解TLS(thread-local-storage)

在前面打印出来main函数的符号表里面，细心的读者可能注意到一个比较奇怪的重定向，他没有对应到任何函数调用，连符号也是一个空的`Sym:    goobj.SymID{}`:

```
				{
                    Offset: 5,
                    Size:   4,
                    Sym:    goobj.SymID{},
                    Add:    0,
                    Type:   9,
                },
```
那么上面的重定向是干啥的？我们看到他的偏移量是5，替换4个字节的数据，查看这个偏移量对应的汇编指令为：

	0x0000 00000 (test.go:3)	MOVQ	(TLS),CX

我们也可以观察到这条指令的偏移量是0，然后下一条指令的偏移量就已经是9了，所以这一条指令占据了9个字节的空间，我们初步的估计就是他与TLS有关，但是TLS具体做了一些什么事情呢？

TLS的全称是[线程局部存储][7]，很多编程语言里面都有这个概念，这个简单介绍就是线程局部存储，定义一个变量，这个变量在每个线程都存在一个单独的实例。

在Go语言里面，用TLS存储了当前Goroutine的环境变量G结构体的指针，链接器对这个指针是感知的，上面的偏移量为0的指令就是把这个结构体的指针放到寄存器CX里面，TLS的实现在不同的架构上他的实现是不一样的，比如在AMD64处理器上，这个不是指针会被存储到FS寄存器，那么前面的指令就会变成`0x0000 00000 (test.go:3)	MOVQ	(TLS),FS`。

这里我们列举所有重定向类型，来结束我们关于重定向的讨论：
```
// Reloc.type
enum
{
	R_ADDR = 1,
	R_SIZE,
	R_CALL, // relocation for direct PC-relative call
	R_CALLARM, // relocation for ARM direct call
	R_CALLIND, // marker for indirect call (no actual relocating necessary)
	R_CONST,
	R_PCREL,
	R_TLS,
	R_TLS_LE, // TLS local exec offset from TLS segment register
	R_TLS_IE, // TLS initial exec offset from TLS base pointer
	R_GOTOFF,
	R_PLT0,
	R_PLT1,
	R_PLT2,
	R_USEFIELD,
};
```
上面的R_CALL和R_TLS就是我们讨论里面涉及到的两个重定向类型。


## 进一步深挖Object文件

下一个主题还是讨论Object文件，下一节会展示更多详细的信息，为后续理解Go的运行时提供更全面的背景知识。



[1] http://blog.altoros.com/golang-internals-part-3-the-linker-and-object-files.html "The Linker, Object Files, and Relocations"
[2] https://github.com/golang/go/tree/master/src/cmd/internal/goobj "goobj"
[3] https://github.com/s-matyukevich/goobj_explorer "goobj_explorer"
[4] https://github.com/golang/go/blob/master/src/cmd/internal/goobj/read.go#L30 "Sym Kind"
[5] http://man7.org/linux/man-pages/man3/memmove.3.html "memmove"
[6] http://golang.org/s/go14internal "internal"
[7] https://en.wikipedia.org/wiki/Thread-local_storage "thread-local-storage"



