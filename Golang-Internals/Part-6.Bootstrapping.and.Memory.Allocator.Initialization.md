# 深入浅出 Golang，第五部分：启动过程以及内存分配器的初始化 [Part 6: Bootstrapping and Memory Allocator Initialization][1]

本文关注的依然是启动过程，了解整个启动过程对理解Golang运行时非常关键的。前面的小节已经讨论了一部分，这里讨论剩下的部分，这一部分会有非常多的运行时函数调用，我们会对一些重点函数进行讲解。

## 启动序列
上一小节关于`runtime.rt0_go`函数我们还剩下一小节：
```
CLD                         // convention is D is always left cleared
CALL    runtime·check(SB)

MOVL    16(SP), AX          // copy argc
MOVL    AX, 0(SP)
MOVQ    24(SP), AX          // copy argv
MOVQ    AX, 8(SP) 
CALL    runtime·args(SB)
CALL    runtime·osinit(SB)
CALL    runtime·schedinit(SB)
```
第一个汇编指令`CLD`是清除方向寄存器`FLAGS`，[方向寄存器][2]控制字符串的处理方式。第二条指令是调用了一个函数`runtime.check`，这个函数主要是Golang內建的类型int、string等做一些必要的校验，如果失败就会`panic`，这个函数对于整个过程也不是非常关键，我们不展开，可以在这个[地方][3]了解到详细的内容。后面部分的汇编主要就是初始化命令行参数，并调用了几个有些意思的初始化函数，我们对这几个函数分开解析。

## `runtime.args`参数分析
函数`runtime.args`这个其实不像字面的这么简单，在Linux上，这个函数除了把`argc`和`argv`存到静态变量里面外，他还负责解析`ELF`[PE-ELF][Executable and Linkable]头，并初始化系统调用的地址。
对于这个可能要稍微解释一下，当操作系统将一个可执行的文件加载进内存的时候，系统会初始化一个初始的可执行栈，然后根据执行镜像的头初始化一些预先定义好的格式化数据，这个可执行栈的顶部区域会存放环境变量相关的参数，同时会把ELF的辅助信息放到可执行栈的底部，如下的代码段所示：
```
position            content                     size (bytes) + comment
  ------------------------------------------------------------------------
  stack pointer ->  [ argc = number of args ]     4
                    [ argv[0] (pointer) ]         4   (program name)
                    [ argv[1] (pointer) ]         4
                    [ argv[..] (pointer) ]        4 * x
                    [ argv[n - 1] (pointer) ]     4
                    [ argv[n] (pointer) ]         4   (= NULL)

                    [ envp[0] (pointer) ]         4
                    [ envp[1] (pointer) ]         4
                    [ envp[..] (pointer) ]        4
                    [ envp[term] (pointer) ]      4   (= NULL)

                    [ auxv[0] (Elf32_auxv_t) ]    8
                    [ auxv[1] (Elf32_auxv_t) ]    8
                    [ auxv[..] (Elf32_auxv_t) ]   8
                    [ auxv[term] (Elf32_auxv_t) ] 8   (= AT_NULL vector)

                    [ padding ]                   0 - 16

                    [ argument ASCIIZ strings ]   >= 0
                    [ environment ASCIIZ str. ]   >= 0

  (0xbffffffc)      [ end marker ]                4   (= NULL)

  (0xc0000000)      < bottom of stack >           0   (virtual)
```
关于ELF辅助信息(ELF auxiliary vector)可以通过阅读[这篇文章][5]加深了解。

函数`runtime.args`会负责解析整个elf，但Golang主要关注的是一个字段`startupRandomData`，Go用这个字段来驱动hash函数，并初始化一些系统调用函数的地址。下面的三个函数就是在这个阶段初始化的：
```
__vdso_time_sym 
__vdso_gettimeofday_sym 
__vdso_clock_gettime_sym
```
上面的函数是用来获取各种单位的时间，这三个函数都有默认的实现，Golang通过`vsyscall`的方式调用上述的函数。

- - -

## `runtime.osinit`系统相关的初始化
下一个初始化阶段调用的函数就是`runtime.osinit`，在linux上，这个函数主要干的一个事情就是通过系统调用获取当前机器的cpu个数，并保存到变量`ncpus`里面。

