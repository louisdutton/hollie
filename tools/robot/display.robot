*** Settings ***
Resource         game.resource
Test Setup       Start Journey
Test Teardown    Finish Journey

*** Variables ***
${GAME_BACKEND}         gamescope
${GAME_DISPLAY_SIZE}    3840x2160

*** Test Cases ***
Gamescope native 4K render and fullscreen windowed round-trip
    ${title}=    Observe Game    capture=title-4k.png
    Should Be Equal As Numbers    ${title}[presentation][ui_scale]    3
    ${game}=    Reset Game    capture=native-4k.png
    Should Be Equal As Numbers    ${game}[presentation][ui_scale]    3
    Image Dimensions Should Be    native-4k.png    3840    2160
    Advance Ticks    1    F3    capture=dimensions.png
    Image Dimensions Should Be    dimensions.png    3840    2160
    Advance Ticks    1    P
    Advance Ticks    1    DOWN
    Advance Ticks    1    ENTER
    Advance Ticks    1    DOWN
    Advance Ticks    1    ENTER
    Advance Ticks    1
    ${windowed}=    Advance Ticks    1    ENTER    capture=windowed.png
    Should Be Equal As Numbers    ${windowed}[presentation][ui_scale]    1
    Image Dimensions Should Be    windowed.png    1280    720
    Advance Ticks    1
    ${fullscreen}=    Advance Ticks    1    ENTER    capture=fullscreen-restored.png
    Should Be Equal As Numbers    ${fullscreen}[presentation][ui_scale]    3
    Image Dimensions Should Be    fullscreen-restored.png    3840    2160
