# Regular Expression Matching with a Trigram Index or How Google Code Search Worked



## Introduction

2006年暑假，非常幸运能够在Google进行实习。当时，Google内部与一个叫gsearch的工具，这个工具看起来是可以在Google的整个代码库的所有文件进行grep操作，然后打印出搜索结果。当然，当时他的实现是比较挫的，而且运行也是非常慢的，其实gsearch做的就是向一组把整个source-tree加载到内存里面的服务器发请求：在每一台机器上对里面加载的source-tree执行grep操作，然后gsearch会合并所有的搜索结果并打印出来。Jeff Dean, 我实习期间的老板，也是gsearch的作者之一，做了一个提议说，如果做一个web入口，然后上面提交搜索请求，然后可以在全世界所有的开源代码上运行gsearch会是一个很吊的事。我一听觉得有点意思，所以我那个夏天我就在Google干这个自己看来吊吊的事情。由于我们开始的计划过分乐观，我们的发布延后到了10月份，到2006年10月5号的时候，我们终于发布了(那个时候我刚好会学校了，但依然是兼职实习的状态)。

因为碰巧对Ken-Thompson的Pan-9里面的grep有过了解，所以这个项目的早期Demo是我基于Pan-9的grep搭建的。原计划是准备切换到一个更加现代的正则引擎，或者是PCRE，或者是自己全新写的。对于PCRE来说，因为他的解析那块的代码有一个众所周知的安全问题，所以对这块代码有完整的Review。那个时候发现的一个问题是现在这些流行的正则实现，[不管是Perl，还是Python或者PCRE都不是基于状态机实现](http://swtch.com/~rsc/regexp/regexp1.html)。这个发现，对于我来说是有点小吃惊的，因为Rob-Pike写了Plan 9 的正则引擎，所以当我跟他交流的时候，他也收到了一万点惊讶(当时Ken还没有在Google，所以当时也就还没有跟Ken进行相关的交流)。我一起再学校的时候，在龙书上有学习过正则表达式以及状态机，也通过阅读Rob和Ken的相关代码对这块实作有过了解。其实在我的理解里面，这块的搜索匹配理所当然的理解应该应该是线性时间复杂度的。但后面发现Rob实作，其实很少有人知道，而且在实作后的这么长时间内也基本是[被大家遗忘的状态](http://swtch.com/~rsc/regexp/regexp2.html#ahu74)。有了前面的了解过后，所以这个项目启动的时候，我们就基于Pan-9的相关grep代码来构建的；这部分在几年后，也已经用我实作的RE2进行替代升级。

代码搜索这个是Google第一个也是唯一的一个只接受正则表达式作为输入的搜索引擎。然后发现比较悲剧的是大部分程序猿都不会写正则表达式，更加不用说写一个高效的正则表达式。所以在进代码搜索的时候，会有一个"正则表达式"本身的辅助搜索站点出现，类似当你输入"电话号码"的时候会得到相应的正则表达式`\(\d{3}\) \d{3}-\d{4}`。

在2010年5月份，给代码搜索项目写的[RE2](http://code.google.com/p/re2)，现在是[Google 开源正则引擎](http://google-opensource.blogspot.com/2010/03/re2-principled-approach-to-regular.html)。代码搜索项目以及相关的RE2成功的帮助很多同学深入的了解了正则表达式；而且Tom Christiansen最近跟我说，在Perl社区也已经开始使用RE2了(Mre::engine::RE2)，现在网页上的实际运行的正则引擎已经是RE2了，而不是原来那个容易遭受服务攻击的引擎。

在2011年的10月份，Google宣布了新的调整，[重新聚焦在高影响力的产品上](http://googleblog.blogspot.com/2011/09/fall-spring-clean.html)，其中也包括[关掉代码搜索项目](http://googleblog.blogspot.com/2011/10/fall-sweep.html)，所以现在大家可以看到代码搜索项目已经下线了。在这个时间点，作为深入参与整个项目过程的一个老鸟来说，觉得是应该写一点什么来纪念或者说回顾一下代码搜索项目中做的相关工作。代码搜索项目，其实是建立在Google的世界级的文档索引和检索工具集上的；本文提到的相关实现，聚焦在单机上完成海量代码的索引和检索。



## Indexed Word Search

在我们进入正则搜索前，我们需要先来了解一下基于单词的全文搜索是怎么做的。全文搜索的关键是一个叫做位置列表或者反向索引的数据结构，这个这个列表里面会列出所有可能的搜索条目，每个条目列举的是包含这个条目的所有相关文档。

举例来说，有如下三个非常短的文档：

* (1) Google Code Search
* (2) Google Code Project Hosting
* (3) Google Web Search

上面三篇文档的Inverted-index看起来会是这样的：

​	Code: {1, 2}

​	Google: {1, 2, 3}

​	Hosting: {2}

​	Project: {2}

​	Search: {1, 3}

​	Web: {3}

为了找到所有包含Code和Search的文档，你需要加载索引 Code {1, 2}和 Search {1, 3}，然后进行做集合的差操作，得到集合 {1}。为了找到包含Code或者Search的文档，你需要加载相应的索引然后做集合的并操作。因为Inverted-index本身是有序的，所以相应的集合操作都是线性时间复杂度。

在全文搜索引擎里面，为了支持文本分析应用，通常会在Inverted-index记录每一次单词出现的具体的位置，这样上面的索引结构数据会是如下：

​	Code: {(1, 2), (2, 2)}

​	Google: {(1, 1), (2, 1), (3, 1)}

​	Hosting: {(2, 4)}

​	Project: {(2, 3)}

​	Search: {(1,3), (3, 4)}

​	Web: {(3, 2)}

比如现在我们需要找到"Code Search"，其中的一种方法是先加载Code对应的Inverted-index列表，然后扫描Code的列表，找到那些至少有一个后继单词的条目。其中Code的列表里面的条目(1,2)，以及Search列表里面的条目(1,3)都是来自文档1，并且他们具备单词的连续性(一个是2，另外一个是3)，所以文档1包含文本"Code Search"。

另外一个可选的方案，是把搜索的文本进行分词，然后把他理解为一组单词查询的与操作，其中每个单词都能找到相关的候选文档，然后加载候相应文档后，在文档上执行搜索，并过滤掉那些找不到相应匹配的文档。在实际的应用中，这种方法对于类似"to be or not to be"的搜索文本来说，不太可行。在索引里面存储位置信息会加大索引本身的存储空间，并增加索引更新的代价，但是可以最大限度的来避免去磁盘加载不必要的文档。



## Indexed Regular Expression Search

全球的代码量已经可以用海量来形容了，所以我们基本是没有可能把所有代码都加载到内存，然后在上面进行正则搜索，这个其实不管你的正则匹配效率有多高，都是不可行的。代码搜索项目，我们使用了一个inverted-index来检索每个匹配请求的候选文档，我们对候选文档进行搜索，打分，分级然后合并相关的结果呈现出匹配结果。

因为正则匹配并不是以单词为搜索边界的，所以这里的inverted-index是不能像前面的例子一样以单词为基础来构建。对于这种场景，我们使用一种古老的信息检索编码技术[n-grams/n-元语法](https://en.wikipedia.org/wiki/N-gram "n-元语法")，长度为n的字符子串(基于[n阶的马尔科夫链概率模型](https://en.wikipedia.org/wiki/Markov_chain))。光从名字其实看不出特别，在实际的工业应用中，采用2-grams的不多，采用4-grams的有很多，然后采用3-grams(三元语法)的不算多也不算少。

继续以上一节的例子来说明问题，假如还是如下的文档集合：

 	(1) Google Code Search

​	(2) Google Code Project Hosting

​	(3) Google Web Search

具备如下的三元索引：

```
_Co: {1, 2}     Sea: {1, 3}     e_W: {3}        ogl: {1, 2, 3}
_Ho: {2}        Web: {3}        ear: {1, 3}     oje: {2}
_Pr: {2}        arc: {1, 3}     eb_: {3}        oog: {1, 2, 3}
_Se: {1, 3}     b_S: {3}        ect: {2}        ost: {2}
_We: {3}        ct_: {2}        gle: {1, 2, 3}  rch: {1, 3}
Cod: {1, 2}     de_: {1, 2}     ing: {2}        roj: {2}
Goo: {1, 2, 3}  e_C: {1, 2}     jec: {2}        sti: {2}
Hos: {2}        e_P: {2}        le_: {1, 2, 3}  t_H: {2}
Pro: {2}        e_S: {1}        ode: {1, 1}     tin: {2}
```

(其中字符'_'代表的是空格)

给定如下的正则表达式`/Google.*Search/`，我们可以构建一个三元语法单元的AND和OR的符合查询，这个复合查询表达的是正则匹配的超集(匹配正则的文本都需要匹配给出的这个三元语法单元的符合查询)。所以上面的三元复合查询会是：

`Goo` AND `oog` AND `ogl` AND `gle` AND `Sea` AND `ear` AND `arc` AND`rch`

我们可以在上面的三元索引上执行上面的三元查询，找出候选文档的合集，然后在每一篇文档上执行相应的正则匹配。

把正则表达式转换到一个三元语法单元的过程并不是简单的从正则表达式里面提前子串然后进行AND连接操作。当正则表达式里面用到`|`操作符的时候需要转换到相应的OR查询，当涉及到括号括起来的子表达式的时候，这个转换过程会变得更加复杂。

一个完备的转换规则，会从每个正则表达式计算得到5个结果：空字符串是否是正则表达式的匹配字符串；正则表达式的确切的匹配集合的或者判定出确切集合是未知的；一个正则表达式匹配字符串的前缀字符串集合；一个正则表达式匹配字符串的后缀字符串集合；另外一个与前面类似的所有匹配字符串的集合通常用来表征匹配字符串的中部。下面的规则定义正则表达式的单元的转换规则：

| ‘’ (empty string)          |                         |      |                                          |
| -------------------------- | ----------------------- | ---- | ---------------------------------------- |
|                            | emptyable(‘’)           | =    | true                                     |
|                            | exact(‘’)               | =    | {‘’}                                     |
|                            | prefix(‘’)              | =    | {‘’}                                     |
|                            | suffix(‘’)              | =    | {‘’}                                     |
|                            | match(‘’)               | =    | ANY (special query: match all documents) |
| `c` (single character)     |                         |      |                                          |
|                            | emptyable(`c`)          | =    | false                                    |
|                            | exact(`c`)              | =    | {`c`}                                    |
|                            | prefix(`c`)             | =    | {`c`}                                    |
|                            | suffix(`c`)             | =    | {`c`}                                    |
|                            | match(`c`)              | =    | ANY                                      |
| *e*? (zero or one)         |                         |      |                                          |
|                            | emptyable(*e*?)         | =    | true                                     |
|                            | exact(*e*?)             | =    | exact(*e*) ∪ {‘’}                        |
|                            | prefix(*e*?)            | =    | {‘’}                                     |
|                            | suffix(*e*?)            | =    | {‘’}                                     |
|                            | match(*e*?)             | =    | ANY                                      |
| e* (zero or more)          |                         |      |                                          |
|                            | emptyable(*e**)         | =    | true                                     |
|                            | exact(*e**)             | =    | unknown                                  |
|                            | prefix(*e**)            | =    | {‘’}                                     |
|                            | suffix(*e**)            | =    | {‘’}                                     |
|                            | match(*e**)             | =    | ANY                                      |
| *e*+ (one or more)         |                         |      |                                          |
|                            | emptyable(*e*+)         | =    | emptyable(*e*)                           |
|                            | exact(*e*+)             | =    | unknown                                  |
|                            | prefix(*e*+)            | =    | prefix(*e*)                              |
|                            | suffix(*e*+)            | =    | suffix(*e*)                              |
|                            | match(*e*+)             | =    | match(*e*)                               |
| *e*1 \| *e*2 (alternation) |                         |      |                                          |
|                            | emptyable(*e*1 \| *e*2) | =    | emptyable(*e*1) or emptyable(*e*2)       |
|                            | exact(*e*1 \| *e*2)     | =    | exact(*e*1) ∪ exact(*e*2)                |
|                            | prefix(*e*1 \| *e*2)    | =    | prefix(*e*1) ∪ prefix(*e*2)              |
|                            | suffix(*e*1 \| *e*2)    | =    | suffix(*e*1) ∪ suffix(*e*2)              |
|                            | match(*e*1 \| *e*2)     | =    | match(*e*1) OR match(*e*2)               |
| *e*1 *e*2 (concatenation)  |                         |      |                                          |
|                            | emptyable(*e*1*e*2)     | =    | emptyable(*e*1) and emptyable(*e*2)      |
|                            | exact(*e*1*e*2)         | =    | exact(*e*1) × exact(*e*2), if both are known |
|                            |                         |      | or       unknown, otherwise              |
|                            | prefix(*e*1*e*2)        | =    | exact(*e*1) × prefix(*e*2), if exact(*e*1) is known |
|                            |                         |      | or       prefix(*e*1) ∪ prefix(*e*2), if emptyable(*e*1) |
|                            |                         |      | or       prefix(*e*1), otherwise         |
|                            | suffix(*e*1*e*2)        | =    | suffix(*e*1) × exact(*e*2), if exact(*e*2) is known |
|                            |                         |      | or       suffix(*e*2) ∪ suffix(*e*1), if emptyable(*e*2) |
|                            |                         |      | or       suffix(*e*2), otherwise         |
|                            | match(*e*1*e*2)         | =    | match(*e*1) AND match(*e*2)              |

上面的规则很完整，但是仅仅依据上面规则来转换正则表达式并不能得到有效的查询语句，并且转换某些正则表达式的时候，得到是查询语句集合很容易是指数增长的。所以，在上述的每一个转换步骤，我们可以来进行一些简化，使得到的查询信息可控。首先我们来抽象一个函数计算三元语法单元。

三元函数(计算三元语法单元的函数)的输入可以是任意的字符串，如果字符串长度小于3的时候，匹配的是任意单元；如果长度大于3，那么函数得到是字符串里面所有三元语法单元的AND连接串。三元函数输入的如果是一组字符串，那么输出是分别针对每个字符串进行转换得到的三元串，然后对这组三元串进行OR连接，就是这一组字符串的三元查询结果。

(单个字符串)

- trigrams(`ab`) = ANY
- trigrams(`abc`) = `abc`
- trigrams(`abcd`) = `abc` AND `bcd`
- trigrams(`wxyz`) = `wxy` AND `xyz`

(一组字符串)

- trigrams({`ab`}) = trigrams(`ab`) = ANY
- trigrams({`abcd`}) = trigrams(`abcd`) = `abc` AND `bcd`
- trigrams({`ab`, `abcd`}) = trigrams(`ab`) OR trigrams(`abcd`) = ANY OR (`abc` AND `bcd`) = ANY
- trigrams({`abcd`, `wxyz`}) = trigrams(`abcd`) OR trigrams(`wxyz`) = (`abc` AND `bcd`) OR (`wxy` AND `xyz`)

任意的正则表达式，在表达式分析的每一个步骤，我们都可以决定这个步骤上应用哪些三元转换。上述的三元转换会得到不同的计算过程信息，我们可以有选择性的来应用和抉择，以保障整个过程和最后得到的结果信息都是可控的：

(信息保留转换)

- At any time, set match(*e*) = match(*e*) AND trigrams(prefix(*e*)).
- At any time, set match(*e*) = match(*e*) AND trigrams(suffix(*e*)).
- At any time, set match(*e*) = match(*e*) AND trigrams(exact(*e*)).

(信息丢弃转换)

- If prefix(*e*) contains both *s* and *t* where *s* is a prefix of *t*, discard *t*.
- If suffix(*e*) contains both *s* and *t* where *s* is a suffix of *t*, discard *t*.
- If prefix(*e*) is too large, chop the last character off the longest strings in prefix(*e*).
- If suffix(*e*) is too large, chop the first character off the longest strings in suffix(*e*).
- If exact(*e*) is too large, set exact(*e*) = unknown.

一个可取的应用转换的办法是在进行“信息丢弃转换”之前先进行一次"信息保留转换"。高效的转换是尽可能的丢弃从前置，后缀以及确定集上得到的那些信息中的冗余信息，让进入最终查询集本身的信息更加内敛。在另外一个方面，我们也可以在表达式的链接分析中再挤掉一些冗余信息：如果e1e2是不确定的，那么match(e1e2)的时候可以应用如下的转换 `trigrams( suffix(e1)  ×  prefix(e2))`。

除了前面提到的那些转换，我们可以简单的用“布尔简化”来简化变换构造后的匹配查询语句：比如`abc OR (abc AND def)`查询比`abc`要复杂，查询代价大，但本身表达是意思还不如`abc`来得精确。



## Implementation

为了示范上面提及的想法，我发布了一个用[Go编写的基础版本](http://code.google.com/p/codesearch)。如果你安装了最新的[Go的版本](http://golang.org/)，你可以直接运行：

```
goinstall code.google.com/p/codesearch/cmd/{cindex,csearch}
```

来安装相应的二进制命令 cindex 和 csearch。如果你么有安装Go，可以[下载二进制的安装包](https://code.google.com/p/codesearch/downloads/list)，支持FreeBSD, Linux, OpenBSD, OS X, 和 Windows 平台。

首先第一步是运行cindex，cindex接受一个目录的列表或者文件列表作为参数，来建立索引：

```
cindex /usr/include $HOME/src
```

默认情况下cindex是把生成的索引加入到现在的索引库里面，所以上面的命令其实等价于如下：

```
cindex /usr/include
cindex $HOME/src
```

在不带参数的情况下，cindex是刷新本地已经存在的索引，所以运行上述命令后，再继续运行：

```
cindex
```

会重新扫描 /usr/include 和 $HOME/src ，然后重写相关的索引文件。要找到相关的帮助信息可以运行 `cindex -help`。

[The indexer](https://code.google.com/p/codesearch/source/browse/cmd/cindex/cindex.go)会假定所有处理的文件都是以UTF-8为编码的。对于那些包含无效的UTF-8的文件或者说是行数过大的文件，或者说是拥有的三元语法单元过于庞大的文件，都会被索引处理程序丢弃掉。









