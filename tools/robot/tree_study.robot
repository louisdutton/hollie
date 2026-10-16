*** Settings ***
Resource         game.resource
Test Setup       Start Journey
Test Teardown    Finish Journey

*** Variables ***
${GAME_RENDER_SIZE}    1280x720

*** Test Cases ***
One tree responds to world sun, ambient and local lighting
    ${day}=    Enter Tree Study    tree-day.png
    Should Be Equal    ${day}[scene]    Tree_Study
    Should Be Equal As Numbers    ${day}[presentation][tree_study][trees]    1
    Should Not Be True    ${day}[presentation][volumetric_lighting]
    ${day_mean}=    Image Region Mean    tree-day.png    600    220    160    180
    Press Gamepad For Ticks    1    RIGHT_FACE_LEFT    capture=tree-sun-turned.png
    Run Keyword And Expect Error    *pixels differ*    Images Should Match    tree-day.png    tree-sun-turned.png
    ${reverse}=    Next Study Light    tree-reverse.png
    ${reverse_mean}=    Image Region Mean    tree-reverse.png    600    220    160    180
    Should Be True    abs($reverse_mean['luminance'] - $day_mean['luminance']) > 0.005
    Next Study Light    tree-dim.png
    ${dim}=    Image Region Mean    tree-dim.png    600    220    160    180
    Should Be True    $dim['luminance'] < $day_mean['luminance'] * 0.8
    Next Study Light    tree-sunset.png
    ${warm}=    Image Region Mean    tree-sunset.png    600    220    160    180
    Next Study Light    tree-moon.png
    ${cool}=    Image Region Mean    tree-moon.png    600    220    160    180
    Should Be True    $cool['blue'] / max($cool['red'], 0.001) > $warm['blue'] / max($warm['red'], 0.001) * 1.5
    ${lamp}=    Next Study Light    tree-lantern.png
    Should Be True    ${lamp}[presentation][tree_study][lamp] > 0
    ${local}=    Image Region Mean    tree-lantern.png    600    220    160    180
    Should Be True    $local['luminance'] > 0.005
    ${black}=    Next Study Light    tree-black.png
    Should Be Equal As Numbers    ${black}[presentation][tree_study][sun]    0
    Should Be Equal As Numbers    ${black}[presentation][tree_study][ambient]    0
    Should Be Equal As Numbers    ${black}[presentation][tree_study][lamp]    0
    ${dark}=    Image Region Mean    tree-black.png    600    220    160    180
    Should Be True    $dark['luminance'] < $day_mean['luminance'] * 0.1
    Next Study Light    tree-ambient.png
    ${ambient}=    Image Region Mean    tree-ambient.png    600    220    160    180
    Should Be True    $ambient['luminance'] > $dark['luminance'] + 0.005
    Next Study Light    tree-day-restored.png
    Images Should Match    tree-day.png    tree-day-restored.png
    Observe Game    capture=tree-frozen.png
    Images Should Match    tree-day-restored.png    tree-frozen.png
    ${front_width}=    Foliage Width    tree-day.png
    ${side}=    Move Stick For Ticks    118    1    0    capture=tree-quarter.png
    ${side_width}=    Foliage Width    tree-quarter.png
    Move Stick For Ticks    118    1    0    capture=tree-back.png
    ${back_width}=    Foliage Width    tree-back.png
    Move Stick For Ticks    118    1    0    capture=tree-three-quarters.png
    ${other_width}=    Foliage Width    tree-three-quarters.png
    Should Be True    min($front_width, $side_width, $back_width, $other_width) / max($front_width, $side_width, $back_width, $other_width) > 0.75
    ${title}=    Press Gamepad For Ticks    1    RIGHT_FACE_RIGHT    capture=tree-exit.png
    Should Be Equal    ${title}[scene]    Title
    Should Be Equal As Numbers    ${title}[presentation][tree_study][trees]    0
    Should Be True    ${title}[presentation][volumetric_lighting]

