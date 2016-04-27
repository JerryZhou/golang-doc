# 深入浅出 Golang，第五部分：运行时的启动过程 [Part 5: the Runtime Bootstrap Process][1]

搞清楚Golang-Runtime的启动引导过程是理解Golang-Runtime的工作机制非常关键的一步。如果想把Golang玩弄于鼓掌之间，就必须搞清楚它的运行时。所以<深入浅出Golang>这个系列的第五部分，我们就来重点探讨Golang-Runtime以及它的启动引导过程。

这一部分我们会着重三个方面的探讨：

1. Golang 的启动引导过程
2. resizable stacks: 动态栈的实现
3. internal TLS: 内部线程局部存储的实现

注意：本文会涉及到一些Go-Assemble-Code, 也就要求你对Golang的汇编应该具备基本的了解。如果不了解,可以先去参考[这篇文章][2]，当然如果不习惯E文，也还是有[译文][5]可读的。

## 从程序的入口开始
我们先写一个简单的测试程序，编译一下，看开始执行一个Go程序，最开始调用的函数或者说执行的代码是到底神马。我们用如下的测试程序来做实验：
```
package main

func main() {
	print(123)
}
```
然后我们对这个程序做编译链接操作，生成正在的可执行文件。

	go tool 6g test.go
	go tool 6l test.6
	
{对于Go1.5以上: `go tool compile test.go`  和 `go tool link test.o`}
	
然后我们用objdump工具来看下这个执行镜像的pe头，对于没有这个工具的Windows或者Mac平台用户你就直接跳过这一步，查看笔者这里贴出来的结果就好。

	objdump -f 6.out
	
{对于Mac用户，其实可以`brew install binutils`，里面有带一个`gobjdump -f test.out`}
通过上面的命令应该可以得到如下输出：
```
6.out:     file format elf64-x86-64
architecture: i386:x86-64, flags 0x00000112:
EXEC_P, HAS_SYMS, D_PAGED
start address 0x000000000042f160
```

通过上面的操作，我们知道了起始地址，那我们通过如下命令把执行文件编译到汇编代码：

	objdump -d 6.out > disassemble.txt

{对于Go1.5以上的用户，其实Golang自带了objdump工具：`go tool objdump test.out`}
然后我们打开反编译的汇编代码，查找起始地址：`42f160`，然后我们得到起始地址的代码是：
```
000000000042f160 <_rt0_amd64_linux>:
  42f160:	48 8d 74 24 08       		lea    0x8(%rsp),%rsi
  42f165:	48 8b 3c 24          		mov    (%rsp),%rdi
  42f169:	48 8d 05 10 00 00 00 	lea    0x10(%rip),%rax        # 42f180 <main>
  42f170:	ff e0               		 	jmpq   *%rax
```
好了，我们发现了在笔者的操作系统上的入口函数是：`_rt0_amd64_linux`

## 启动那一坨
现在我们在Go-Runtime的源代码里面查找入口函数，对于笔者的情况入口函数在文件[`rt0_linux_amd64.s`][3]里面。仔细看的话，你会在当前源代码目录下面发现很多rt0_[OS]_[architecture].s 的文件，这些就对应到不同系统，不同架构的入口函数。好，我们来仔细瞧瞧这个[`rt0_linux_amd64.s`][3]文件：
```
TEXT _rt0_amd64_linux(SB),NOSPLIT,$-8
	LEAQ	 8(SP), SI // argv
	MOVQ	 0(SP), DI // argc
	MOVQ	 $main(SB), AX
	JMP	AX

TEXT main(SB),NOSPLIT,$-8
	MOVQ	 $runtime·rt0_go(SB), AX
	JMP	AX
```
`_rt0_amd64_linux`函数非常简单，把参数`argv`和`argc`放到寄存器`SI`和`DI`里面，然后调用了`main` 函数，同时我们也看到`argv`和`argc`是位于`SP`上的，也就说是属于栈变量，可以通过`SP`寄存器访问到。后续的`main`函数也非常简单，只是调用了`runtime·rt0_go`函数。好`runtime·rt0_go`函数相对复杂一些了，我们把这个函数拆成几个部分来解析。

`runtime·rt0_go`的第一部分：
```
MOVQ DI, AX		// argc
MOVQ	 SI, BX		// argv
SUBQ	 $(4*8+7), SP		// 2args 2auto
ANDQ	 $~15, SP
MOVQ	 AX, 16(SP)
MOVQ	 BX, 24(SP)
```
这里我前面存在`DI`和`SI`里面的`argv`和`argc`放到`AX`和`BX`里面去，然后我们腾出4个变量栈空间，同时把腾出的空间按照16字节对齐，然后把刚才的`AX`和`BX`里面的参数放到栈上。

