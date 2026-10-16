*** Settings ***
Resource         game.resource
Test Setup       Start Journey
Test Teardown    Finish Journey

*** Variables ***
@{full_speed_axes}    ${0}    ${1}
&{first_player}    axes=${full_speed_axes}
@{gamepad}    ${first_player}

*** Test Cases ***
Single-player analog input and replay
    ${initial}=    Reset Game    room=demo    seed=84
    ${moved}=    Advance Ticks    30    gamepads=${gamepad}    capture=moved.png
    Should Not Be Equal    ${initial}[players][0][body][position]    ${moved}[players][0][body][position]
    Length Should Be    ${initial}[players]    1
    Length Should Be    ${moved}[players]    1
    Should Be Equal    ${{ $moved['frame'] - $initial['frame'] }}    ${30}
    Move Stick For Ticks    1    0    2    expected_error=invalid input state
    ${after_error}=    Observe Game
    Should Be Equal    ${moved}    ${after_error}
    ${reset}=    Reset Game    room=demo    seed=84
    Should Be Equal    ${initial}    ${reset}
    ${replayed}=    Advance Ticks    30    gamepads=${gamepad}    capture=replayed.png
    Should Be Equal    ${moved}    ${replayed}
    Images Should Match    moved.png    replayed.png
    ${single}=    Reset Game    room=demo
    ${ignored}=    Advance Ticks    30    RIGHT    SEMICOLON    L
    Length Should Be    ${ignored}[players]    1
    Should Be Equal    ${single}[players][0][body][position]    ${ignored}[players][0][body][position]
    Should Be Equal    ${ignored}[players][0][body][height]    ${0.0}
