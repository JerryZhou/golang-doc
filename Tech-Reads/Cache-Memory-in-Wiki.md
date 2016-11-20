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

### Cache efficiency

### Cache organization and structure
#### Fully associative cache
#### Direct mapped cache
#### Set associative cache
#### Replacement policy
#### Types of cache
##### Instruction and data cache
##### Non-blocking cache
#### Write policy
##### Write through
##### Write-back (or copy back)
##### Write allocate
##### Write no-allocate

### Cache levels
#### Multi-level cache hierarchy function
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
 
 
 
 
 
 



