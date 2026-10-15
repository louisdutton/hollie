*** Settings ***
Resource         game.resource
Test Teardown    Save Journey Evidence

*** Test Cases ***
Pause, editor paint and undo, frozen state, discard and reset
    ${started}=    Advance Ticks    1    ENTER    capture=first-entry.png
    Should Be Equal    ${started}[scene]    Gameplay
    Should Be Equal    ${started}[room]    demo
    ${initial}=    Reset Game
    ${paused}=    Advance Ticks    1    P    capture=paused.png
    Should Be Equal    ${paused}[scene]    Paused
    ${still_paused}=    Advance Ticks    30    D
    Should Be Equal    ${still_paused}[scene]    Paused
    Should Be Equal    ${paused}[players]    ${still_paused}[players]
    ${resumed}=    Advance Ticks    1    ENTER
    Should Be Equal    ${resumed}[scene]    Gameplay
    ${editor}=    Advance Ticks    1    F1    capture=editor.png
    Should Be Equal    ${editor}[scene]    Editor
    Advance Ticks    1    RIGHT
    ${painted}=    Advance Ticks    1    SPACE    capture=painted.png
    Should Be Equal    ${painted}[editor][dirty]    ${True}
    Sleep    0.5s
    ${idle}=    Observe Game
    Should Be Equal    ${painted}    ${idle}
    ${undone}=    Advance Ticks    1    LEFT_CONTROL    Z
    Should Be Equal    ${editor}[editor][base]    ${undone}[editor][base]
    ${exit}=    Advance Ticks    1    F1
    Should Be Equal    ${exit}[scene]    Gameplay
    ${reset}=    Reset Game
    Should Be Equal    ${initial}    ${reset}
