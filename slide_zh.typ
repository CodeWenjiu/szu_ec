#import "@preview/touying:0.6.1": *
#import themes.university: *
#import "@preview/cetz:0.3.2"
#import "@preview/fletcher:0.5.5" as fletcher: node, edge
#import "@preview/numbly:0.1.0": numbly
#import "@preview/theorion:0.3.2": *
#import cosmos.clouds: *
#show: show-theorion

#let cetz-canvas = touying-reducer.with(reduce: cetz.canvas, cover: cetz.draw.hide.with(bounds: true))
#let fletcher-diagram = touying-reducer.with(reduce: fletcher.diagram, cover: fletcher.hide)

#show: university-theme.with(
    aspect-ratio: "16-9",
    config-common(
        frozen-counters: (theorem-counter,), 
        show-notes-on-second-screen: right
    ), 

    config-info(
        title: [现代处理器架构简述],
        subtitle: [并行执行能力],
        author: [JinHui Lin],
        date: datetime.today(),
        institution: [ShenZhen University],
        logo: emoji.computer,
    ),
)

#set text(font: ("Sarasa Term SC Nerd")) 

#speaker-note[
    今天我要讨论的是现代处理器架构设计

    现代处理器的架构设计基本上只为了一个目标

    性能——即在相同时间内执行更多的指令
]

#title-slide()

== cpu性能受什么影响？

#speaker-note[
    Optional
    鉴于时间优先，我就跳过引入部分，直接开始讲正文<start>
]

指令数量

这取决于
- 程序的目的
- 程序是否良好编写
- 使用的编程语言
- 编译器行为
- etc.

#pause 
并非我们今天要讨论的范围

#pagebreak()

频率

这却决于
- 前端cpu设计
- 后端设计
- 制造工艺
- etc.

#pause 
并非我们今天要讨论的范围

#pagebreak()
IPC(Instructions Per Cycle)

即每周期能够执行的指令数量

这基本上等价于——"cpu并行化执行指令的能力"

我们今天讨论的主体就是cpu通过自身微架构并行化串行指令的设计

== 计算机基本架构<start>

#speaker-note[
    这是现代计算机的基础架构

    \<pause\>

    直到今天，这套架构依旧能够用来解释计算机架构

    \<pause\>

    虽然部分地方有些微的差别，但这部分远远超过了我们想要讨论的范围
    今天的讨论仅设计cpu内部的设计
]

#slide(composer: (1fr, 1fr))[
  #image("processor/Von_Neumann.excalidraw.svg")
][
    经典冯诺依曼计算机架构

    #pause 
    直到今天，这套架构依旧能够用来解释计算机架构

    #pause 
    虽然部分地方有些微的差别(比如内部寄存器，缓存，MMIO等)

    #pause
    它的运行过程基本就是"取指->执行"的循环
]

== 流水线
流水线是相当经典的cpu并行化加速手段，通过将cpu执行分为多个阶段，同时执行这些阶段从而在提高频率的同时不大量降低IPC，
从而实现了性能的提升

现代很少有cpu不使用流水线技术，即使是你家洗衣机使用的主控(MCU)，也大概率有至少二级流水线(Arm CortexM0+)

// == 冯诺依曼机
// #image("processor/Von_Neumann.excalidraw.svg")
// 这是现代计算机的基础架构，不过有几个不同之处
// - 由于访存速度往往低于cpu处理速度，因此不会每条指令都访问Memory或Input Output，大多数指令只与cpu内部的寄存器交互，只在必要的时候用访存指令访问内存和IO
// - 内存和IO没有本质区别，可以将IO视为特殊的内存，或者将内存视为能够存储数据的IO，因此现代计算机在指令层面上往往不再对两者做区分
//     - 将内存和设备区分对待的IO访问方式称为PMIO，将其统一的访问方式称为MMIO
//     - 现代的cpu往往使用MMIO，某些特殊的cpu使用PMIO，我们日常使用的计算机(x86)同时支持PMIO(USB)和MMIO(PCIE)
// - 冯诺依曼机将指令也视为一种特殊的数据存放在内存中，因此指令和数据没有本质区别，都可以被读取和修改，
//     因此允许程序运行时修改自身，这种程序称为"自修改程序"
//     - 然而现代程序往往不会再在运行期修改自身，这种情况下，指令和数据的特性就很不一样了，前者只读后者却可读写，
//         再加上后期的cpu并行化能力允许同时进行取指和访存，
//         现在往往会在L1缓存(可以视为Memory的一个子集)中将指令和数据分别存放以达到最高的利用率


