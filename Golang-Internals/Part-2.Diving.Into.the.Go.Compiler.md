# 深入浅出 Golang，第一部分：工程的结构以及主要概念 [Part 2: Diving Into the Go Compiler][1]

你是否知道我们是怎么通过Golang的运行时，让[interface][2]去引用到一个变量的？这其实是一个非常有深度的问题，因为在Golang里面一个type实现了某一个interface，但type本身没有存储任何信息关联到这个interface，当然我们可以尝试用我们从[Part 1]里面了解到的信息，从go的编译器实现角度来回答这个问题。

为了更精准的回答上面的类似问题，我们接下来更加深入的分析go的编译器：我们写一个非常小的golang版本的"hello world"，然后通过分析这个"hello world"，了解内部的类型转换等相关机制，通过例子也进一步对node-tree的生成过程做详细解析。当然了解node-tree的生成过程不是我们的最终目的，我们的目的是以此为基础去横向涉猎go编译器的其他特性。

- - -

## 前戏
为了准备了解编译器，我们准备我们的实验环境，我们从golang的编译器直接入手，而不是通过golang的集成工具。可以通过如下的方式够到编译器(注意安装go1.4版本)：

	```
	go tool 6g test.go
	```

上面的命令会编译源文件test.go，然后在当前目录生成object文件。在笔者机器上6g是一个amd64架构的编译器，要生成其他架构的代码必须要用相应架构的编译器。
我们直接操作编译器的时候，我们可以手动在编译器上加上一些命令行参数，让编译器给我们生成相关辅助信息，更详细的编译器参数可以参考这个[地方][3]，我们这里会给编译器上架_-W_参数，加上这个参数，编译器会把node-tree打印出来。

## 编写"hello world"程序
首先我们编写一个用于分析的简单go程序，我的版本是这样的：

```
  1  package main
  2 
  3  type I interface {
  4          DoSomeWork()
  5  }
  6 
  7  type T struct {
  8          a int
  9  }
 10 
 11  func (t *T) DoSomeWork() {
 12  }
 13 
 14  func main() {
 15          t := &T{}
 16          i := I(t)
 17          print(i)
 18  }
```




[1]: http://blog.altoros.com/golang-internals-part-2-diving-into-the-go-compiler.html "Part 2: Diving Into the Go Compiler"
[2]: http://jordanorelli.com/post/32665860244/how-to-use-interfaces-in-go "interface in go"
[3]: https://golang.org/cmd/compile/ "Compiler"