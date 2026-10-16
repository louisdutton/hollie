*** Settings ***
Resource         game.resource
Test Setup       Start Journey
Test Teardown    Finish Journey

*** Test Cases ***
Title and gameplay fill the requested render extent
    ${title}=    Observe Game    capture=title.png
    Should Be True    $title['presentation']['title_grass_vertices'] > 0
    Should Be True    ${title}[presentation][volumetric_lighting]
    Scene Should Be Revealed    ${title}
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
    Scene Should Be Revealed    ${new_game}

Scene reveal visibly fades from black
    Advance Ticks    1    ENTER    capture=reveal.png    fade_captures=${True}
    Reveal Should Blend From Black    reveal
    Advance Ticks    1    P
    Advance Ticks    1    DOWN
    Advance Ticks    1
    Advance Ticks    1    DOWN
    ${title}=    Advance Ticks    1    ENTER    capture=title-reveal.png    fade_captures=${True}
    Should Be Equal    ${title}[scene]    Title
    Reveal Should Blend From Black    title-reveal

*** Keywords ***
Scene Should Be Revealed
    [Arguments]    ${state}
    Should Be Equal    ${state}[presentation][scene_transition][phase]    Visible
    Should Be Equal As Numbers    ${state}[presentation][scene_transition][alpha]    0
    Should Be True    ${state}[presentation][scene_transition][renderer_ready]
    Should Be True    $state['presentation']['scene_transition']['confirmations'] >= 5

Reveal Should Blend From Black
    [Arguments]    ${prefix}
    ${covered}=    Image Region Mean    ${prefix}-covered.png    0    0    640    360
    ${half}=    Image Region Mean    ${prefix}-half.png    0    0    640    360
    ${visible}=    Image Region Mean    ${prefix}-visible.png    0    0    640    360
    Should Be True    $covered['luminance'] < 0.001
    Should Be True    $visible['luminance'] > 0.05
    Should Be True    $visible['luminance'] * 0.1 < $half['luminance'] < $visible['luminance'] * 0.9
