## [乱码][^4]

互联网上乱码是一个常见的问题，相信大家或多或少都遇到过。比如浏览网页的时候，打开一个的文件的时候等等。

这里的原因大致可以分为如下几类：

* 字符编码不匹配，一个用UTF8编码的数据，用UTF16去解码
* 字符集不匹配，一个Uniocde的数据，尝试用GBK去匹配
* 字体不支持相应的字符，出现占位框
* 数据不完整或者解码位置错位

对于开发同学来说，在各种编程语言里面都会需要跟字符串打交道，也需要审视自己设计的相关系统应该选用的字符编码问题。所以要完整理解这个问题，应该要搞清楚：语言，字符，字符集，字符编码，字体之间的关系。



## [字符](https://zh.wikipedia.org/wiki/%E5%AD%97%E7%AC%A6)

从计算机诞生开始，一个重要是使命就是把_**“信息”**_进行_**“数字化”**_，而文本是遇到的第一个需要数字化的信息之一。对于[印欧语系](https://zh.wikipedia.org/wiki/%E5%8D%B0%E6%AC%A7%E8%AF%AD%E7%B3%BB)，典型的现代英文来说主要是字母组合而来的单词(也有重音等其他西欧语)，还有一种典型的是[汉藏语系](https://zh.wikipedia.org/wiki/%E6%B1%89%E8%97%8F%E8%AF%AD%E7%B3%BB)，主体是象形字组合，没有穷尽的最小单元。像东亚的语系是典型的复杂语系，繁体字和简体字就是典型的差异。可以看到不同区域，不同语言的字符差异非常大。全世界现存的语言约[6900种](https://zh.wikipedia.org/wiki/%E8%AF%AD%E8%A8%80%E7%B3%BB%E5%B1%9E%E5%88%86%E7%B1%BB)。



## 字符集

计算机发展起于[印欧语系](https://zh.wikipedia.org/wiki/%E5%8D%B0%E6%AC%A7%E8%AF%AD%E7%B3%BB)，所以面对的第一个文本是英文的数字化，因为[印欧语系](https://zh.wikipedia.org/wiki/%E5%8D%B0%E6%AC%A7%E8%AF%AD%E7%B3%BB)的基本语法单元是字母，标点，数字和少数控制字符，所以到1967年，以信息化英文为目标的[ASCII][2]第一次发布，共定义了128个字符。其中33个字符无法显示（一些终端提供了扩展，使得这些字符可显示为诸如[笑脸](https://zh.wikipedia.org/w/index.php?title=%E7%AC%91%E8%87%89&action=edit&redlink=1)、[扑克牌花式](https://zh.wikipedia.org/w/index.php?title=%E6%92%B2%E5%85%8B%E7%89%8C%E8%8A%B1%E5%BC%8F&action=edit&redlink=1)等8-bit符号），且这33个字符多数都已是陈废的[控制字符](https://zh.wikipedia.org/wiki/%E6%8E%A7%E5%88%B6%E5%AD%97%E5%85%83)。但对于非现代英文，比如naïve、café、élite包含重音符合就无法表达了。

不同的国家和地区会整理本地区或国家的语言文字基础上考虑使用的现实情况制定相应的标准，比如[GB 2312](https://zh.wikipedia.org/wiki/GB_2312)，1981年5月1日实施。GB 2312编码通行于中国大陆；[新加坡](https://zh.wikipedia.org/wiki/%E6%96%B0%E5%8A%A0%E5%9D%A1)等地也采用此编码。中国大陆几乎所有的中文系统和国际化的软件都支持GB 2312。标准共收录6763个[汉字](https://zh.wikipedia.org/wiki/%E6%B1%89%E5%AD%97)，其中[一级汉字](https://zh.wikipedia.org/wiki/%E5%B8%B8%E7%94%A8%E5%AD%97)3755个，[二级汉字](https://zh.wikipedia.org/wiki/%E6%AC%A1%E5%B8%B8%E7%94%A8%E5%AD%97)3008个；同时收录了包括[拉丁字母](https://zh.wikipedia.org/wiki/%E6%8B%89%E4%B8%81%E5%AD%97%E6%AF%8D)、[希腊字母](https://zh.wikipedia.org/wiki/%E5%B8%8C%E8%85%8A%E5%AD%97%E6%AF%8D)、[日文](https://zh.wikipedia.org/wiki/%E6%97%A5%E8%AF%AD)[平假名](https://zh.wikipedia.org/wiki/%E5%B9%B3%E5%81%87%E5%90%8D)及[片假名](https://zh.wikipedia.org/wiki/%E7%89%87%E5%81%87%E5%90%8D)字母、[俄语](https://zh.wikipedia.org/wiki/%E4%BF%84%E8%AF%AD)[西里尔字母](https://zh.wikipedia.org/wiki/%E6%96%AF%E6%8B%89%E5%A4%AB%E5%AD%97%E6%AF%8D)在内的682个字符。对于80后参加高考的时候应该有记忆，填写志愿表的时候，名字等信息除了写汉字以外，还要写拼音，除了这个以外还要写区位码等信息。其实同样的汉字本身不足以表达确切的码点(渖（68–41）：由“审[審]”类推简化而来，可以归类到沈，但定义的时候是有不同的码点的)，所以他们也找了一个最直接的方式，填报志愿的同学自己去找到自己的码点，这里介绍一下GB对于汉字的处理：

GB 2312中对所收汉字进行了“分区”处理，每区含有94个汉字／符号。这种表示方式也称为[区位码](https://zh.wikipedia.org/wiki/ISO/IEC_2022)

- 01–09区为特殊符号。
- 16–55区为一级汉字，按[拼音](https://zh.wikipedia.org/wiki/%E6%8B%BC%E9%9F%B3)排序。
- 56–87区为二级汉字，按[部首](https://zh.wikipedia.org/wiki/%E9%83%A8%E9%A6%96)／[笔画](https://zh.wikipedia.org/wiki/%E7%AC%94%E7%94%BB)排序。

举例来说，“啊”字是GB 2312之中的第一个汉字，它的区位码就是1601。

在字符集定义上基本是百花齐放的姿态，到一个点的时候，互联网的主流同学都意思到了全世界其实如果是一个统一的字符集来表达的话，那么信息交流就简单多了。通用字符集又称Universal Multiple-Octet Coded Character Set(UCS)，UCS包含了已知语言的所有字符。除了拉丁语、希腊语、斯拉夫语、希伯来语、阿拉伯语、亚美尼亚语、格鲁吉亚语，还包括中文、日文、韩文这样的方块文字，UCS还包括大量的图形、印刷、数学、科学符号。中国大陆译为**通用多八位编码字符集**，台湾译为**广用多八字节编码字元集** 。到这个地方大家估计心里有一个疑惑，这个统一字符集和Unicode是啥关系呢？

历史上存在两个独立的尝试创立单一字符集的组织：

* 国际标准化组织（ISO）于1984年创建的ISO/IEC
* [统一码联盟](https://zh.wikipedia.org/wiki/%E7%B5%B1%E4%B8%80%E7%A2%BC%E8%81%AF%E7%9B%9F)由[Xerox](https://zh.wikipedia.org/wiki/Xerox)、[Apple](https://zh.wikipedia.org/wiki/Apple)等软件制造商于1988年组成

前者开发的ISO/IEC 10646项目，后者开发的[统一码](https://zh.wikipedia.org/wiki/%E7%B5%B1%E4%B8%80%E7%A2%BC)项目。因此最初制定了不同的标准。1991年前后，两个项目的参与者都认识到，世界不需要两个不兼容的字符集。所以通过友好协商，在不拆散任何一方办事机构，增加失业率的情况下，两个机构合作开发一个字符集，这个就是Unicode：

* 1991年 就发布了 Unicode 1.0 (不包含CJK统一汉字)
* 1993年 发布了Unicode 1.1，这个还有一个名字是ISO 10646-1:1993(CJK统一汉字集的制定于1993年完成)
* 1996年 发布了Unicode 2.0，Unicode采用了与ISO 10646-1相同的字库和字码，ISO也承诺，ISO 10646将不会替超出U+10FFFF的UCS-4编码赋值，以使得两者保持一致

到现在为止，两个机构依然是并存的，但关于字符集的字库和编码上两者已经协商高度统一(依然有一些细微差别，比如2.0里面对于变形字的规定)。这里其实有必要对机构的工作做一个大体的描述，标准组织其实不仅仅是找全字符安排码点，这里其实涉及到编码的别名，标准有关的术语，语义符号学，绘制某些语言（如阿拉伯语）表达形式的算法，处理双向文字（比如拉丁文和希伯来文的混合文字）的算法，排序与字符串比较所需的算法等等，其实这些都是标准化组织需要做的事情。

举个例子，拿中文来说，古文是经常会出现通假字(严重怀疑很多时候是自别字)的，还有古文里面关于同一个字其实是有非常多的写法的，这些都是标准化组织需要去处理的。



### GB0

在进入字符编码前，我们对中文的字符集也有必要做一个统一的了解：

**GB 2312** 或 **GB 2312–80** 是[中华人民共和国国家标准](https://zh.wikipedia.org/wiki/%E4%B8%AD%E5%8D%8E%E4%BA%BA%E6%B0%91%E5%85%B1%E5%92%8C%E5%9B%BD%E5%9B%BD%E5%AE%B6%E6%A0%87%E5%87%86)[简体中文](https://zh.wikipedia.org/wiki/%E7%AE%80%E4%BD%93%E4%B8%AD%E6%96%87)[字符集](https://zh.wikipedia.org/wiki/%E5%AD%97%E7%AC%A6%E9%9B%86)，全称《**信息交换用汉字编码字符集·基本集**》，又称**GB0**，由[中国国家标准总局](https://zh.wikipedia.org/w/index.php?title=%E4%B8%AD%E5%9B%BD%E5%9B%BD%E5%AE%B6%E6%A0%87%E5%87%86%E6%80%BB%E5%B1%80&action=edit&redlink=1)发布，1981年5月1日实施。显然这货搞得很早，想得不够全面，一共也只收纳了6763个汉字，[古汉语](https://zh.wikipedia.org/wiki/%E5%8F%A4%E6%B1%89%E8%AF%AD)等方面出现的[罕用字](https://zh.wikipedia.org/wiki/%E7%BD%95%E7%94%A8%E5%AD%97)和[繁体字](https://zh.wikipedia.org/wiki/%E7%B9%81%E9%AB%94%E5%AD%97)这个都是Cover不到的，比如宝岛就搞了一个[大五码](https://zh.wikipedia.org/wiki/%E5%A4%A7%E4%BA%94%E7%A2%BC)（Big5）搞定繁体古文相关的字符。所以GB0肯定需要再往下走一步，这个时候就有了[GB 12345](https://zh.wikipedia.org/wiki/GB_12345) 和 [GB 18030](https://zh.wikipedia.org/wiki/GB_18030)。

1993年发布的Unicode1.1收录[中国大陆](https://zh.wikipedia.org/wiki/%E4%B8%AD%E5%9B%BD%E5%A4%A7%E9%99%86)、[台湾](https://zh.wikipedia.org/wiki/%E5%8F%B0%E6%B9%BE)、[日本](https://zh.wikipedia.org/wiki/%E6%97%A5%E6%9C%AC)及[韩国](https://zh.wikipedia.org/wiki/%E9%9F%A9%E5%9B%BD)通用[字符集](https://zh.wikipedia.org/wiki/%E5%AD%97%E7%AC%A6%E9%9B%86)的[汉字](https://zh.wikipedia.org/wiki/%E6%B1%89%E5%AD%97)，总共有20,902个。中国大陆订定了等同于Unicode 1.1版本的“[GB 13000.1-93](https://zh.wikipedia.org/wiki/GB_13000)”“信息技术通用多八位编码字符集（UCS）第一部分：体系结构与基本多文种平面”，关于多文种平面后面再侃。因为GB2312收录的实在太少，比如现在来看常见的"啰"，以及“镕”都没有，更加不用说繁体字了。所以从厂商的角度，他的产品肯定得出啊，不能等你的标准全部定稿再发布吧。



### CP936

微软利用GB 2312-80未使用的编码空间，收录GB 13000.1-93全部字符制定了GBK编码，这个对应到windows里面来说就是**CP936字码表**（Code Page 936）*的扩展，最早实现于[Windows 95](https://zh.wikipedia.org/wiki/Windows_95)简体中文版。这里有一个名词 Code Page, 这个其实起源于IBM，这个是IBM 对一个字符集的形象描述，他把不同系统，不同区域的字符集按照码点页的形式进行存储，随着系统发布，所以对于厂商内部来说，字符集和CodePage基本是等价的。这里我们看到了GBK， GB12000.1-93, 以及Unicode1.1之间的联系，但这里的联系一定要清晰的认识到这里只是字符集的联系，字符集的和编码是两回事，所以Unicode1.1 和 GB 13000.1-93一致，但所说的UTF8， UTF16，GBK等完全是不兼容的。 这里我们讨论到的Codepage，前面提到的字符集等价是一个约等于，其实Codepage在这里的一个重要作用是通过指定的转换表将非Unicode的字符编码转换为同一字符对应的系统内部使用的Unicode编码。可以在“语言与区域设置”中选择一个代码页作为非Unicode编码所采用的默认编码方式，如936为简体中文[GB码](https://zh.wikipedia.org/wiki/%E5%9B%BD%E5%AE%B6%E6%A0%87%E5%87%86%E4%BB%A3%E7%A0%81)，950为繁体中文[Big5](https://zh.wikipedia.org/wiki/Big5)（皆指PC上使用的）。在这种情况下，一些非英语的欧洲语言编写的软件和文档很可能出现乱码。而将代码页设置为相应语言中文处理又会出现问题，这一情况无法避免。只有完全采用统一编码才能彻底解决这些问题，但目前尚无法做到这一点。

代码页技术现在广泛为各种平台所采用。UTF-7的代码页是65000，UTF-8的代码页是65001。



### GBK

还有一个是GBK我们说是微软搞的，对应他内部的CP936，但这里也要深巴一下，真正的全面定义的**GBK**，全名为**《汉字内码扩展规范(GBK)》1.0版**，由中华人民共和国[全国信息技术标准化技术委员会](https://zh.wikipedia.org/w/index.php?title=%E5%85%A8%E5%9B%BD%E4%BF%A1%E6%81%AF%E6%8A%80%E6%9C%AF%E6%A0%87%E5%87%86%E5%8C%96%E6%8A%80%E6%9C%AF%E5%A7%94%E5%91%98%E4%BC%9A&action=edit&redlink=1)1995年12月1日制订，[国家技术监督局](https://zh.wikipedia.org/wiki/%E4%B8%AD%E5%8D%8E%E4%BA%BA%E6%B0%91%E5%85%B1%E5%92%8C%E5%9B%BD%E5%9B%BD%E5%AE%B6%E6%8A%80%E6%9C%AF%E7%9B%91%E7%9D%A3%E5%B1%80)标准化司和[电子工业部](https://zh.wikipedia.org/wiki/%E4%B8%AD%E5%8D%8E%E4%BA%BA%E6%B0%91%E5%85%B1%E5%92%8C%E5%9B%BD%E7%94%B5%E5%AD%90%E5%B7%A5%E4%B8%9A%E9%83%A8)科技与质量监督司1995年12月15日联合以《技术标函[1995]229号》文件的形式公布。 GBK共收录21886个汉字和图形符号，其中汉字（包括部首和构件）21003个，图形符号883个。GBK定义之字符较CP936多出95字（15个非汉字及80个汉字），皆为其时未收入ISO 10646 / Unicode之符号。

对于很多字符集的定义着来说，通常会流出一部分未定义的区域，一个是未来可以加字符，也有很多会流出一些造字区用使用方来自定义。比如Big5码是一套[双字节字符集](http://zh.wikipedia.org/wiki/%E5%8F%8C%E5%AD%97%E8%8A%82%E5%AD%97%E7%AC%A6%E9%9B%86)，明确定义了**0x8140-0xA0FE** 为**保留给用户自定义字符（造字区）**。



### Unicode

作为从通用字符集发展过来的全球通用字符集支持多语言环境（指可同时处理多种语言混合的情况）。但因为全球的语言环境确实太他妈恶劣了，字符集也是被坑得不行，比如Unicode编码包含了不同写法的字，如“ɑ／a”、“強／强”、“戶／户／戸”，在[汉字](https://zh.wikipedia.org/wiki/%E6%B1%89%E5%AD%97)方面引起了一字多形的认定争议。

![Unicode BMP](https://upload.wikimedia.org/wikipedia/commons/thumb/8/8e/Roadmap_to_Unicode_BMP.svg/750px-Roadmap_to_Unicode_BMP.svg.png)

目前，几乎所有电脑系统都支持基本拉丁字母，并各自支持不同的其他编码方式。Unicode为了和它们相互兼容，其首256字符保留给ISO 8859-1所定义的字符，使既有的西欧语系文字的转换不需特别考量；并且把大量相同的字符重复编到不同的字符码中去，使得旧有纷杂的编码方式得以和Unicode编码间互相直接转换，而不会丢失任何信息。举例来说，[全角](https://zh.wikipedia.org/wiki/%E5%85%A8%E5%BD%A2)格式区块包含了主要的拉丁字母的全角格式，在中文、日文、以及韩文字形当中，这些字符以全角的方式来呈现，而不以常见的半角形式显示，这对竖排文字和等宽排列文字有重要作用。

Unicode从统一码过来，最开始集成的是我们常见到的UCS-2的统一码版本，也就是每个字符两个字节，一共可以容纳65536个字符。最新（但未实际广泛使用）的统一码版本定义了16个[辅助平面](https://zh.wikipedia.org/wiki/%E8%BE%85%E5%8A%A9%E5%B9%B3%E9%9D%A2)，两者合起来至少需要占据21位的编码空间，比3字节略少。但事实上辅助平面字符仍然占用4字节编码空间，与[UCS-4](https://zh.wikipedia.org/wiki/UCS-4)保持一致。理论上最多能表示$2^{31}$个字符，完全可以涵盖一切语言所用的符号。

其实到这个地方有Windows开发经验的同学肯定会想到很多开发场景，char, wchar_t, TCHAR 以及相关的函数，这里有一个操蛋的地方是wchar_t的本意是宽字符定义，但并没有约定wchar_t的字节数，所以在windows上sizeof(wchar_t)等于2，而在linux上是等于4的。也就是在windows上这货只能表达UCS-2，而在Linux上可以表达UCS-4。在Windows内核的存储也是对应的UCS-2，所以关于字符函数很多时候会有对应的Ex版本用来单独处理UCS-4的情形。

延展一下，这了还有一个常用的场景，在libc里面有一个函数setlocale，当向终端、控制台输出 wchar_t 类型的字符时，需要设置 setlocale()，因为通常终端、控制台环境自身是不支持 UCS 系列的字符集编码的，使用流操作函数时（如：printf()），在标准/RT库实现的内部会将 UCS 字符转换成合适的本地 ANSI 编码字符，转换的依据就是 setlocale() 设定的活动 locale，最后将结果字符序列传递给终端，对于来自终端的输入流这个过程刚好相反(**Windows CRT 是不支持 UTF-8 编码作为 locale **)。在windows开发里面有两个常见的函数，在UTF-16LE（wchar_t类型）与UTF-8（代码页CP_UTF8）之间的转码。

```c
#include <windows.h>
int main() {
	char a1[128], a2[128] = { "Hello" };
	wchar_t w = L'页';
	int n1, n2= 5;
	wchar_t w1[128];
	int m1 = 0;

	n1 = WideCharToMultiByte(CP_UTF8, 0, &w, 1, a1, 128, NULL, NULL);
	m1 = MultiByteToWideChar(CP_UTF8, 0, a2, n2, w1, 128);
}
```





## 字符编码

定义字符集的同学，是天然有权利定义字符集对应的编码方式的。如果是ASCII来说，这货太简单了，就一个字节就可以表达字符集的所有字符。比如前面的GB 2312就不一样了，定义的字符是大于256的，一个字节搞不定，所以肯定就需要整很多幺蛾子来编码字符，[EUC](https://zh.wikipedia.org/wiki/EUC)就是GB采用的编码方式，[EUC](https://zh.wikipedia.org/wiki/EUC)本身也是一个变长编码，**EUC**全名为**Extended Unix Code**，是一个使用8[位](https://zh.wikipedia.org/wiki/%E4%BD%8D)编码来表示[字符](https://zh.wikipedia.org/wiki/%E5%AD%97%E7%AC%A6)的方法。EUC最初是针对Unix系统，由一些Unix公司所开发，于1991年标准化。EUC基于[ISO/IEC 2022](https://zh.wikipedia.org/wiki/ISO/IEC_2022)的7位编码标准，因此单字节的编码空间为94，双字节的编码空间（区位码）为94x94。把每个区位加上0xA0来表示，以便符合ISO 2022。它主要用于表示及储存[汉语文字](https://zh.wikipedia.org/wiki/%E6%B1%89%E8%AF%AD)、[日语文字](https://zh.wikipedia.org/wiki/%E6%97%A5%E8%AF%AD)及[朝鲜文字](https://zh.wikipedia.org/wiki/%E9%9F%93%E8%AA%9E)。

在具体深入字符编码前可以统一的介绍一下现代字符编码的[五层模型](https://zh.wikipedia.org/wiki/%E5%AD%97%E7%AC%A6%E7%BC%96%E7%A0%81)，它们将字符编码的概念分为：有哪些字符、它们的[编号](https://zh.wikipedia.org/wiki/%E7%BC%96%E5%8F%B7)、这些[编号](https://zh.wikipedia.org/wiki/%E7%BC%96%E5%8F%B7)如何编码成一系列的“码元”（有限大小的数字）以及最后这些单元如何组成八位字节流。

这里容易绕晕，用一个例子来表达。比如有 a, b, c 三个字符，他们的编号是 1, 2, 3，他们的码元可以定义为 4, 5, 6，定义一个厨房的编码方案 码元 + 0xA1，他们他们编码后的字节是 0xA5, 0xA6, 0xA7，如果我要用Email来传输这货，我希望采用URLEncoding的方式缩小到7bit的域里面来，这个就对应到传输编码方案。



### EUC

EUC定义了4个单独的码集（code set）。码集0总是对应于7位的[ASCII](https://zh.wikipedia.org/wiki/ASCII)（或其它的各国定义的[ISO 646](https://zh.wikipedia.org/wiki/ISO_646)），包括了ISO 2022定义的C0与G0空间的值。码集1, 2, 3表示G1空间的值。其中，码集1表示一些未经修饰（unadorned）的字符。码集2的字符编码以0x8E（属于C1控制字符，或称SS2）为第一字节。码集3的字符编码以0x8F（另一个属于C1的控制字符，或称SS3）为第一字节。码集0总是编码为单字节；码集2、3总是编码为至少2个字节；码集1编码为1-3个字节。



### [UTF16](https://zh.wikipedia.org/wiki/UTF-16)(Unicode Transformation Format，简称为UTF)

Unicode字符集的抽象[码位](https://zh.wikipedia.org/wiki/%E7%A0%81%E4%BD%8D)映射为16位长的整数（即[码元](https://zh.wikipedia.org/wiki/%E7%A0%81%E5%85%83)）的序列，用于数据存储或传递。Unicode字符的码位，需要1个或者2个16位长的码元来表示，因此这是一个变长表示

目前在PC机上的Windows系统和Linux系统对于UTF-16编码默认使用UTF-16 LE。UTF16也是一个变长编码，而且因为UTF16的码元是16位的，所以存在大小端的问题。

Unicode的编码空间从U+0000到U+10FFFF，共有1,112,064个码位（code point）可用来映射字符. Unicode的编码空间可以划分为17个平面（plane），每个平面包含216（65,536）个码位。在第0个平面基本包含了绝大部分用到的统一编码字符，所以用UTF16的话，大部分情况都是一个16位的码元的直接映射，效率非常高。

对于需要扩展到2个16位码元的情况的时候，从Unicode的平面设定来说是一个$2^{20}$的区域，所以每一个码元需要的存储空间只需要10bit，刚好在Unicode里面的BMP里面有一个约定，从U+D800到U+DFFF之间的码位区块是永久保留不映射到Unicode字符(**UCS-2的时代，U+D800..U+DFFF内的值被占用，用于某些字符的映射**)，所以对于任何一个BMP以外的我们都可以映射到连个位于U+D800到U+DFFF之间的码点。这就是UTF16，具体的映射，其实这里可以区分一下前后，做前导和后导的区分，直接判定码元流是否完整，高位的10比特的值（值的范围为0..0x3FF）被加上0xD800得到第一个码元或称作高位代理（high surrogate），值的范围是0xD800..0xDBFF，低位的10比特的值（值的范围也是0..0x3FF）被加上0xDC00得到第二个码元或称作低位代理（low surrogate），现在值的范围是0xDC00..0xDFFF。



### UTF8

总的来说UTF8是变长编码字符，相对UTF16来说有一个很大的优先是，他的基本码元是8bit的，这样对于128一下的字符，依然是一个字节，完全兼容了ASCII时代的所有资料，同时还没有大小端问题；然后UTF8还是是一个完备的前缀编码方案，变长码元的前缀判定是完备的，也就不会出现位置错误，而乱码了；再者这个编码方案，最长可以到6字节，他的潜在编码区域其实对Unicode是全覆盖的，原则上所有的Unicode都可以被UTF8进行编码(2003年11月UTF-8被RFC 3629重新规范只能使用原来Unicode定义的区域，U+0000到U+10FFFF，也就是说最多四个字节)。

巴拉巴拉说了很多，大家应该基本了解了他的强大的地方，而且[互联网工程工作小组](https://zh.wikipedia.org/wiki/%E7%B6%B2%E9%9A%9B%E7%B6%B2%E8%B7%AF%E5%B7%A5%E7%A8%8B%E5%B7%A5%E4%BD%9C%E5%B0%8F%E7%B5%84)（IETF）要求所有[互联网](https://zh.wikipedia.org/wiki/%E7%B6%B2%E9%9A%9B%E7%B6%B2%E8%B7%AF)[协议](https://zh.wikipedia.org/wiki/%E7%BD%91%E7%BB%9C%E5%8D%8F%E8%AE%AE)都必须支持UTF-8编码[[1\]](https://zh.wikipedia.org/wiki/UTF-8#cite_note-1)。[互联网邮件联盟](https://zh.wikipedia.org/w/index.php?title=%E4%BA%92%E8%81%AF%E7%B6%B2%E9%83%B5%E4%BB%B6%E8%81%AF%E7%9B%9F&action=edit&redlink=1)（IMC）建议所有电子邮件软件都支持UTF-8编码。1996年起，[微软](https://zh.wikipedia.org/wiki/%E5%BE%AE%E8%BB%9F)的[CAB](https://zh.wikipedia.org/wiki/CAB)（MS Cabinet）规格在UTF-8标准正式落实前就明确容许在任何地方使用UTF-8编码系统。

这个编码的由来也是有一些小的逸闻的：

1992年[ISO/IEC 10646](https://zh.wikipedia.org/wiki/%E9%80%9A%E7%94%A8%E5%AD%97%E7%AC%A6%E9%9B%86)的初稿中有一个非必须的附录，名为UTF，定义了一个版本来编码Unicode，但是性能，兼容性压缩率等各方面都不满意，这个时候前面提到的参与Unicode的另外一个联盟机构，赶紧想抢占先机，[X/Open](https://zh.wikipedia.org/wiki/X/Open)委员会XoJIG开始寻求一个较佳的编码系统，[Unix系统实验室](https://zh.wikipedia.org/wiki/Unix%E7%B3%BB%E7%BB%9F%E5%AE%9E%E9%AA%8C%E5%AE%A4)（USL）的Dave Prosser为此提出了一个编码系统的建议。它具备可更快速实现的特性，并引入一项新的改进。其中，7[比特](https://zh.wikipedia.org/wiki/%E4%BD%8D%E5%85%83)的[ASCII](https://zh.wikipedia.org/wiki/ASCII)符号只代表原来的意思，所有多字节序列则会包含第8[比特](https://zh.wikipedia.org/wiki/%E4%BD%8D%E5%85%83)的符号，也就是所谓的[最高有效比特](https://zh.wikipedia.org/wiki/%E6%9C%80%E9%AB%98%E6%9C%89%E6%95%88%E4%BD%8D%E5%85%83)。这个方案很快流传到一些感兴趣的团体，[贝尔实验室](https://zh.wikipedia.org/wiki/%E8%B2%9D%E7%88%BE%E5%AF%A6%E9%A9%97%E5%AE%A4)[九号项目](https://zh.wikipedia.org/wiki/%E8%B2%9D%E7%88%BE%E5%AF%A6%E9%A9%97%E5%AE%A4%E4%B9%9D%E8%99%9F%E8%A8%88%E7%95%AB)[操作系统](https://zh.wikipedia.org/wiki/%E4%BD%9C%E6%A5%AD%E7%B3%BB%E7%B5%B1)工作小组的[肯·汤普逊。大神](https://zh.wikipedia.org/wiki/%E8%82%AF%C2%B7%E6%B1%A4%E6%99%AE%E9%80%8A)对这编码系统作出重大的修改，让编码可以自我同步，使得不必从字符串的开首读取，也能找出字符间的分界。刚好1992年8月Ken Thmpson和Rob pike 一起出差去开会，他们两个基友就在在[美国](https://zh.wikipedia.org/wiki/%E7%BE%8E%E5%9C%8B)[新泽西州](https://zh.wikipedia.org/wiki/%E6%96%B0%E6%BE%A4%E8%A5%BF%E5%B7%9E)一架餐车的餐桌垫上描绘出此设计的要点。开完会回来Rob Pike 就着手进行具体的实现并将这编码系统完全应用在[九号项目](https://zh.wikipedia.org/wiki/%E8%B2%9D%E7%88%BE%E5%AF%A6%E9%A9%97%E5%AE%A4%E4%B9%9D%E8%99%9F%E8%A8%88%E7%95%AB)当中，及后他将有关成果回馈X/Open。

到这个地方有必要把一个名词给弄来说说了，因为Windows在字符编码这块一直都有一些些自由的微创新，许多Windows程序（包括Windows记事本）在UTF-8编码的文件的开首加入一段字节串`EF BB BF`，用来标示这个是UTF8编码的。同时也知道UTF16等有字节序的问题，所以在Unicode里面**字节顺序标记**（英语：byte-order mark，**BOM**）是位于码点`U+FEFF`的[统一码](https://zh.wikipedia.org/wiki/%E7%B5%B1%E4%B8%80%E7%A2%BC)字符的名称。微软的`EF BB BF`和这里的BOM也就统称为BOM了，用来标示文件是以[UTF-8](https://zh.wikipedia.org/wiki/UTF-8)、[UTF-16](https://zh.wikipedia.org/wiki/UTF-16)或[UTF-32](https://zh.wikipedia.org/wiki/UTF-32)编码的记号。

Posix系统明确不建议使用字节序掩码`EF BB BF`。所以对于一个跨环境的团队来说，在Windows工作的同学，用Windows自带的很多编辑器编译的是，注意就不要插入这么一个东西了。

这个世界上有标准之说，那么就肯定有非标准的存在，对于UTF8来说也存在一些非标准或者说被局部修改的版本，比如有个修改的版本为了解决UTF8的结束符和优化扩展平面，把 [空字符](https://zh.wikipedia.org/wiki/%E7%A9%BA%E5%AD%97%E7%AC%A6)（null character，U+0000）使用双字节的0xc0 0x80，而不是单字节的0x00。这保证了在已编码字符串中没有嵌入空字节。因为[C语言](https://zh.wikipedia.org/wiki/C%E8%AF%AD%E8%A8%80)等语言程序中，单字节空字符是用来标志字符串结尾的。当已编码字符串放到这样的语言中处理，一个嵌入的空字符将把字符串一刀两断。第二个不同点是[基本多文种平面](https://zh.wikipedia.org/wiki/%E5%9F%BA%E6%9C%AC%E5%A4%9A%E6%96%87%E7%A8%AE%E5%B9%B3%E9%9D%A2)之外字符的编码的方法。在标准UTF-8中，这些字符使用4字节形式编码，而在改正的UTF-8中，这些字符和UTF-16一样首先表示为代理对（surrogate pairs），然后再像[CESU-8](https://zh.wikipedia.org/w/index.php?title=CESU-8&action=edit&redlink=1)那样按照代理对分别编码。

一个非常简单的utf8编解码实现可以参考：

http://stackoverflow.com/questions/4607413/c-library-to-convert-unicode-code-points-to-utf8/4609989#4609989

```c
if (c<0x80) *b++=c;
else if (c<0x800) *b++=192+c/64, *b++=128+c%64;
else if (c-0xd800u<0x800) goto error;
else if (c<0x10000) *b++=224+c/4096, *b++=128+c/64%64, *b++=128+c%64;
else if (c<0x110000) *b++=240+c/262144, *b++=128+c/4096%64, *b++=128+c/64%64, *b++=128+c%64;
else goto error;
```

一个工业级可用的版本可以参考：

https://github.com/JerryZhou/isee/blob/master/code/foundation/util/iutf8.c

非常好理解。

最后又一个纪要就是很多服务端开发同学遇到的，关于**数据库的编码方案选择的问题**。**MySql**里面有一个很迷惑人的地方，里面有：`utf8`， `utf8_unicode_ci` `utf8_general_ci`， `utf8mb4`，  `utf8mb4_generate_ci`，  `utf8mb4_unicode_ci` 等等。utf8 和 utfbmb4的区别是MySql里面，把Utf8的多字节阉割到了至多3字节，也就是只能表达BMP里面的字符，而utf8mb4：utf8-mulitiple-byte-4，很显然他是扩展到了4个字节，这样至少emoji是可以显示了。

置于后面的generate_ci 和 unicode_ci 可以详细查看：

http://stackoverflow.com/questions/766809/whats-the-difference-between-utf8-general-ci-and-utf8-unicode-ci

综合的建议就是如果没有特别极度的理由，我们无脑用`utf8mb4_uncidoe_ci`就对了。



[1]: https://www.freetype.org/freetype2/docs/glyphs/glyphs-3.html	"Glyph"
[2]: https://zh.wikipedia.org/wiki/ASCII	"American Standard Code for Information Interchange"
[3]: https://zh.wikipedia.org/wiki/EASCII	"Support 128-256"
[4]: https://en.wikipedia.org/wiki/Mojibake	"乱码"
[5]: https://zh.wikipedia.org/wiki/%E4%B8%AD%E6%97%A5%E9%9F%93%E7%B5%B1%E4%B8%80%E8%A1%A8%E6%84%8F%E6%96%87%E5%AD%97	"CJK"