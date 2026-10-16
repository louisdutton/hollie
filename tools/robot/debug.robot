*** Settings ***
Resource         game.resource
Test Setup       Start Journey
Test Teardown    Finish Journey

*** Test Cases ***
Right-stick collider overlay, held-input edges, keyboard fallback and reset
    ${off}=    Reset Game    capture=off.png
    Should Be Equal    ${off}[debug][enabled]    ${False}
    ${on}=    Press Gamepad For Ticks    1    RIGHT_THUMB    capture=on.png
    Should Be Equal    ${on}[debug][enabled]    ${True}
    Should Be True    $on['debug']['colliders'] > 0
    ${frozen}=    Observe Game    capture=frozen.png
    Should Be Equal    ${on}    ${frozen}
    Images Should Match    on.png    frozen.png
    ${held}=    Press Gamepad For Ticks    4    RIGHT_THUMB
    Should Be Equal    ${held}[debug][enabled]    ${True}
    Advance Ticks    1
    ${off_again}=    Press Gamepad For Ticks    1    RIGHT_THUMB    capture=off-again.png
    Should Be Equal    ${off_again}[debug][enabled]    ${False}
    Should Be Equal    ${off_again}[debug][colliders]    ${0}
    ${keyboard}=    Advance Ticks    1    F3    capture=keyboard.png
    Should Be Equal    ${keyboard}[debug][enabled]    ${True}
    ${editor}=    Advance Ticks    1    F1
    ${still_editor}=    Advance Ticks    1    F3
    Should Be Equal    ${still_editor}[debug][colliders]    ${0}
    Should Be Equal    ${editor}[debug][enabled]    ${still_editor}[debug][enabled]
    ${reset}=    Reset Game    capture=reset.png
    Should Be Equal    ${reset}[debug][enabled]    ${False}
    Should Be Equal    ${off}    ${reset}
    Images Should Match    off.png    reset.png
