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

Controller operates the complete tree study
    Press Gamepad For Ticks    1    Player_1    LEFT_FACE_DOWN
    Advance Ticks    1
    Press Gamepad For Ticks    1    Player_1    LEFT_FACE_DOWN
    Advance Ticks    1
    Press Gamepad For Ticks    1    Player_1    LEFT_FACE_DOWN
    Advance Ticks    1
    ${day}=    Press Gamepad For Ticks    1    Player_1    RIGHT_FACE_DOWN    capture=pad-day.png
    Should Be Equal    ${day}[scene]    Tree_Study
    ${drift}=    Move Stick For Ticks    30    0.1    0
    Should Be Equal As Numbers    ${drift}[presentation][tree_study][yaw]    0
    ${orbit}=    Move Stick For Ticks    30    0.5    0    capture=pad-orbit.png
    Should Be True    0.1 < $orbit['presentation']['tree_study']['yaw'] < 0.4
    ${held}=    Move Stick For Ticks    30    0.5    0
    Should Be Equal As Numbers    ${held}[presentation][tree_study][yaw]    ${{ $orbit['presentation']['tree_study']['yaw'] * 2 }}    precision=5
    ${reset}=    Press Gamepad For Ticks    1    Player_1    RIGHT_FACE_UP    capture=pad-reset.png
    Should Be Equal As Numbers    ${reset}[presentation][tree_study][yaw]    0
    Images Should Match    pad-day.png    pad-reset.png
    ${turned}=    Press Gamepad For Ticks    1    Player_1    RIGHT_FACE_LEFT    capture=pad-sun.png
    Should Be True    $turned['presentation']['tree_study']['sun_turn'] > 0.7
    ${held}=    Press Gamepad For Ticks    20    Player_1    RIGHT_FACE_LEFT
    Should Be Equal As Numbers    ${held}[presentation][tree_study][sun_turn]    ${turned}[presentation][tree_study][sun_turn]
    FOR    ${preset}    IN    Reverse    Dim    Sunset    Moonlight    Lantern    Darkness    Ambient    Daylight
        Advance Ticks    1
        ${light}=    Press Gamepad For Ticks    1    Player_1    RIGHT_TRIGGER_1
        Should Be Equal    ${light}[presentation][tree_study][preset]    ${preset}
        Should Be Equal As Numbers    ${light}[presentation][tree_study][sun_turn]    0
    END
    ${previous}=    Press Gamepad For Ticks    1    Player_1    LEFT_TRIGGER_1
    Should Be Equal    ${previous}[presentation][tree_study][preset]    Ambient
    ${dpad}=    Press Gamepad For Ticks    30    Player_1    LEFT_FACE_LEFT
    Should Be True    $dpad['presentation']['tree_study']['yaw'] < -0.3
    ${title}=    Press Gamepad For Ticks    1    Player_1    RIGHT_FACE_RIGHT
    Should Be Equal    ${title}[scene]    Title
    FOR    ${index}    IN RANGE    3
        Advance Ticks    1
        Press Gamepad For Ticks    1    Player_1    LEFT_FACE_DOWN
    END
    Advance Ticks    1
    ${study}=    Press Gamepad For Ticks    1    Player_1    RIGHT_FACE_DOWN
    Should Be Equal    ${study}[scene]    Tree_Study
    ${title}=    Press Gamepad For Ticks    1    Player_1    MIDDLE_RIGHT
    Should Be Equal    ${title}[scene]    Title
