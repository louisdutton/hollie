*** Settings ***
Resource         game.resource
Resource         routes.resource
Test Setup       Start Journey
Test Teardown    Finish Journey

*** Test Cases ***
Bison charge, head lowering, heavy gait and rider banking replay
    ${initial}=    Reset Game
    Approach Bison And Mount
    ${mounted}=    Advance Ticks    30    capture=bison-mounted.png
    Should Be Equal    ${mounted}[players][0][mounted]    ${9}
    ${charge}=    Advance Ticks    120    S    D    capture=bison-charge.png
    Should Be Equal    ${charge}[enemies][2][body][ram_ready]    ${True}
    Should Be True    $charge['enemies'][2]['body']['ram'] > 0
    ${bank}=    Advance Ticks    25    S    A    capture=bison-bank.png
    ${rest}=    Advance Ticks    80    capture=bison-rest.png
    ${reset}=    Reset Game
    Should Be Equal    ${initial}    ${reset}
    Approach Bison And Mount
    Advance Ticks    30
    ${replayed}=    Advance Ticks    120    S    D    capture=bison-replayed.png
    Should Be Equal    ${charge}    ${replayed}
    Images Should Match    bison-charge.png    bison-replayed.png
    Advance Ticks    25    S    A
    Advance Ticks    80
