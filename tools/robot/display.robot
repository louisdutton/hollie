*** Settings ***
Resource         game.resource
Test Teardown    Save Journey Evidence

*** Test Cases ***
Gamescope native 4K render and fullscreen windowed round-trip
    Reset Game    capture=native-4k.png
    Image Dimensions Should Be    native-4k.png    3840    2160
    Advance Ticks    1    F3    capture=dimensions.png
    Image Dimensions Should Be    dimensions.png    3840    2160
    Advance Ticks    1    P
    Advance Ticks    1    DOWN
    Advance Ticks    1    ENTER
    Advance Ticks    1    DOWN
    Advance Ticks    1    ENTER
    Advance Ticks    1
    Advance Ticks    1    ENTER    capture=windowed.png
    Image Dimensions Should Be    windowed.png    1280    720
    Advance Ticks    1
    Advance Ticks    1    ENTER    capture=fullscreen-restored.png
    Image Dimensions Should Be    fullscreen-restored.png    3840    2160
