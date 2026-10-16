*** Settings ***
Resource         game.resource
Test Setup       Start Journey
Test Teardown    Finish Journey

*** Variables ***
${GAME_RENDER_SIZE}    1280x720

*** Test Cases ***
One tree responds to world sun, ambient and local lighting
    Advance Ticks    1    DOWN
    Advance Ticks    1
    Advance Ticks    1    DOWN
    Advance Ticks    1
    Advance Ticks    1    DOWN
    ${day}=    Advance Ticks    1    ENTER    capture=tree-day.png
    Should Be Equal    ${day}[scene]    Tree_Study
    Should Be Equal As Numbers    ${day}[presentation][tree_study][trees]    1
    Should Not Be True    ${day}[presentation][volumetric_lighting]
    ${day_mean}=    Image Region Mean    tree-day.png    600    220    160    180
    Advance Ticks    1    L    capture=tree-sun-turned.png
    Run Keyword And Expect Error    *pixels differ*    Images Should Match    tree-day.png    tree-sun-turned.png
    Advance Ticks    1    D
    ${reverse}=    Advance Ticks    1    R    capture=tree-reverse.png
    ${reverse_mean}=    Image Region Mean    tree-reverse.png    600    220    160    180
    Should Be True    abs($reverse_mean['luminance'] - $day_mean['luminance']) > 0.005
    Advance Ticks    1    F    capture=tree-dim.png
    ${dim}=    Image Region Mean    tree-dim.png    600    220    160    180
    Should Be True    $dim['luminance'] < $day_mean['luminance'] * 0.8
    Advance Ticks    1    E    capture=tree-sunset.png
    ${warm}=    Image Region Mean    tree-sunset.png    600    220    160    180
    Advance Ticks    1    N    capture=tree-moon.png
    ${cool}=    Image Region Mean    tree-moon.png    600    220    160    180
    Should Be True    $cool['blue'] / max($cool['red'], 0.001) > $warm['blue'] / max($warm['red'], 0.001) * 1.5
    ${black}=    Advance Ticks    1    B    capture=tree-black.png
    Should Be Equal As Numbers    ${black}[presentation][tree_study][sun]    0
    Should Be Equal As Numbers    ${black}[presentation][tree_study][ambient]    0
    Should Be Equal As Numbers    ${black}[presentation][tree_study][lamp]    0
    ${dark}=    Image Region Mean    tree-black.png    600    220    160    180
    Should Be True    $dark['luminance'] < $day_mean['luminance'] * 0.1
    Advance Ticks    1    A    capture=tree-ambient.png
    ${ambient}=    Image Region Mean    tree-ambient.png    600    220    160    180
    Should Be True    $ambient['luminance'] > $dark['luminance'] + 0.005
    ${lamp}=    Advance Ticks    1    P    capture=tree-lantern.png
    Should Be True    ${lamp}[presentation][tree_study][lamp] > 0
    ${local}=    Image Region Mean    tree-lantern.png    600    220    160    180
    Should Be True    $local['luminance'] > $dark['luminance'] + 0.005
    Advance Ticks    1    D    capture=tree-day-restored.png
    Images Should Match    tree-day.png    tree-day-restored.png
    Observe Game    capture=tree-frozen.png
    Images Should Match    tree-day-restored.png    tree-frozen.png
    Advance Ticks    45    RIGHT    capture=tree-orbit.png
    ${title}=    Advance Ticks    1    ESCAPE    capture=tree-exit.png
    Should Be Equal    ${title}[scene]    Title
    Should Be Equal As Numbers    ${title}[presentation][tree_study][trees]    0
    Should Be True    ${title}[presentation][volumetric_lighting]
