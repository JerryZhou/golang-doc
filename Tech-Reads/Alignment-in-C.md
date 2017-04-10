## Alignment in C (Effiziente Programmierung in C)[0]

### Introduction
当代的处理器里面，内存操作是相对耗时的，所以，我们需要仔细关注内存的各种问题。这篇文章我们会重点描述两个层面的问题，第一个层面处理器是怎么处理内存寻址的，第二个层面数据结构体的对其怎么来最大化寻址性能。

#### Memory Addressing
现代计算机的寻址通常是基于word-sized-chunk为单元的寻址，一个word-sized-chunk是基本寻址单元，通常这个寻址单元的大小是由处理器的架构决定的。现代处理的寻址单元通常是4字节(32位处理器)或者8字节(64位处理器)。早期的计算机，也是只能以这个word-sized为基本单元，这样也就导致计算机的寻址只能寻址word-sized的整数倍的地址。不过这里也需要被注明的是，现代计算机通常是支持多种word-sizes寻址，也就是寻址单元可以从最小的一个字节到自然word-size，最新的处理器甚至可以处理16字节的chunk寻址，或者直接一条[指令处理]( References
[1] http://software.intel.com/en-us/articles/
increasing-memory-throughput-with-intel-streaming-simd-extensions-4-intel-sse4-)full-cache-line的单元(比较典型的缓存线大小是64字节)。先现在的UNIX机器上，我们可以通过如下的命令获取当前处理器的word-size：
* `getconf WORD_BIT`
* `getconf LONG_BIT`
  比如在`x86_64`的机器上，`WORD_BIT` 会返回32，`LONG_BIT`会返回64。在没有64-bit扩展的单纯x86机器上`WORD_BIT`和`LONG_BIT`都是32。