- - -

## `runtime.schedinit`初始化调度器
接下来的[这个函数][6]做的事情比前面的`runtime.osinit`要多一些，他会先获取当前goroutine的上下文`runtime.g`的指针，前面关于tls的讨论里面我们已经多次涉及到这个东东了；然后如果开启了竞争检测，会调用函数[`runtime.raceinit`][7]，但这个函数通常都不会调用，我们跳过这个；过完这个函数后，紧接着又是一系列的函数调用：
```
	sched.maxmcount = 10000

	// Cache the framepointer experiment.  This affects stack unwinding.
	framepointer_enabled = haveexperiment("framepointer")

	tracebackinit()
	moduledataverify()
	stackinit()
	mallocinit()
	mcommoninit(_g_.m)

	goargs()
	goenvs()
	parsedebugvars()
	gcinit()
```
我们对上面的函数一个一个进行解析。

### 栈回溯初始化`tracebackinit`
函数`runtime.tracebackinit`这个[函数][8]让我们有能力可以进行调用栈的回溯，这个调用栈保存了从当前goroutine启动到当前函数的完整执行路径，任何时候发生`panic`，我们都可以通过`runtime.gentraceback`[获取当前的调用栈][9]，当然这个调用栈里面我们不需要列出一些我们不需要关注的內建函数调用，而函数`runtime.tracebackinit`就是做这个事情，把我们不需要关注的內建函数地址初始化，后续栈追踪的时候去掉这些內建函数。

### 符号验证`moduledataverify`
符号是链接器生成的，这个函数用于验证这些数据的一致性。关于链接器，我们第三篇文章[Golang Internals, Part 3: The Linker, Object Files, and Relocations][10]有重点讨论这个，对于运行时来说，一个符号会对应到一个`moduledata`[结构体][11]，函数`runtime.moduledataverify`会验证这个可执行镜像的所有符号的一致性，如果二进制被篡改就会`panic`。
```
type moduledata struct {
	pclntable    []byte
	ftab         []functab
	filetab      []uint32
	findfunctab  uintptr
	minpc, maxpc uintptr

	text, etext           uintptr
	noptrdata, enoptrdata uintptr
	data, edata           uintptr
	bss, ebss             uintptr
	noptrbss, enoptrbss   uintptr
	end, gcdata, gcbss    uintptr

	typelinks []*_type

	modulename   string
	modulehashes []modulehash

	gcdatamask, gcbssmask bitvector

	next *moduledata
}
```

### 初始化动态栈的分配池`stackinit`
要理解这一部做的事情，要先有一个背景知识，在Golang里面会开始为每一个goroutine分配一个容量比较小的栈，当这个栈的使用量达到某个阀值的时候就会扩容，运行时会从新分配一个两倍大小的栈，然后把原有栈里面的内容拷贝到新的栈里面，然后把新的栈赋值给这个goroutine。
当然前面我们还是比较初略的讲的，这里面还是有很多细节的，比如Golang是怎么判断栈达到阀值的，然后申请新的栈后，怎么调整栈里面的指针让这个新栈可以继续有效的使用等等，在前面的博文里面我们也讨论了这个问题，关于这个主题读者可以从[这篇文章][12]里面获取更多详细的内容。
对于栈的管理，Golang使用一个缓冲池来管理，Golang会在`runtime.stackinit`[函数][13]里面初始化这个，这个池是一个数组，数组的每一项都是栈的列表，同一个列表的栈的容量是一样的。另外一个在这个函数里面初始化的变量是`runtime.stackFreeQueue`，这也是一个栈的列表，这个列表在垃圾回收的过程中，会把需要回收的栈加入到这个列表，然后在垃圾回收结束的时候，释放这个列表上的所有栈。注意：这里栈的缓冲池只管理2Kb、4Kb、8Kb大小的栈，更大的栈通过直接分配释放来管理。

