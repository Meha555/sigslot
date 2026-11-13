#include <sigslot/signal.hpp>
#include <iostream>

int main()
{
    sigslot::signal<> sig1, sig2, sig3;
    sigslot::connect(sig1, sig2);
    sigslot::connect(sig2, sig3);

    sig1.connect([]() { std::cout << "First" << std::endl; });
    sig2.connect([]() { std::cout << "Second" << std::endl; });
    sig3.connect([]() { std::cout << "Third" << std::endl; });

    sig1();
    
    return 0;
}