*** Settings ***
Resource         game.resource
Test Teardown    Save Journey Evidence

*** Test Cases ***
Grass contact, swimming foam and wakes, frozen visuals and replay
    ${initial}=    Reset Game    capture=start.png
    ${grass}=    Advance Ticks    220    W    A    capture=grass.png
    Should Be True    $grass['visual']['grass_contacts'] > 0
    Should Be True    $grass['visual']['grass_trails'] > 0
    ${entry}=    Advance Ticks    180    A    S    capture=entry.png
    ${swimming}=    Advance Ticks    60    A    S    capture=swimming.png
    Should Be Equal    ${swimming}[players][0][body][swimming]    ${True}
    Should Be True    $swimming['visual']['water_contacts'] > 0
    Should Be True    $swimming['visual']['wakes'] > 0
    Sleep    0.5s
    ${frozen}=    Observe Game
    Should Be Equal    ${swimming}    ${frozen}
    ${calm}=    Advance Ticks    120    capture=calm.png
    ${reset}=    Reset Game
    Should Be Equal    ${initial}    ${reset}
    Advance Ticks    220    W    A
    Advance Ticks    180    A    S
    ${replayed}=    Advance Ticks    60    A    S    capture=replayed.png
    Should Be Equal    ${swimming}    ${replayed}
    Images Should Match    swimming.png    replayed.png
