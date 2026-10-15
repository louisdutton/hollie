*** Settings ***
Resource         game.resource
Resource         routes.resource
Test Teardown    Save Journey Evidence

*** Test Cases ***
Pickup, hand-anchored carry, turn and release replay
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
