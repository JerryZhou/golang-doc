# Regular Expression Matching in the Wild

## Introduction

本系列的前面两篇文章[Regular Expression Matching Can Be Simple And Fast](https://swtch.com/~rsc/regexp/regexp1.html),  [Regular Expression Matching: the Virtual Machine Approach](https://swtch.com/~rsc/regexp/regexp2.html)，分别对基于DFA和NFA的正则匹配算法做了解析，为了说明解析过程的原理，在正则规则上我们采用了从简原则。这篇文章从工程实作角度来描述具体的实现过程。

2006年的我花了一个暑假做了一个[Code Search](http://www.google.com/codesearch)项目，让程序员可以用正则表达式来搜索代码。也就意味着，可以让你在全球的所有开源代码里面执行[grep](http://plan9.bell-labs.com/magic/man2html/1/grep)操作。我们开始打算采用PCRE做我们的正则匹配引擎，但后面了解到他采用的是回溯算法，会导致潜在的[指数时间复杂度](https://swtch.com/~rsc/regexp/regexp1.html)，以及相应的运行时栈溢出。因为代码搜索的服务是面向所有互联网用户的，如果采用PCRE，就会给我们带来攻击风险导致服务不可用。在排除PCRE以外的一个选择，就是我自己来写一个，新的这个匹配引擎是基于Ken Thompson的[开源版本的grep](http://swtch.com/usr/local/plan9/src/cmd/grep/)，这个grep采用的是基于DFA算法的。

在接下来的三年，我实现了一个新的匹配后端替换了grep里面相应的代码，扩展了原有的功能到支持POSIX的标准grep。这个新版本就是RE2, 提供与PCRE类似的C++的接口，而且功能也和PCRE基本保持一致，同时还保证了线性时间复杂度，同时不会出现栈溢出的问题。RE2现在被广泛的运用在Google里面，包括Code-Search,以及一些内部的系统比如[Sawzall](http://labs.google.com/papers/sawzall.html)和[Bigtable](http://labs.google.com/papers/bigtable.html)。

到2010年三月，RE2变成了一个[开源](http://code.google.com/p/re2/source/browse/LICENSE)项目。这篇文章就是对RE2的源代码进行统领说明的，在本文中会详细展示前面两篇文章中提到的技术是怎么在RE2里面实作的。

## Step 1: Parse

在早期，正则表达式的[语法非常简单](http://www.freebsd.org/cgi/man.cgi?query=grep&apropos=0&sektion=1&manpath=Unix+Seventh+Edition&format=html)，回想一下第一篇文章里面提到：concatenation, repetition, 和 alternation。还有字符分类：普通字符，+, ? 等元字符，以及位置断言符 ^ 和 $。表面看起来，今天的程序员，面对的正则表达式字符分类要丰富得多，但现在的正则表达式解析器一个重要的工作就是把输入转义到前面的那些基础概念上去。RE2的解析器定义了一个正则表达式结构体，定义在[regexp.h](http://code.google.com/p/re2/source/browse/re2/regexp.h#103)文件中，他和原有的egrep语法非常接近，只是有多了少量的几个特殊情形：

1. 字面字符串由kRegexpLiteralString节点表述，这样比串联一组kRegexpLiteral节点省内存。
2. 重复链接操作由kRegexpRepeat节点表述，虽然单靠这个节点不能完成重复语义。我们后面会看到这个节点具体是怎么编译的。
3. 字符类不是通过简单的一组范围或者一个位图来表述，而是平衡二叉树的节点范围来表述，这种方式会带来复杂度的提升，但对于处理Unicode字符类的时候却非常的关键。
4. 任意字符由一个特殊的节点类型来表述，和任意字节操作符一样。但任意字符和任意字节在RE2里面，在匹配UTF8的输入文本的时候，因为RE2的默认操作模式会有一点点差异。
5. 大小写不敏感的匹配是通过特殊的标志位来实现的。对于ASCII字符来说和那种多字节字符还不一样，比如 (?i)abc，被解析为 abc 和一个大小写敏感标志位，而不是解析为 `[Aa][Bb][Cc]`。RE2开始的时候，其实解析为后者的。对于后者来说比较消耗内存，特别是哪些tree-based的字符类。

RE2的解析器实现在[parse.cc](http://code.google.com/p/re2/source/browse/re2/parse.cc#1539)。这是一个纯手写的解析器，主要是为了避免两个事情，一个是避免对另外一个解析器生成器的依赖，另外一个是现在的正则表达式规则已经不规则了，有太多的特殊设计。这里实现的解析器，没有使用递归下降，因为递归的深度会带来潜在的指数增长和栈溢出问题，特别是在多线程环境下。这里的解析器维持了一个解析栈，和LR(1)语法接下器做的类似。

有一个时期让我蛮惊讶的，对于同样的正则表达式不同的用户居然会有如此多不同的写法。例如，对于一个单字符类，比如-[.]，或者 \\. ,可选项用 a|b|c|d 而不是 [a-d]。接下器里面会要处理这些情况，并且选用最有效的形式来表达相应的匹配语义，而不是把这种情况传递到第二阶段。



## Walking a Regexp

在解析完正则表达式后，接下来就是处理过程了。解析的结果是一个标准的树结构，通常树结构都是用标准的递归遍历。不幸的是，我们这里并不能确保我们是否有足够的栈空间来做递归遍历。比如一些别有用心的用户可能会写出如下的正则表达式`((((((((((a*)*)*)*)*)*)*)*)*)*)*`(或者是更大的)直接就导致懵逼的栈溢出。所以，遍历过程，我们采用显式栈的方式。这里[Walker](http://code.google.com/p/re2/source/browse/re2/walker-inl.h#22)有一个模板隐藏了栈管理，让这种限制条件更可操作。

回想一下，我再想解析结果是树的形式，然后我们通过Walker的方式来遍历，也许这整个处理过程就是错误的。如果递归在这里是不允许的，我们或许就应该从根上来避免递归的表述形式，可以把解析结果存储在[Thompson's 1968 论文](http://swtch.com/~rsc/regexp/regexp1.html#thompson)里面提到的[逆波兰式](http://en.wikipedia.org/wiki/Reverse_Polish_notation)，如[示例代码](http://swtch.com/~rsc/regexp/nfa.c.txt)里面一样。如果RPN形式记录了最大的栈深度，那么在遍历的时候，我们就可以申请确定大小的栈，然后依次对表达式进行线性的扫描。



## Step 2:Simplify

接下来的补助就是简化，会重写那些复杂操作符为尽可能简单的，让后续的处理更加容易。随着时间的迁移，在RE2里面简化这个步骤的代码大部分都被挪到第一步解析器里面去了，因为简化步骤越早做越好，会减少大量的临时内存消耗。现在在简化里面还有最后的一个工作就是简化重复计数的正则表达式为一个基本的序列。比如把 `x{2,5}`简化为`xx(x(x(x)?)?)?`。



## Step 3: Compile

一旦正则表达式已经变成只使用第一篇文章里面提到的那些基础操作符以后，我们就可以用[这里](https://swtch.com/~rsc/regexp/regexp1.html#compiling)提到的技术进行编译了。我们也很容易的了解到这里的[编译规则](http://code.google.com/p/re2/source/browse/re2/compile.cc#17)。

在RE2的编译器里面有一个非常有意思的技巧，是我从Thompson的grep那里学来的。他会把UTF8的编译进一个自动机，也就是一次只读取一个字节。也就是状态机就是用的UTF8解码器来读取输入数据的。比如，为了匹配码点再0000到FFFF的Unicode字符，自动机会接受如下的字节序列：

```
[00-7F] 							 // code points 0000-007F
[C2-DF][80-BF]						  // code points 0080-07FF
[E0][A0-BF][80-BF]					  // code points 08000-0FFF
[E1-EF][80-BF][80-BF]				  // code points 1000-FFFF
```

这里列举处理，并不是说编译的时候选择其中一种，对于[80-BF]这种通用后缀也是可以被拎出来的。上述的实际编译形式应该是如下图所示：

![](https://swtch.com/~rsc/regexp/utf3.png)

上面的例子其实是一个具备明显优势的规则表达式。下面的状态机匹配的全域的Unicode，从0000000-10FFFF:

![](https://swtch.com/~rsc/regexp/utf4.png)

比前面的状态机要大，但依然是规则度很高的。在实际的情况下，也由于Unicode的发展历史，字符类其实面临的是不规则的情况。比如， \p{Sc}, 当前的符号码点就会是如下的状态机：

![](https://swtch.com/~rsc/regexp/cat_Sc.png)

这个符号类在本文中来看，到目前为止已经是最复杂的了，但实际情况下，还有其他的字符类比这个还要复杂；比如，[`\p{Greek}`](https://swtch.com/~rsc/regexp/script_Greek.png)(所有希腊脚本)或者 [`\p{Lu}`](https://swtch.com/~rsc/regexp/cat_Lu.png)(所有大写字符)。

编译的结果其实是一个指令图，从描述上更加和第一篇文章里面的图更加贴近，但打印出来看其起来是一个虚拟机的执行程序。

编译成UTF-8的形式会让编译器更加复杂，但是会让匹配引擎执行更快：每次都只处理一个字节。对于每次只处理一个字节，也让很多匹配器更加容易处理匹配过程。



## Step 4: Match

到现在为止，前面所有的讨论都是构建一个RE2。在构建好RE2以后，就可以用来执行匹配操作。从使用者角度来看，只有两个方法：`RE2::PartialMatch`用来在输入文本里面找到第一个匹配的子串，和`RE2::FullMatch`用来完整搜索整个输入字符串的。但从RE2的实现角度，这里是有非常多可以讨论的地方。RE2主要处理4类基本的正则表达式匹配问题：

1. 正则表达式是否和整个输入字符串匹配？

   > RE2::FullMatch(s, "re")
   >
   > RE2::PartialMatch(s, "^re$")

2. 正则表达式是否匹配输入字符串里面的一个子串？

   > RE2::PartialMatch(s, "re")

3. 如果正则表达式匹配字符串中的一个子串，那么具体是哪个子串？

   > RE2::PartialMatch(s, "(re)", &match)

4. 如果正则表达式匹配字符串中的一个子串，那么具体是哪个子串，同时相应的子匹配是什么？

   > RE2::PartialMatch(s, "(r+)(e+)", &m1, &m2)

接下来会对上面的4中情况分别做描述。从使用者的角度，提供4种匹配使用看起来应该已经足够。但从实现角度来看的话，并不是这样来区分的，而且前面的问题其实是比后面的问题有更加高效手段实现的(只判定是否匹配肯定其实相对子匹配来说要简单一些)。



## _Does the regexp match the whole string ?_

> RE2::FullMatch(s, "re")
>
> RE2::PartialMatch(s, "^re$")

这个问题，其实在第一篇文章里面我们就有解析。在第一篇文章中，我们看到通过运行时生成一个简单的DFA来达到目的。[RE2也是采用的DFA](http://code.google.com/p/re2/source/browse/re2/dfa.cc#5)来解决这个问题，只是这里的DFA在内存使用和线程安全上有更多的改进，主要来自如下的两个修改。

_Be able to flush the DFA cache_一个给定的正则表达式和输入文本，是可能导致每处理一个字节，都需要DFA创建一个新的状态的。对于大型的输入文本来说，状态是一个快消品。在RE2的DFA里面，他的状态会有一个[cache来管理](http://code.google.com/p/re2/source/browse/re2/dfa.cc#1081)。这样让DFA的整个匹配过程对于内存来说是恒定的。

_Don't store state in the compiled program_在DFA第一篇文章里面，我们用一个整形的序列号字段在编译程序里面来追踪状态是否出现在特定的列表里面(s->lastlist和listid)。这个追踪手段让我们把状态加入列表的时候可以在常量时间里面进行去重操作。在一个多线程的程序里面，在线程之间共享同一个RE2对象，这个对象来唯一的管理序列号，这样就有引入了锁。但我们肯定是希望在常量时间内能处理列表的插入去重操作的。幸运的是，有一个数据结构稀疏集合就是被设计用来干这个事情的。RE2实现了这个数据结构[SparseArray](http://code.google.com/p/re2/source/browse/util/sparse_array.h)，详情可以参考这个[文章](http://research.swtch.com/2008/03/using-uninitialized-memory-for-fun-and.html)。



## _Does the regexp match a substring of the string ?_

> RE2::PartialMatch(s, "re")



