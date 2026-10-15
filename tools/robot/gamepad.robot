*** Settings ***
Resource         game.resource
Test Setup       Start Journey
Test Teardown    Finish Journey

*** Variables ***
@{full_speed_axes}    ${0}    ${1}
&{first_player}    player=Player_1    axes=${full_speed_axes}
@{half_speed_axes}    ${0}    ${0.5}
&{second_player}    player=Player_2    axes=${half_speed_axes}
@{both_players}    ${first_player}    ${second_player}

*** Test Cases ***
Two-player analog input and replay
    ${initial}=    Reset Game    room=demo    players=2    seed=84
    ${moved}=    Advance Ticks    30    gamepads=${both_players}    capture=moved.png
    Should Not Be Equal    ${initial}[players][0][body][position]    ${moved}[players][0][body][position]
    Should Not Be Equal    ${initial}[players][1][body][position]    ${moved}[players][1][body][position]
    Should Be Equal    ${{ $moved['frame'] - $initial['frame'] }}    ${30}
    Move Stick For Ticks    1    0    2    expected_error=invalid input state
    ${after_error}=    Observe Game
    Should Be Equal    ${moved}    ${after_error}
    ${reset}=    Reset Game    room=demo    players=2    seed=84
    Should Be Equal    ${initial}    ${reset}
    ${replayed}=    Advance Ticks    30    gamepads=${both_players}    capture=replayed.png
    Should Be Equal    ${moved}    ${replayed}
    Images Should Match    moved.png    replayed.png