#### Alignment 101
内存对其对于计算机来说非常重要，前面我们已经说到，对于比较老的处理器他们是不能处理没有对其的数据的，对于现代的处理器会采取一些低效的办法来适配没有对其的数据，只有最近的个别计算机具备能力无差别的加载字节对其数据和非对其数据[misaligned-data](http://www.agner.org/optimize/blog/read.php?i=142&v=t)。下面我们有图来形象的表述字节对其是怎么回事：
|0x00000000|0x00000004|0x00000008|0x00000012|
| - - - -  | - - - -  | - - - -  | - - - -  |
Figure 1: 32位计算机上的4个word-sized 内存单元
比如要存储一个4字节的int(####int)到咱们内存里面，这个时候不需要做什么特殊的工作，因为在32位计算机上本身就是4字节对其，这样刚好把int放到一个word-sized单元里面，比如我们把int放到图1里面后的内存如下会如下所示：
|0x00000000|0x00000004|0x00000008|0x00000012|
|####(int) | - - - -  | - - - -  | - - - -  |
Firgure 2: 内存里面存放了一个4字节的int
如果我们决定要放一个char(#char), 一个short(##short), 和一个int(####int)到我们的内存里面，如果完全不考虑对其，只是把他无脑放到内存，那么内存的布局会是如下：
|0x00000000       |0x00000004 |0x00000008|0x00000012|
|#(char)##(short)#|###(int) -  | - - - -  | - - - -  |
Firgure 3: 没有内存对其的示范
如果按照上面的内存结构，我们加载一个int到处理器上面，需要进行两次内存寻址然后加上一些bitshifint操作才能完成这个，为了让这个加载操作更加高效，计算机科学家想处理一个主意就是在内存里面加上一些合适的padding，让数据与处理器的word-size对其。在我们前面的例子里面，如果我们在第一个字节(char)后面加上一个padding, 那么后面的数据就都进行合适的内存对其，布局如下：
|0x00000000       |0x00000004|0x00000008|0x00000012|
|#(char)-##(short)|####(int) | - - - -  | - - - -  |
Firgure 4: 通过在合适的地方加入padding达到内存对其的示例
上图中表达的其实是一种naturally-aligned, 这个行为是编译器自动为了达到内存对其会在相应的地方加入padding的一种特性，当然我们也可以显式的关闭这个特性。

#### Consequences of Misalignment
数据不对其问题导致的后果在不同的处理器上也不完全一样。在一些RISC、ARM、MIPS处理器上，如果我们进行misaligned-address访问会导致一个alignment-fault。对于一些个别处理器，比如SDP，通常是完全不支持对misaligned-address的访问的。当然大部分现代处理器都是支持对misaligned-address进行访问的，只是需要至少花费两倍的时间来处理这种不对其数据。对于SSE指令来说，指令本身是要求数据必须是对其的，如果给的是misaligned-address数据，那么指令的行为就会变得不可定义。

### Data Structure Alignment
这一小节，我们会通过一系列的小例子，介绍C语言里面结构体是怎么进行字节对其的。

#### Example With Structs
下面的结构体其实是Figure4里面的一个真实反映：
```
struct Foo {
    char x;     /* 1 byte  */
    short y;    /* 2 bytes */
    int z;      /* 4 bytes */
};
```
Listing 1: 需要padding进行对其的一个结构体定义
这个结构体的大小，如果没有进行对其的情况下应该是 1byte + 2 bytes + 4 bytes = 7 bytes，当然聪慧如读者的你肯定知道因为编译器会对结构体进行内存对其，上面的结构体实际的大小会是8字节。下面我们阐述结构体对齐的原则：
**一个结构体总是会对齐到最大的类型**
接下来我们根据上述的原则，我们看另外一个内存不友好的结构体定义：
```
struct Foo {
    char x;     /* 1 byte  */
    double y;   /* 8 bytes */
    char z;     /* 1 byte  */
};
```
Listing 2: 一个对齐不友好的结构体定义
这个结构体的没有对其的情况下应该是 1 byte + 8 bytes + 1 bytes. 然后他对其后的大小是 24 bytes。
我们可以通过对成员重新排列来优化这个结构体的内存占用：
```
struct Foo {
    char x;     /* 1 byte */
    char z;     /* 1 byte */
    double y;   /* 8 bytes*/
};
```
Listing 3: 一个通过重排来优化结构体内存占用的例子
在保持内存对其的情况下，现在这个结构体只暂用16个字节了。

#### Padding In The Real World
前面的段落，读者应该已经注意到，我们需要人工花一些精力关注C结构体的定义，当然在实际的开发过程中，现在的编译器都会根据当前的处理器架构自动处理padding问题，有一些编译器也会提供一些编译选项，比如`-Wpadded`会打印一些帮助信息，让开发者优化相关padding，达到高效的内存布局，比如如下的clang的例子：
```
clang -Wpadded -o example1 example1.c
example1.c:5:11: warning: padding struct
'struct Foo' with 1 byte to align 'y' [-Wpadded] short y;

1 warning generated.
```
Listing 4: clang 加参数 -Wpadded 产生的警告的例子
当如，如果你想关闭编译器的padding特性也是可以的，有如下的一些途径，比如方一个`__attribute__((packed))`在结构体定义后面，放一个 `#pragma pack (1)`在结构体定义前面，或者通过加一个编译器参数`-fpack-struct`。 这里需要特别提醒的是，如果进行上面的操作，那么这里会让应用程序产生一个[ABI](https://zh.wikipedia.org/wiki/%E5%BA%94%E7%94%A8%E4%BA%8C%E8%BF%9B%E5%88%B6%E6%8E%A5%E5%8F%A3)问题，我们需要在运行时检查一个结构体的sizeof信息，确保传入的参数是合法的。

#### Performance Implications
对于开发者来说，内存对齐带来的效率提升我们需要仔细的弄清楚其中的原委，是不是值得开发者花精力来做，或者我们可以完全忽略内存对其，因为效率提升不明显，我们通过购买更快的处理器就好了。当然要弄清楚其中的详细的情况，我们需要根据具体情况来做一些区分，比如内核开发，驱动开发，或者内存极其有限的系统上，或者在一些非常，非常古老的编译器上，这些情景与之关联的情况也都是不一样的。
 如果我们想知道什么时候我们可以不用管内存对其问题，那么我们先来弄清楚他对新能的影响到底是怎么样的，为了测试性能，我们这里用两个同样的结构体，一个是内存对其的，另外一个是不对其的。
 ```
 struct Foo {
     char x;
     short y;
     int z;
 };

 struct Foo foo;
 clock_gettime(CLOCK, &start);
 for (unsigned long i = 0; i < RUNS; ++i) {
     foo.z = 1;
     foo.z += 1;
 }
 clock_gettime(CLOCK, &end);
 ```
 Listing 5: 字节对其的结构体进行性能压力测试

 ```
 struct Bar {
     char x;
     short y;
     int z;
 } __attribute__((packed));

 struct Bar bar;

 clock_gettime(CLOCK, &start);
 for (unsigned long i = 0; i < RUNS; ++i) {
     bar.z = 1;
     bar.z += 1;
 }
 clock_gettime(CLOCK, &end);
 ```
Listing 6: Misaligned struct for the benchmark
压力测试的例子我们是用 gcc(GCC)4.8.2 20131219(prerelease)版本，通过如下的编译指令`gcc -DRUNS=400000000 -DCLOCK=CLOCK_MONOTONIC -std=gnu99 -O0`编译，然后运行在一台Intel Core i7-2670QM CPU的 Linux3.12.5上，性能测试的结果如下：
| aligned runtime: | unaligned runtime: |
| 9.504220399 s    | 9.491816620 s      |
我们会发现，两者的时间基本是一致的，这个测试的结果也已经在[参考文献]()里面提到了。在最近的Intel的处理器上，对于misaligned-memory的访问已经基本没有明显的性能影响，这个对于最新的其他处理器也基本是一致的，接下来我们继续在相对旧的处理器上进行试验。
我们在 Raspberry Pi的处理器上继续前面的试验，所以编译器，操作系统等都一样，只是我们这里把性能测试循环数减少到原来的十分之一，然后我们得到如下的结果：
|aligned runtime: | unaligned runtime: |
| 12.174631568s   | 26.453561832s      |
上面的结果其实更符合我们的预期，我们前面也提到过访问不对齐内容会有一个两倍的寻址加上一些bitshifting操作，这里的结果基本印证了我们前面文章里面提到的寻址模型。

#### SSE
以前，当使用SIMD指令的时候，比如SSE指令，我们通常会被要求代码要每一条SSE指令都要求的16字节边界对齐, 这里说的其实不仅仅要求数据结构要参照这个对齐，还要求指令stack本身也要参照这个进行边界对齐。对于交叉编译32位平台代码者确实会是一个[问题](http://www.peterstock.co.uk/games/mingw_sse/)，因为他本身也不知道应该进行对齐。在后面的小节里面，我们也会具体开到如果一个program调用一个库函数后，如果program和库本身他们的alignment是不一致的，这种情况下回发生什么事情。通常这种情况会导致崩溃。现在`x86_64`已经是主流的处理器，并且他的默认对其是16字节，这样导致的问题也就少了，但对于老的32位处理器来说，还是一个相对普遍的问题。
 现在很多编译器即使在32位处理器上，当使用类似`__m128`等SIMD类的指令的时候，他们也自动把字节对其到16字节。更现代的编译器，他们甚至根本不需要开发者去显式的通过`__m128`等手段告诉编译器，编译器它自动就会对一些类型的循环向量化，让指令在边界处于对其状态，虽然这个时候的对其是没有神马显式的依据。

### Stack Alignment
前面咱们已经提到了不同的平台有不同的stack-alignment，读者需要知道主流平台的对其规则：
 1. Linux : 看情况，以前的是 4字节对齐，现代的是16字节对齐
 2. Windows : 4 字节对齐
 3. OSX: 16字节对齐
    清晰上面的stack-alignment非常重要，因为混合的stack-alignment通常会导致非常严重的问题。

考虑如下的情况：
```
void foo() {
    struct MyType bar;
}
```
上述的函数以及其中的结构体看起来都非常简单，考虑如下的情况，如果上面的函数是用16字节对齐编译生成的库函数，然后我们在4字节对其的`program`里面来调用这个函数会导致什么呢？当然这个行为会导致`stack-corruption`，因为栈指针端了12个字节或者说离真正的指令还有12个字节。
在现实情况中，上面的问题很少发生，如果真的发生了，这种崩溃也很难查证，如果开发者对字节对其的这个问题没有意思的话，就更不可能发现其中的问题了。这个问题再这里抛出的一个点是，提醒大家在做一些跨架构调用的地方需要特别注意，我们需要做`stack-realignment`. 在gcc或者clang里面，我们可以通过在函数上面加上属性`__attribute__((force_align_arg_pointer))`或者用编译器参数`-mstackrealign`来一次性应用到所有函数。虽然这个可以解决这个问题，但读者也要知道这里面其实是对函数加了一层调用路由的`realignment intro/outro`，这一层路由会确保函数的`stack-pointer`会按照调用方预期的传递。

### Conclusion
结论，现在的编译器在通过padding的方式尽力优化数据结构, 提升效率，这种效率提升是以牺牲内存占用为代价的。但是通过前面我们的性能测试的例子，我们也关注到了，这种牺牲内存为代价或者潜在的性能提升的方法的收益甚微的。当然在一些老的处理器上字节对其带来的性能提升还是非常明显的。
 现在对于开发者来说还需要关注到的字节对齐问题，就是我们应该尽可能优化数据结构体，合理排序成员，尽可能少的浪费内存，生成内存紧凑的结构体。


### Reference
[0] https://wr.informatik.uni-hamburg.de/_media/teaching/wintersemester_2013_2014/epc-14-haase-svenhendrik-alignmentinc-paper.pdf
[1] http://software.intel.com/en-us/articles/increasing-memory-throughput-with-intel-streaming-simd-extensions-4-intel-sse4-
[2] http://www.agner.org/optimize/blog/read.php?i=142&v=t
[3] http://www.peterstock.co.uk/games/mingw_sse/ 

### 其他文献
https://msdn.microsoft.com/zh-cn/library/83ythb65.aspx
https://en.wikipedia.org/wiki/Data_structure_alignment
http://www.catb.org/esr/structure-packing/
http://www.cnblogs.com/clover-toeic/p/3853132.html
http://www.cnblogs.com/Dageking/archive/2013/03/11/2954394.html


