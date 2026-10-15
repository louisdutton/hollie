*** Settings ***
Resource         game.resource
Test Setup       Start Journey
Test Teardown    Finish Journey

*** Test Cases ***
Move, freeze, reset, and replay
    ${initial}=    Reset Game    room=demo    players=1    seed=42    capture=initial.png
    Sleep    0.5s
    ${idle}=    Observe Game
    Should Be Equal    ${initial}    ${idle}
    ${moved}=    Advance Ticks    30    S    capture=moved.png
    Should Not Be Equal    ${initial}[players][0][body][position]    ${moved}[players][0][body][position]
    Should Be Equal    ${{ $moved['frame'] - $initial['frame'] }}    ${30}
    Sleep    0.5s
    ${held_idle}=    Observe Game
    Should Be Equal    ${moved}    ${held_idle}
    Advance Ticks    0    expected_error=frames must be between 1 and 600
    Reset Game    room=does_not_exist    expected_error=unknown room
    ${after_errors}=    Observe Game
    Should Be Equal    ${moved}    ${after_errors}
    ${reset}=    Reset Game    room=demo    players=1    seed=42
    Should Be Equal    ${initial}    ${reset}
    ${replayed}=    Advance Ticks    30    S    capture=replayed.png
    Should Be Equal    ${moved}    ${replayed}
    Images Should Match    moved.png    replayed.png
