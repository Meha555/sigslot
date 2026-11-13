# Sigslot，一个信号 - 槽库

Sigslot 是一个仅包含头文件、线程安全的 C++ 信号 - 槽实现。

## 特性

主要目标是替换 Boost.Signals2。

除了通常的功能外，它还提供

- 线程安全，
- 对象生命周期跟踪以实现自动槽断开连接（可通过 ADL 扩展），
- RAII 连接管理，
- 槽组以强制执行槽执行顺序，
- 合理的性能。以及简单直接的实现。

Sigslot 经过单元测试，应该足够可靠和稳定，可以替换 Boost Signals2。

测试在地址、线程和未定义行为清理器下干净地运行。

许多实现允许信号返回类型，但 Sigslot 不支持，因为我不需要它们。如果能说服我，我稍后可能会改变主意。

> 即没法像Qt的信号那样可以给信号传参从而实现像槽函数传参！

## 安装

不需要编译或安装，只需包含 `sigslot/signal.hpp` 并使用即可。Sigslot 目前依赖于符合 C++14 标准的编译器，但如果需要，可以 retrofitted 到 C++11。已知它在 GNU Linux 上的 Clang 4.0 和 GCC 5.0+ 编译器、MSVC 2017 及更高版本、Windows 上的 Clang-cl 和 MinGW 上工作。

但是，请注意 Windows 上 MSVC 和 Clang-Cl 编译器的潜在问题，在特殊情况下可能需要 `/OPT:NOICF` 链接器标志。请阅读实现细节章节了解解释。

提供了 CMake 列表文件用于安装和生成 CMake 导入模块。`Pal::Sigslot` 导入目标已经应用了所需的链接器标志。示例和测试可选地依赖于 Qt5 和 Boost，以执行适配器单元测试。

```cmake
# 使用来自 cmake 的 Sigslot
find_package(PalSigslot)

add_executable(MyExe main.cpp)
target_link_libraries(MyExe PRIVATE Pal::Sigslot)
```

在配置时提供了一个配置选项 `SIGSLOT_REDUCE_COMPILE_TIME`。当激活时，它尝试通过避免 `std::make_shared` 调用导致的大量模板实例化来减少代码膨胀。
此选项默认关闭，但可以为那些希望以稍微降低代码效率为代价来 favor 代码大小和编译时间的人激活。

可以使用以下说明从根目录进行安装：

```sh
mkdir build && cd build
cmake .. -DSIGSLOT_REDUCE_COMPILE_TIME=ON -DCMAKE_INSTALL_PREFIX=~/local
cmake --build . --target install

# 如果你想编译示例：
cmake --build . --target sigslot-examples

# 并编译/执行单元测试：
cmake --build . --target sigslot-tests
```

### CMake FetchContent

