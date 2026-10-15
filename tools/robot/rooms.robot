*** Settings ***
Resource         game.resource
Test Setup       Start Journey
Test Teardown    Finish Journey

*** Test Cases ***
First-entry grass and door fades without pause
    ${started}=    Advance Ticks    1    ENTER    capture=first-entry.png
    Should Be Equal    ${started}[room]    demo
    Should Be Equal    ${started}[render][fade_alpha]    ${0}
    Should Be Equal    ${started}[scene]    Gameplay
    Should Be True    $started['render']['grass_vertices'] > 0
    ${fading}=    Advance Ticks    8    W    D
    Should Be True    $fading['render']['fade_alpha'] > 0
    ${inside}=    Advance Ticks    45    capture=small-room.png
    Should Be Equal    ${inside}[room]    small_room
    Should Be Equal    ${inside}[render][fade_alpha]    ${0}
    Should Be Equal    ${inside}[scene]    Gameplay
    Should Not Be Empty    ${inside}[presentation][area_title][text]
    Should Be True    $inside['presentation']['area_title']['alpha'] > 0
    ${idle}=    Observe Game
    Should Be Equal    ${inside}    ${idle}
    Advance Ticks    1
    Advance Ticks    8    A    S
    ${returned}=    Advance Ticks    45    capture=returned.png
    Should Be Equal    ${returned}[room]    demo
    Should Be Equal    ${returned}[render][fade_alpha]    ${0}
    Should Be Equal    ${returned}[scene]    Gameplay
    Should Be True    $returned['render']['grass_vertices'] > 0
    Should Be True    $returned['presentation']['area_title']['alpha'] > 0
    ${visible}=    Advance Ticks    30    capture=area-title.png
    Should Be Equal As Numbers    ${visible}[presentation][area_title][alpha]    1
    Advance Ticks    1    P
    ${paused}=    Advance Ticks    240
    Should Be Equal As Numbers    ${paused}[presentation][area_title][alpha]    0
    ${resumed}=    Advance Ticks    1    ENTER
    Should Be Equal As Numbers    ${resumed}[presentation][area_title][alpha]    1
    ${expired}=    Advance Ticks    240    capture=area-title-expired.png
    Should Be Equal As Numbers    ${expired}[presentation][area_title][alpha]    0
