## Cache Memory [Wiki](https://en.wikipedia.org/wiki/Cache_memory)

在数据处理系统(常规意义上的[计算机](https://en.wikipedia.org/wiki/Computers)), 我们说的cache-memory 或者是 memory-cache (或者常规意义上的 [CPU](https://en.wikipedia.org/wiki/Central_processing_unit) 各级cache(`*`)) 是指一个快速存取能力的相对小的内存区域，这个内存区域对软件是不可见的，这块内存区域完全由硬件自己来负责管理，这块区域会存储[最近](https://en.wikipedia.org/wiki/Cache_replacement_policies#Examples "MRU")使用到的[主内存](https://en.wikipedia.org/wiki/Computer_data_storage#Primary_storage "MM")数据。cache-memory 的主要作用是用来__加速__MM数据的访问，并且用于在多核系统上共享内存，__减少[system-bus](https://en.wikipedia.org/wiki/System_bus "system-bus")和MM的通讯瓶颈__，通常system-bus和MM访问会是多核系统的一个主要性能瓶颈。 
Cache-Memory 会使用一项称为[SRAM](https://en.wikipedia.org/wiki/Static_random-access_memory "SRAM") (static random-access [memory cells](https://en.wikipedia.org/wiki/Memory_cell_(binary)))的技术，让Cache-Memory直接与处理器连接起来，这个技术是与MM的访问技术[DRAM](https://en.wikipedia.org/wiki/Dynamic_random-access_memory) 想对应的。

名词"cache"来自法语的(发音 /ˈkæʃ/cash/ (deprecated template)) and means "隐藏"。
这个名词根据上下文的不同会有多种不同的含义。比如: [disk-cache](https://en.wikipedia.org/wiki/Disk_buffer), [TLB](https://en.wikipedia.org/wiki/Translation_lookaside_buffer) (translation lookaside buffer) (Page Table cache), branch prediction cache, branch histroy table, Branch Address Cache, trace cache, 这些都是硬件的物理内存。另外也有很多是由软件进行管理的，比如用来存储MM内存空间的临时数据, 比如[disk-cache](https://en.wikipedia.org/wiki/Page_cache "page-cache"), system-cache, application cache, database cache, web cache, [DNS cache](https://en.wikipedia.org/wiki/Name_server#Caching_name_server), browser cache, router cache, 等等。前面提到的这些cache，有些只是缓冲区"buffers", 他们只是支持顺序访问(__sequential-access__)的无关联的内存(__non-associative-memory__)，与最开始定义的那种典型的通过关联内存(associative-memory)机制，具备随机访问(__random-accesses__)能力的"memory-to-cache"不一样. 其实这里我们主要就是区分缓存(cache)和缓冲(buffer)两种内存访问机制。

- - -
名词 "cache memory" 或者 "memory cache" 如无特别说明我们简称为 "cache"，通常他指的就是存储了 [main-memory](https://en.wikipedia.org/wiki/Main_memory "MM")上马上要被处理器用到的，当前执行程序的指令"Instructions"以及相关数据"Data"的一块隐藏的内存区块。 
注意："CPU cache"这个名词在学术和工业领域都是用的相对少的表达方式，在美国的大量文献里面，名词"CPU cache"的使用率是 2%， 其中 "Cache Memory"的使用率是 83%, "Memory Cache"的使用率是 15%。
- - -

### Cache general definition
**"Cache" 是一个用来存储临时数据的内存区块，这个内存区块对上层使用者来说是透明的，他的主要目的是为了提供快速复用**

### Functional principles of the cache memory
Cache-Memory 操作基于两个主要的"principles of locality"[Locality of reference](https://en.wikipedia.org/wiki/Locality_of_reference)
    - Temporal locality
    - Spatial locality
* _Temporal locality_
 - **最近用到的数据，很有可能还会被再次使用**
   Cache 存储的是MM里面最近最长被使用到的子集。当数据从MM里面加载到Cache里面的时候，如果处理器请求同样地址的数据，会直接从Cache里面读取。因为在应用程序里面，遍历，循环等是很常见的，这些操作通常是对同一份数据或者变量进行操作，这种情况下Cache就提供很高的性能表现。
* _Spatial locality_
 - **如果一个数据被用到了，那么这份数据周边的数据很有可能也会被后续的操作用到**
   MM里面的指令和数据是以固定大小的块读取到Cache里面的，通常把这个固定大小叫做cache-lines. 一个Cache-line 的大小一般是4字节到512字节，所以当从MM里面读取需要处理的数据的时候(4/8字节)的时候，通常会把数据周边的大小为cache-line的数据一次性读取进来，放到一个cache-entry里面。
   大部分程序都是高度线性有效的，下一个指令通常来自于邻近的内存区域。结构化的数据也是一样具备高度线性特性的，它们通常是被连续存储的(比如字符串，数组等)。
   比较大的Cache-line 的大小会增强_spatial locality_的命中有效性，但同时在无效命中时候也增加了换行的成本，详细可以参考[Replacement policy](https://en.wikipedia.org/wiki/Cache_memory#Replacement_policy)。
(Note - 名词 "data" 通常会当做 "cache-line"或者"cache block"的简写)

### Cache efficiency
我们通常用命中率"Hit Rate"来评估缓存的效率。命中率是一个命中百分比，说的是在Cache里面发现数据的次数与总的数据访问次数的百分比。与"Hit"对应的是"Miss"。
Cache-efficiency依赖如下几个因素：缓存的总大小，cache-line的大小，缓存的类型以及缓存的具体架构，以及当前执行体的类型。一个号的缓存效率，通常需要80%到95%的命中率。

### Cache organization and structure
Cache通常是如下的三种基本结构和两种基本类型: 
 - Fully Associative cache
 - Direct Mapped cache
 - Set Associative cache
类型:
 - 指令缓存(Instruction code)
 - 数据缓存(Data cache)
  * Stack cache 
   - 这是一种特殊的"Data cache", 我们叫 *[栈缓存](https://en.wikipedia.org/wiki/Cache_memory#Stack_cache)*

#### Fully associative cache
![Any](https://upload.wikimedia.org/wikipedia/commons/9/94/Fully_Associative_Cache.svg "Fully Associative Cache")
memory-block 可以存储在cache里面的任何位置，这种cache称为"fully associative"，因为存储在cache里面会给每一个data存储相应的"full address"。
缓存会分成两个数组：目录*Directory*和数据*Data*。其中*Directory*也会被分为两个成员：*data-attribute-bits*或者叫*State*，和*ADD(data address)*。
*Data-attribute*包括一个"Valid bit"和其他几个标志：*Modified bit(M)*, *Shared bit(S)*和其他几个[状态标志位](https://en.wikipedia.org/wiki/Cache_memory#Cache_states)，另外还会包括保护标志位*"protection bits"*，比如"Supervisor/User" 和"Write protection"写保护。
在"fully-associative cache"里面，我们会存储每一个block的地址*full address*绝对地址。当需要从cache里面读取一个数据的时候，我们会比对所有存储在"Directory"目录字段里面的绝对地址，如果匹配到了，我们就称为一次命中，相应的"Data"就会直接从cache的"Data"读取。如果没有命中，就会从MM里面读取，读取到相应数据的时候，也会把相应的数据存储到cache里面，这个时候会根据[Replacement policy](https://en.wikipedia.org/wiki/Cache_memory#Replacement_policy)选择一个cache-line进行复写替换。
"fully-associative cache"的效率非常高，从MM读取的数据可以存储到cache的任意一个entry，但他的实现电路是比较昂贵的，每一个cache里面的entry都需要一个独立的通道进行并行的地址匹配和存取。因此，通常这种类型的缓存一般都不大，而且不做为通用缓存，只是针对一些特定的用途，比如[TLB](https://en.wikipedia.org/wiki/Translation_lookaside_buffer)，通常这种类型的缓存不会作为现代的处理器缓存，现代处理器通常用"direct-mapped"和"set-associative"。

#### Direct mapped cache
![In](https://upload.wikimedia.org/wikipedia/commons/a/a2/Direct_Mapped_Cache.svg "Direct mapped cache")
"direct-mapped"或者叫"single set-associacive cache"里面，任意的一个内存块只会被存储到一个特定的cache-entry上。用来存储的cache-entry可以从memory-block的地址直接推导计算出来，这个也是这个类型的cache名字的由来。
因为Cache 的大小肯定会比MM小，所以MM的内存地址需要某种方式映射到cache-space。所有的内存数据都在一个相对小的地址空间lower-space里面进行操作。有很多类似这样的映射算法，我们叫[hash coding](https://en.wikipedia.org/wiki/Hash_function)或者就叫"hashing"。常用的Cache-space的寻址方案是：用地址的一部分来寻址，或者更精确的说是，用一个称为*Index*的字段，这个字段是排除掉偏移量[offset](https://en.wikipedia.org/wiki/Offset_(computer_science))，地址的[Least Significant Bits](https://en.wikipedia.org/wiki/Least_significant_bit "LSB")当做"Index"，如图"Cache addressing"所示。其中[offset](https://en.wikipedia.org/wiki/Offset_(computer_science) "line offset")用来在一个"cache-line"内部进行byte-level的级别进行寻址的。比如在一个32位的地址空间上，有一个4MB的缓存，缓存的cache-line大小是256 B, 其中"Index"字段LBS(less significant bits)(8-21位)用来选择相应的cache-entry。这种线性寻址方案，在[Demand-paging](https://en.wikipedia.org/wiki/Demand_paging) [Virtual memory](https://en.wikipedia.org/wiki/Virtual_memory)用来把全地址空间的内存映射到缓存里面。
![Cache Addressing](https://upload.wikimedia.org/wikipedia/commons/6/6e/Cache_Addressing.svg "Cache Addressing")
 *注意- 另外一种 hash coding 算法有时候也用来做 TLB, "bit XORing", 会对地址进行与一个特定的一对位字段做[XOR](https://en.wikipedia.org/wiki/XOR)运算, 这种算法会产生一个伪随机的寻址* 
映射到同一个*Index*的数据，我们把这些数据较"synonyms"，他们会被存储到同一个entry里面，所以这种情况下一次只有一个"synonym"可以被存储到相应的entry里面(这种情况较"synonym"冲突)，不同的"Synonyms"他们的[MSB](https://en.wikipedia.org/wiki/Most_significant_bit "Most Significant Bits")地址字段是不一样的。
为了有效区分不同的"synonyms"，字段 MSB(named address Tag)会被存储到 cache的目录字段里面，也就是前面例子中的(22-31)位。当从Cache里面读取数据的时候，相应的MSB会信息比较，这个跟"Fully Associative"里面一样，如果一直就是命中了，就从Cache完成读取，否则需要从MM里面读取。
在前面我们描述的寻址方案里面，两个"synonyms"之间的距离一定是"cache-size"的整数倍, 如果增大"cache size"的大小，那么两个"synonyms"之间的距离就变大了，那么"synonym"之间冲突的几率也就变小了。
在这种类型的cache里面，我们只会同事选择操作一个cache-line，所以也就只需要一个comparator电路。
为了最小化"synonym"冲突问题，我们可以用一个"Associative cache"集合来优化这种情况。

#### Set associative cache
![Set Associative Cache](https://upload.wikimedia.org/wikipedia/commons/b/bf/Set_Associative_Cache.svg "Set Associative Cache") 
"Set associative cache"或者叫"multi-way-direct-mapped"是一种结合前面两种方案的综合方案，用来尽可能的降低"synonyms"冲突。
这类Cache由一组采用完全同样寻址算法的"Direct Mapped cache"组成，所以对于一个cache-entry, 可以存储多个"synonym"，根据[Replacement policy](https://en.wikipedia.org/wiki/Cache_memory#Replacement_policy)算法，每一个"synonym"可以存储到组内的任意一个"direct maped cache"的entry上。
通常会有2组8组,16组，乃至48组[AMD Athlon](https://en.wikipedia.org/wiki/Athlon)并发的"direct-mapped-cache"，对于[IBM POWER3](https://en.wikipedia.org/wiki/POWER3)甚至有128组，具体依赖于是什么类型的cache(指令缓存还是数据缓存)。
在"Set Associative cache"里面，每一个相应的"direct-mapped-cache"都需要一个寻址比较器。
 *注意：一个单独的 "Direct Mapped cache" 可以理解为只有一组并发的"Set Associative cache"; 一个"Fully Associative cache" 可以理解为n路并发的"Set Associative cache", 只是每一个"Direct Mapped cache"只有一个cache-entry*
根据采用的[Replacement policy](https://en.wikipedia.org/wiki/Cache_memory#Replacement_policy), "Directory"字段里面有可能需要包含一个"Replace bits"来控制候选的替换cache-line。

#### Replacement policy
只要存在多个entry用来存储数据，比如在"Fully Associative cache"和"Set Associative cache", 我们就需要有替换策略和算法来控制具体的换入换出行为。
大体有如下的几个主流的替换策略：
 - [LRU](https://en.wikipedia.org/wiki/Cache_replacement_policies#LRU) -- [Least Recently Used](https://en.wikipedia.org/wiki/Cache_replacement_policies)
 - [FIFO](https://en.wikipedia.org/wiki/FIFO_(computing_and_electronics)) -- First-In First-Out
 - [LFU](https://en.wikipedia.org/wiki/Least_frequently_used) -- [Least Frequently Used](https://en.wikipedia.org/wiki/Least_frequently_used)
 - [Round-robin](https://en.wikipedia.org/wiki/Round-robin_scheduling)
 - [Random](https://en.wikipedia.org/wiki/Randomness)

* LRU
    - 通常由于"Set Associative cache"
    - "Set"里面的每一个entry, 都会关联一个*age counter*, *age counter*的最大值就是"Set"的组数，优先级最高的entry就是其中拥有最大*age counter*的entry，每一次访问一个cache-line的时候，他的*age counter*就会被设置为0，同时比当前entry小的entry的*age counter*都会被加一。比如有一个4路的"Set Associative cache"，那么*age counter*的最大值需要用2bit来存储，比如当前4路的*age counter*值为 3-0-2-1 (从Set-1到Set-4)，如果产生一次Set-3的访问，那么*age counter*就会变成  3-1-0-2，那么现在的更新优先级的顺序就会从 1-3-4-2 变成 1-4-2-3, Set-3 就已经变成优先级最低的了。
* FIFO
    - 用于"Set Associative cache"
    - 跟LRU算法很类似，唯一的区别就是计算器只会在更新行为发生的时候，拥有最大值的cache-line会被选中为当前的替换cache-line，并且他的计数器会被清零，其他的cache-line的计算机都会加一。
* LFU
    - 更有效的替换算法，但是代价更大，实际中一般不使用。
* Round-robin
    - 用于 "Full Associative cache"
    - 用一个指针来选择下一个被替换的cache-line, 每次循环递增指针，指向下一个cache-line, 这个实现方案里面只需要一个指针就可以了。
    - 实现成本很小
* Random
    - 用于 "Full Associative cache"
    - 跟Round-robin类似，只需要一个指针，但是这个指针在每次访问或者时钟周期的时候都会来更新指针
    - 实现成本很小

#### Types of cache
##### Instruction and data cache
有两类信息会存储在MM里面，指令也叫code, 另外一个数据也叫操作数。
* "Unified" cache 两者都可以存储
* 在 "Separated" cache 里面，指令和数据会存储在不同的cache上，其中"I-Cache"是用来缓存指令的，"D-Cache"是用来缓存数据的。
对于分开的这种模式，主要有三个优势：
1. 两种不同结构类型的数据他们之间的干扰会减少
    - 对于指令来说他的线性访问特征更加明显，而对于操作数来说更具随机性；而且对于分开的这种结构，我们可以对他们采用不同的cache实现，通常我们会用2路或者4到8路的"Associative cache"来承载指令缓存，而用4到16路，或者更多的128路"Associative cache"来承载操作数缓存。
2. 允许采用["Harvard architecture"](https://en.wikipedia.org/wiki/Harvard_architecture)实现, 这种类型的结构会增大处理器的并行执行的能力，因为根据前面执行的具体操作数以及相关的指令，这种结构允许并发的预加载。
3. 实现多处理器系统上的，_snoopy-activity_和_processor-activity_在"I-Cache"无干扰。_Snoopy activity_通常只会在"D-Cache"上出现，详情可以参考文章下面的[Write policy](https://en.wikipedia.org/wiki/Cache_memory#Write_policy) 和[Snoopy and processor activity interference](https://en.wikipedia.org/wiki/Cache_memory#Snoopy_and_processor_activity_interference)。
##### Non-blocking cache
大部分cache一次只能处理一个请求。当向cache查询的时候，如果出现miss行为，那么cache必须等着从MM加载数据，这个请求就会阻塞则，知道加载完成，这其中也不能再处理其他请求。对于一个_non-blocking(或者叫lock-free)_cache，是有能力在等待从MM加载数据的过程中处理其他请求的。
#### Write policy
cache的写策略决定了cache怎么处理缓存中的内存区块怎么回写到MM里面。通常只有"D-Cache"会升级到写的问题，因为指令通常意义是不能self-modifying, 在确实出现self-modifying的情况下，通常软件会采用弃用Cache的策略，直接在MM里面进行操作(比如[AMD64](https://en.wikipedia.org/wiki/AMD64)的 Self-Modifying)。
有两类基础的写策略：
* 直接写 Write Through
* 延后写 Write-Back (or Copy Back)
##### Write through
 - 数据会立刻在cache和MM同时写，或者先在cache里面写，然后紧接着立刻在MM写.
##### Write-back (or copy back)
 - 数据只会在Cache 里面写，只有在必要的时候才回写到Mm里面，比如发生cache-line替换的时候，或者被加载到其他cache的时候。这种策略会减少总线和内存的冲突，因为cache-line的更新只会发生在cache本身，不升级MM的更新，但我们会在cache-line的Directory里面做"D"和"M"(Dirty 或者 Modified)标记，详情见下面的[缓存状态](https://en.wikipedia.org/wiki/Cache_memory#Cache_states)。

根据write的时候如果出现miss行为也有两种不同的处理策略：
##### Write allocate
在"miss"的时候发生Write allocate, 也叫 "Fetch-on-write"或者*RWITM*(Read With Intent To Modify) 或者 "Read for Write"
* 在写行为的时候发生miss, 首先会从MM加载cache-line, 或者在[Cache Intervention](https://en.wikipedia.org/wiki/Cache_memory#Snoopy_coherency_operations)的时候从其他的cache加载cache-line，然后就在加载好的cache-line里面进行写入新的数据，这个时候会发生cache-line的更新操作，更具写的偏移量，大小等对cache-line进行局部更新。
##### Write no-allocate (也叫 no-Write allocate)
数据被直接绕过cache直接写到MM上。
*  Write-allocate 通常是用于 *write-back* 策略， 而 Wite-no-allocate 通常是被用于 *write-through*

### Cache levels
在一个系统里面，通常不只一个cache可以被使用，cache会被分层，通常会被分解到4层，从L1到L4 或者更多。
大的cache会提高命中率，但是访问延时也会增大，而多层的cache方案运行高命中率的同时，提供更快的访问速度。
分层的cache方案，通常会从比较小的L1-cache开始查询，如果命中，处理器就直接访问，如果miss，则访问下一个更大的级别的L2-cache，以此类推。
随着技术的发展，运行在处理芯片内部直接放一个L1-cache，内部的cache会提供比外边cache快得多的访问速度，但是命中率会相对低一些，内部的cache的大小通常也是不大，从8KB到64KB。为了提高命中率，加大缓存区的大小，一个更大的L2-cache也会放到处理器内部，L2的大小通常从64KB到8MB不等，当然也有一些L2-Cache是挂在在处理器外部的，对于挂在外部cache的芯片莱索，也是可以提供一个更大的L3-cache，这种cache通常会是4MB-256MB。对于多核系统来说，L3-Cache可以放在 [McM](https://en.wikipedia.org/wiki/Multi-Chip_Module "Multi-Chip Module")模块上(eg. 比如[POWER4](https://en.wikipedia.org/wiki/POWER4)处理器)
通常L1是"Set Associative cache", 并且指令和数据分开的；L2 可以是"unified",也可以是"separated"，可以是"Direct Mapped cache" 也可以是 "Set Associative cache"。L3和L2类似。
#### Multi-level cache hierarchy function
![Multi-level cache Hierarchy](https://upload.wikimedia.org/wikipedia/commons/9/93/Multi-level_Cache_Hierarchy_diagram.svg "Multi-level cache Hierarchy")
- L1 --> 处理器芯片内部，快速存储
    - 大小是 8KB - 64KB
- L2 --> 增加缓存的总的大小 "for data coherency"
    - "Snoopy" 基于bus的多处理器缓存，在多个核之间共享
    - 可以在处理器芯片上，也可以外部的
    - 从64KB - 8MB 不等的大小
- L3 --> 增加缓存的总的大小， 作为L2的[兜底缓存](https://en.wikipedia.org/wiki/Cache_memory#Inclusive_and_exclusive_cache "Victim cache")存在
    - 从 4MB - 128MB
    - 如果L2位于芯片内部，或者没有L2缓存的时候，会使用L3
- L4 --> [Remote cache](https://en.wikipedia.org/wiki/Cache_memory#Remote_cache) 或者 [cc-NUMA Clastering System](https://en.wikipedia.org/wiki/Cache_memory#cc-NUMA_.E2.80.93_Clustering_Systems)
    - 大小大于L3(512MB或者更大) 依赖于节点数量
    - 有的时候做作为L3的兜底缓存，放在[GPU](https://en.wikipedia.org/wiki/Graphics_processing_unit)上
*注意: 上一个级别的cache-line的大小比小一个级别的cache-line 大小要大或者相等*
#### Inclusive and exclusive cache

### Shared cache

### Multi-bank and multi-ported cache
#### Multi-bank cache
##### Linear addressing
##### Cache interleaving
#### Multi-ported cache
#### Multiple cache copies
#### Virtual multi-porting cache
#### Hybrid solution

### Cache coherency
#### Snoopy coherency protocol
##### SMP - symmetric multiprocessor systems
##### Cache states
##### Various coherency protocols
##### Snoopy coherency operations
###### Bus transactions
###### Data characteristics
###### Cache operations
##### Coherency protocols
###### MESI protocol
###### MOESI protocol 
###### Illinois protocol
###### Write-once (or write-first) protocol
###### Bull HN ISI protocol
###### Synapse protocol
###### Berkeley protocol
###### Firefly (DEC) protocol
###### Dragon (Xerox) protocol 
###### MERSI (IBM) / MESIF (Intel) protocol 
###### MESI vs MOESI 
###### RT-MESI protocol 
###### RT-ST-MESI protocol 
###### HRT-ST-MESI protocol 
###### POWER4 IBM protocol
##### General considerations on the protocols
##### Snoopy and processor activity interference
#### Directory-based cache coherence - message-passing
##### Remote cache
##### cc-NUMA cache coherency 
###### Local memory read
###### Local memory write
###### Remote memory read
###### Remote memory write
#### Shared cache - coherency protocol
##### Multi-core systems
###### cc-NUMA in multi-core systems

### Stack cache
#### Overview
#### Stack cache implementation

### Virtual, physical, and pseudo virtual addressing
#### MMU
#### TLB
#### Virtual addressing
##### Coherency problem
#### Physical addressing
#### Pseudo-virtual addressing

### See also

### References
 
 
 
 
 
 