Controller operates the complete tree study
    ${day}=    Enter Tree Study    pad-day.png
    Should Be Equal    ${day}[scene]    Tree_Study
    ${drift}=    Move Stick For Ticks    30    0.1    0
    Should Be Equal As Numbers    ${drift}[presentation][tree_study][yaw]    0
    ${orbit}=    Move Stick For Ticks    30    0.5    0    capture=pad-orbit.png
    Should Be True    0.1 < $orbit['presentation']['tree_study']['yaw'] < 0.4
    ${held}=    Move Stick For Ticks    30    0.5    0
    Should Be Equal As Numbers    ${held}[presentation][tree_study][yaw]    ${{ $orbit['presentation']['tree_study']['yaw'] * 2 }}    precision=5
    ${reset}=    Press Gamepad For Ticks    1    RIGHT_FACE_DOWN    capture=pad-reset.png
    Should Be Equal As Numbers    ${reset}[presentation][tree_study][yaw]    0
    Images Should Match    pad-day.png    pad-reset.png
    ${turned}=    Press Gamepad For Ticks    1    RIGHT_FACE_LEFT    capture=pad-sun.png
    Should Be True    $turned['presentation']['tree_study']['sun_turn'] > 0.7
    ${held}=    Press Gamepad For Ticks    20    RIGHT_FACE_LEFT
    Should Be Equal As Numbers    ${held}[presentation][tree_study][sun_turn]    ${turned}[presentation][tree_study][sun_turn]
    FOR    ${preset}    IN    Reverse    Dim    Sunset    Moonlight    Lantern    Darkness    Ambient    Daylight
        Advance Ticks    1
        ${light}=    Press Gamepad For Ticks    1    RIGHT_TRIGGER_1
        Should Be Equal    ${light}[presentation][tree_study][preset]    ${preset}
        Should Be Equal As Numbers    ${light}[presentation][tree_study][sun_turn]    0
    END
    ${previous}=    Press Gamepad For Ticks    1    LEFT_TRIGGER_1
    Should Be Equal    ${previous}[presentation][tree_study][preset]    Ambient
    ${ignored}=    Advance Ticks    30    RIGHT    L    D    ESCAPE    HOME
    Should Be Equal    ${ignored}[scene]    Tree_Study
    Should Be Equal As Numbers    ${ignored}[presentation][tree_study][yaw]    0
    Should Be Equal    ${ignored}[presentation][tree_study][preset]    Ambient
    ${title}=    Press Gamepad For Ticks    1    RIGHT_FACE_RIGHT
    Should Be Equal    ${title}[scene]    Title
    ${study}=    Enter Tree Study
    ${title}=    Press Gamepad For Ticks    1    MIDDLE_RIGHT
    Should Be Equal    ${title}[scene]    Title

Tree parameters rebuild the specimen and persist between visits
    ${initial}=    Enter Tree Study    editor-initial.png
    Should Be Equal    ${initial}[presentation][tree_study][parameters][layout]    Joined_Crown
    ${initial_pixels}=    Image Region Signature    editor-initial.png    360    90    600    600
    ${old}=    Press Gamepad For Ticks    1    LEFT_FACE_LEFT    capture=editor-leafy.png
    Should Be Equal    ${old}[presentation][tree_study][parameters][layout]    Leafy_Tiers
    Advance Ticks    1
    ${old}=    Press Gamepad For Ticks    1    LEFT_FACE_LEFT    capture=editor-rounded.png
    Should Be Equal    ${old}[presentation][tree_study][parameters][layout]    Rounded_Tiers
    Press Gamepad For Ticks    1    RIGHT_FACE_UP    capture=editor-restored.png
    Images Should Match    editor-initial.png    editor-restored.png
    Press Gamepad For Ticks    1    LEFT_FACE_DOWN
    ${wide}=    Press Gamepad For Ticks    30    LEFT_FACE_RIGHT    capture=editor-width.png
    Should Be True    $wide['presentation']['tree_study']['parameters']['width'] > 1.05
    ${wide_pixels}=    Foliage Width    editor-width.png
    ${original_pixels}=    Foliage Width    editor-initial.png
    Should Be True    $wide_pixels > $original_pixels * 1.04
    Press Gamepad For Ticks    1    RIGHT_FACE_RIGHT
    ${returned}=    Enter Tree Study
    Should Be Equal    ${wide}[presentation][tree_study][parameters]    ${returned}[presentation][tree_study][parameters]
    Press Gamepad For Ticks    1    RIGHT_FACE_UP
    FOR    ${row}    IN RANGE    2    10
        Advance Ticks    1
        ${selected}=    Press Gamepad For Ticks    1    LEFT_FACE_DOWN
        Should Be Equal As Numbers    ${selected}[presentation][tree_study][selected]    ${row}
        ${before}=    Observe Game
        Press Gamepad For Ticks    1    LEFT_FACE_RIGHT    capture=editor-field-${row}.png
        ${pixels}=    Image Region Signature    editor-field-${row}.png    360    90    600    600
        Should Not Be Equal    ${pixels}    ${initial_pixels}
        ${changed}=    Observe Game
        Should Not Be Equal    ${before}[presentation][tree_study][parameters]    ${changed}[presentation][tree_study][parameters]
        ${restored}=    Press Gamepad For Ticks    1    RIGHT_FACE_UP    capture=editor-reset-${row}.png
        ${pixels}=    Image Region Signature    editor-reset-${row}.png    360    90    600    600
        Should Be Equal    ${pixels}    ${initial_pixels}
        Should Be Equal    ${before}[presentation][tree_study][parameters]    ${restored}[presentation][tree_study][parameters]
    END
    Press Gamepad For Ticks    1    RIGHT_FACE_RIGHT

*** Keywords ***
Enter Tree Study
    [Arguments]    ${capture}=${EMPTY}
    FOR    ${index}    IN RANGE    2
        Advance Ticks    1
        Press Gamepad For Ticks    1    LEFT_FACE_DOWN
    END
    Advance Ticks    1
    ${state}=    Press Gamepad For Ticks    1    RIGHT_FACE_DOWN    capture=${capture}
    Should Be Equal    ${state}[scene]    Tree_Study
    RETURN    ${state}

Next Study Light
    [Arguments]    ${capture}
    Advance Ticks    1
    ${state}=    Press Gamepad For Ticks    1    RIGHT_TRIGGER_1    capture=${capture}
    RETURN    ${state}
