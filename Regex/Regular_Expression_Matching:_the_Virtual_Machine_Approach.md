# Regular Expression Matching: the Virtual Machine Approach



## Introduction

说出被使用得最多的字节解释器或者说是虚拟机。Sum的JVM？Adobe的Flash? .Net 还是 Mono? Perl? Python? 或者说是 PHP?. 这些确定无疑是非常流行的虚拟机，但有一个使用得比刚才提到的这些加起来还要广泛的字节解释器，就是Henry Spencer 的正则表达式库以及在它的基础上发展起来的后继者。

在本系列的[第一篇文章](https://swtch.com/~rsc/regexp/regexp1.html)中描述了实现正则匹配的两种主要的策略：基于NFA-或者DFA-based，具备最差情况下的线性时间复杂度，被主要用在 awk 和 egrep(现在的大部分greps工具)；还有另外一种基于递归回溯的，最差情况下是指数时间复杂度，被广泛使用与各大常见的正则引擎比，包括ed, sed, Perl, PCRE 和 Python等。

本文会展现这两种策略下怎么实现一个类似.Net和Mono那样的虚拟机，把正则表达式编译为文本匹配的字节码，来执行正则规则匹配。当然这里的虚拟机绝壁不是.Net和Mono一样的虚拟机，.Net这种虚拟机是执行那些被翻译为[CLI](https://en.wikipedia.org/wiki/Common_Language_Infrastructure)字节码的程序。

把正则表达式的匹配过程认知为在一个特殊的机器上执行机器指令，这样就很容易通过增加和扩展新的机器指令来为正则表达式增加新的特性。比如，我们可以通过给正则表达式的机器增加子表达式提前指令，这样比如在执行正则表达式`(a+)(b+)`匹配`aabbbb`的时候，使用方就可以知道括号括起来的子表达式`(a+)`("这个子表达式通常会被记为\1或者$1，匹配到了aa)，然后(b+)匹配到了bbbb。子匹配或者叫子提取，可以在回溯的虚拟机里面来实现，也可以哪些非回溯的虚拟机里面实现(这总做法可以追溯到1985年，但我详细这篇文章是第一篇书面对这个过程做详细解释的文章)。

## A Regular Expression Virtual Machine

开始的时候，我们先定义正则表达式的虚拟机(参考到 [Java VM](https://en.wikipedia.org/wiki/Java_Virtual_Machine))。VM会执行一个或者多个线程，每个线程都执行的是一个正则匹配程序，这些匹配程序基本只是一组简单的正则指令。每一个执行的线程都持有两个寄存器：一个指令寄存器(PC)和一个字符指针(SP)。

主要的正则指令如下：	

| 指令         | 说明                                       |
| :--------- | ---------------------------------------- |
| char c     | 如果当前的SP指针指向的位置不是c，则当前线程停止运行，标示当前线程的正则匹配失败。否则递进SP到下一个字符，并且递进PC寄存器到下一个指令 |
| match      | 停止当前线程的执行，标示当前匹配程序为匹配状态                  |
| jmp x      | 跳转到位于x的指令(设置当前的PC到x)                     |
| split x, y | 分割执行：创建一个新线程拷贝当前线程的SP，当前线程继续在 PC=x的地方开始执行指令；另外一个线程在PC=y的地方开始执行(类似同时跳转到两个地方开始并行执行匹配过程) |

VM 开始的时候启动一个线程，设置PC到程序第一个指令的位置，同时设置SP指向输入字符串的起始地址。线程开始执行的时候，就会开始执行当前线程的PC寄存器指向的指令；执行完当前指令，就移动PC到下一个指令执行。重复整个过程，直到停止状态(遇到了一个char指令导致匹配失败，或者遇到一个match指令匹配成功)。如果有任何一个线程达到匹配状态，我们就认为正则表达式与当前输入字符串匹配。

根据正则表达式的具体形式，循环递归的把正则表达式编译为相应的字节码。回忆前面的第一篇文章，我们知道正则表达式具备四种基本形式：单独的字符，类似字符`a`，连接操作e1e2，可选操作e1|e2，或者是重复操作 e?(零个或者一个)，e*(零个或者多个)，e+(一个或者多个)。

一个单独的字符被编译位一个`char a`的指令。一个连接操作会被编译位两个子表达式。一个可选操作会使用`split`指令允许两个选择都会被处理。e?会被编译位可选操作，只是其中一个操作处理空字符串。e*或者e+其实是一个循环匹配，这两个也会被编译为可选操作，其中一个选择是匹配e，另外一个是跳出这个循环匹配过程。

准确的编译代码如表格所示：



| 正则表达式  | 指令                                       |
| :----: | :--------------------------------------- |
|   a    | char a                                   |
|  e1e2  | codes for e1 <br> codes for e2           |
| e1\|e2 | split L1, L2<br> L1: codes for e1<br>     jmp L3<br> L2: codes for e2<br> L3: |
|   e?   | split L1, L2<br> L1: codes for e<br> L2: |
|   e*   | L1: split L2, L3<br> L2: codes for e<br>    jmp L1<br>L3: |
|   e+   | L1: codes for e<br>    split L1, L3<br>L3: |

在正则表达式的全部编译完成后，就在最后补充一个match指令作为结束。

比如正则表达式`a+b+`会被编译位如下：

| 指令行号 | 具体指令       |
| ---- | ---------- |
| 0    | char a     |
| 1    | split 0, 2 |
| 2    | char b     |
| 3    | split 2, 4 |
| 4    | match      |

前面编译好的正则表达式在匹配字符串`aab`的时候，VM的整个运行过程如下：

| 线程   | PC           | SP      | Execution                  |
| ---- | ------------ | ------- | -------------------------- |
| T1   | 0 char a     | **a**ab | 字符匹配                       |
| T1   | 1 split 0, 2 | a**a**b | 创建线程T2，设置PC=2 SP=a**a**b   |
| T1   | 0 char a     | a**a**b | 字符匹配                       |
| T1   | 1 split 0, 2 | a**a**b | 创建线程T3,  设置PC=2 SP=aa**b** |
| T1   | 0 char a     | aa**b** | 不匹配：线程T1终止                 |
| T2   | 2 char b     | a**a**b | 不匹配：线程T2终止                 |
| T3   | 2 char b     | aa**b** | 字符匹配                       |
| T3   | 3 split 2, 4 | abb_    | 创建线程T4, 设置PC=4 SP=abb_     |
| T3   | 2 char b     | abb_    | 不匹配(当前是字符结束)：线程T3停止        |
| T4   | 4 match      | abb_    | 达到最终匹配状态                   |

在前面我们的表格展示的例子里面，先创建的线程会等当前线程结束才会开始执行，新创建的线程的执行顺序也就是他们的创建顺序(first-in-first-out, 老的线程先运行)。这个病不是VM的本身的要求，这个看线程调度的具体实现方法，其他的一些实现方式，可能就是让线程交叉着运行。

## VM Interface in C

本文的接下来的的部分会采用C代码来阐述VM的具体实现。正则表达式编译以后是一个Inst结构体的数组，结构体的C定义如下：

```c
enum {    /* Inst.opcode */
    Char,
    Match,
    Jmp,
    Split
};

struct Inst {
    int opcode;
    int c;
    Inst *x;
    Inst *y;
};
```

这个字节码的定义与前面第一篇文章中的NFA图是一致的。我们可以把这个bytecode看做是NFA图里面节点的编码，NFA的节点也就对应到虚拟机的机器指令；当然我们可以把NFA的图看做字节码的执行流程。不同的视角，会让你在某些方便更加容易理解整个机制的某一部分，这篇文章我们会聚焦在机器指令的视角来解读整个过程。

VM的实现可以看做是一个函数，接受编译好的执行指令的数组，和一个输入字符串作为参数，返回一个整数来表达是否匹配(零代表没有匹配，非零代表匹配成功)。

```c
int implementation(Inst *prog, char *input);
```

## A Recursive Backtracking Implementation

一个VM的非常简单的实现，就是不直接引入线程来表达执行过程，而是在需要启动一个线程执行的时候，通过递归调用自己，其中传递的`prog`参数和`input`参数分别可以看做`PC`和`SP`寄存器的初始值。

```c
int
recursive(Inst *pc, char *sp)
{
    switch(pc->opcode){
    case Char:
        if(*sp != pc->c)
            return 0;
        return recursive(pc+1, sp+1);
    case Match:
        return 1;
    case Jmp:
        return recursive(pc->x, sp);
    case Split:
        if(recursive(pc->x, sp))
            return 1;
        return recursive(pc->y, sp);
    }
    assert(0);
    return -1;  /* not reached */
}
```

上面的递归的版本对于很多程序员来说非常熟悉，尤其是那些熟悉Lisp, ML 和 Erlang等具备重度递归特质的语言的程序员。大部分 C语言的编译器都会重写和优化上面的`return recursive(...);`这些叫做尾调用的语句，优化成goto语句，跳转到函数的顶部，所以上面的函数就会被编译优化为类似 下面的函数：

```c
int
recursiveloop(Inst *pc, char *sp)
{
    for(;;){
        switch(pc->opcode){
        case Char:
            if(*sp != pc->c)
                return 0;
            pc++;
            sp++;
            continue;
        case Match:
            return 1;
        case Jmp:
            pc = pc->x;
            continue;
        case Split:
            if(recursiveloop(pc->x, sp))
                return 1;
            pc = pc->y;
            continue;
        }
        assert(0);
        return -1;  /* not reached */
    }
}
```

上面的循环的表述非常清晰。

但也注意到，上面的版本依然是有一个分支是递归调用(不是尾调用)，在 `case Split`的时候，先尝试 `pc->x`，然后再尝试`pc->y`。

上面的实现是Henry Spencer的原版递归回溯实现版本的核心部分，也是Java, Perl, PCRE, Python 等编程语言，以及初始版的工具 ed, sed, 以及grep 所采用的方式。这个版本在没有太多递归的情况下运行是非常快速的，但只要出现一些可选操作，让递归路径以指数的方式增长几次，性能就会非常糟糕(和前面[文章](https://swtch.com/~rsc/regexp/regexp1.html)中看到的一样)。

上面的实现里面和真实的产品级别实现对比的话还是相对简单，上面的递归实现有一个致命的缺点：类似`(a*)*`的正则表达式会导致编译程序死循环，上面实现的编译器并没有检测这样的循环。当然这个是非常容易修正的一个问题(文章末尾我们会看到相关细节)，因为回溯不是我们的重点要讨论的，所以我们在这里就直接忽略他不做过多的扩展了。

## A Non-recursive Backtracking Implementation

在前面递归版本的回溯实现里面，是通过启动一个线程执行直到线程结束，然后以线程创建的顺序挑选待运行的线程来执行。线程等待执行的这个没有很清晰的在代码里面表述出来：任何需要递归的时候，通过隐含的方式把`pc`和`sp`的值保持在C的调用栈上面，然后依靠运行栈的的递进和回退来达成线程的选择。如果有太多的线程在等待执行，就可能导致C的调用栈出现溢出的情况，这种错误比性能问题更难调试和诊断。出现栈溢出的情况，通常是出现了很多类似`.*`这样的重复操作符，像这种操作符会为每一个可能的输入创建一个新的线程(和前面的`a+`做的一样)。对于多线程程序来说，通常每个线程的运行栈都不会太大，而且没有特殊的硬件来检测栈溢出，所以这会是一个还蛮需要注意的问题。

我们可以通过显式的维护一个C的线程栈来避免C的运行时栈出现溢出的情况。我们定义一个结构体来表示一个线程，并定义一个构造函数来构建线程对象:

```c
struct Thread {
    Inst *pc;
    char *sp;
};

Thread thread(Inst *pc, char *sp);
```

有这个待运行的线程列表以后，VM就是从待运行列表里面获取一个线程，然后运行，直到待运行线程列表为空，或者其中一个运行的线程已经达到了匹配状态，这个是就可以停止VM的执行了。如果所有线程都结束了，但没有到达匹配状态，就说明不匹配。在显式维护线程列表的时候，我们可以简单的设定一个等待线程个数的上限，如果达到上限就报告相关的错误。

```c
int
backtrackingvm(Inst *prog, char *input)
{
    enum { MAXTHREAD = 1000 };
    Thread ready[MAXTHREAD];
    int nready;
    Inst *pc;
    char *sp;

    /* queue initial thread */
    ready[0] = thread(prog, input);
    nready = 1;
    
    /* run threads in stack order */
    while(nready > 0){
        --nready;  /* pop state for next thread to run */
        pc = ready[nready].pc;
        sp = ready[nready].sp;
        for(;;){
            switch(pc->opcode){
            case Char:
                if(*sp != pc->c)
                    goto Dead;
                pc++;
                sp++;
                continue;
            case Match:
                return 1;
            case Jmp:
                pc = pc->x;
                continue;
            case Split:
                if(nready >= MAXTHREAD){
                    fprintf(stderr, "regexp overflow");
                    return -1;
                }
                /* queue new thread */
                ready[nready++] = thread(pc->y, sp);
                pc = pc->x;  /* continue current thread */
                continue;
            }
        }
    Dead:;
    }
    return 0;
}
```

上面的实现和`recursive`以及`recursiveloop`的版本是一致的；只是这个版本不再使用C的运行时栈来存储回溯过程。比较两个版本的`Split`分支:

```c
/* recursiveloop */
case Split:
    if(recursiveloop(pc->x, sp))
        return 1;
    pc = pc->y;
    continue;
```

```c
/* backtrackingvm */
case Split:
    if(nready >= MAXTHREAD){
        fprintf(stderr, "regexp overflow");
        return -1;
    }
    /* queue new thread */
    ready[nready++] = thread(pc->y, sp);
    pc = pc->x;  /* continue current thread */
    continue;
```

依然是回溯的过程，只是`backtrackingvm`会显式的把这个递归过程写出来的，显式的自己维护待运行线程的列表，这个显式的维护让自己可以很容易的加上栈溢出检测。

## Thompson's Implementation

把正则表达式的匹配过程看做是运行在VM里面的线程，我们可以在这里给大家呈现Ken Thompson算法的具体实做，这种实做会比第一篇文章中的更加贴近Thompson的PDP-11 机器码。

Thompson 注意到回溯有的时候需要重复扫描输入字符串的某些输入多次，为了避免这种情况，他构建了一个虚拟机，在虚拟机里面会以锁同步的方式同时运行所有线程：所有线程都会开始处理输入字符串的第一个字符，然后所有线程处理第二个字符，以此类推。在原来的说明里面，我们看到其实新创建的线程是不需要回溯去处理父亲线程已经处理过的输入字符，所以Thompson的这种方式是可行的，新创建的线程是可以与现在的线程以锁同步的方式处理后续的输入字符。

因为所有线程是以锁同步的方式运行，也就是他们其实是共享的`SP`，也就意味着不需要把`SP`作为线程的状态保存了:

```c
struct Thread
{
	Inst *pc;
};
Thread thread(Inst *pc);
```

那么，Thompson的VM 实现就是如下的:

```c
int
thompsonvm(Inst *prog, char *input)
{
    int len;
    ThreadList *clist, *nlist;
    Inst *pc;
    char *sp;
    
    len = proglen(prog);  /* # of instructions */
    clist = threadlist(len);
    nlist = threadlist(len);

    addthread(clist, thread(prog));
    for(sp=input; *sp; sp++){
        for(i=0; i<clist.n; i++){
            pc = clist.t[i].pc;
            switch(pc->opcode){
            case Char:
                if(*sp != pc->c)
                    break;
                addthread(nlist, thread(pc+1));
                break;
            case Match:
                return 1;
            case Jmp:
                addthread(clist, thread(pc->x));
                break;
            case Split:
                addthread(clist, thread(pc->x));
                addthread(clist, thread(pc->y));
                break;
            }
        }
        swap(clist, nlist);
        clear(nlist);
    }
}
```

假定一个正则表达式被编译后总共是n条执行指令，因为我们的线程状态只有指令计数器`PC`，也就是在`clist`和`nlist`里面最多出现n个不同的线程，如果`addthread`不会重复添加线程(具备同一个`PC`的认为是一样的线程)，那么ThreadLists 只最多需要准备n个线程的空间，这样我们也就消除了出现溢出的可能性。

因为已经知道在线程列表里面最多有n个线程，这样也就对每一个输入字符的处理时间我们是可以估算出上确界的。假定addthread的时间复杂度是O(1)，那么处理一个输入字符的最大消耗时间就就是O(n)了，那么整个字符串的处理时间就是O(nm)。这个是比前面的回溯算法不可同日而语的，同时这种算法还消除了前面提到的死循环的情形。

严格来说，这样看就没有任何理由为什么回溯的算法实现上不采用这样的技巧来优化立即的线程数，确保线程不被重复添加(因为在回溯里面一个线程的状态其实有`PC`和`SP`组成，也就是具备同样`PC`和`SP`的线程也是可以认为是一个线程)，如果启动这样的优化，那么我们需要追踪 n*m 个可能的线程状态，每一个`pc`和`sp`对都会是一个线程的Key，而实际情况下对于m来说通常都可能是一个多变而且不可控的变量。

用一个20字节的正则表达式在一个兆字节的字符串上进行匹配，在实际情况中是很普通的情况。在这种情况下，n最大不会超过40，但是 n*m 会是 4000万。时至今日，兆字节的文本已经算是小的了。Thompson的方法，他一个非常大的优势就是任何一个时间点最多可能有n个线程，而且这个n个线程是以锁同步的方式运行，线程相当于是在任何时间点上是一个完备的并发，而且这个方法隔离了对输入字符串长度的依赖，他的运行时间不会因为输入字符串出现较大的差异。

## Tracking Submatches

把正则表达式翻译为字节码的方式来处理匹配过程，这样我们也很容易来给正则表达式增加新的特性，比如这里的子表达式提取，只需要定义一个新的字节码，然后实现这个字节码。

为了能够处理子表达式的提前，我们在线程状态里面加一个字符指针数组。新定义的字节码`save i`会存储当前的输入字符串指针到当前线程状态的指针数组的第i个槽。为了编译正则表达式`(e)`，这个正则表达式表达了子表达式提前，所以需要存储`e`具体的匹配边界，我们会放两个存储指令到`e`编译后的指令周围，对于第k个子表达式(Perl里面的$k)，我们会使用槽2k来存储匹配的起始位置，2k+1来存储匹配的结束位置。

比如对比编译`a+b+`和`(a+)(b+)`：

| a+b+          | (a+)(b+)     |
| ------------- | ------------ |
| 0  char a     | 0 save 2     |
| 1  split 0, 2 | 1 char a     |
|               | 2 split 1, 3 |
|               | 3 save 3     |
|               | 4 save 4     |
| 2  char b     | 5 char b     |
| 3  split 2, 4 | 6 split 5, 7 |
|               | 7 save 5     |
| 4 match       | 8 match      |

如果我们需要找到整个匹配的边界，我们可以在把整个字节码用指令 `save 0` 和 `save 1`包起来。

在`recursiveloop`的算法里面实现save 指令是非常直观的：`saved[pc->i]=sp`，只是这个赋值操作在匹配失败的时候要可撤销。下面的代码就说明了处理线程匹配失败的情况：

```c
int
recursiveloop(Inst *pc, char *sp, char **saved)
{
    char *old;

    for(;;){
        switch(pc->opcode){
        case Char:
            if(*sp != pc->c)
                return 0;
            pc++;
            sp++;
            break;
        case Match:
            return 1;
        case Jmp:
            pc = pc->x;
            break;
        case Split:
            if(recursiveloop(pc->x, sp, saved))
                return 1;
            pc = pc->y;
            break;
        case Save:
            old = saved[pc->i];
            saved[pc->i] = sp;
            if(recursiveloop(pc+1, sp, saved))
                return 1;
            /* restore old if failed */
            saved[pc->i] = old;
            return 0;
        }
    }
}
```

我们注意到在save指令的分支和split分支一样，也存在一个躲不掉的递归调用。save指令所在的递归其实比split指令所在的递归更难进行拆解；把save指令拟合到backtrackingvm里面其实还需要更多的努力。虽然递归会导致潜在的栈溢出问题，但大部分的实现者还是更加倾向于用递归来实现，不太愿意花更多的心思来拆解递归过程。

## Pike's Implementation

在类似上面thmpsonvm的“线程制”的实现里面，我们简单的给线程状态结构体增加一个`saved`指针数组。Rob Pike 在他的文本编辑器sam里面最先开始用这种方法。

```c
struct Thread
{
	Inst *pc;
	char *saved[20];  /* $0 through $9 */
};
Thread thread(Inst *pc, char **saved);
int
pikevm(Inst *prog, char *input, char **saved)
{
    int len;
    ThreadList *clist, *nlist;
    Inst *pc;
    char *sp;
    Thread t;
    
    len = proglen(prog);  /* # of instructions */
    clist = threadlist(len);
    nlist = threadlist(len);

    addthread(clist, thread(prog, saved));
    for(sp=input; *sp; sp++){
        for(i=0; i>clist.n; i++){
            t = clist.t[i];
            switch(pc->opcode){
            case Char:
                if(*sp != pc->c)
                    break;
                addthread(nlist, thread(t.pc+1, t.saved));
                break;
            case Match:
                memmove(saved, t.saved, sizeof t.saved);
                return 1;
            case Jmp:
                addthread(clist, thread(t.pc->x, t.saved));
                break;
            case Split:
                addthread(clist, thread(t.pc->x, t.saved));
                addthread(clist, thread(t.pc->y, t.saved));
                break;
            case Save:
                t.saved[t->pc.i] = sp;
                addthread(clist, thread(t.pc->x, t.saved));
                break;
            }
        }
        swap(clist, nlist);
        clear(nlist);
    }
}
```

pikevm里面的Save指令的分支比recursizveloop的要来得简单，因为每一个线程都有一份他自己的saved：也意味着不需要恢复saved里面的值。

在Thompson的VM里面，addthread里面的线程列表大小被限制到了正则表达式编译程序的指令长度n，每一个线程都有唯一的pc指针对应。在Pike的VM里面，线程状态结构体要多一个saved指针，但addthread依然具备同样的约束关系，一个线程唯一的通过PC寄存器来区分，因为saved指针其实并不影响线程后续的执行，Saved指针只是记录线程的父亲线程过去的执行情况，对于具备同样PC寄存器的线程来说，即使他们的saved 指针不一样，他们后续的执行是完全一样的，因此每一个PC地址只需要保留线程在线程列表就可以了。

## Ambiguous Submatching

一个正则表达式，对于一个输入字符串，有的时候会有多条路径可以达成匹配。比如，用正则表达式`<.*>` 来匹配搜索 `<html></html>`这个字符串，这个时候正则表达式匹配的是`<html>`还是整个`<html></html>`呢？在这个情况下，也就是对于子表达式提前来说，他是不确定的了，子表达式`.*`可以匹配 `html`，也可以匹配`html></html`，在Perl(Perl的正则实现基本算是事实上的标准了)里面，子表达式选择匹配的是后者。在这种语义上来说，`*`展现的是贪婪匹配，会进行尽可能多的输入匹配。

要求`*`表现出贪婪匹配的特征，这个时候我们就需要对每一个执行的线程赋予相应的一个优先级。在VM定义的规格里面，我们可以通过定义split指令的执行顺序，让优先执行第一个分支，再执行第二个分支来给VM增加优先级的支持。

有了带优先级支持的split指令，我们可以实现一个贪婪版本的`e*`(`e?`和`e+`是类似的)，让split分裂出来的指令优先选择匹配更多的`e`。Perl里面还支持一种非贪婪的`e*?`（`e??`和`e+?`），这种就是尽可能少的匹配。对于非贪婪的版本，通过翻转split指令的参数选择分支，让优先选择匹配更少实例的分支。

确切的字节码序列如下：

| greedy (same as above)                   | non-greedy                               |
| ---------------------------------------- | :--------------------------------------- |
| e?  split L1, L2 <br> L1: codes for e <br> L2: | e??   split L2,L1 <br> L1: codes for e <br> L2: |
| e* L1: split L2, L3 <br> L2: codes for e <br>    jmp L1 <br> L3: | e*? L1: split L3, L2 <br> L2: codes for e <br>    jmp L1 <br> L3 |
| e+ L1: codes for e <br>   split L1, L3 <br> L3: | e+? L1: codes for e    <br> split L3, L1<br> L3: |

在前面的回溯版本的实现其实已经默认支持了优先级，这里我们再review一遍前面的实现，看他具体是怎么支持的。	对于`recursive`和`recursiveloop`的实现来说，他只需要简把pc->x放到pc->y前面就可以：

```c
/* recursive */
case Split:
    if(recursive(pc->x, sp))
        return 1;
    return recursive(pc->y, sp);

/* recursiveloop */
case Split:
    if(recursiveloop(pc->x, sp))
        return 1;
    pc = pc->y;
    continue;
```

而对于`backtrackingvm`的实现，他会创建一个低优先级的线程来执行pc->y,然后把当前线程pc设置为pc->x，然后继续执行：

```c
/* backtrackingvm */
case Split:
    if(nready >= MAXTHREAD){
        fprintf(stderr, "regexp overflow");
        return -1;
    }
    /* queue new thread */
    ready[nready++] = thread(pc->y, sp);
    pc = pc->x;  /* continue current thread */
    continue;
```

因为线程是通过一个先进后出的栈来管理的，指令pc->y所在的线程会需要等到pc->x所在的线程以及相应的具备比pc->y线程高优先级的子线程全部执行完成才会开始执行。

上面的pikevm的实现里面还并没有完全遵循线程优先级，但可以通过小量修改来修正对线程优先级的支持，`addthread`在处理Jmp, Split, Save指令的时候，通过递归调用`addthread`(这样调整可以看到addthread和第一篇文章中的addstate就是一一对应的了)来代替执行具体指令。这样的调整可以确保在clist和nlist里面线程是按照线程优先级的顺序从高到底排列的。在pikevm的处理循环就会按照线程优先级的顺序在调度线程的执行，贪婪版本的addthread确保nlist会一个级别一个级别的处理线程的加入。

pikevm 的这个调整都是基于递归的调用顺序必须和线程优先级匹配。在新代码里面，处理一个字符的输入的时候是一个循环过程，nlist是按照优先级顺序添加的，当然整个过程依然是以锁同步的方式递进所有线程的执行过程，具备良好的运行效率。因为nlist的生成过程满足优先级顺序，所以在添加新线程的过程中，"如果具备同样PC的线程已经出现，那么就忽略这个线程"这种启发式的添加方式是安全的：已经出现过的线程是具备更高优先级的，也是已经被存储状态的。

还有一个在pikevm必要的调整：如果发现了一个匹配，后面位于clist里面的线程就可以直接中断执行了，因为clist本身是按照优先级排序的，更高优先级的线程应该给更高的权限去运行，允许他匹配尽可能长的输入字符串。调整后的pikevm的主循环看起来是这样的：

```c
for(i=0; i<clist.n ;i++){
    pc = clist.t[i].pc;
    switch(pc->opcode){
    case Char:
        if(*sp != pc->c)
            break;
        addthread(nlist, thread(pc+1), sp+1);
        break;
    case Match:
        saved = t.saved;  // save end pointer
        matched = 1;
        clist.n = 0;
        break;
    }
}
```

对于thompsonvm也可以做同样的跳转，但因为thompsonvm不需要记录子表达式的匹配位置，所以唯一需要做的调整就是在出现匹配的时候对选择不一样结束的指针。这样thompsonvm的结束位置就会和回溯版本的实现完全一致。这个本系列的下一篇文章会看到非常有用。

线程结合的约束规则可以不一样，比如还有一种实现，直接通过比较子匹配集合来约束线程集的大小。在Unix的第八版里面就用的是左边最长匹配规则，用在DFA-based的工具上，比如awk和egrep。



## Real world regular expressions

在实际的生产环节里面使用的正则表达式在某些方面是比我们文章中描述的版本要更加复杂一些的。这个小节简要的描述怎么来实现一些通用的基础设施。

**Character classes** 字符类是一个非常典型的特殊VM指令，在生产实现里面，我们不会把这个扩展为一些列的可选项。下面的示例代码里面我们会为元字符(metacharacter)逗号实现一个叫做`any byte`的特殊指令。

**Reptition** 重复操作后面通常会接一个不在重复字符集里面的其他字符，列如：`/[0-9]+:[0-9]+/`, 第一个`[0-9]+`后面会接一个`:`，第二个`[0-9]+`后面接的不能是数字，这样我们就可以推出一个一字节的前向探测操作来避免在重复操作里面创建过多而且不必要的线程。这个技术在回溯版本的实现里面很常见，因为回溯版本会每一个字符都要创建一个新的线程，如果通过地柜的方式来实现线程，这个优化技术在避免一些简单表达式而导致栈溢出的问题上就显得很有必要了。

**Backtracking loops** 在文章开始的时候，最开始版本的回溯算法的实现是可能导致，在处理一些类似`(a*)*`的表达式的时候，因为要处理空的匹配，会出现死循环。一个简单的方式来避免在回溯算法里面出现死循环的方法就是推出一个进度指令，进度指令要求VM在执行某些指令的时候必须和上一次执行的时候相比有新的步进。

**Alternate program structures for backtracking**  另外一个避免循环的方法就是为修改重复操作对应的指令集，用introduce-intructions代替。这种指令具备调度能力，能够把给定的一个片段的指令当做一个subroutine来运行，这样就避免了无线循环的问题，这种特性的指令集也更加高效的实现列如重复计数器以及断言等特性。当然，这些指令也会让实现一个非递归的版本变得更难，而且这些指令也直接让自己被排除在了Pike的那种基于自动机技术的VM之外。即便如此，这个也依然很容易让实现的版本失去控制，不行可以去看一下 Perl 和 PCRE 或者其他任意一个宣布实现了“全功能”正则表达式的哪些实作版本。

**Backreferences**  后向引用在回溯的算法实现里面是非常简单的。在Pike实现的VM里面也是可以调整来实现后向引用的，只是会导致不能像以前一样，通过比较线程的PC值就可以知道两个线程相同了：两个拥有同样PC值的线程可能有不能的捕获集合，而且当前的捕获集会对将来的执行产生影响，这样就只能同时都把两个线程都添加到线程待运行集合里面取，这也带来了潜在的指数增长点。GNU的 grep，结合两个方法：他会通过把后向引用，用具体的表达式来代替，这样会产生一个近似的不带后向引用的正则表达式版本，比如`(cat|dog)\1`会被翻译成`(cat|dog)(cat|dog)`，然后这个生成的正则表达式就可以用DFA的技术了，当匹配发生的时候再回过头来检查后向引用是否一致。

**Unanchored matches**  为了实现非锚点匹配，很多实现都是先从第0个开始匹配，如果失败则从第1个开始，以此类推。这种方法实现的非锚点匹配的时间复杂度就是以输入字符长度的O(n^2)了。在基于VM的实现里面，一个更有效的实现非锚点搜索的方法就是在正则表达式前面放一个`.*?`，这样就让VM自己去做非锚点匹配了，时间复杂度就会是线性O(n)。

**Character encodings** 因为在 Thompson和Pike的VM实现里面，每次都是处理一个字符，单次pass，不会出现重复扫描输入字符，而且对字符集大小没有任何约束需求，这样就很容易的扩展支持不同的编码和字符集，甚至支持UTF-8：在输入字符串的输入循环里面，每次都解码一个字符。对于一些复杂的字符解码来说，VM每次都只解码一个字符，这样就非常牛逼了(UTF-8的解码不是特别昂贵，但与ASCII来说还是有一些代价的)。



## Digression: POSIX Submatching



