*** Settings ***
Resource         game.resource
Test Setup       Start Journey
Test Teardown    Finish Journey

*** Test Cases ***
Title and gameplay fill the requested render extent
    ${title}=    Observe Game    capture=title.png
    Should Be True    $title['presentation']['title_grass_vertices'] > 0
    Should Be True    ${title}[presentation][volumetric_lighting]
    ${animated}=    Advance Ticks    120    capture=title-animated.png
    Should Be True    $animated['presentation']['title_elapsed'] > $title['presentation']['title_elapsed'] + 1.9
    Run Keyword And Expect Error    *pixels differ*    Images Should Match    title.png    title-animated.png
    ${observed}=    Observe Game    capture=title-observed.png
    Should Be Equal    ${animated}    ${observed}
    Images Should Match    title-animated.png    title-observed.png
    ${gameplay}=    Reset Game    capture=gameplay.png
    Should Not Be True    ${gameplay}[presentation][volumetric_lighting]
    Image Dimensions Should Be    title.png    ${SESSION}[width]    ${SESSION}[height]
    Image Dimensions Should Be    gameplay.png    ${SESSION}[width]    ${SESSION}[height]
    Advance Ticks    1    P
    Advance Ticks    1    DOWN
    Advance Ticks    1
    Advance Ticks    1    DOWN
    Advance Ticks    1    ENTER    capture=return-title.png
    ${returned}=    Advance Ticks    120    capture=return-title-animated.png
    Should Be Equal    ${returned}[scene]    Title
    Should Be True    ${returned}[presentation][volumetric_lighting]
    Should Be Equal    ${returned}[presentation][area_title][alpha]    ${0}
    ${new_game}=    Advance Ticks    1    ENTER
    Should Be Equal    ${new_game}[scene]    Gameplay
    Length Should Be    ${new_game}[players]    1
