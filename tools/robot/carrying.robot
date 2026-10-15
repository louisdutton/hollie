*** Settings ***
Resource         game.resource
Resource         routes.resource
Test Setup       Start Journey
Test Teardown    Finish Journey

*** Test Cases ***
Pickup, carry, placement, jump throws and inherited momentum
    ${initial}=    Reset Game
    Approach Crate And Pick Up
    ${carrying}=    Advance Ticks    20    capture=carrying.png
    Should Be True    $carrying['players'][0]['carrying'] > 0
    ${walking}=    Advance Ticks    60    S    D    capture=carrying-walk.png
    ${turning}=    Advance Ticks    25    S    A    capture=carrying-turn.png
    ${dropped}=    Advance Ticks    1    J    capture=dropped.png
    Should Be Equal    ${dropped}[players][0][carrying]    ${0}
    ${settled}=    Advance Ticks    60    capture=settled.png
    ${reset}=    Reset Game
    Should Be Equal    ${initial}    ${reset}
    Approach Crate And Pick Up
    Advance Ticks    20
    Advance Ticks    60    S    D
    ${replayed}=    Advance Ticks    25    S    A    capture=carry-replayed.png
    Should Be Equal    ${turning}    ${replayed}
    Images Should Match    carrying-turn.png    carry-replayed.png
    Advance Ticks    1    J
    Advance Ticks    60

    Reset Game
    Approach Crate And Pick Up
    ${rising_holding}=    Advance Ticks    20    capture=rising-holding.png
    Should Be Equal    ${rising_holding}[players][0][carrying]    ${13}
    Should Be True    22.3 <= $rising_holding['holdables'][0]['held_anchor']['y'] <= 40
    Advance Ticks    4    H
    ${rising}=    Advance Ticks    1    J    capture=rising-throw.png
    Should Be Equal    ${rising}[players][0][carrying]    ${0}
    Should Be Equal    ${rising}[players][0][body][grounded]    ${False}
    Should Be True    abs($rising['holdables'][0]['body']['vertical_velocity'] - $rising['players'][0]['body']['vertical_velocity'] - 15) <= 0.001
    Should Be True    100 <= $rising['holdables'][0]['body']['vertical_velocity'] <= 250
    Reset Game
    Approach Crate And Pick Up
    ${simultaneous_holding}=    Advance Ticks    20    capture=simultaneous-holding.png
    Should Be Equal    ${simultaneous_holding}[players][0][carrying]    ${13}
    Should Be True    22.3 <= $simultaneous_holding['holdables'][0]['held_anchor']['y'] <= 40
    ${simultaneous}=    Advance Ticks    1    H    J    capture=simultaneous-throw.png
    Should Be Equal    ${simultaneous}[players][0][carrying]    ${0}
    Should Be Equal    ${simultaneous}[players][0][body][grounded]    ${False}
    Should Be True    abs($simultaneous['holdables'][0]['body']['vertical_velocity'] - $simultaneous['players'][0]['body']['vertical_velocity'] - 15) <= 0.001
    Should Be True    100 <= $simultaneous['holdables'][0]['body']['vertical_velocity'] <= 250
    Reset Game
    Approach Crate And Pick Up
    ${falling_holding}=    Advance Ticks    20    capture=falling-holding.png
    Should Be Equal    ${falling_holding}[players][0][carrying]    ${13}
    Should Be True    22.3 <= $falling_holding['holdables'][0]['held_anchor']['y'] <= 40
    Advance Ticks    1    H
    Advance Ticks    21
    ${falling}=    Advance Ticks    1    J    capture=falling-throw.png
    Should Be Equal    ${falling}[players][0][carrying]    ${0}
    Should Be Equal    ${falling}[players][0][body][grounded]    ${False}
    Should Be True    abs($falling['holdables'][0]['body']['vertical_velocity'] - $falling['players'][0]['body']['vertical_velocity'] - 15) <= 0.001
    Should Be True    -200 <= $falling['holdables'][0]['body']['vertical_velocity'] <= -1
