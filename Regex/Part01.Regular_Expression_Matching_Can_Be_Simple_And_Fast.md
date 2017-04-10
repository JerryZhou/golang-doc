# Regular Expression Matching Can Be Simple And Fast

## Introduction
关于正则表达式有这么一个小段子，有两个方法来实现正则匹配。其中一种是被广泛使用的，许多的编程语言都是用的这种，几乎是一种标准的实现，包括我们见到的Perl、Python等；另外一种只是在少数几个不太起眼的地方用到，比如Unix下的工具awk和grep。两个方法的性能数据差别很大，如下图所示：
![a?a?a?aaa](https://swtch.com/~rsc/regexp/grep3p.png)![image](https://swtch.com/~rsc/regexp/grep4p.png)
```math
 a?^3a^3 == a?a?a?aaa
```
前面出现的a?-n-a-n-我们来简化一下表达式，比如a?-3-a-3-就是a?a?a?aaa的简写，上面的测试案例就是用上述的重复式样来匹配a-n-这样的原字符串。

我们可以注意到在测试数据差异非常大，Perl匹配长度为29的字符串就已经需要超过60秒，而另外一种叫做Thomposon-NFA的方法只需要20毫秒。而且图里面我们看到对于NFA对应的方法它的时间抽的单位是毫秒，而且对于长度越长的正则串，他们之间的差异就越大，对于100个字符的船,Thompson只需要200毫秒，而Perl采用的方法却需要10-15-年(其实Perl只是一种比较典型的语言，其他常见的Python、PHP或者Ruby等都是类似的状况)。

前面的图表看起来非常难以置信：或许你也有使用过Perl，而且也没有觉得它的正则表达式有性能问题。事实上，大部分时间，Perl的正则匹配效率还是很高的，只是确实我们可以很容易写出一种对Perl可以称为“病态”的正则串，但是对Thompson-NFA来说确是一个非常正常的串。需要这个时候你可以心里已经产生了一个疑问：为什么Perl不采用Thompson-NFA的这种实现方式呢？他确实可以，而且应该采用这种方式，这篇文章下面的内容就会详细的讲解NFA的具体实现算法。

历史上，正则表达式是计算机科学中一个非常典型的理论走向工程，并完美结合的例子。正则表达式是理论学家发明的一个非常简单的计算模型，Ken Thompson把他带到了工业界，带给了广大的程序员，他在给CTSS实现文本编辑器QED的时候实现了正则表达式。后面Dennis Ritchie跟随脚步，在给GE-TSS写文本编辑器GED的时候也干了这个事情。 后面Thompson和Ritchie一起去倒腾Unix的时候也一并把正则表达带进来了。在70年代后期，正则表达式在Unix上也形成了一道亮丽的独特风景，许多的工具应运而生，包括ed、grep、awk和lex等。

今天，正则表达式也成为了一个非常典型的失败例子，我们看到在脱离理论后，在工业界，在广大的程序员手上被整得不成样子。今天我们流行的这些使用正则表达式的工具，他的运行效率比30年的Unix工具效率还低，并且已经低到不能忍的地步了。

这篇文章我们会来回顾老头子Thomposon在1960年代中期发明的关于正则表达式，有限状态机，正则匹配搜索算法等理论知识。同时我们也会在这篇文章中把相关理论的实现做描述。其实整个实现还不到400行C代码，但它其实比Perl里面的那种实现不知道要优秀了多少代，同时他的实现复杂度还比那些被用在Perl、Python、PCRE等还要低。这边文章会讨论理论，同时也会把理论怎么到具体的实现做讨论和阐述。

## Reglular Expressions

正则表达式其实是一个助记符，他描述的就是一组字符串。如果给定的字符串出现在正则表达式描述的字符串组里面，我们就说这个正则表达式匹配当前字符串。

一个最简单的正则表达式就是一个单独的字符，当前我们这里要去掉如下的一些元字符`*+?()|`，如果要匹配这些元字符，我们需要在元字符前面加一个反斜杠：比如`\+`匹配加号字符。

可以通过两个正则规则：可选和连接来组成新的正则表达式。如果`e1`匹配`s`以及`e2`匹配`t`，那么`e1|e2`可以匹配`s`或者`t`；`e1e2`匹配`st`。

元字符 `*`、`+`和`?`都是属于重复操作符：`e*`匹配零个或者多个字符串(字符串可以不一样)，其中每一个字符串都匹配规则`e`；`e+`匹配一个或者多个；`e?`匹配零个或者一个。

操作符的处理优先级是 或操作 < 连接操作 < 重复操作。一个明确的括号符可以用来强制表达不同的意思，和算术运算里面一样，比如：`ab|cd`和`(ab)|(cd)`是等价的；`ab*`和`a(b*)`是等价的。

到现在为止，我们描述的正则表达式是传统的Unix的egrep正则表达式语法的一个子集。现在描述的这个子集已经足够来描绘正则语言：简单说，正则语言就是一组字符串，在一个固定的内存消耗下，这组字符串我们可以通过一个pass就可以来对目标串进行匹配。现在新的正则表达式(比较典型的是Perl里面的正则表达式)都是在这个基础上，新增一些新的操作符合和一些编码串。新增的这些正则表达式规则会让正则语言编写更简单，但有的时候这些新增的规则也把这个搞复杂同时还没有达到强化匹配的目的。而且新增的那些看起来很漂亮的表达式通常都还不如用传统的语法来表达。

一个给正则表达式提供额外能力的典型扩展就是`backreferences`后向引用。后向引用的意思就是用`\1`或者`\2`这样的表达式来匹配前面已经匹配过的具体字符串。比如`(cat|dog)\1`可以匹配`catcat`或者`dogdog`，但不能匹配`catdog`或者`dogcat`.严格意义上来说`backreferences`不是正则表达式，而且支持的`backreferences`需要消耗巨大的代价，比如典型的在Perl里面，在某些条件下这个搜索算法是指数复杂度的。而且现在Perl等语言已经不能移除对`backreferences`的支持了。当然这些语言可以改进相关实现，对于没有出现`backreferences`的正则表达式采用一些其他的算法。

## Finite Automata

另外一个用来描述一组字符串的方法就是有限状态机。在后面想文章中，我们会交替使用`automaton`和`machine`来表达这个。

下面一个简单的例子，我们来看下和正则表达式`a(bb)+a`匹配同样的一组字符串的这么一个状态机：

![image](https://swtch.com/~rsc/regexp/fig0.png)

一个有限状态机他任何时候都会处于它其中的某一个状态(前面图中的一个圆圈就是一个状态，圈圈里面的标签我们文章的后面再说明)。这个状态机从字符串一个一个读取字符的时候，他会从一个状态到另外一个状态进行迁移。状态机有两个特殊的状态：一个起始状态`s0`和匹配状态`s4`。起始状态会有一个缺少来源线的箭头指向它，而匹配状态会被画成两个圈的形式。

状态机从字符串一个字符一个字符的读取，输入字符串上的箭头标示当前的读取字符，状态机上状态间的连接箭头上的字符标示的是状态间转移的条件字符。键入输入字符串是`abbbba`。状态机读取的第一个字符是`a`，这个时候状态机处于`s0`，读取`a`后跳转到`s1`。状态机在一次从输入串读取其他字符重复这个过程：依次读`b`跳转到`s2`，读`b`跳转到`s3`，读`b`跳转到`s2`，读`b`跳转到`s3`，最后读`a`跳转到`s4`。

![image](https://swtch.com/~rsc/regexp/fig1.png)

状态机最后停留在`s4`的匹配状态，这个时候就叫做状态机匹配字符串`abbbba`。如果状态机最后停留的状态不是`s4`，那么状态机就不匹配这个字符串。如果在状态机执行的过程中，读取一个字符后，发现没有相应的状态可以跳转，这个时候状态机就会过早的停下来。

我们前面描述的状态机，我们叫做DFA(deterministic finite automaton)确定有限状态机，在任何状态下，每一个可能的字符输入都会有至多有一个新的跳转状态。我们也可以创建一状态机，他在某些情况下可以有多个可选的跳转状态下做选择。比如下面的状态机他就不是确定的：

![image](https://swtch.com/~rsc/regexp/fig2.png)

这个状态机就不是确定的，因为当他处于`s2`的状态的时候，如果读取`b`后，下一个跳转状态有多个选择，他可以跳转到`s1`也可以跳转到`s3`。因为状态机对后续的输入这个时候还是未知的，他没有足够的信息来做正确与否的决定，这个时候到底跳转到那个状态才是正确的是一个非常有意思的事情。对于这种状态机，我们叫非确定性状态机NFAS后者NDFAS。对于NFAS来说，如果存在一条路径匹配字符串，我们就叫这个NFA匹配这个字符串。

有的时候，如果允许NFA里面出现一种零输入的跳转是一个非常便利的方法。我们对于不需要输入的跳转，我们在图上他们的跳转箭头上就不写任何输入标示。一个NFA如果处于存在无标示跳转的状态，他可以选择不读取任何数据而执行相应的无标示跳转。下面图中的状态机与前面的状态机等价，但他更清晰的表达了正则表达式`a(bb)+a`：

![image](https://swtch.com/~rsc/regexp/fig3.png)

## Converting Regular Expressions to NFAs

可以证明在能力上正则表达式和NFAs他们是等值的：每一个正则表达式都有一个NFA(他们匹配同样的字符串组)匹配。(其实也可以证明DFAs在能力上与NFAs以及正则表达式也是一致的，这个我们在文章的后面会看到)。有多种方法可以把正则表达式转换到NFAs。本文描述的方法由Thompson在1968年发表在CACM的论文上。

一个正则表达式的NFA是通过组合一组对应到正则表达式的子表达式匹配的NFAs构造的。正则表达式里面的每一个操作符都有一种他自己的组合方式。每一个子表达式对应的NFAs本身是不具备匹配状态的(子表达式对应的状态机是没有终结状态的)，反而他们会有一些指向未知状态的箭头，整个构造过程会把这些链接起来构造一个完整的匹配状态。

匹配单独一个字符的NFAs看起来是这样的：

![image](https://swtch.com/~rsc/regexp/fig4.png)

链接操作符`e1e2`的NFA看起来是这样的，`e1`的结束箭头指向`e2`的开始：

![image](https://swtch.com/~rsc/regexp/fig5.png)

可选操作符`e1|e2`会增加一个起始状态来做选择：

![image](https://swtch.com/~rsc/regexp/fig6.png)

重复操作符`e?`的状态机会增加一个空的路径：

![image](https://swtch.com/~rsc/regexp/fig7.png)

重复操作符`e*`和前面的类似，只是增加一个循环路径：

![image](https://swtch.com/~rsc/regexp/fig8.png)

重复操作符`e+`也会创建一个循环路径，只是他会要求这儿循环路径至少执行一次：

![image](https://swtch.com/~rsc/regexp/fig9.png)

前面的图我们可以看出，我们会为每一个字符包括每一个元字符会创建一个相应的状态。因此最后NFA的状态数基本会和正则表达式一样。

通过前面的NFA例子，我们知道任何时候都可以移除哪些没有标示的状态跳转箭头，我们也可以完全不依赖这种无标示跳转，只是加上这种跳转会更清晰的表达正则表达式，而且更加容易理解，而且让后面的C语言实现也更加简单，所以我们保留这种无标示跳转。

## Regular Expression Search Algorithms

现在我们已经有方法可以用来检测字符串与正则表达式匹配与否了：通过把正则表达式转换到一个NFA，然后把目标字符串当做NFA的输入。这里需要提醒一下的是NFAs的运作是假定在遇到多个可选的跳转状态的时候，状态机能对下一个跳转状态做出完美预判的能力，也就是我们需要为NFAs找出一种方法来模拟这种预判的能力。

其中一种模拟预判的方法是：任意选择一条路径，如果不行再退回来选择另外一条路径。比如正则表达式`abab|abbb`等价的NFA状态机在处理字符输入`abbb`的情形：

![image](https://swtch.com/~rsc/regexp/fig10.png)

![image](https://swtch.com/~rsc/regexp/fig11.png)

在 step-0的时候，NFA做出面临的选择：选择用`abab`来匹配还是`abbb?`来匹配。在上面的图表中，NFA选择了`abab`，但是当输入进行到step-3的时候，匹配失败。然后NFA退回去到step-4选择另外一条路径。这种回退的方法可以用递归的方式来简单实现，只是我们需要对输入字符串进行多次读取。在这总递归的处理中，如果遇到匹配失败，自动机需要退回去选择其他路径，直到所有可能的路劲都尝试到了。在上面的例子中，我们看到只有两个可能的选择，在实际情况中，这种可能的路劲很容易引入指数的复杂度。

另外一个更加高效但是相对比较难进行模拟实现的方法是进行平行处理，在面对处理多个选择的时候，我们同时对多个选择进行处理。这种情况需要状态机可以同时处理多个状态，状态机对于匹配成功的状态会同时更新到下一个状态。

![image](https://swtch.com/~rsc/regexp/fig12.png)

上图中，状态机开始在起始状态，然后在step-1和step-2里面，NFA同时处于两个状态，然后到step-3的时候状态又只匹配到一个状态。在这种多状态并行处理的方法中，我们对于输入字符串只会遍历一次。对于这种并发的状态机，最差的情况就是每次输入我们的状态机都会同时处于所有可能的状态，但是这种情况的复杂度其实与输入字符串的长度是保持线性复杂度的，这个与前面递归情况的指数复杂度是一个巨大的性能提升，这种提升主要来自于我们枚举的是可能的状态数，而不是可能的路径数，比如对于一个有n个状态节点的NFA，任何时候，我们都至多同时处于n个状态，但是对于NFA的路劲来说却有2^n条。

## Implementation

Thompson在他1968年发表的论文里面介绍了一种多状态并发的实现方法。在他的理论体系下，NFA的状态会用一串非常简洁的机器码的序列来表示，其中这些机器码都是一些简洁的函数调用指令。非常关键的是，Thompson把正则表达式编译成非常聪明和优秀的机器码来提升整体的执行效率。在40年后的今天，计算机的计算能力已经有了质的飞跃，这种机器码的方式已经不是非常必须了。接下来的小节中，我们会用ANSI-C的方式来实现，全部的代码量不足400行，我们也对这个做了性能的压力测试，具体相关数据可以在网上找到(对于不熟悉C语言和指针的读者可以跳过具体的实现代码，只看相关的描述就好)。

### Implementation: Compiling to NFA

第一步要做的就是把正则表达式翻译成NFA状态机。在我们的C的程序里面，我们用如下的结构体代表状态，而状态机是如下结构体所示状态的一个链表：


```
struct State
{
    int c;
    struct State *out;
    struct State *out1;
    int lastlist;
};
```
每一个状态都根据c的具体的值，代表如下的三种NFA片段中的一种：

![image](https://swtch.com/~rsc/regexp/fig13.png)

(参数lastlist会在状态机执行的过程中用到，后面的小节会详细解释这个参数)

在Thompson的论文里面，编译器接受的正则表达式是采用逗号`.`的后缀标记法，什么意思呢，就是会用逗号来明确表达连接操作。里面会写一个函数`re2post`专门来做这个转换，比如把如下的正则表达式`a(bb)+a`转换后缀标记法`abb.+.a.`的形式(在实际的实现上逗号是属于元字符中的一个，一个正儿八经对外用的编译器一般是直接操作正则表达式，而不会做这一次转换，我们这里为了更加贴近Thompson的论文，而且确实后缀标记法也确实有提供一定的便利性，我们依然沿用这种标记方法)。

在扫描后缀正则表达式的时候，编译器会维持一个NFA-fragments的栈结构；遇到普通字符的时候会产生新的NFA-fragment然后入栈，遇到操作符的时候会pop栈，然后根据操作的具体类型产生新的NFA-fragment并入栈。比如例子里面的，在扫描了`abb`的时候，栈里面就有三个NFA-fragments片段，分别是`a`，`b`和`b`。然后遇到`.`操作符，他会pop栈上的两个`b`的NFA-fragment，然后会产生一个新的NFA-fragment来代表`bb..`的连接操作。每一个NFA-fragment都由他自己的本身的状态值和相应的outgoing外链箭头组成：

```
struct Frag
{
    struct State *start;
    Ptrlist *out;
};
```
其中`start`是片段的起始点，`out`是一个指向`struct State*`的指针列表，指针列表里面的状态暂时还没有指向任何其他下一个状态，处于一个待链接的状态，他们是NFA-fragment里面的dangling-arrows。

下面有一些辅助函数来操作这个指针列表：

```
Ptrlist *list1(struct State **outp);
Ptrlist *append(Ptrlist *l1, Ptrlist *l2);

void patch(Ptrlist *l, struct State *s);
```
函数`List1`会创建一个新的指针列表，指针列表包含一个指针`outp`。`append`函数会连接两个指针列表，然后返回连接后的结果。`Patch`函数会链接列表里面那些待连接的dangling-arraws到状态`s`：也就是变量`l`里面的`outp`指针，并设置`*outp=s`。

在给定的fragment和fragment-stack的情况下，编译器要做的事情就是一个简单的遍历后缀表达式的循环。在遍历结束后，栈上只留下一个frament：最后的这个fragment把他的待连接状态链接到一个matching-state，这个NFA就完整了。


```
State*
post2nfa(char *postfix)
{
    char *p;
    Frag stack[1000], *stackp, e1, e2, e;
    State *s;

    #define push(s) *stackp++ = s
    #define pop()   *--stackp

    stackp = stack;
    for(p=postfix; *p; p++){
        switch(*p){
        /* compilation cases, described below */
        }
    }
    
    e = pop();
    patch(e.out, matchstate);
    return e.start;
}
```
上面算法中的switch-case的具体情况，其实前面我们我们已经有过描述，这里再详细展开一次：
普通字符：

```
default:
    s = state(*p, NULL, NULL);
    push(frag(s, list1(&s->out));
    break;
```
![image](https://swtch.com/~rsc/regexp/fig14.png)

连接操作：

```
case '.':
    e2 = pop();
    e1 = pop();
    patch(e1.out, e2.start);
    push(frag(e1.start, e2.out));
    break;
```
![image](https://swtch.com/~rsc/regexp/fig15.png)

可选操作：

```
case '|':
    e2 = pop();
    e1 = pop();
    s = state(Split, e1.start, e2.start);
    push(frag(s, append(e1.out, e2.out)));
    break;
```
![image](https://swtch.com/~rsc/regexp/fig16.png)

零个或者一个：

```
case '?':
    e = pop();
    s = state(Split, e.start, NULL);
    push(frag(s, append(e.out, list1(&s->out1))));
    break;
```
![image](https://swtch.com/~rsc/regexp/fig17.png)

零个或者多个：

```
case '*':
    e = pop();
    s = state(Split, e.start, NULL);
    patch(e.out, s);
    push(frag(s, list1(&s->out1)));
    break;
```
![image](https://swtch.com/~rsc/regexp/fig18.png)

一个或者多个：

```
case '+':
    e = pop();
    s = state(Split, e.start, NULL);
    patch(e.out, s);
    push(frag(e.start, list1(&s->out1)));
    break;
```
![image](https://swtch.com/~rsc/regexp/fig19.png)

### Implementation: Simulating the NFA

经过前面的步骤，我们已经构建了一个NFA，现在我们需要来模拟运行状态机。模拟运行的过程需要追踪状态，我们把状态存储为一个简单的如下数组：

```
struct List
{
    State **s;
    int n;
};
```

状态机的模拟运行需要用到两个状态列表：`clist`代表当前的NFA所处的状态列表，`nlist`是NFA接受下一个输入以后的的状态列表。状态机运行前会初始化`clist`为zhi只包含开始状态，然后开始执行循环，每一步接受一个输入参数，从`clist`的状态列表转换到`nlist`的状态列表：


```
int
match(State *start, char *s)
{
    List *clist, *nlist, *t;

    /* l1 and l2 are preallocated globals */
    clist = startlist(start, &l1);
    nlist = &l2;
    for(; *s; s++){
        step(clist, *s, nlist);
        t = clist; clist = nlist; nlist = t;    /* swap clist, nlist */
    }
    return ismatch(clist);
}
```

避免在循环里面每次都申请创建列表，我们会预创建两个全局列表`l1`和`l2`，作为`clist`和`nlist`来用，每一步我们交换`l1`和`l2`做位`clist`和`nlist`。如果再处理完所有输入以后，最后NFA停留的状态列表里面包含了matching-state，我们就说当前的输入字符串与状态机匹配。


```
int
ismatch(List *l)
{
    int i;

    for(i=0; i<l->n; i++)
        if(l->s[i] == matchstate)
            return 1;
    return 0;
}
```

函数`Addstate`会把一个状态`state`加入列表，这个加入操作如果需要扫描整个列表来确认当前状态是否已经加入列表的话，会相对低效，所以这里我们用通过一个`listid`来代表当前列表的快照id,如果状态上的快照id和列表的快照id一致，就说明状态已经加入列表；`Addstate`函数会处理那种unlabeled-arraw，如果当前处理的状态是一个`Split`类型的状态，`Addstate`会把两个unlabeled-arraws指向的状态加入列表，而不是直接把这个`Split`状态加入列表。


```
void
addstate(List *l, State *s)
{
    if(s == NULL || s->lastlist == listid)
        return;
    s->lastlist = listid;
    if(s->c == Split){
        /* follow unlabeled arrows */
        addstate(l, s->out);
        addstate(l, s->out1);
        return;
    }
    l->s[l->n++] = s;
}
```

函数`Startlist`会创建一个包含起始状态`s`的列表。


```
List*
startlist(State *s, List *l)
{
    listid++;
    l->n = 0;
    addstate(l, s);
    return l;
}
```

最后函数`step`会处理一个字符输入，把状态机NFA前进一步，计算`clist`的所有状态变更，带入下一个状态列表`nlist`。

```
void
step(List *clist, int c, List *nlist)
{
    int i;
    State *s;

    listid++;
    nlist->n = 0;
    for(i=0; i<clist->n; i++){
        s = clist->s[i];
        if(s->c == c)
            addstate(nlist, s->out);
    }
}
```

## Performance

上面我们介绍的C语言的实现版本，并不是主要以性能优化为目的编写的。但即使是这样，他的复杂度依然是线性复杂度，而对于一个线性复杂度的算法写得再挫，只要输入参数足够大，也是很容易碾压一个精致实现的指数复杂度算法的版本。我们可以通过测试一些典型的比较难搞的正则表达式，来验证我们这里的结论。

考虑如下的正则表达式`a?^n.a^n`，`a?`不匹配任何字符的情况下，这个正则表达式会匹配到`a^n`，在匹配`a^n`的情况下，通过回溯的方式实现`?`zero-or-one的匹配算法，会开始尝试匹配one的情形，然后才会尝试匹配zero的情形，如果有n个类似这样的zero-or-one的选择，那么对于正则表达式来说就存在 2^n 这种潜在可能的路径，对于上面的情形，最快达成匹配结果的路径就是所有zero-or-one的选择，都选择到zero的情形。所以对于回溯算法来说，他的时间复杂度就是2^n的，如果n=25的情况，这个算法基本就是瘫痪的。

与Thomposon的算法对比，他需要维持一个与输入字符串长度n相近的状态列表，总的需要的时间复杂度最多是O(n^2)。(但匹配本身的时间复杂度是一个超线性复杂度，因为对于一个正则表达式来说，正则表达式本身不会随着输入的变化而产生变化，所以正则表达式的编译过程来说是一次性的。对于一个长度m的正则表达式，匹配长度为n的输入字符串，Thompson的NFA的匹配时间复杂度为O(mn))。

下面的图会列出用`a?^n.a^n`来匹配`a^n`的时间消耗对比：

![image](https://swtch.com/~rsc/regexp/grep1p.png)

我们会注意到上图中的y轴他是一个非等比的数轴，因为各种语言的正则算法那在时间消耗上差异巨大，为了在一张图里面能够呈现他们的时间消耗，我们采用了这种方式。

从图上我们能够清晰的认识到Perl, PCRE，Python和Ruby 都是采用的递归回溯的算法。而且PCRE在n=23的时候就已经不能正常执行匹配了，因为他的递归路径已经太长了。对于Perl来说，他宣称在5.6的版本中，优化了他的正则匹配引擎，最小化在匹配过程中的[内存消耗](http://perlmonks.org/index.pl?node_id=502408 "said to memoize")，他的匹配算法时间复杂度依然是指数的，除非它移除对`backreferences`的支持。其实Perl来说，在图中我们也观察到，即使当前匹配的正则表达式不包含`backreferences`，他的匹配算法的时间复杂度依然是指数的。虽然我们这里没有对Java语言做性能测试，但是可以肯定的告诉读者Java也是采用的递归回溯的方式实现的。而且从`java.util.regex`的对外接口可以看到，他支持一些匹配路径的替换，而且从接口就可以看到他的实现规约就是回溯的方式。对于PHP来说，他是依赖于PCRE库的。

上图中的粗体的蓝色线条标示的就是Thompson算法的C语言实现版本。其中Awk, Tcl, GNU grep 和 GNU awk 他们要么采用预编译的方式或者运行时动态编译的方式来编译DFAs,在接下来的小节里面会详细描述。

有些读者可能会觉得这个测试不太公平，因为这个地方只对这么一种zero-or-one的情形做测试。这个不公平争论的出发点其实是站不住脚的，给你两个选择，其中一个选择对所有的输入数据提供可预知，一致可靠，高效的运行时匹配，另外一个选择对很多输入可以快速完成，但对一些输入需要消耗甚至以年为单位的CPU时间，两种选择让你选择一种来使用，我相信这个不会是一个会有争论的选择。虽然上面我们用来举例子的那个正则表达式在实际的使用中很少出现，但另外一些类似的正则表达式确是经常出现的，比如 `(.*)(.*)(.*)(.*)(.*)`用来匹配用5个空格分割的字符串，比如用可选操作`|`来构建正则表达式。对于一些程序员来说，经常会构建一些特殊正则表达式的来检测的算法，然后优化相关算法在这些输入情况下的表现，我们通常也会叫这些程序员为[optimizers](http://search.cpan.org/~dankogai/Regexp-Optimizer-0.15/lib/Regexp/Optimizer.pm)。如果使用Thompson的NFA的状态机算法，根本就不需要采用这样的优化方法，因为它根本不存在所谓的特殊正则表达式。

## Caching the NFA to build a DFA

我们回顾前面关于状态机的部分，我们知道DFAs其实是比NFAs具备更加高效的执行效率的，因为DFAs在任何时候都只会处于一个状态，对于一个输入，它只有一个确定的选择。其实任何一个NFA都可以被转换为一个等级的DFA，只是在这个DFA里面，他的每一个状态都对应到一组NFA的状态。

比如拿我们前面用过的对应到`abab|abbb`的NFA的状态机(这里我们为每一个状态加上了一个状态号码)：

![image](https://swtch.com/~rsc/regexp/fig20.png)

与他等级的DFA看起来应该是这样的：

![image](https://swtch.com/~rsc/regexp/fig21.png)

在DFA中的每一个状态都是对应到NFA中的状态列表。

如果你还记得前面Thompson的NFA状态机的运行过程，你应该会意思到，这个执行过程其实相当于执行转换后的DFA：前面的`clist`和`nlist`其实都对应到一组DFA的状态，其中step函数就是具体的执行NFA到DFA状态的转换计算。所以Thompson的NFA的状态机的运行过程其实就是执行NFA到DFA的转换过程，每一次运行就执行一次转换计算，所以我们可以缓存`step`函数的运行结果到一个稀疏数组，避免每次都需要去执行重复的转换计算。这一小节，我们会具体来呈现这个过程，怎么来缓存计算结果。这里在前面的基础上来实现，大约会增加100行的代码。

为了实现缓存，我们先介绍一个新的数据结构，他代表的是DFA的一个状态。


```
struct DState
{
    List l;
    DState *next[256];
    DState *left;
    DState *right;
};
```
一个DState是列表`l`的缓存，其中`next`字段存储的是所有可能的字符输入的下一个DFA的状态：如果当前状态是`d`，下一个输入字符是`c`，那么下一个状态是`d->next[c]`，如果`d->next[c]`是null，代表下一个状态还没有被计算过，那么函数`NextState`就执行计算，并把结果记录下来。正则表达式的匹配过程就是根据输入一直执行`d->next[c]`的计算过程：

```
int
match(DState *start, char *s)
{
    int c;
    DState *d, *next;
    
    d = start;
    for(; *s; s++){
        c = *s & 0xFF;
        if((next = d->next[c]) == NULL)
            next = nextstate(d, c);
        d = next;
    }
    return ismatch(&d->l);
}
```
当所有的`DState`都被计算好以后，我们需要把这些`DState`存到一个结构里面，因为一个`DState`其实是与他里面的`l`一一对应的，也就是一个NFA的状态列表唯一的对应到一个`DState`，所以我们可以通过`DState`的`List`成员`l`唯一的查找到`DState`，为了达到这个目的，我们把所有的`DState`存储到一个二叉树里面。函数`dstate`根据参数`l`返回相应的`DState`，如果还不存在，则创建一个`DState`，插入二叉树并返回。


```
DState*
dstate(List *l)
{
    int i;
    DState **dp, *d;
    static DState *alldstates;

    qsort(l->s, l->n, sizeof l->s[0], ptrcmp);

    /* look in tree for existing DState */
    dp = &alldstates;
    while((d = *dp) != NULL){
        i = listcmp(l, &d->l);
        if(i < 0)
            dp = &d->left;
        else if(i > 0)
            dp = &d->right;
        else
            return d;
    }
    
    /* allocate, initialize new DState */
    d = malloc(sizeof *d + l->n*sizeof l->s[0]);
    memset(d, 0, sizeof *d);
    d->l.s = (State**)(d+1);
    memmove(d->l.s, l->s, l->n*sizeof l->s[0]);
    d->l.n = l->n;

    /* insert in tree */
    *dp = d;
    return d;
}

```

函数`Nextstate`运行`NFA`的函数`step`，并返回相应的`DState`：

```
DState*
nextstate(DState *d, int c)
{
    step(&d->l, c, &l1);
    return d->next[c] = dstate(&l1);
}

```

最后DFA的起始的`DState`状态，对于到NFA的其实状态列表:


```
DState*
startdstate(State *start)
{
    return dstate(startlist(start, &l1));
}
```
(在NFA状态机中，l1是预生成的列表)

`DState`对应到DFA状态机的一个状态，只是DFA状态机的状态是按需生成的，如果再匹配过程中没有遇到这个DFA的状态，那么这些状态就不会生成，也就不会进入缓存；另外一种可选的实现就是先提前生成好所有的DFA状态。这样做的话也会让运行时效率提高一点点，因为可以快速移除哪些可选的分支，这种是以牺牲启动时间和内存为代价的。

对于运行时生成DFA，并缓存DFA的状态，有些同学可能会对内存消耗产生担忧。因为`DState`其实只是函数`step`的运行结果的缓存，其实在`dstate`实现的实现里面，我们是可以根据内存情况，完全抛弃掉这个缓存的，如果要加上这个缓存的管理，只需要再增加50行左右的代码，这里有一份相应的[实现](https://swtch.com/~rsc/regexp/ "自己找")。其实Awk的实现里面就有缓存管理，默认他会缓存32个`DState`，这个也能从前面的性能图从窥探到，知道为什么在n=28的时候性能曲线出现了不一致连续的情况。

从正则表达式编译的NFAs其实具备非常好的缓存一致性：对大部分字符的匹配，在执行匹配的时候，状态机访问一个状态的然后总是朝着一样的转换箭头到下一个状态。这种特征让我妈可以和好的利用缓存，当第一次一个转换箭头流转的时候，箭头的下一个状态就需要被计算，但后面再次访问这个箭头的时候，我妈就只需要访问结果所在的内存地址就好。在实际实现基于DFA的匹配算法的时候，还可以利用一些其他的优化手段来加快匹配效率。后面还会有相关的文章来详细讨论基于DFA的正则表达式的实现。

## Real world regular expressions

在真实的使用场景中的增则表达式比我们前面介绍在某些方便要复杂一些。这小节会简单对实用意义上的正则表达式做完整描述，但一个全面的介绍显然已经超出了本文的篇幅。

__字符类(Character classes)__ 无论是`[0-9]`还是`\w` 或者`.`, 都表达的一个连续的可选择序列。在编译的时候，字符类我们可以把他编译成可选择操作，显然为了性能考虑，我们会考虑增加一种新的NFA节点来更加有效的表达这种可选择操作。在[POSIX](http://www.opengroup.org/onlinepubs/009695399/basedefs/xbd_chap09.html)里面定义了一些特殊的字符，比如`[[:uppe:]]`会更具上去的locale来确定具体的意义。

__转义序列(Escape sequences)__ 正则表达式语法需要处理转义字符，这里包括处理类似`\(`,`\)`,`\\`等元字符，还包括哪些不能直接书写的而约定的特殊字符类似`\n`,`\t`，`\r`等等。

__计数(Counted repetition)__ 许多正则表达式实现了一种操作符`{n}`，用来计数n个匹配给定正则规则的输入字符；还有操作符`{n,m}`用来至少匹配n个，但不操过m; 以及`{n,}`用来匹配大于等于n个。可以用递归回溯来实现这种计数。一个基于NFA 或者 DFAs的实现，需要把这种计数直接展开，比如`e{3}`展开为`eee`；`e{3,5}`会展开为`eeee?e?`; `e{3,}`会展开为`eee+`。

__子提取(Sub match extraction)__ 当用一个正则表达式来分割字符或者解析字符串的时候，我们通常需要知道输入字符串的那些部分分别匹配到那些子表达式。比如用正则表达式`([0-9]+-[0-9]+-[0-9]+) ([0-9]+:[0-9]+)`来匹配字符串，搜索字符串里面出现的日期和时间，我们通常需要知道匹配结束后匹配到的具体日期和时间是什么。很多正则表达式引擎提供了一种能力，可以提前每一个括号表达式的匹配内容。比如在Perl里面你可以这样写:


```
if(/([0-9]+-[0-9]+-[0-9]+) ([0-9]+:[0-9]+)/){
    print "date: $1, time: $2\n";
}
```
提取子表达式的匹配内容，这种语义会被大部分的计算机理论科学家所忽视，这个也是很多正则表达式引擎的实现者说他为什么需要采用递归回溯的方式来实现的论据之一。然而，类Thompson的算法也是可以做适当调整在不牺牲性能的前提下达到提取匹配内容。早在1985年，发行的Unix的第八版里面 regexp(3) 就实现了这个提取子表达式匹配串，这个工具被广泛使用，但大家都没有关注它的实现。

__非锚点匹配(Unanchored matches)__ 这篇文章在讨论正则表达式的时候是假定表达式与整个输入字符串是否匹配。在实际的使用中，我们遇到的场景通常是从输入字符串里面找到匹配的最长子字符串。对于Unix的匹配工具，通常也是返回从左右开始的最长匹配子串。其实一个队`e`的非锚匹配，是一种子串提取的特例：比如我们扩充表达式为`.*(e).*`，让开始的`.*`匹配尽可能短的字符串，这样就达到了前面的语义。

__非贪婪操作符(Non-greedy operators)__ 在传统的Unix正则表达式里面，重复操作符 `?`,`*`和`+`被定义为在满足整体匹配规则的情况下尽可能的匹配更多的字符，比如正则表达式`(.+)(.+)`在匹配`abcd`的时候，第一个`(.+)`匹配`abc`，第二个`(.+)`匹配`d`，这种匹配形式我们叫做贪婪匹配。Perl提供了 `??`,`*?`和`+?`重复操作符为非贪婪的版本，这些操作符在符合整体匹配规则的情况下，尽可能少的匹配字符串，比如用`(.+?)(.+?)`匹配`abcd`,第一个`(.+?)`只会匹配`a`，第二个匹配`bcd`。通过前面的定义，我们知道操作符是否是贪婪的他不会影响到整体的匹配，只会影响到子匹配的边界。对于回溯算法来说，实现非贪婪的版本非常简单，先尝试最短匹配再尝试最长匹配。比如在标准的回溯实现里面`e?`首先尝试用`e`来匹配，然后尝试忽略掉`e`去执行匹配；而`e??`用相反的顺序。Thompson的算法也可以通过简单的调整支持到这种非贪婪的操作符。

__断言(Assertions)__ 传统的正则表达式里面，元字符`^`和`$`可以用来断言操作符周边的字符：`^`断言前面的字符是一个换行(或者是字符串的开头)，`$`短夜下一个字符是一个新行(或者是字符串的结束)。Perl增加了更多的断言，比如单词边界`\b`，他断言前面的是一个有效的可输入字符alphanumeric，下一个不是有效的可输入字符，或者说是前面的补集字符。Perl还产生了一种前置的条件断言：`(?=re)`断言当前输入位置后的字符匹配`re`，但不对实际的输入位置做递进，也就是这个匹配不占用实际输入；`?!re`类似前面的断言，只是断言接下来的字符不匹配`re`。还有后置条件断言：`?<=re`和`?<!re`和前面的条件断言很类似，只是他的断言的输入是当前输入位置的前面。简单断言`^`,`$`和`\b`很容易用NFA的方式来表达，只需要为断言预留一个字节的输入。后面的通用的复杂断言相对难处理一些，但是原则上也可以把t他转义到NFA上来的。

__后向引用(Backreferences)__ 这个特性文章中我们很早就有提到，没有人知道怎么来高效的实现它，甚至都没有人能够证明存在一种高效实现的方法(其实，这是一个[NP难](http://perl.plover.com/NPC/NPC-3SAT.html)的问题，也就意味着只要有人发现了一种高效的实现方法，对于计算机科学来说就是一个*大事件*，你也可以赢得[百万美金](http://www.claymath.org/Popular_Lectures/Minesweeper/)的奖励)。在awk以及egre等工具里面，对后向引用的最简单和最有效的策略就是不支持。只是这个在实际操作上已经比较困难了，因为用户已经使用这个最少十年了，大家已经依赖上他，而且后向引用已经成为[标准](http://pubs.opengroup.org/onlinepubs/009695399/basedefs/xbd_chap09.html)的一部分。我想在这里说的是，即使是这样，我们也是有相当充分的理由，优先使用NFA的状态机方式来实现大部分正则表达式，只有在用到后向引用这种特性的时候，才去使用回溯的方法。一个比较聪明的实现，应该是结合两者的实现，只有出现了后向引用的时候才跳转到回溯的分支。

__回溯加记忆优化(Backtracking with memoization)__ Perl的正则引擎里面用到了[记忆化](https://zh.wikipedia.org/wiki/%E8%AE%B0%E5%BF%86%E5%8C%96)这个技术，避免在回溯的过程中出现指数级别的爆炸式性能消耗。至少在理论上，通过这种技术，会让Perl的正则表达式引擎的实现表现得更像是一个NFA，而不是回溯。记忆化并不最终解决问题：记忆化本身会对内存有一个基本的增长需求，这个增长的规模基本与输入的文本乘以正则表达式的大小相匹配；记忆化依然不结局递归回溯对栈空间的需求，在匹配一个较长输入字符串的时候，就会导致典型的递归算法问题，耗尽栈空间：

```
	$ perl -e '("a" x 100000) =~ /^(ab?)*$/;'
	Segmentation fault (core dumped)
	$
```

__字符集(Character sets)__ 现代的正则表达式的实现通常需要处理比ASCII更大的字符集，比如Unicode。在 [Plan9 的正则库](https://swtch.com/plan9port/unix/)里面，构建一个NFA，每次处理一个Unicode-character作为输入(UTF8编码的字符，也就是一个字节)，库里面把状态机和输入解码做分离，所以同样的正则表达式状态机可以同样用来处理[UTF8](http://plan9.bell-labs.com/sys/doc/utf.html)编码和宽字符编码的输入。

## History and References

Michael Rabin 和 Dana Scott 在1959年提出了non-deterministic finite automato(非确定性有限状态机)和non-determinism(非确定性理论)，理论里面向大家展示了NFAs可以用一个潜在的更大的DFAs来模拟，而且这个DFAs里面的状态都会对应到一组NFA的状态(他们两在1976年因为这个非确定性理论获得了图灵奖)。

R. McNaughton 和 H. Yamada[4](https://swtch.com/~rsc/regexp/regexp1.html#mcnaughton-yamada) 和 Ken Thompson[9](https://swtch.com/~rsc/regexp/regexp1.html#thompson) 他们是被普遍公认为是第一个把正则表达式翻译成NFAs的同学，虽然他们两个的在文章里面都没有显示的提出NFA这个理论。McNaughton和Yamada的构建的结构是创造一个DFA，然后Thompson的构建结构是创建一个IBM 7094上的机器编码，但是通过阅读他们两的文章可以感知到他们都是在创建一个我们后面称之为NFA的状态机。正则表达式本身与NFA结构唯一的差别在于怎么编码NFA里面的可选操作。前面我们提到的Thompson使用的方法是把选择显式的编码成一个可选节点(也就是前面的Split节点)和未标签箭头。另外一个更加普遍接受和容易理解的可选的方式，就是McNaughton和Yamada选择的方法，避免出现未标箭头，而是允许NFA的状态对于同一个输入标签可以有多个输出箭头，并且[McIlroy](https://swtch.com/~rsc/regexp/regexp1.html#mcilroy) 在Haskell里面给出了一种相对特别和优雅的具体实现。

Thompson的正则表达式最先是在[CTSS](https://swtch.com/~rsc/regexp/regexp1.html#vanvleck "运行在IBM 7094上")操作系统上的QED编辑器里面实现的。编译器的实现可以在CTSS的源代码里面找到，QED的编辑器的第一个版本是 L.Peter Deutsch 和 Butler Lampson开发实现的，只是后面Thompson重新实现了，并引入了正则表达式。 后面 Dennis Ritchie 实现了另外一个 QED 编辑器，这篇[文章](https://swtch.com/~rsc/regexp/regexp1.html#ritchie)里面详细记录了QED 编辑器的历史(Thompson, Ritchie 和 Lampson 后面也都有获得图灵奖，只是不是因为QED或者有限状态机理论相关的工作)。

以Thompson的论文发表为七点，出现了一大票正则表达式的实现。在编写ed的时候，Thompson并没有应有正则表达式，ed的第一版在Unix的1971发布的版本里面第一次出现，以及后面1973年发行的第四版本也没有应有正则表达式，并且在发布的ed里面搜索匹配是通过回溯的方式来实现的。在当时的场景下，回溯确实已经满足需求了，因为那个时候的正则语法还非常有限，他不能组合自表达式，没有`|`,`?`和`+`等这些操作符。 Al Aho的工具egrep是第一个出现在Unix工具集里面，具备全部的正则表达式语法的工具，它通过预编译DFA的方式实现，这个版本是1979年的第七版本第一次发布。在随后1985年发布的第八版里面,egrep通过运行时计算DFA的方式来实现，类似在本文前面我们示范代码里面的方式。

早在1980左右，当Rob Pike 写文本编辑器 [sam](https://swtch.com/~rsc/regexp/regexp1.html#pike)的时候，写了一个新的正则表达式的实现方式，后面这块代码被 Dave Presotto 提取出来编程一个库随着第八版本发布。Pike 的实现方式已经支持子表达式的组合，然后编译成一个高效的NFA状态机，但和第八版本的其他代码一样，没有被广泛的分发。Pike 他自己也没有意识到他采用的技术是非常新和有价值的。后面Henry Spencer 从头开始重新实现了第八版本的库接口，但他采用的是回溯的算法，后面Spencer 把他的[实现](http://arglist.com/regex/)向公众发布了。后面Henry 发布的版本被广泛使用，而且也成为了前面我们提到的，现在很多编程语言：Perl, PCRE, Python 等等，效率比较低的正则表达式实现的基础源头版本(在Spencer后面的讨论和辩护中，Spencer知道他的实现在某些情况下是可能很慢的，并且他当时不知道更有效的算法存在。他当时甚至在文档中警告说，"许多用户发现速度完全足够，但是用这个代码替换egrep的内部的相关实现代码将是一个错误"。)。 Pike 的正则表达式后面扩展了一下用来支撑Unicode，并且在1992年发布的sam编译器里面发布，只是当时这个非常高效的正则表达式搜索算法没有被广大的同学注意到。现在这些代码在许多论坛作为 [sam编辑器](http://plan9.bell-labs.com/sources/plan9/sys/src/cmd/sam/)的一部分或者作为 [Plan9的正则表达式库](http://plan9.bell-labs.com/sources/plan9/sys/src/libregexp/)或者作为一个独立的 [Unix库](https://swtch.com/plan9port/unix/)可以被下载到。 [Ville Laurikari](https://swtch.com/~rsc/regexp/regexp1.html#laurikari) 在1999年独立发现了Pike的算法，也开发了相应的理论基础体系。

最后，任何关于正则表达式的讨论如果不提到 Jeffrey Friedl的关于正则表达的书<Mastering Regular Expressions>，都讲是不完整的讨论，这本书也许是程序员里面关于正则表达式最流行的书。在Friedl的书里面，会告诉大家怎么来有效的使用现在的正则表达式实现，而不是叫大家怎么来高效的实现正则表达式。如果一定要说关于实现部分有什么内容的话，就是书里面清晰的表达了一个大家广泛都知道的理论，后向引用的唯一实现方式就是回溯。但Friedl 也清晰的表述了，他对背后的理论是[不感兴趣](http://regex.info/blog/2006-09-15/248)的也不理解的(感觉Russ Cox 在黑Friedl呀.哈哈)。

## Summary

正则表达式匹配可以很简单并且迅速的通过基于有限状态机的技术来实现。对比 Perl , PCRE, Python Ruby, Java 等许多基于递归回溯的方式来实现的编程语言来说，回溯的方式固然简单，但是效率在某些情况下会非常糟糕，除掉对于后向引用的支持，正则表达式的其他特性都可以通过基于状态机的技术来实现非常高效且稳定的匹配算法。

本系列的下一篇文章 <Regular Expression Matching: the Virtual Machine Approach> 会讨论基于NFA的子串提取。第三篇文章 <Regular Expression Matching in the Wild> 会测试一个产品级别品质的正则表达式实现，第四篇文章 <Regular Expression Matching with a Trigram Index> 会解析在谷歌的代码搜索引擎里面是怎么实现的。

## Acknowledgements
Lee Feigenbaum, James Grimmelmann, Alex Healy, William Josephson, 和 Arnold Robbins 读了这篇文章的草稿，并且提了很多有用的建议。Rob Pike 对于他实现的正则表达式相关的那段历史跟我讲了很多。谢谢大家。谢谢阅读。

## References
[1] L. Peter Deutsch and Butler Lampson, “An online editor,” Communications of the ACM 10(12) (December 1967), pp. 793–799. http://doi.acm.org/10.1145/363848.363863

[2] Ville Laurikari, “NFAs with Tagged Transitions, their Conversion to Deterministic Automata and Application to Regular Expressions,” in Proceedings of the Symposium on String Processing and Information Retrieval, September 2000. http://laurikari.net/ville/spire2000-tnfa.ps

[3] M. Douglas McIlroy, “Enumerating the strings of regular languages,” Journal of Functional Programming 14 (2004), pp. 503–518. http://www.cs.dartmouth.edu/~doug/nfa.ps.gz (preprint)

[4] R. McNaughton and H. Yamada, “Regular expressions and state graphs for automata,” IRE Transactions on Electronic Computers EC-9(1) (March 1960), pp. 39–47.

[5] Paul Pierce, “CTSS source listings.” http://www.piercefuller.com/library/ctss.html (Thompson's QED is in the file com5 in the source listings archive and is marked as 0QED)

[6] Rob Pike, “The text editor sam,” Software—Practice & Experience 17(11) (November 1987), pp. 813–845. http://plan9.bell-labs.com/sys/doc/sam/sam.html

[7] Michael Rabin and Dana Scott, “Finite automata and their decision problems,” IBM Journal of Research and Development 3 (1959), pp. 114–125. http://www.research.ibm.com/journal/rd/032/ibmrd0302C.pdf

[8] Dennis Ritchie, “An incomplete history of the QED text editor.” http://plan9.bell-labs.com/~dmr/qed.html

[9] Ken Thompson, “Regular expression search algorithm,” Communications of the ACM 11(6) (June 1968), pp. 419–422. http://doi.acm.org/10.1145/363347.363387 (PDF)

[10] Tom Van Vleck, “The IBM 7094 and CTSS.” http://www.multicians.org/thvv/7094.html

Discussion on [reddit](http://programming.reddit.com/info/10c60/comments) and [perlmonks](http://perlmonks.org/?node_id=597262) and [LtU](http://lambda-the-ultimate.org/node/2064)