`runtime·rt0_go`的第二部分比第一部分要复杂一些了：
```
// create istack out of the given (operating system) stack.
// _cgo_init may update stackguard.
MOVQ		$runtime·g0(SB), DI
LEAQ		(-64*1024+104)(SP), BX
MOVQ		BX, g_stackguard0(DI)
MOVQ		BX, g_stackguard1(DI)
MOVQ		BX, (g_stack+stack_lo)(DI)
MOVQ		SP, (g_stack+stack_hi)(DI)
```
首先把全局变量`runtime·g0`放到`DI`寄存器，这个变量定义在`proc1.go`文件里面，是一个`runtime.g`类型指针，相信看过[Part-3][4]对这个类型应该不陌生，系统会为每一个goroutine创建一个上下文，你应该也能猜到这个就是第一个gorountine的上下文，也就类似于主线程的线程上下文。后面的汇编我们初始化`runtime.g0`的各个成员变量，在汇编里面`stack_lo`和`stack_hi`这两个大家要弄清楚他们的含义，他们是当前goroutine的栈的起始地址和结束地址，汇编里面还有两个`g_stackguard0`和`g_stackguard1`变量，他们分别是搞什么黑科技的呢？要搞清楚这两个变量，我们要要先暂停`runtime·rt0_go`函数的探讨，然后专门讨论一下Go的真正黑科技`resizable stacks`动态栈。

## 实现动态栈`resizable stacks`

Go语言使用一项叫做动态栈的技术，每次一个goroutine启动的时候只会分配一个很小的栈`_StackMin = 2048`，这个栈的大小会在每次函数调用的时候做检查，当达到一定阀值的时候，就调整栈的大小。为了详细了解这个过程我们继续对前面的示例程序做编译`go tool compile -S test.go`，生成相关汇编代码。编译后main函数对应的汇编代码应该是这样的：
```
"".main t=1 size=48 value=0 args=0x0 locals=0x8
	0x0000 00000 (test.go:3)	TEXT	"".main+0(SB),$8-0
	0x0000 00000 (test.go:3)	MOVQ	 (TLS),CX
	0x0009 00009 (test.go:3)	CMPQ 	SP,16(CX)
	0x000d 00013 (test.go:3)	JHI	,22
	0x000f 00015 (test.go:3)	CALL	,runtime.morestack_noctxt(SB)
	0x0014 00020 (test.go:3)	JMP	,0
	0x0016 00022 (test.go:3)	SUBQ		$8,SP
```
首先我们把TLS(前面[Part-3][4]已经对TLS做过说明)里面的变量放到寄存器`CX`。我们知道TLS里面的变量存储的是一个指向`runtime.g`类型的指针，然后我们比较`SP`栈指针与`runtime.g`结构体偏移为16字节的变量，也就是比较栈栈指针和`runtime.g.stackguard0`字段。
这个就是进行栈大小比较的相关代码，这里我们检查当前栈是否达到了给定的阀值，如果空间不够则调用函数`runtime.morestack_noctxt`获取更多空间，然后跳转到`JMP	,0`继续做栈空间的检查。注意：关于顶部的一段描述`TEXT	"".main+0(SB),$8-0`这里其实已经说明了函数对栈空间的要求，`$8-0`是说函数体的栈空间需求是8个字节，函数的参数包含返回值对栈的空间需求是0。
这里可以进一步查看一下[stack.go][6]的具体Layout：
```
// Stack frame layout
//
// (x86)
// +------------------+
// | args from caller |
// +------------------+ <- frame->argp
// |  return address  |
// +------------------+
// |  caller's BP (*) | (*) if framepointer_enabled && varp < sp
// +------------------+ <- frame->varp
// |     locals       |
// +------------------+
// |  args to callee  |
// +------------------+ <- frame->sp
//
// (arm)
// +------------------+
// | args from caller |
// +------------------+ <- frame->argp
// | caller's retaddr |
// +------------------+ <- frame->varp
// |     locals       |
// +------------------+
// |  args to callee  |
// +------------------+
// |  return address  |
// +------------------+ <- frame->sp
```
以及 stack的定义：
```
// Stack describes a Go execution stack.
// The bounds of the stack are exactly [lo, hi),
// with no implicit data structures on either side.
type stack struct {
	lo uintptr
	hi uintptr
}
```
知道栈顶指针指向区间段[lo, hi)，已经使用的空间可以通过`used := old.hi - gp.sched.sp`计算得到，那么当前栈的空闲空间是`space := gp.stackAlloc-used`，但可被使用的空闲空间其实是要除掉一部分系统保留区域`StackGuard`，也就是说栈的阀值：`runtime.g.stackguard0 == runtime.stack.lo+StackGuard`。其实关于栈的阀值还有一个是`runtime.g.stackguard1`他是用于cgo里面动态调整栈用的，具体的用法跟这里类似。关于调整栈大小的函数`runtime.morestack_noctxt`其实也是一个值得说一说的函数，后续篇幅中我们再来聊这个，我们这里抓紧回到主线继续讨论启动引导过程。

