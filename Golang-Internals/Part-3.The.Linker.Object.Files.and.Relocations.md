# 深入浅出 Golang，第三部分：链接，重定向以及Object文件 [Part 3: The Linker, Object Files, and Relocations][1]

今天我们聊聊Go的链接器，Object文件，以及重定向。

好，为什么我们需要关心上述的这些概念呢，这个道理其实也很简单，比如你要了解一个大项目，那么你首先肯定得把大项目分解成很多小的模块；然后你再搞清楚模块与模块之间的依赖关系，一起他们之间项目调用的约定。对于Go这个大项目来说，他可以分解成：编译器，链接器，运行时；然后编译器生成Object文件，链接器在这个基础上工作。我们今天这里主要讨论就是这一部分。

- - -

## 怎么生成Go的Object文件
我们来做一个实验，我们写一个超级简单的示例程序，看Go的编译器会生成什么样的Object文件。我们用如下的程序来做实验：
```
package main

func main() {
	print(1)
}
```

是不是简单到你怀疑人生！好我们编译这个简单程序：
```
go tool 6g test.go
```
如果是Go1.5或者以上的版本可以执行：
```
go tool compile test.go
```
上面的命令会生成test.6的Object文件(如果是Go1.5以上会生成test.o的Object文件)，为了刺探这个Object文件的内部结构我们需要用到[goobj][2]库，这个库随着Go的源代码一起发布，主要用来检查Object文件格式是否正确。为了解释内部结构，笔者基于这个库写了一个小工具，用来打印Object文件内部结构信息，小工具的源代码可以在[这里][3]找到。
我们先下载和安装这里需要用到的这个小工具：

	go get github.com/s-matyukevich/goobj_explorer

然后执行如下命令：

	goobj_explorer -o test.6

好，你将在控制台里面看到`goob.Package`结构体。

- - -

## 详解Object文件
Object文件比较有意义的部分是Sym数组，这其实是一个符号表。应用程序里面定义所有符号信息都在这个表里面，包括定义的函数，全局表里，类型，常量等等。我们看一下关于main函数的符号(我们这里暂时把`Reloc`和`Func`这两个部分先省略，我们后续对这两部分再详细讨论)。
```
&goobj.Sym{
            SymID: goobj.SymID{Name:"main.main", Version:0},
            Kind:  1,
            DupOK: false,
            Size:  48,
            Type:  goobj.SymID{},
            Data:  goobj.Data{Offset:137, Size:44},
            Reloc: ...,
            Func:  ...,
}
```
我们用一个表格对goobj.Sym的各个字段做一个说明：

|字段|描述|
|---|---|
|SumID|全局唯一的符号ID，由符号名和版本组成，版本用来区分同名的不同符号|
|Kind|表明符号属于什么类型，后续会进一步说明这个字段|
|DupOK|表明这个符号是否可以存在多个同名的|
|Size|符号的内存大小|
|Type|可以指向另外一个详细说明类型信息的符号，可以是空|
|Data|包含符号的二进制信息，不同类型的符号这个字段的内容解释是不一样的，如果是函数类型的符号，这里存储的是汇编代码，如果是字符串类型的符号，这个字段存储的是字符串的值|
|Reloc|包含重定向信息，后面详细说明...|
|Func|如果是函数类型的符号，这里存储的是函数的元信息|







[1] http://blog.altoros.com/golang-internals-part-3-the-linker-and-object-files.html "The Linker, Object Files, and Relocations"
[2] https://github.com/golang/go/tree/master/src/cmd/internal/goobj "goobj"
[3] https://github.com/s-matyukevich/goobj_explorer "goobj_explorer"



