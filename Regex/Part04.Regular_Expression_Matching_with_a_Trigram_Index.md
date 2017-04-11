# Regular Expression Matching with a Trigram Index or How Google Code Search Worked



## Introduction

2006年暑假，非常幸运能够在Google进行实习。当时，Google内部与一个叫gsearch的工具，这个工具看起来是可以在Google的整个代码库的所有文件进行grep操作，然后打印出搜索结果。当然，当时他的实现是比较挫的，而且运行也是非常慢的，其实gsearch做的就是向一组把整个source-tree加载到内存里面的服务器发请求：在每一台机器上对里面加载的source-tree执行grep操作，然后gsearch会合并所有的搜索结果并打印出来。Jeff Dean, 我实习期间的老板，也是gsearch的作者之一，做了一个提议说，如果做一个web入口，然后上面提交搜索请求，然后可以在全世界所有的开源代码上运行gsearch会是一个很吊的事。我一听觉得有点意思，所以我那个夏天我就在Google干这个自己看来吊吊的事情。由于我们开始的计划过分乐观，我们的发布延后到了10月份，到2006年10月5号的时候，我们终于发布了(那个时候我刚好会学校了，但依然是兼职实习的状态)。