## 继续Go的Bootstrapping过程
我们看`runtime.rt0_go`函数的第三部分：
```
	// find out information about the processor we're on
	MOVQ	$0, AX
	CPUID
	CMPQ	AX, $0
	JE	nocpuinfo

	// Figure out how to serialize RDTSC.
	// On Intel processors LFENCE is enough. AMD requires MFENCE.
	// Don't know about the rest, so let's do MFENCE.
	CMPL	BX, $0x756E6547  // "Genu"
	JNE	notintel
	CMPL	DX, $0x49656E69  // "ineI"
	JNE	notintel
	CMPL	CX, $0x6C65746E  // "ntel"
	JNE	notintel
	MOVB	$1, runtime·lfenceBeforeRdtsc(SB)
notintel:

	MOVQ	$1, AX
	CPUID
	MOVL	CX, runtime·cpuid_ecx(SB)
	MOVL	DX, runtime·cpuid_edx(SB)
nocpuinfo:
```
这一部分对于理解整个Go的启动引导过程不是非常关键，而且汇编里面的注释也基本进行了有效的自说明，我们这里只是单纯过一遍。代码开始部分主要是找出当前的CPU架构，如果是Intel架构，则设置变量`runtime·lfenceBeforeRdtsc`为1，这个变量主要是用在函数`runtime·cputicks`里面，在这个函数里面根据这个变量用不同的汇编代码去获取CPU的`ticks`，后面的汇编代码则执行了一个汇编指令`CPUID`然后把结果保存在`runtime.cpuid_ecx`和`runtime.cpuid_edx`里面，这里存储的数值主要是用来根据不同的cpu架构选择我们使用什么样的hash算法。

继续探索`runtime.rt0_go`函数的第四部分：
```
// if there is an _cgo_init, call it.
MOVQ	_cgo_init(SB), AX
TESTQ	AX, AX
JZ	needtls
// g0 already in DI
MOVQ	DI, CX	// Win64 uses CX for first parameter
MOVQ	$setg_gcc<>(SB), SI
CALL	AX

// update stackguard after _cgo_init
MOVQ	$runtime·g0(SB), CX
MOVQ	(g_stack+stack_lo)(CX), AX
ADDQ	$const__StackGuard, AX
MOVQ	AX, g_stackguard0(CX)
MOVQ	AX, g_stackguard1(CX)

CMPL	runtime·iswindows(SB), $0
JEQ ok
```
第四部分是只有开启了`cgo`支持的情况下才会执行，好`cgo`又是一个比较独立的主题，在后面的讨论中我们会单独探讨。这里我们还是抓主线，搞清楚Bootstrapping过程，所以我们这里依然跳过这一部分。

来到`runtime.rt0_go`函数的第五部分，这一部分主要是关于初始化TLS的：
```
needtls:
	// skip TLS setup on Plan 9
	CMPL	runtime·isplan9(SB), $1
	JEQ ok
	// skip TLS setup on Solaris
	CMPL	runtime·issolaris(SB), $1
	JEQ ok

	LEAQ	runtime·tls0(SB), DI
	CALL	runtime·settls(SB)

	// store through it, to make sure it works
	get_tls(BX)
	MOVQ	$0x123, g(BX)
	MOVQ	runtime·tls0(SB), AX
	CMPQ	AX, $0x123
	JEQ 2(PC)
	MOVL	AX, 0	// abort
```
前面我们提到过好几次TLS(thread-local-storage)，好这里我们将直面TLS的实现问题。


