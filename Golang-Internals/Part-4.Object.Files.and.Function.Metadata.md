# 深入浅出 Golang，第四部分：Object文件以及函数元信息 [Part 4: Object Files and Function Metadata][1]

今天我们详细探讨Go里面的`Func`这个结构，以及涉及一下Go的垃圾回收工作原理。
这一篇作为[Part-3.The.Linker.Object.Files.and.Relocations][2] 的姊妹篇，我们也会用同一个示例程序来探讨，如果没有阅读过第三篇，强烈建议先过一下第三篇文章。

## 函数结构体
第三篇文章后，应该对重定向的基本原理已经了解。然后我们来观察下main函数的符号定义：
```
Func: &goobj.Func{
    Args:    0,
    Frame:   8,
    Leaf:    false,
    NoSplit: false,
    Var:     {
    },
    PCSP:   goobj.Data{Offset:255, Size:7},
    PCFile: goobj.Data{Offset:263, Size:3},
    PCLine: goobj.Data{Offset:267, Size:7},
    PCData: {
        {Offset:276, Size:5},
    },
    FuncData: {
        {
            Sym:    goobj.SymID{Name:"gclocals·3280bececceccd33cb74587feedb1f9f", Version:0},
         Offset: 0,
     },
     {
         Sym:    goobj.SymID{Name:"gclocals·3280bececceccd33cb74587feedb1f9f", Version:0},
               Offset: 0,
           },
       },
       File: {"/home/adminone/temp/test.go"},
   },
```
你可以认为上面的结构体就是编译器为main函数生成的Metadata，这个Metadata是Go运行时可以访问的(当然实际上函数的Metadata没有这么多字段，下面马上就会看到具体定义)。这里有一篇[文章][4]详细介绍了这个结构体的每一个字段的含义。接下来我们跳过这部分说明，直接介绍运行时是怎么使用这个Metadata的。
在运行时里面上面的符号定义会对应到一个如下的结构体：
```
type _func struct {
	entry   uintptr // start pc
	nameoff int32   // function name

	args  int32 // in/out args size
	frame int32 // legacy frame size; use pcsp if possible

	pcsp      int32
	pcfile    int32
	pcln      int32
	npcdata   int32
	nfuncdata int32
}
```
从上面的定义可以清晰看到，并没有把编译器生成的所有字段映射到运行时里面，有一些字段只供链接器使用。这里比较有意义的字段是：pcsp、pcfile、pcln，在真正遇到[指令运算-指令寄存器][3]执行的时候，上述的字段就会翻译成栈指针，文件名，以及相应的行号。一个很常见的情形就是发生panic的时候，运行时得知道当前汇编指令对应的函数，行号，以及相应的文件名，运行时就是通过当前的指令寄存器得到相应的函数名和行号，然后通过回溯字段pcsp获取整个调用栈。
好，问题来了，我们是怎么通过指令寄存器获取行号这些信息的？为了回答这个问题，我们再回来看下生成的汇编代码，以及行号信息是怎么存储在Object文件里面的：
```
	0x001a 00026 (test.go:4)	MOVQ	$1,(SP)
	0x0022 00034 (test.go:4)	PCDATA	$0,$0
	0x0022 00034 (test.go:4)	CALL	,runtime.printint(SB)
	0x0027 00039 (test.go:5)	ADDQ	$8,SP
	0x002b 00043 (test.go:5)	RET	,
```
从上面的汇编代码我们看到指令寄存器从`00026`到`00038`对应的行号是`test.go:4`，从`00039`到下一个函数调用对应的是`test.go:5`，简化这个对应关系，我们存储下面的一个map：
```
26 - 4
39 - 5
…
```
上面的过程基本也是编译器做的事情。字段`pcln`存储的是与当前函数的起始指令的偏移量，再加上下一个函数的起始指令的偏移量，我们就可以用二分查找找到给定的指令寄存器对应的行号。
在Go里面很多地方都应用了上面的map机制，不仅仅通过建立一个map，建立指令寄存器与行号的关系，可以通过上述的机制让指令寄存器映射到任何整数。汇编代码里面的`PCDATA`就是用来干这个事情的。每一次链接器发现了下面的指令：

	0x0022 00034 (test.go:4)    PCDATA  $0,$0

链接器不会为上述的汇编生成任何要执行的指令，相反他会当前指令的第二个参数和当前的指令寄存器建立一个上述的映射关系，而指令的第一个参数表示的就是map的类型，通过传递不同的第一个参数可以建立很多运行时可以感知的映射关系。

## 垃圾回收是怎么利用函数的Metadata的呢？
最后一个Func-Metadata里面需要说明的是`FuncData`数组，它为GC准备了一些必要的信息。Go的GC采用的是[Mark-and-Sweep][5]算法，这个算法分为两个阶段，第一个阶段给所有能达到的对象做标记(mark)，第二个阶段释放(sweep)所有没有标记的对象。

所以算法的第一阶段就是从几个已知的地方开始扫描所有对象，这些地方包括：全局变量，寄存器，栈帧上，以及已经标记为可达的对象的成员变量上。如果你仔细想想，你也会发现这个扫描过程是一个非常棘手的问题，怎么扫描栈上的指针，怎么来区分是指针还是普通变量等等，这个时候就需要到一些辅助信息了。
编译器会为每个函数生成两个位图，第一个位图用来跟踪函数的参数里面栈帧上的那些指针变量(堆变量)；第二个位图用来跟踪函数体内部栈帧上的指针变量(堆变量)。Garbage-Collector(GC)就可以用上述的两个位图执行扫描操作。

这里我们提到了两种附加数据，类似这里` PCDATA, FUNCDATA`的附加数据是由Go编译器生成的伪汇编指令：

	0x001a 00026 (test.go:3)	FUNCDATA	$0,gclocals·3280bececceccd33cb74587feedb1f9f+0(SB)

上面指令的第一个参数表面是参数位图还是函数体局部变量位图，第二个参数就是真正的包含GC-Mask(位图)的隐藏变量。

## 还有啥？？

在接下来的篇幅中，我们会探讨Glang的启动引导过程，这个对于理解Go的运行时机制也是非常关键的。




[1]: http://blog.altoros.com/golang-part-4-object-files-and-function-metadata.html "Part 4: Object Files and Function Metadata"
[2]: https://github.com/JerryZhou/golang-doc/blob/master/Golang-Internals/Part-3.The.Linker.Object.Files.and.Relocations.md "Part-3.The.Linker.Object.Files.and.Relocations"
[3]: https://en.wikipedia.org/wiki/Program_counter "IP/IAR"
[4]: https://docs.google.com/document/d/1lyPIbmsYbXnpNj57a261hgOYVpNRcgydurVQIyZOz_o/pub "Func"
[5]: http://www.brpreiss.com/books/opus5/html/page424.html "Mark-and-Sweep Garbage Collection"