`Pal::Sigslot` 也可以使用 [FetchContent](https://cmake.org/cmake/help/latest/module/FetchContent.html) 方法集成。

```cmake
include(FetchContent)

FetchContent_Declare(
  sigslot
  GIT_REPOSITORY https://github.com/palacaze/sigslot
  GIT_TAG        19a6f0f5ea11fc121fe67f81fd5e491f2d7a4637 # v1.2.0
)
FetchContent_MakeAvailable(sigslot)

add_executable(MyExe main.cpp)
target_link_libraries(MyExe PRIVATE Pal::Sigslot)
```

### Xmake

根目录 `xmake.lua` 定义项目选项和 `sigslot` 目标，通过 `includes()` 加载 `example/xmake.lua` 和 `test/xmake.lua` 中的示例、测试目标。

需要 Xmake 2.8.5 或更高版本。在其他 Xmake 项目中包含本地源码目录，通过 `add_deps("sigslot")` 使用头文件目标：

```lua
includes("path/to/sigslot")

target("MyExe")
    set_kind("binary")
    add_files("main.cpp")
    add_deps("sigslot")
```

`sigslot` 目标会传递头文件目录、C++14 要求、线程参数，以及 MSVC 兼容链接器需要的 `/OPT:NOICF`。示例和测试默认关闭。在仓库根目录执行：

```sh
xmake f -m release --examples=y --tests=y
xmake
xmake run sigslot-example-basic
xmake test
xmake install -o path/to/install sigslot
```

使用 `--reduce_compile_time=y` 启用 `SIGSLOT_REDUCE_COMPILE_TIME`。
启用 `--tests=y` 后，`--with_boost=y` 会启用 Boost 适配器测试，并通过 Xmake 包管理器获取 Boost；`--with_qt=y` 会使用已安装的 Qt SDK 构建 Qt 适配器测试，必要时通过 `--qt=path/to/Qt/version/compiler` 指定 SDK 目录。

## 文档

Sigslot 实现了在 UI 框架中流行的信号 - 槽结构，使其易于使用观察者模式或基于事件的编程。库的主要入口点是 `sigslot::signal<T...>` 类模板。

信号是可以发出类型化通知的对象，实际上是按照信号类模板参数参数化的值，并注册任何数量的兼容参数类型的通知处理程序（可调用对象），以便在发生信号发射时使用提供的值执行。在信号 - 槽术语中，这称为将槽连接到信号，其中"槽"表示可调用实例，"连接"可以被认为是从信号到槽的概念链接。

下面展示的所有代码片段都以可编译源代码的形式在示例子目录中提供。

### 基本用法

这是第一个展示库最基本功能的示例。

我们首先声明一个无参数信号 `sig`，然后继续连接几个槽，最后发射一个信号，触发预先连接的每个槽可调用对象的调用。注意库如何处理不同形式的可调用对象。

```cpp
#include <sigslot/signal.hpp>
#include <iostream>

void f() { std::cout << "free function\n"; }

struct s {
    void m() { std::cout << "member function\n"; }
    static void sm() { std::cout << "static member function\n";  }
};

struct o {
    void operator()() { std::cout << "function object\n"; }
};

int main() {
    s d;
    auto lambda = []() { std::cout << "lambda\n"; };
    auto gen_lambda = [](auto && ...a) { std::cout << "generic lambda\n"; };

    // 声明一个无参数的信号实例
    sigslot::signal<> sig;

    // 连接槽
    sig.connect(f);
    sig.connect(&s::m, &d);
    sig.connect(&s::sm);
    sig.connect(o());
    sig.connect(lambda);
    sig.connect(gen_lambda);

    // 也可以使用自由的 connect() 函数
    sigslot::connect(sig, f);

    // 发射信号
    sig();
}
```

默认情况下，发射信号时的槽调用顺序是未指定的，请不要依赖它总是相同的。你可以通过使用槽组来约束特定的调用顺序，这将在后面介绍。

### 带参数的信号

第一个例子很简单但不是很有用，让我们转向一个发射值的信号。信号可以发射任意数量的参数，如下所示。

```cpp
#include <sigslot/signal.hpp>
#include <iostream>
#include <string>

struct foo {
    // 注意我们在这里接受 double 作为第一个参数。
    // 这没问题，因为 float 可以转换为 double。
    // 's' 是一个引用，因此可以被修改。
    void bar(double d, int i, bool b, std::string &s) {
        s = b ? std::to_string(i) : std::to_string(d);
    }
};

// 函数对象可以处理默认参数和重载。
// 它不适用于静态和成员函数。
struct obj {
    void operator()(float, int, bool, std::string &, int = 0) {
        std::cout << "I was here\n";
    }

    void operator()() {}
};

int main() {
    // 声明一个带有 float、int、bool 和 string& 参数的信号
    sigslot::signal<float, int, bool, std::string&> sig;

    // 一个将其参数打印到 stdout 的通用 lambda
    auto printer = [] (auto a, auto && ...args) {
        std::cout << a;
        (void)std::initializer_list<int>{
            ((void)(std::cout << " " << args), 1)...
        };
        std::cout << "\n";
    };

    // 连接槽
    foo ff;
    sig.connect(printer);
    sig.connect(&foo::bar, &ff);
    sig.connect(obj());

    float f = 1.f;
    short i = 2;  // 可转换为 int
    std::string s = "0";

    // 发射信号
    sig(f, i, false, s);
    sig(f, i, true, s);
}
```

如图所示，槽参数类型不需要与信号模板参数完全相同，可以转换即可。使用通用参数也没问题，如 `printer` 通用 lambda 所示（也可以写为函数模板）。

目前我能想到的关于可调用对象处理有两个限制：默认参数和函数重载。两者在函数对象的情况下都能正常工作，但对于静态和成员函数会编译失败，原因不同但相关。

#### 处理重载函数

考虑以下代码：

```cpp
struct foo {
    void bar(double d);
    void bar();
};
```

`&foo::bar` 应该指代什么？根据重载，这个成员函数指针不映射到唯一的符号，因此编译器无法选择正确的符号。解决这个符号的一种方法是显式地将函数指针转换为正确的函数类型。这里是一个使用小助手工具来更轻量语法的示例（事实上我可能很快就会把它添加到库中）。

```cpp
#include <sigslot/signal.hpp>

template <typename... Args, typename C>
constexpr auto overload(void (C::*ptr)(Args...)) {
    return ptr;
}

template <typename... Args>
constexpr auto overload(void (*ptr)(Args...)) {
    return ptr;
}

struct obj {
    void operator()(int) const {}
    void operator()() {}
};

struct foo {
    void bar(int) {}
    void bar() {}

    static void baz(int) {}
    static void baz() {}
};

void moo(int) {}
void moo() {}

int main() {
    sigslot::signal<int> sig;

    // 连接槽，必要时转换为正确的重载
    foo ff;
    sig.connect(overload<int>(&foo::bar), &ff);
    sig.connect(overload<int>(&foo::baz));
    sig.connect(overload<int>(&moo));
    sig.connect(obj());

    sig(0);

    return 0;
}
```

#### 处理带有默认参数的函数

默认参数不属于函数类型签名的一部分，并且可以重新定义，因此它们确实很难处理。当将槽连接到信号时，库确定提供的可调用对象是否可以使用信号参数类型调用，但此时默认函数参数的存在是未知的，因此参数数量可能不匹配。

这个用例的一个简单的解决方法是创建一个 bind 适配器，事实上我们可以使它相当通用：

```cpp
#include <sigslot/signal.hpp>

#define ADAPT(func) \
    [=](auto && ...a) { (func)(std::forward<decltype(a)>(a)...); }

void foo(int &i, int b = 1) {
    i += b;
}

int main() {
    int i = 0;

    // 没问题，所有参数都处理了
    sigslot::signal<int&, int> sig1;
    sig1.connect(foo);
    sig1(i, 2);

    // 必须包装在适配器中
    i = 0;
    sigslot::signal<int&> sig2;
    sig2.connect(ADAPT(foo));
    sig2(i);

    return 0;
}
```

### 连接管理

#### 连接对象

直到现在还没有明显的是 `signal::connect()` 实际上返回一个 `sigslot::connection` 对象，该对象可用于管理信号 - 槽连接的行为和生命周期。`sigslot::connection` 是一个轻量级对象（基本上是 `std::weak_ptr`），允许与正在进行的信号 - 槽连接交互，并提供以下功能：

- 状态查询，即测试连接是否有效、正在进行或面临销毁，
- 连接（取消）阻塞，允许在发射信号时临时禁用槽的调用，
- 槽断开连接，通过 `signal::connect()` 创建的连接的销毁。

`sigslot::connection` 不将连接绑定到作用域：这不是 RAII 对象，这解释了为什么它可以被复制。但是它可以隐式转换为 `sigslot::scoped_connection`，后者在超出作用域时销毁连接。

这里是一个说明其中一些功能的示例：

```cpp
#include <sigslot/signal.hpp>
#include <string>

int i = 0;

void f() { i += 1; }

int main() {
    sigslot::signal<> sig;

    // 保留一个 sigslot::connection 对象
    auto c1 = sig.connect(f);

    // 断开连接
    sig();  // i == 1
    c1.disconnect();
    sig();  // i == 1

    // 基于作用域的断开连接
    {
        sigslot::scoped_connection sc = sig.connect(f);
        sig();  // i == 2
    }

    sig();  // i == 2;


    // 连接阻塞
    auto c2 = sig.connect(f);
    sig();  // i == 3
    c2.block();
    sig();  // i == 3
    c2.unblock();
    sig();  // i == 4
}
```

#### 扩展连接签名

Sigslot 支持带有额外的 `sigslot::connection` 引用作为第一个参数的扩展槽签名，这允许从槽内部管理连接。可以使用 `connect_extended()` 方法访问这个扩展签名。

```cpp
#include <sigslot/signal.hpp>

int main() {
    int i = 0;
    sigslot::signal<> sig;

    // 扩展连接
    auto f = [](auto &con) {
        i += 1;             // 做工作
        con.disconnect();   // 然后断开连接
    };

    sig.connect_extended(f);
    sig();  // i == 1
    sig();  // i == 1 因为 f 被断开了
}
```

#### 自动槽生命周期跟踪

用户必须确保槽的生命周期超过信号的生命周期，这在复杂的软件中可能很麻烦。为了简化这个任务，Sigslot 可以自动断开它能够跟踪其生命周期的槽对象。为此，槽必须可以转换为某种形式的弱指针。

`std::shared_ptr` 和 `std::weak_ptr` 是开箱即用的，并且提供了适配器来支持 `boost::shared_ptr`、`boost::weak_ptr` 和 Qt 的 `QSharedPointer`、`QWeakPointer` 以及任何从 `QObject` 派生的类。

可以通过声明 `to_weak()` 适配器函数来添加其他可跟踪对象。

```cpp
#include <sigslot/signal.hpp>
#include <sigslot/adapter/qt.hpp>

int sum = 0;

struct s {
    void f(int i) { sum += i; }
};

class MyObject : public QObject {
    Q_OBJECT
public:
    void add(int i) const { sum += i; }
};

int main() {
    sum = 0;
    signal<int> sig;

    // 跟踪对象的生命周期并连接到成员函数
    auto p = std::make_shared<s>();
    sig.connect(&s::f, p);

    sig(1);     // sum == 1
    p.reset();
    sig(1);     // sum == 1

    // 跟踪无关对象的生命周期
    struct dummy;
    auto l = [&](int i) { sum += i; };

    auto d = std::make_shared<dummy>();
    sig.connect(l, d);
    sig(1);     // sum == 2
    d.reset();
    sig(1);     // sum == 2

    // 跟踪 QObject
    {
        MyObject o;
        sig.connect(&MyObject::add, &o);

        sig(1); // sum == 3
    }

    sig(1);     // sum == 3
}
```

#### 侵入式槽生命周期跟踪

确保自动断开成员函数指针槽的另一种方法是显式地从 `sigslot::observer` 或 `sigslot::observer_st` 继承。前者是线程安全的，后者不是。

这里是一个示例用法。

```cpp
#include <sigslot/signal.hpp>

int sum = 0;

struct s : sigslot::observer_st {
    void f(int i) { sum += i; }
};

struct s_mt : sigslot::observer {
    ~s_mt() {
        // 需要在多线程上下文中确保在对象销毁之前正确断开连接
        this->disconnect_all();
    }

    void f(int i) { sum += i; }
};

int main() {
    sum = 0;
    signal<int> sig;

    {
        // 跟踪对象实例 p 的生命周期
        s p;
        s_mt pm;
        sig.connect(&s::f, &p);
        sig.connect(&s_mt::f, &pm);
        sig(1);     // sum == 2
    }

    // 槽在实例销毁时被断开
    sig(1);         // sum == 2
}
```

使用这种侵入式方法的对象可以连接到任意数量的不相关信号。

### 无需连接对象的断开连接

从 1.2.0 版本开始，支持通过提供适当的函数签名、对象指针或跟踪器来断开槽。

可以使用 `signal::disconnect()` 方法断开任意数量的槽，该方法提供 4 个重载来指定断开连接标准：

- 第一个接受可调用对象的引用。可以传递任何类型的可调用对象，甚至成员函数指针、函数对象和 lambda，
- 第二个接受对象指针，用于绑定到成员函数指针的槽，或跟踪对象，
- 第三个重载同时接受这两种参数，可用于精确定位特定的对象 + 可调用对象对。
- 最后一个重载接受组 id 并断开该组中的所有槽。

由于 lambda 的唯一性，lambda 的断开连接仅适用于绑定到变量的 lambda。

目前第二个重载需要 RTTI 来从成员函数指针、函数对象和 lambda 断开连接。这个限制不适用于自由函数和静态成员函数。原因是在 C++ 中，不相关类型的成员函数指针是不可比较的，与自由函数和静态成员函数指针相反。例如，不同类的虚方法的成员函数指针可以具有相同的地址（它们有点存储方法在 vtable 中的偏移量）。

但是，Sigslot 可以在禁用 RTTI 的情况下编译，并且对于有问题的情况，重载将被停用。

顺便说一句，这个功能显然比最初预期的增加了更多的代码，因为它很棘手且容易出错。它是经过精心设计的，以正确性为出发点，除非你实际使用它，否则没有任何隐藏成本。

这里是一个演示功能的示例。

```cpp
#include <sigslot/signal.hpp>
#include <string>

static int i = 0;

void f1() { i += 1; }
void f2() { i += 1; }

struct s {
    void m1() { i += 1; }
    void m2() { i += 1; }
    void m3() { i += 1; }
};

struct o {
    void operator()() { i += 1; }
};

int main() {
    sigslot::signal<> sig;
    s s1;
    auto s2 = std::make_shared<s>();

    auto lbd = [&] { i += 1; };

    sig.connect(f1);           // #1
    sig.connect(f2);           // #2
    sig.connect(&s::m1, &s1);  // #3
    sig.connect(&s::m2, &s1);  // #4
    sig.connect(&s::m3, &s1);  // #5
    sig.connect(&s::m1, s2);   // #6
    sig.connect(&s::m2, s2);   // #7
    sig.connect(o{});          // #8
    sig.connect(lbd);          // #9

    sig();  // i == 9

    sig.disconnect(f2);              // #2 被移除
    sig.disconnect(&s::m1);          // #3 和 #6 被移除
    sig.disconnect(o{});             // #8 被移除
 // sig.disconnect(&o::operator());  // 与上面相同，更高效
    sig.disconnect(lbd);             // #9 被移除
    sig.disconnect(s2);              // #7 被移除
    sig.disconnect(&s::m3, &s1);     // #5 被移除，不是 #4

    sig();  // i == 11

    sig.disconnect_all();         // 移除所有剩余的槽
    return 0;
}
```

### 使用槽组强制执行槽调用顺序

从 1.2.0 版本开始，可以为槽分配组 id 以控制槽的相对调用顺序。

同一组内槽的调用顺序是未指定的，不应依赖，但是槽组按升序组 id 顺序调用。
当槽的组 id 未设置时，它被分配给组 0。
组 id 可以在有符号 32 位整数的任何值范围内。

```cpp
#include <sigslot/signal.hpp>
#include <cstdio>
#include <limits>

int main() {
    sigslot::signal<> sig;

    // 只需将组 id 作为最后一个参数分配给 connect
    sig.connect([] { std::puts("Second"); }, 1);
    sig.connect([] { std::puts("Last"); }, std::numeric_limits<sigslot::group_id>::max());
    sig.connect([] { std::puts("First"); }, -10);
    sig();

    return 0;
}
```

### 信号链

可以使用独立的 `sigslot::connect()` 函数将信号连接到另一个具有兼容参数的信号。

```cpp
#include <sigslot/signal.hpp>
#include <iostream>

int main() {
    sigslot::signal<int> sig1;
    sigslot::signal<double> sig2;

    sigslot::connect(sig1, sig2);
    sigslot::connect(sig2, [] (double d) { std::cout << "got " << d << std::endl; });
    sig(1);

    return 0;
}
```

### 线程安全

线程安全已经过单元测试。特别是，跨信号发射和递归发射在多线程场景中运行良好。

`sigslot::signal` 是更通用的 `sigslot::signal_base` 模板类的 typedef，其第一个模板参数必须是 Lockable 类型。此类型将决定类的锁定策略。

Sigslot 提供 2 个 typedef，

- `sigslot::signal` 可从多个线程使用，并使用 std::mutex 作为可锁定对象。
  特别是，连接、断开连接、发射和槽执行是线程安全的。它在递归信号发射方面也是安全的。
- `sigslot::signal_st` 是一个非线程安全的替代方案，它以安全性为代价换取稍微更快的操作。


## 实现细节

### 使用函数指针断开槽

在 C++ 中比较函数指针是一场噩梦。这里是一个表格，展示了各种情况的大小和地址，作为展示：

```cpp
void fun() {}

struct b1 {
    virtual ~b1() = default;
    static void sm() {}
    void m() {}
    virtual void vm() {}
};

struct b2 {
    virtual ~b2() = default;
    static void sm() {}
    void m() {}
    virtual void vm() {}
};

struct c {
    virtual ~c() = default;
    virtual void w() {}
};

struct d : b1 {
    static void sm() {}
    void m() {}