### 初始化内存分配器 `mallocinit`
内存分配器是基于`tcmalloc`，Golang 会在函数`runtime.mallocinit`里面初始化它，如果想理解这个分配器，强烈建议读者阅读[代码注释][14]里面提到的[这篇文章][15]，我们这里对分配器初始化函数做进一步的探讨：
```
func mallocinit() {
	initSizes()

	if class_to_size[_TinySizeClass] != _TinySize {
		throw("bad TinySizeClass")
	}

	var p, bitmapSize, spansSize, pSize, limit uintptr
	var reserved bool

	// limit = runtime.memlimit();
	// See https://golang.org/issue/5049
	// TODO(rsc): Fix after 1.1.
	limit = 0

	// Set up the allocation arena, a contiguous area of memory where
	// allocated data will be found.  The arena begins with a bitmap large
	// enough to hold 4 bits per allocated word.
	if ptrSize == 8 && (limit == 0 || limit > 1<<30) {
		// On a 64-bit machine, allocate from a single contiguous reservation.
		// 512 GB (MaxMem) should be big enough for now.
		
		arenaSize := round(_MaxMem, _PageSize)
		bitmapSize = arenaSize / (ptrSize * 8 / 4)
		spansSize = arenaSize / _PageSize * ptrSize
		spansSize = round(spansSize, _PageSize)
		for i := 0; i <= 0x7f; i++ {
			switch {
			case GOARCH == "arm64" && GOOS == "darwin":
				p = uintptr(i)<<40 | uintptrMask&(0x0013<<28)
			case GOARCH == "arm64":
				p = uintptr(i)<<40 | uintptrMask&(0x0040<<32)
			default:
				p = uintptr(i)<<40 | uintptrMask&(0x00c0<<32)
			}
			pSize = bitmapSize + spansSize + arenaSize + _PageSize
			p = uintptr(sysReserve(unsafe.Pointer(p), pSize, &reserved))
			if p != 0 {
				break
			}
		}
	}

	if p == 0 {
		
		arenaSizes := []uintptr{
			512 << 20,
			256 << 20,
			128 << 20,
		}

		for _, arenaSize := range arenaSizes {
			bitmapSize = _MaxArena32 / (ptrSize * 8 / 4)
			spansSize = _MaxArena32 / _PageSize * ptrSize
			if limit > 0 && arenaSize+bitmapSize+spansSize > limit {
				bitmapSize = (limit / 9) &^ ((1 << _PageShift) - 1)
				arenaSize = bitmapSize * 8
				spansSize = arenaSize / _PageSize * ptrSize
			}
			spansSize = round(spansSize, _PageSize)

			
			p = round(firstmoduledata.end+(1<<18), 1<<20)
			pSize = bitmapSize + spansSize + arenaSize + _PageSize
			p = uintptr(sysReserve(unsafe.Pointer(p), pSize, &reserved))
			if p != 0 {
				break
			}
		}
		if p == 0 {
			throw("runtime: cannot reserve arena virtual address space")
		}
	}

	// PageSize can be larger than OS definition of page size,
	// so SysReserve can give us a PageSize-unaligned pointer.
	// To overcome this we ask for PageSize more and round up the pointer.
	p1 := round(p, _PageSize)

	mheap_.spans = (**mspan)(unsafe.Pointer(p1))
	mheap_.bitmap = p1 + spansSize
	mheap_.arena_start = p1 + (spansSize + bitmapSize)
	mheap_.arena_used = mheap_.arena_start
	mheap_.arena_end = p + pSize
	mheap_.arena_reserved = reserved

	if mheap_.arena_start&(_PageSize-1) != 0 {
		println("bad pagesize", hex(p), hex(p1), hex(spansSize), hex(bitmapSize), hex(_PageSize), "start", hex(mheap_.arena_start))
		throw("misrounded allocation in mallocinit")
	}

	// Initialize the rest of the allocator.
	mHeap_Init(&mheap_, spansSize)
	_g_ := getg()
	_g_.m.mcache = allocmcache()
}
```

