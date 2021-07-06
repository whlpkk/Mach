# Mach-O 学习小结（六）

最近学习了一下 Mach-O ,这里做个笔记记录，整理思路，加深理解。

## 概述

[第一章](https://www.jianshu.com/p/fa5666308724) 描述了 Mach-O 文件的基本结构；  
[第二章](https://www.jianshu.com/p/92b4f611170a) 概述了符号，分析了符号表（symbol table）。  
[第三章](https://www.jianshu.com/p/9e4ccd3cb765) 探寻动态链接。   
[第四章](https://www.jianshu.com/p/c9445935b055) 分析fishhook。   
[第五章](https://www.jianshu.com/p/bad714ea8df7) 分析BeeHive。    
[第六章](https://www.jianshu.com/p/a174f17a9d82) App启动时间。



关于App启动时间的优化，网上有无数的文章，本文不讲如何具体优化。只是结合前面几章Mach-O文件的学习，带着大家一块分析启动中的一部分操作，加深理解。

## 背景知识

#### APP的启动流程

1. iOS系统首先会加载解析该APP的Info.plist文件，因为Info.plist文件中包含了支持APP加载运行所需要的众多Key，value配置信息，例如APP的运行条件(Required device capabilities)，是否全屏，APP启动图信息等。

2. 创建沙盒(iOS8后，每次启动APP都会生成一个新的沙盒路径)

3. 根据Info.plist的配置检查相应权限状态

4. 加载Mach-O文件读取dyld路径并运行dyld动态连接器(内核加载了主程序，dyld只会负责动态库的加载)
	- 4.1 首先dyld会寻找合适的CPU运行环境
	- 4.2 然后加载程序运行所需的依赖库，并对这些库进行链接。
	- 4.3 加载所有方法(runtime就是在这个时候被初始化并完成OC的内存布局)
	- 4.4 加载C函数
	- 4.5 加载category的扩展(此时runtime会对所有类结构进行初始化)
	- 4.6 加载C++静态函数，加载OC+load
	- 4.7 最后dyld返回main函数地址，main函数被调用

#### 安全

 ASLR（Address Space Layout Randomization）：地址空间布局随机化，镜像会在随机的地址上加载。

代码签名：为了在运行时验证 Mach-O 文件的签名，并不是每次重复的去读入整个文件，而是把文件每页内容都生成一个单独的加密散列值，并把值存储在 `__LINKEDIT` 中。这使得文件每页的内容都能及时被校验确并保不被篡改。而不是每个文件都做hash加密并做数字签名。



##  加载Mach-O文件

#### dyld
dyld叫做动态链接器，主要的职责是完成各种库的连接。dyld是苹果用C++写的一个开源库，可以在[苹果的git上直接查看源代码](https://links.jianshu.com/go?to=https%3A%2F%2Fgithub.com%2Fopensource-apple%2Fdyld)。

Unix 的前二十年很安逸，因为那时还没有发明动态链接库。有了动态链接库后，一个用于加载链接库的帮助程序被创建。在苹果的平台里是 `dyld`，其他 Unix 系统也有 `ld.so`。 当内核完成映射进程的工作后会将名字为 `dyld` 的Mach-O 文件映射到进程中的随机地址，它将 PC 寄存器设为 `dyld` 的地址并运行。`dyld` 在应用进程中运行的工作是加载应用依赖的所有动态链接库，准备好运行所需的一切，它拥有的权限跟应用一样。

下面的步骤构成了 `dyld` 的时间线：

Load dylibs -> Rebase -> Bind -> ObjC -> Initializers

#### 加载 Dylib

从主执行文件的 header 获取到需要加载的所依赖动态库列表，而 header 早就被内核映射过。然后它需要找到每个 dylib，然后打开文件读取文件起始位置，确保它是 Mach-O 文件。接着会找到代码签名并将其注册到内核。然后在 dylib 文件的每个 segment 上调用 `mmap()`。应用所依赖的 dylib 文件可能会再依赖其他 dylib，所以 `dyld` 所需要加载的是动态库列表一个递归依赖的集合。一般应用会加载 100 到 400 个 dylib 文件，但大部分都是系统 dylib，它们会被预先计算和缓存起来，加载速度很快。

#### Rebasing

正如我们前面几章学到的，Mach-O文件中，对于镜像内部的一些指针指向，都是按照虚拟内存地址没有偏移计算的。如今用了 ASLR 后会将 dylib 加载到新的随机地址(actual_address)，这个随机的地址跟代码和数据指向的旧地址(preferred_address)会有偏差，`dyld` 需要修正这个偏差(slide)，做法就是将 dylib 内部的指针地址都加上这个偏移量，偏移量的计算方法如下：

Slide = actual_address - preferred_address

然后就是重复不断地对 `__DATA` 段中需要 rebase 的指针加上这个偏移量。这就又涉及到 page fault 和 COW（`copy-on-write`）。这可能会产生 I/O 瓶颈，但因为 rebase 的顺序是按地址排列的，所以从内核的角度来看这是个有次序的任务，它会预先读入数据，减少 I/O 消耗。

#### Binding

Binding 是处理那些指向 dylib 外部的指针，它们实际上被符号（symbol）名称绑定，也就是个字符串。具体如何绑定的，不清楚的同学可以再回顾一下第三章相关知识。在这步时，链接器会需要找到 symbol 对应的实现，这需要很多计算，去符号表里查找。找到后会将内容存储到 `__DATA` 段中的那个指针中。Binding 看起来计算量比 Rebasing 更大，但其实需要的 I/O 操作很少，因为之前 Rebasing 已经替 Binding 做过了。

这里，`Rebasing` 和 `Binding` 都可以被统称为 `Fix-ups` 。即修正（fix-up）指针和数据。

* Rebasing：在镜像内部调整指针的指向
* Binding：将指针指向镜像外部的内容

Objective-C 中有很多数据结构都是靠 Rebasing 和 Binding 来修正（fix-up）的，比如 `Class` 中指向超类的指针和指向方法的指针。

ObjC 是个动态语言，可以用类的名字来实例化一个类的对象。这意味着 ObjC Runtime 需要维护一张映射类名与类的全局表。当加载一个 dylib 时，其定义的所有的类都需要被注册到这个全局表中。

在 ObjC 中可以通过定义类别（Category）的方式改变一个类的方法。有时你想要添加方法的类在另一个 dylib 中，而不在你的镜像中（也就是对系统或别人的类动刀），这时也需要做些 fix-up。

## 总结

Fix-up之后，就是创建OC的内存布局，runtime等等，本文就不一一细讲了。

结合上面的知识，我们可以知道，想要加快App的启动速度：

* 加载Dylib阶段，之前提到过加载系统的 dylib 很快，因为有优化。但加载内嵌（embedded）的 dylib 文件很占时间，所以尽可能把多个内嵌 dylib 合并成一个来加载，或者使用 static archive。
* `Rebase/Binding` 阶段，查看 `__DATA` 段中需要修正（fix-up）的指针，减少指针数量才会减少这部分工作的耗时。对于 ObjC 来说就是减少 `Class`,`selector` 和 `category` 这些元数据的数量。从编码原则和设计模式之类的理论都会鼓励大家多写精致短小的类和方法，并将每部分方法独立出一个类别，其实这会增加启动时间。对于 C++ 来说需要减少虚方法，因为虚方法会创建 vtable，这也会在 `__DATA` 段中创建结构。虽然 C++ 虚方法对启动耗时的增加要比 ObjC 元数据要少，但依然不可忽视。最后推荐使用 Swift 结构体，它需要 fix-up 的内容较少。

本文只是简要的介绍了相关方面知识，感兴趣的同学，可以自行 google 相关资料。