## TLS的实现细节
前面关于tls的汇编代码里面，如果过滤一下，我们不难发现真正干事情应该就只有如下两行汇编：
```
	LEAQ		runtime·tls0(SB), DI
	CALL		runtime·settls(SB)
```
其他汇编指令都是用于检测系统架构是否支持tls，如果不支持则跳过这部分或者如果支持，则检查tls环境是否工作正常。上面真正干事情的两行汇编第一行`LEAQ		runtime·tls0(SB), DI`把`runtime.tls0`存入`DI`寄存器，第二行`CALL		runtime·settls(SB)`调用了一个函数`runtime.settls`。真正的猫腻都在这个函数里面了，我们继续深入函数：
```
// set tls base to DI
TEXT runtime·settls(SB),NOSPLIT,$32
	ADDQ		$8, DI	// ELF wants to use -8(FS)

	MOVQ		DI, SI
	MOVQ		$0x1002, DI	// ARCH_SET_FS
	MOVQ		$158, AX	// arch_prctl
	SYSCALL
	CMPQ		AX, $0xfffffffffffff001
	JLS		2(PC)
	MOVL		$0xf1, 0xf1  // crash
	RET
```
从汇编代码我们容易看到，它其实主要是用参数`ARCH_SET_FS`，调用了一个系统函数`arch_prctl`，而这个系统调用其实是设置`FS`段寄存器的基址，对应到我们这里的情形，我们设置TLS指向`runtime.tls0`变量。
是否还记得前面我们讨论`main`函数的时候，开始有一段这样的汇编：

	0x0000 00000 (test.go:3)	MOVQ		(TLS),CX

前面我们说过，这个指令他会把一个指向`runtime.g`的指针移动到寄存器`CX`里面，而这个指针正是当前goroutine的上下文，结合前面的说明，我们能基本猜测到上面的伪汇编会翻译成什么样的机器代码，我们依然从前面解析的`disassemble.txt`文件里面去查证我们的猜测，我们找到`main.main`这个函数，它的第一条机器指令是：

	400c00:       64 48 8b 0c 25 f0 ff    mov    %fs:0xfffffffffffffff0,%rcx
	
上面机器指令里面的冒号代表的是段寻址，也就是我们的`runtime.g`的指针位于段基址，我们通过访问端基址就可以得到当前的tls上下文，关于段寻址更多详细的背景知识可以阅读[这里][7]。

## 继续Bootstrapping过程
函数`runtime.rt0_go`函数还剩下两部分，我们继续看接下来的：
```
ok:
	// set the per-goroutine and per-mach "registers"
	get_tls(BX)
	LEAQ		runtime·g0(SB), CX
	MOVQ		CX, g(BX)
	LEAQ		runtime·m0(SB), AX

	// save m->g0 = g0
	MOVQ		CX, m_g0(AX)
	// save m0 to g0->m
	MOVQ		AX, g_m(CX)
```
先把tls的地址放到BX寄存器，然后把`runtime.g`的指针保持到tls里面去，然后继续初始化`runtime.m0`，如果`runtime.g0`代表的主goroutine，那么`runtime.m0`代表就是主线程了。后面的文章我们可以对`runtime.g0`和`runtime.m0`的结构体做详细的解读。

函数`runtime.rt0_go`的最后一部分依然是初始化相关参数，并调用一些其他的函数，关于启动引导过程，我们已经讨论很大一部分了，我们先花些时间消化一下，我们把这最后的一部分拿到下一章节再单独探讨。

## 还有啥？
经过前面的探讨，我们知道了动态栈是怎么实现的，我们也搞清楚了tls的实现，关于启动引导过程，还剩下最后一部分，我们下一节马上探讨这个。




[1]: http://blog.altoros.com/golang-internals-part-5-runtime-bootstrap-process.html "Part 5: the Runtime Bootstrap Process"
[2]: https://golang.org/doc/asm "Go's Assembler"
[3]: https://golang.org/src/runtime/rt0_linux_amd64.s "rt0_linux_amd64"
[4]: https://github.com/JerryZhou/golang-doc/blob/master/Golang-Internals/Part-3.The.Linker.Object.Files.and.Relocations.md "Part-3.The.Linker.Object.Files.and.Relocations"
[5]: http://blog.rootk.com/post/golang-asm.html "golang-asm"
[6]: https://github.com/golang/go/blob/master/src/runtime/stack.go "stack"
[7]: http://thestarman.pcministry.com/asm/debug/Segments.html "Segments:OFFSET-Addressing"