#### 初始化类大小
函数`runtime.mallocinit`第一个做的事情就是调用函数`runtime.initSizes`[初始化][16]一个类大小的数组，这个负责预先计算一系列的类大小，这些小的内存块主要应对的是小于32Kb的小对象的分配。对于new一个对象的时候，Go会把申请的大小round到一个固定大小，这个大小会大于等于需要申请的内存大小，当然这样也就导致一部分内存浪费，但是也让不同类型的对象能够共享内存块，提高内存利用率。我们大概贴一下这个函数的关键部分：
```
 	align := 8
	for size := align; size <= _MaxSmallSize; size += align {
		if size&(size-1) == 0 { 
			if size >= 2048 {
				align = 256
			} else if size >= 128 {
				align = size / 8
			} else if size >= 16 {
				align = 16 
…
			}
		}
```
从代码里面可以看到最小的两个类别大小是8字节和16字节，这里会分为四组对齐方式:
1. [0,16)大小的内存采用8字节对齐
2. [16, 128)大小的内存采用16字节对齐的方式
3. [128, 2048)大小的内存采用size/8字节对齐的方式
5. [2048, -)大小的内存采用256字节对齐的方式
函数`runtime.initSizes`会初始化`class_to_size`[数组][17]，这个数组建立类别与大小的关系，每一个列表对应到一个内存的大小，这里的类别也就是`class_to_size`数组的下标；同时这个函数还会初始化[数组][18]`class_to_allocnpages`，这个数组存储的是类别对应的内存页面数，也就是当前类别对应大小，映射到系统这边需要分配的内存页的数目。从一个内存大小转换到类别，有两个辅助数组`class_to_size8`和`class_to_size128`，这两个数组分别负责[0, 1Kb], 以及[1Kb, 32Kb]的内存分类。

#### 保留部分虚拟内存
函数`runtime.mallocinit`干的另外一个事情就是申请虚拟内存，加快后续的内存分配。我们看下在x64体系下是怎么做的，首先初始化如下的变量：
```
arenaSize := round(_MaxMem, _PageSize)
bitmapSize = arenaSize / (ptrSize * 8 / 4)
spansSize = arenaSize / _PageSize * ptrSize
spansSize = round(spansSize, _PageSize)
```
* arenaSize: 是保留的最大虚拟内存，在x64架构上是512Gb
* bitmapSize: 是GC的辅助位图需要保留的总的内存大小，这个内存位图是一块特殊的内存，这块内存会记录那些地方存放了对象指针，以及指针对象是否已经被标记
* spansSize：是存储Memory-Span指针数组所需要的总的内存大小。而Memory-Span是Golang里面对象内存分配器使用的原始内存区块

上述的内存大小计算好后，系统需要保留的总的内存大小可以如下计算得到：
```
pSize = bitmapSize + spansSize + arenaSize + _PageSize  
p = uintptr(sysReserve(unsafe.Pointer(p), pSize, &reserved)) 
```
最后我们初始化全局变量`mheap_`，这个是所有内存释放的中心存储器，所有内存分配都是在这个堆对象上进行。
```
p1 := round(p, _PageSize)

mheap_.spans = (**mspan)(unsafe.Pointer(p1))
mheap_.bitmap = p1 + spansSize
mheap_.arena_start = p1 + (spansSize + bitmapSize)
mheap_.arena_used = mheap_.arena_start
mheap_.arena_end = p + pSize
mheap_.arena_reserved = reserved
```
注意到：在堆变量初始化里面我们把`mheap_.arena_used `设置为`mheap_.arena_start`，因为在开始的时候我们还没有发生任何内存分配。

