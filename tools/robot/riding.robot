*** Settings ***
Resource         game.resource
Resource         routes.resource
Test Teardown    Save Journey Evidence

*** Test Cases ***
Mount, stride blend, turn banking, airborne pose and dismount replay
    ${initial}=    Reset Game
    Approach Horse And Mount
    ${mounted}=    Advance Ticks    30    capture=mounted.png
    Should Be Equal    ${mounted}[players][0][mounted]    ${8}
    ${riding}=    Advance Ticks    60    S    D    capture=riding.png
    ${turning}=    Advance Ticks    45    S    A    capture=turning.png
    ${jump}=    Advance Ticks    1    H    capture=jump.png
    ${airborne}=    Advance Ticks    18    capture=airborne.png
    ${landed}=    Advance Ticks    120    capture=landed.png
    ${dismount}=    Advance Ticks    1    J    capture=dismount.png
    Should Be Equal    ${dismount}[players][0][mounted]    ${0}
    ${settled}=    Advance Ticks    80
    Sleep    0.5s
    ${idle}=    Observe Game
    Should Be Equal    ${settled}    ${idle}
    ${reset}=    Reset Game
    Should Be Equal    ${initial}    ${reset}
    Approach Horse And Mount
    Advance Ticks    30
    Advance Ticks    60    S    D
    ${replayed}=    Advance Ticks    45    S    A    capture=replayed.png
    Should Be Equal    ${turning}    ${replayed}
    Images Should Match    turning.png    replayed.png
    Advance Ticks    1    H
    Advance Ticks    18
    Advance Ticks    120
    Advance Ticks    1    J
    Advance Ticks    80
