<!doctype HTML>
<html>
<head>
<meta charset="utf-8" />
<title>深入浅出Golang</title>
<style>
body {
    font-family: Tahoma;
    font-size: 10pt;
    line-height: 170%;
padding: 0 10pt;
}

nav {
background: gray;
color: white;
       overflow-x: hidden;
       overflow-y: auto;
position: fixed;
top: 0;
left: 0;
bottom: 0;
width: 200px;
}

header {
    padding-left: 200px;
}

article {
    padding-left: 200px;
}

footer {
    padding-left: 200px;
}
</style>
</head>
<body>
<header>
<x-markdown src="Golang-Internals/Part-0.head.md" />
</header>
<nav>
<x-index />
</nav>
<article>
<x-markdown src="Golang-Internals/Part-1.Main.Concepts.and.Project.Structure.md" />
<x-markdown src="Golang-Internals/Part-2.Diving.Into.the.Go.Compiler.md" />
<x-markdown src="Golang-Internals/Part-3.The.Linker.Object.Files.and.Relocations.md" />
<x-markdown src="Golang-Internals/Part-4.Object.Files.and.Function.Metadata.md" />
<x-markdown src="Golang-Internals/Part-5.the.Runtime.Bootstrap.Process.md" />
<x-markdown src="Golang-Internals/Part-6.Bootstrapping.and.Memory.Allocator.Initialization.md" />
</article>
<footer>
<x-markdown src="Golang-Internals/Part-x.footer.md" />
</footer>
</body>
</html>