#### 初始化堆
下一个被调用的[函数][19]是`mHeap_Init`，这个函数里面第一个做的事情是内存分配器的初始化：
```
fixAlloc_Init(&h.spanalloc, unsafe.Sizeof(mspan{}), recordspan, unsafe.Pointer(h), &memstats.mspan_sys)
fixAlloc_Init(&h.cachealloc, unsafe.Sizeof(mcache{}), nil, nil, &memstats.mcache_sys)
fixAlloc_Init(&h.specialfinalizeralloc, unsafe.Sizeof(specialfinalizer{}), nil, nil, &memstats.other_sys)
fixAlloc_Init(&h.specialprofilealloc, unsafe.Sizeof(specialprofile{}), nil, nil, &memstats.other_sys)
```
要理解内存分配器是什么？要先看下内存分配器[是怎么使用的][20]`fixAlloc_Alloc`，每一次需要申请创建[mspan][21]、[mcache][22]、[specialfinalizer][23]或者[specialprofile][24]结构体都需要调用到这个函数`fixAlloc_Alloc`，在这个内存分配器的分配函数里面主要的一段代码如下所示：
```
   	if uintptr(f.nchunk) < f.size {
		f.chunk = (*uint8)(persistentalloc(_FixAllocChunk, 0, f.stat))
		f.nchunk = _FixAllocChunk
	}
```
对于一个分配器来说，他不是直接从系统申请给定大小`f.size`的内存，而是先通过`persistentalloc`申请一个`_FixAllocChunk`(现在是16Kb)的内存，然后把部分内存返回给调用者，把剩下的存在挂载到分配器上，下次通过同样的分配器申请内存的时候就可以直接使用这些余留的内存，这样避免每次调用`persistentalloc`函数带来的开销，`persistentalloc`函数大家也可以看出来，通过这个函数申请的内存是不参与GC的，上述的过程如下代码所示：
```
	v := (unsafe.Pointer)(f.chunk)	// 返回需要的内存大小
	if f.first != nil {
		fn := *(*func(unsafe.Pointer, unsafe.Pointer))(unsafe.Pointer(&f.first))
		fn(f.arg, v)
	}
	f.chunk = (*byte)(add(unsafe.Pointer(f.chunk), f.size)) // 剩下的内存继续放到分配器上
	f.nchunk -= uint32(f.size)
	f.inuse += f.size	// 记录这块已经使用的大小
	return v
```
其中函数`persistentalloc`的内存申请流程是如下：

1. 如果申请的内存大小操过64Kb，则直接从OS申请
2. 否则找一个合适的持久化分配器来处理内存分配
	* 每一个CPU-内核都会绑定一个持久分配器，这样我们就避免了在分配器上加锁的操作，我们需要做的就是获取当前处理器对应的分配器
	* 如果找不到当前处理器对应的分配器，则我们使用一个全局的分配器
3. 如果当前分配器的内存缓存区域已经不够分配这次内存申请，则先从OS申请更多内存
4. 确保分配器的缓冲区的内存足够后，我们从分配器的缓冲区分配内存区块给到使用者


函数`persistentalloc`和函数`fixAlloc_Alloc`他们的机制是基本类似的，我们也可以这样理解，他们分别提供了不同层面的内存缓存机制。当然`persistentalloc`函数不仅仅在`fixAlloc_Alloc`函数里面使用，任何其他需要申请持久内存的地方都会使用到它。

好，我们把焦点移回到函数`mHeap_Init`身上，在前面初始化分配器的时候，我们初始化了4类结构体的分配器，这对于是4类结构体他们的作用分别是什么呢，我们这里就来分别介绍一下这些结构体的作用：

* `mspan`这个结构体封装了用于被垃圾回收的内存块，前面讨论`size_to_class`的时候我们有提到这个，需要申请某一种大小的内存的时候，我们会创建一个相应的`mspan`作为这种大小的内存申请的缓冲区。
* `mcache`这个是`mspan`的缓冲区，会为每一个CPU的核准备一个`mcache`，这样也可以避免内存分配的时候上锁
* `specialfinalizer`这个是调用函数`runtime.SetFinalizer`时候分配的结构体，这个结构体里面存储的信息让我们有能力在某一个对象被垃圾回收的时候，我们顺带着做一些自定义的回收操作，一个典型的例子就是创建文件对象`os.NewFile`，每一个文件对象都会通过调用`runtime.SetFinalizer`关联一个析构结构体，当这个文件对象被垃圾回收的时候，我们调用系统函数关闭相应的文件描述符。
* `specialprofile`这个是做性能分析的时候创建的结构体，这里暂时不多聊

初始化好这些内存分配器后，`mHeap_Init`后面通过[调用][25]`mSpanList_Init`初始化一些列表结构，`mheap`本身还是包含蛮多列表的。

* `mheap.free`和`mheap.busy`包含的是大于32Kb小于1Mb的`mspan`数组，这里的大小是内存页的数目，一个内存页是32Kb，这里数组的一个等差数组，第一个元素包含的是32Kb的span列表，第二个元素包含的就是64Kb的span列表，以此类推。
* `mheap.freelarge`和`mheap.busylarge` 是处理大于1Mb的`mspan`，机制与上一致