#speaker-note[
    但更加高性能的cpu往往会为了更高的频率将流水线进一步细分

    一个经典的流水线阶段划分(你大概率会在教科书上看到)如图

    基本上将指令执行分为五个阶段"取指"、"译码"、"执行"、"访存"、"写回"

    \<pause\>
    但流水线并非可以随意执行

    存在特殊的分支指令，导致出现控制冒险

    \<pause\>

    解决方式是通过推测执行，猜测跳转结果，如果出错将冲刷流水线
]

#slide(composer: (1fr, 1fr))[
    #image("processor\Classic_5-Stage_Pipeline.png")
][
    一个经典的流水线阶段划分

    #pause
    但流水线并非可以随意执行

    存在特殊的分支指令，导致出现控制冒险
    
    同时数据依赖的指令数据会导致数据冒险

    #pause
    解决方式是通过推测执行，猜测跳转结果，如果出错将冲刷流水线
]

== 分支预测

推测执行如果正确，则能够大量提升性能，因此推测的准确率就成为关键

#pause
分支预测算法

- 静态分支预测
    在编译时确定分支预测方向

- 动态分支预测
    记录分支指令的历史跳转结果，使用这些历史结果预测下一次跳转

== 乱序执行
通过将指令顺序重排，提前避免数据冒险

#pause
乱序执行的基本思路：
- 新增一个指令队列
- 将其重新排序以避免冒险
- 执行完成之后，按原始顺序写回

== 超标量

#speaker-note[
    还记得上面提到的指令队列吗，我们在这里用到，因为实现了超标量的处理器往往也实现了乱序执行，因为两者都需要处理器正确判断指令之间的依赖性
]

超标量(Superscalar)是指cpu在同一周期内执行多条指令的能力

#pause
超标量的基本思路
- 同时取多条指令，将其推入指令队列
- 根据指令依赖关系，将不互相依赖的指令推入后端同时执行
- 执行完成之后，按原始顺序写回

== 寄存器重命名

寄存器重命名(Register Renaming)是另一种避免冒险的方式

基本思路就是
#image("processor/register_renaming.excalidraw.svg")

#speaker-note[
    寄存器重命名的基本思路就是通过为单个逻辑寄存器实现多个物理寄存器，从而避免WAR和WAW冒险
    解决这两个冒险之后乱序执行的自由度更高了，因此可以实现更高的指令并行度
    而RAW冒险也能够通过更高的乱序程度来解决
]

#pagebreak()

Tomasulo算法：
- 为每个逻辑寄存器维护一个重命名表
- 当指令需要写入寄存器时，分配一个新的物理寄存器
- 更新重命名表，将逻辑寄存器映射到新的物理寄存器
- 后续读取该逻辑寄存器的指令会使用最新的物理寄存器
- 当指令完成时，释放不再需要的物理寄存器

#speaker-note[
    这个重命名表我们现在往往称之为ROB缓存队列
]

== 总结

#speaker-note[
    让我们总结一下今天讨论的内容

    我们主要讨论了现代处理器架构中提高性能的几种关键技术

    这些技术都是为了解决同一个问题：如何让处理器在单位时间内执行更多的指令
]

现代处理器架构的主要优化技术：

#pause
- 流水线：将指令执行分为多个阶段并行执行
- 分支预测：通过预测分支跳转方向减少流水线停顿
- 乱序执行：重排指令顺序避免数据冒险
- 超标量：同一周期执行多条指令
- 寄存器重命名：通过物理寄存器映射避免寄存器冒险

== 感谢

#speaker-note[
    感谢大家的聆听

    如果有什么问题，欢迎随时提问
]

如有问题，欢迎讨论