下一个初始化的是`mheap.central`，这里存储的是小于32Kb的`mspan`，在`mheap.central`也是按照大小分组。

#### 最后的内存初始化操作
在函数`mallocinit`里面关于内存初始化还有最后一个东西，`mcache`的初始化：

	_g_ := getg()
	_g_.m.mcache = allocmcache()

首先获取goroutine，然后申请一个`mcache`赋值给`g.m.mcache`，函数`allocmcache`会调用`fixAlloc_Alloc`初始化一个新的`mcache`结构体。细心的读者可能也注意到，前面我们提到`mcache`会绑定到处理器，但这里又把`mcache`关联到了goroutine，goroutine对应到到的是系统的处理单元，类似线程的概念。是的这里没有搞错，一个goroutine的`mcache`会在goroutine的相应执行单元切换也就是线程切换的时候进行调整，找到相应线程的`mcache`。

## 到底还有谁？

下一篇文章，我们依然紧靠启动引导过程，我们会关注GC是怎么初始化的，以及第一个goroutine是怎么启动起来的。


[1]: http://blog.altoros.com/golang-internals-part-6-bootstrapping-and-memory-allocator-initialization.html "Part 6: Bootstrapping and Memory Allocator Initialization"
[2]: https://en.wikipedia.org/wiki/Direction_flag "Direction_flag"
[3]: https://github.com/golang/go/blob/go1.5.1/src/runtime/runtime1.go#L136 "check"
[4]: https://en.wikipedia.org/wiki/Executable_and_Linkable_Format "Executable_and_Linkable_Format"
[5]: http://articles.manugarg.com/aboutelfauxiliaryvectors "elf auxiliary vectors"
[6]: https://github.com/golang/go/blob/go1.5.1/src/runtime/proc1.go#L40 "runtime.schedinit"
[7]: https://github.com/golang/go/blob/go1.5.1/src/runtime/race1.go#L110 "raceinit"
[8]: https://github.com/golang/go/blob/go1.5.1/src/runtime/traceback.go#L58 "traceback"
[9]: https://github.com/golang/go/blob/go1.5.1/src/runtime/traceback.go#L120 "gentraceback"
[10]: http://blog.altoros.com/golang-internals-part-3-the-linker-and-object-files.html "Part-3"
[11]: https://github.com/golang/go/blob/go1.5.1/src/runtime/symtab.go#L37 "moduledata"
[12]: https://docs.google.com/document/d/1wAaf1rYoM4S4gtnPh0zOlGzWtrZFQ5suE8qr2sD8uWQ/pub "continues stacks"
[13]: https://github.com/golang/go/blob/go1.5.1/src/runtime/stack1.go#L54 "stackinit"
[14]: https://github.com/golang/go/blob/go1.5.1/src/runtime/malloc.go#L5 "malloc-source-code"
[15]: http://goog-perftools.sourceforge.net/doc/tcmalloc.html "tcmalloc"
[16]: https://github.com/golang/go/blob/go1.5.1/src/runtime/msize.go#L66 "initSizes"
[17]: https://github.com/golang/go/blob/go1.5.1/src/runtime/msize.go#L49 "class_to_size array"
[18]: https://github.com/golang/go/blob/go1.5.1/src/runtime/msize.go#L50 "class_to_allocnpages array"
[19]: https://github.com/golang/go/blob/go1.5.1/src/runtime/mheap.go#L273 "mHeap_Init"
[20]: https://github.com/golang/go/blob/go1.5.1/src/runtime/mfixalloc.go#L54 "fixAlloc_Alloc"
[21]: https://github.com/golang/go/blob/go1.5.1/src/runtime/mheap.go#L101 "mspan"
[22]: https://github.com/golang/go/blob/go1.5.1/src/runtime/mcache.go#L11 "mcache"
[23]: https://github.com/golang/go/blob/go1.5.1/src/runtime/mheap.go#L1009 "specialfinalizer"
[24]: https://github.com/golang/go/blob/go1.5.1/src/runtime/mheap.go#L1050 "specialprofile"
[25]: https://github.com/golang/go/blob/go1.5.1/src/runtime/mheap.go#L863 "spanlist_init"

